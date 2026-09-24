class_name DoorManager
extends Node2D

## Draws every door in DoorRegistry and plays their open / close animation, and
## (host / singleplayer only) closes a door again once nobody is near it. The
## open/closed STATE lives in DoorRegistry and is synced by NetworkSync; this
## node only shows it.
##
## Art comes from each door type's art json (resources/gfx/doors/<Style>_W<n>.json):
## 8 frames left to right, closed -> open. A frame is `frame_size` (16x32 for most
## doors, 16x48 for the tall boss doors) and its bottom 16 rows are the piece's own
## doorway cell (`own_cell_row` is where that starts); everything above hangs over
## the cells to the north.
##
## A LAYERED manifest (the boss doors in doors.boss/, it has a "layers" map) is
## drawn as up to three sprites per piece: frame (posts, picked by the wall the
## door stands in), leaves (the sliding halves, picked by the door's tier, the
## only layer that animates) and overlay (the lintel, above creatures).

const SHADING_MATERIAL := preload("res://resources/shaders/normal_lit_material.tres")
const TILE := 16
## Just above the wall tiles (sort_order 100), so a door covers the wall top it overlaps.
const DOOR_Z := 101
## Creatures draw at z 1000 (players 1500), the light overlay at 2000. A piece is
## normally UNDER creatures (you stand in front of it, on or south of its cell);
## while a creature is on one of the two cells just north of it (two, so it is already
## lifted before the creature steps onto the overhang cell, no clipping mid-step) -- behind it, under its
## overhang -- the piece is lifted over them so it covers their lower body.
const BEHIND_Z := 1600
## A boss door's overlay (the lintel, baked 50% alpha) always draws above creatures
## so they walk under it; still below the light overlay at 2000.
const OVERLAY_Z := 1800
const LAYER_INTERVAL := 0.05
const CLOSE_DELAY := 2.0
const CHECK_INTERVAL := 0.25

var _art := {}       # "type:width:tier:wall" -> {"layers": [{"texture": CanvasTexture, "animated": bool, "overlay": bool}], "pieces": Dictionary, "frames": int, "frame_size": Vector2i, "own_cell_row": int}
var _visuals: Array = []  # [{"door": Door, "sprites": Array, "frame": float, "shown": int}]
var _empty_for := {}  # door id -> seconds nobody has been near it
var _check_left := 0.0
var _layer_left := 0.0

func build() -> void:
	for door: DoorRegistry.Door in DoorRegistry.doors:
		var art := _load_art(door)
		if art.is_empty():
			continue
		var sprites: Array = []
		for entry in door.pieces:
			if not art["pieces"].has(entry["piece"]):
				push_warning("DoorManager: art for '%s' (width %d) has no piece '%s'" % [door.type, door.width, entry["piece"]])
				continue
			var cell: Vector2i = entry["cell"]
			for layer: Dictionary in art["layers"]:
				var sprite := Sprite2D.new()
				sprite.texture = layer["texture"]
				sprite.centered = false
				sprite.region_enabled = true
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.material = SHADING_MATERIAL
				sprite.z_index = OVERLAY_Z if layer["overlay"] else DOOR_Z
				sprite.position = Vector2(cell.x * TILE, cell.y * TILE - art["own_cell_row"])
				sprite.set_meta("cell", cell)
				sprite.set_meta("atlas_y", art["pieces"][entry["piece"]]["atlas_y"])
				sprite.set_meta("frame_size", art["frame_size"])
				sprite.set_meta("animated", layer["animated"])
				sprite.set_meta("overlay", layer["overlay"])
				add_child(sprite)
				sprites.append(sprite)
		var visual := {"door": door, "sprites": sprites, "frame": 0.0, "shown": -1}
		_show_frame(visual, 0)
		_visuals.append(visual)

## Leaving the dungeon (back to town) must not leave stale doors in the registry.
func _exit_tree() -> void:
	DoorRegistry.clear()

func _art_key(door: DoorRegistry.Door) -> String:
	return "%s:%d:%s:%s" % [door.type, door.width, door.tier, door.wall_tile]

## A type's "art" is one manifest path, or a map of width -> path when each width
## has its own art (game/doors/wood.json).
func _load_art(door: DoorRegistry.Door) -> Dictionary:
	var key := _art_key(door)
	if _art.has(key):
		return _art[key]
	var def := DoorRegistry.get_def(door.type)
	var art_setting = def.get("art", "")
	var art_path: String = art_setting.get(str(door.width), "") if art_setting is Dictionary else art_setting
	var file := FileAccess.open(art_path, FileAccess.READ) if art_path != "" else null
	if file == null:
		push_warning("DoorManager: no art json for door type '%s' at width %d (%s)" % [door.type, door.width, art_path])
		_art[key] = {}
		return {}
	var json: Dictionary = JSON.parse_string(file.get_as_text())
	var size: Array = json.get("frame_size", [TILE, TILE * 2])
	var layers: Array
	var frames: int
	if json.has("layers"):
		layers = _boss_layers(json, art_path.get_base_dir(), door)
		frames = int(_leaf_entry(json, door.tier).get("frames", 16))
	else:
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = load(art_path.get_basename() + ".png")
		canvas.normal_texture = load(art_path.get_base_dir().path_join(json.get("normal_texture", "")))
		layers = [{"texture": canvas, "animated": true, "overlay": false}]
		frames = int(json.get("frames", 8))
	_art[key] = {
		"layers": layers,
		"pieces": json["pieces"],
		"frames": frames,
		"frame_size": Vector2i(int(size[0]), int(size[1])),
		"own_cell_row": int(json.get("own_cell_row", int(size[1]) - TILE)),
	}
	return _art[key]

