class_name DoorManager
extends Node2D

## Draws every door in DoorRegistry and plays their open / close animation, and
## (host / singleplayer only) closes a door again once nobody is near it. The
## open/closed STATE lives in DoorRegistry and is synced by NetworkSync; this
## node only shows it.
##
## Art comes from each door type's art json (resources/gfx/doors/door_*.json):
## 8 frames left to right, closed -> open, 16x32 per piece. Each piece is drawn
## on its doorway cell with the top 16 rows hanging over the cell to the north.

const SHADING_MATERIAL := preload("res://resources/shaders/normal_lit_material.tres")
const TILE := 16
## Just above the wall tiles (sort_order 100), so a door covers the wall top it overlaps.
const DOOR_Z := 101
const CLOSE_DELAY := 2.0
const CHECK_INTERVAL := 0.25

var _art := {}       # door type -> {"texture": CanvasTexture, "pieces": Dictionary, "frames": int}
var _visuals: Array = []  # [{"door": Door, "sprites": Array, "frame": float, "shown": int}]
var _empty_for := {}  # door id -> seconds nobody has been near it
var _check_left := 0.0

func build() -> void:
	for door: DoorRegistry.Door in DoorRegistry.doors:
		var art := _load_art(door.type)
		if art.is_empty():
			continue
		var sprites: Array = []
		for entry in door.pieces:
			var sprite := Sprite2D.new()
			sprite.texture = art["texture"]
			sprite.centered = false
			sprite.region_enabled = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.material = SHADING_MATERIAL
			sprite.z_index = DOOR_Z
			var cell: Vector2i = entry["cell"]
			sprite.position = Vector2(cell.x * TILE, cell.y * TILE - TILE)
			sprite.set_meta("atlas_y", art["pieces"][entry["piece"]]["atlas_y"])
			add_child(sprite)
			sprites.append(sprite)
		var visual := {"door": door, "sprites": sprites, "frame": 0.0, "shown": -1}
		_show_frame(visual, 0)
		_visuals.append(visual)

## Leaving the dungeon (back to town) must not leave stale doors in the registry.
func _exit_tree() -> void:
	DoorRegistry.clear()

func _load_art(type: String) -> Dictionary:
	if _art.has(type):
		return _art[type]
	var def := DoorRegistry.get_def(type)
	var art_path: String = def.get("art", "")
	var file := FileAccess.open(art_path, FileAccess.READ)
	if file == null:
		push_warning("DoorManager: no art json for door type '%s' (%s)" % [type, art_path])
		_art[type] = {}
		return {}
	var json: Dictionary = JSON.parse_string(file.get_as_text())
	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = load(art_path.get_basename() + ".png")
	canvas.normal_texture = load(art_path.get_base_dir().path_join(json.get("normal_texture", "")))
	_art[type] = {"texture": canvas, "pieces": json["pieces"], "frames": int(json.get("frames", 8))}
	return _art[type]

func _process(delta: float) -> void:
	for visual in _visuals:
		var door: DoorRegistry.Door = visual["door"]
		var last: float = _art[door.type]["frames"] - 1
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

func _show_frame(visual: Dictionary, frame: int) -> void:
	visual["shown"] = frame
	for sprite: Sprite2D in visual["sprites"]:
		sprite.region_rect = Rect2(frame * TILE, sprite.get_meta("atlas_y"), TILE, TILE * 2)

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