## The leaves entry for a tier (leaf_sets), else the plain placeholder leaves.
func _leaf_entry(json: Dictionary, tier: String) -> Dictionary:
	var sets: Dictionary = json.get("leaf_sets", {})
	return sets.get(tier, json["layers"]["leaves"])

## The layers of a boss door, in the manifest's draw_order: the frame and overlay
## of the wall set the door stands in (else the placeholder ones), and the tier's leaves.
func _boss_layers(json: Dictionary, dir: String, door: DoorRegistry.Door) -> Array:
	var frame_set: Dictionary = json.get("frame_sets", {}).get(door.wall_tile, {})
	if frame_set.is_empty():
		push_warning("DoorManager: no boss door frame set for wall '%s', using the placeholder frame" % door.wall_tile)
	var result: Array = []
	for name in json.get("draw_order", ["frame", "leaves", "overlay"]):
		var diffuse := ""
		var normal := ""
		match name:
			"frame":
				diffuse = frame_set.get("frame", json["layers"]["frame"]["texture"])
				normal = frame_set.get("normal_texture", json["layers"]["frame"].get("normal_texture", ""))
			"leaves":
				var leaves := _leaf_entry(json, door.tier)
				diffuse = leaves["texture"]
				normal = leaves.get("normal_texture", "")
			"overlay":
				diffuse = frame_set.get("overlay", json["layers"]["overlay"]["texture"])
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = load(dir.path_join(diffuse))
		if normal != "":
			canvas.normal_texture = load(dir.path_join(normal))
		result.append({"texture": canvas, "animated": name == "leaves", "overlay": name == "overlay"})
	return result

func _process(delta: float) -> void:
	DoorRegistry.tick()
	_layer_left -= delta
	if _layer_left <= 0.0:
		_layer_left = LAYER_INTERVAL
		_update_layering()
	for visual in _visuals:
		var door: DoorRegistry.Door = visual["door"]
		var last: float = _art[_art_key(door)]["frames"] - 1
		var target := last if door.is_open else 0.0
		if visual["frame"] != target:
			visual["frame"] = move_toward(visual["frame"], target, delta * last / maxf(door.open_seconds, 0.01))
		var frame := roundi(visual["frame"])
		if frame != visual["shown"]:
			_show_frame(visual, frame)
	if _is_authority():
		_check_left -= delta
		if _check_left <= 0.0:
			_check_left = CHECK_INTERVAL
			_auto_close()

## Puts each piece of a horizontal door over or under the creatures next to it (see BEHIND_Z).
func _update_layering() -> void:
	var occupied := {}
	for group in ["protagonist", "antagonist"]:
		for body: Node2D in get_tree().get_nodes_in_group(group):
			occupied[Vector2i(floori(body.global_position.x / TILE), floori(body.global_position.y / TILE))] = true
	for visual in _visuals:
		# Only doors in a north/south wall have a "behind"; a door in an east/west
		# wall is walked through side on, so it stays under creatures.
		if not visual["door"].horizontal:
			continue
		for sprite: Sprite2D in visual["sprites"]:
			if sprite.get_meta("overlay"):
				continue
			var cell: Vector2i = sprite.get_meta("cell")
			sprite.z_index = BEHIND_Z if occupied.has(cell + Vector2i.UP) or occupied.has(cell + Vector2i.UP * 2) else DOOR_Z

func _show_frame(visual: Dictionary, frame: int) -> void:
	visual["shown"] = frame
	for sprite: Sprite2D in visual["sprites"]:
		var size: Vector2i = sprite.get_meta("frame_size")
		var column: int = frame if sprite.get_meta("animated") else 0
		sprite.region_rect = Rect2(column * size.x, sprite.get_meta("atlas_y"), size.x, size.y)

func _is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()

## An open door shuts again CLOSE_DELAY seconds after the last creature left
## it -- "near" means on one of its cells or on any tile touching one.
func _auto_close() -> void:
	var occupied := {}
	for group in ["protagonist", "antagonist"]:
		for body: Node2D in get_tree().get_nodes_in_group(group):
			if "stats" in body and body.stats != null and body.stats.is_ghost:
				continue
			occupied[Vector2i(floori(body.global_position.x / TILE), floori(body.global_position.y / TILE))] = true
	for visual in _visuals:
		var door: DoorRegistry.Door = visual["door"]
		if not door.is_open:
			_empty_for.erase(door.id)
			continue
		if _anyone_near(door, occupied):
			_empty_for[door.id] = 0.0
			continue
		_empty_for[door.id] = _empty_for.get(door.id, 0.0) + CHECK_INTERVAL
		if _empty_for[door.id] >= CLOSE_DELAY:
			_empty_for.erase(door.id)
			NetworkSync.set_door(door.id, false)

func _anyone_near(door: DoorRegistry.Door, occupied: Dictionary) -> bool:
	for cell in door.cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if occupied.has(cell + Vector2i(dx, dy)):
					return true
	return false
