extends Node2D
class_name PlayerVision

## What the players see, and the darkness drawn over everything they don't. A player's vision
## is the sum of their senses (adventurer.json "senses", held in their Viewer):
##   sight  every tile within sight range and line of sight (walls and closed doors stop it)
##          that some light makes DIM or BRIGHT (LightMap: torches, glowing tiles), drawn as
##          bright as that light makes it. Without a torch you still see lava far off.
##   touch  the tiles within touch range, felt in the dark and drawn dim.
## Hearing, smell and taste add nothing to the picture yet.
## Vision is shared by the team: every teammate's view adds to yours (a dead teammate's only to
## other ghosts, Viewer.shown_to_local). The AI never reads this: minions ask LightMap
## whether a torch reaches them. Minion spawning asks is_tile_seen.

const TILE := 16
## Most teammates' views drawn at once (light_smooth's sight_map_1..4).
const MAX_DRAWN := 4

@export var light_map: LightMap
## Half the size of the darkness drawn around the local player, in pixels.
@export var view_half := 320

# One player's view: which tiles their senses reach, on a window of tiles around them.
class View:
	var sight := 0.0
	var touch := 0.0
	var ghost := false
	var seen := {}     # tile -> true: in sight range and line of sight, lit or not
	var touched := {}  # tile -> true
	var image: Image
	var texture: ImageTexture
	var top_left := Vector2i.ZERO
	var last_tile := Vector2i(-99999, -99999)

var _views := {}  # Viewer -> View
var _drawn: Array[View] = []
var _door_version := 0
var _sprite: Sprite2D

func _ready() -> void:
	var side := int(view_half * 2.0 / TILE) + 1
	var blank := Image.create(side, side, false, Image.FORMAT_RGBA8)
	_sprite = Sprite2D.new()
	_sprite.texture = ImageTexture.create_from_image(blank)
	_sprite.centered = false
	_sprite.scale = Vector2(TILE, TILE)
	var shader := ShaderMaterial.new()
	shader.shader = load("res://resources/shaders/light_smooth.gdshader")
	shader.set_shader_parameter("window_cell", float(TILE))
	shader.set_shader_parameter("light_cell", float(LightMap.CELL))
	shader.set_shader_parameter("sight_cell", float(TILE))
	_sprite.material = shader
	_sprite.z_index = 2000
	add_child(_sprite)

func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	_process_inner()
	DebugState.add_time("vision", Time.get_ticks_usec() - started)

func _process_inner() -> void:
	if DoorRegistry.version != _door_version:
		_door_version = DoorRegistry.version
		for view: View in _views.values():
			view.last_tile = Vector2i(-99999, -99999)
	_update_views()
	var local := Viewer.local()
	if local == null:
		return
	_sprite.visible = not DebugState.see_all
	var half := int(view_half / float(TILE))
	_sprite.position = Vector2((_tile_of(local) - Vector2i(half, half)) * TILE)
	_send_to_shader()

## The tile a viewer stands on (their centre, so it changes halfway through a step).
static func _tile_of(viewer: Viewer) -> Vector2i:
	return Vector2i(((viewer.position + Vector2(TILE / 2.0, TILE / 2.0)) / TILE).floor())

## Every viewer's view on every machine: the host needs them all for spawning (is_tile_seen),
## the others to draw their teammates' vision.
func _update_views() -> void:
	for viewer in _views.keys():
		if not Viewer.all.has(viewer):
			_views.erase(viewer)
	_drawn.clear()
	for viewer in Viewer.local_first():
		var view: View = _views.get(viewer)
		if view == null or view.sight != viewer.sight or view.touch != viewer.touch:
			view = _make_view(viewer.sight, viewer.touch)
			_views[viewer] = view
		view.ghost = viewer.ghost
		var tile := _tile_of(viewer)
		if tile != view.last_tile:
			view.last_tile = tile
			_sense(view, tile)
		if _drawn.size() < MAX_DRAWN and Viewer.shown_to_local(viewer):
			_drawn.append(view)

func _make_view(sight: float, touch: float) -> View:
	var view := View.new()
	view.sight = sight
	view.touch = touch
	# Room for the whole sight flood (it runs PATH_SLACK past the range) and for touch.
	var half := ceili(maxf(sight * LightFlood.PATH_SLACK, touch)) + 2
	view.image = Image.create(half * 2 + 1, half * 2 + 1, false, Image.FORMAT_RGBA8)
	view.texture = ImageTexture.create_from_image(view.image)
	return view

## Works out what one player's senses reach from `tile`, and paints their sight map.
func _sense(view: View, tile: Vector2i) -> void:
	view.seen.clear()
	view.touched.clear()
	if view.sight > 0.0:
		var flood := LightFlood.flood(tile, view.sight, light_map.blocks_light)
		LightMap.reveal_doors(flood, func(t: Vector2i) -> Array: return [t])
		for t in flood["reached"]:
			view.seen[t] = true
	var reach := floori(view.touch)
	if view.touch > 0.0:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				view.touched[tile + Vector2i(dx, dy)] = true
	var half := int(view.image.get_width() / 2.0)
	view.top_left = tile - Vector2i(half, half)
	view.image.fill(Color(0, 0, 0, 1))
	for t in view.seen:
		_mark(view, t, Color(1, 0, 0, 1))
	for t in view.touched:
		var pixel: Vector2i = t - view.top_left
		if _inside(view, pixel):
			var old := view.image.get_pixelv(pixel)
			_mark(view, t, Color(old.r, 1, 0, 1))
	view.texture.update(view.image)

func _mark(view: View, tile: Vector2i, color: Color) -> void:
	var pixel := tile - view.top_left
	if _inside(view, pixel):
		view.image.set_pixelv(pixel, color)

static func _inside(view: View, pixel: Vector2i) -> bool:
	return pixel.x >= 0 and pixel.y >= 0 and pixel.x < view.image.get_width() and pixel.y < view.image.get_height()

func _send_to_shader() -> void:
	var shader: ShaderMaterial = _sprite.material
	shader.set_shader_parameter("window_origin", _sprite.position)
	shader.set_shader_parameter("glow_map", light_map.glow_texture)
	shader.set_shader_parameter("glow_origin", light_map.glow_origin())
	shader.set_shader_parameter("glow_size", light_map.glow_size())
	var lights := light_map.drawn
	for i in lights.size():
		shader.set_shader_parameter("light_map_%d" % (i + 1), lights[i].texture)
		shader.set_shader_parameter("light_origin_%d" % (i + 1), Vector2(lights[i].top_left * LightMap.CELL))
	shader.set_shader_parameter("light_count", lights.size())
	for i in _drawn.size():
		shader.set_shader_parameter("sight_map_%d" % (i + 1), _drawn[i].texture)
		shader.set_shader_parameter("sight_origin_%d" % (i + 1), Vector2(_drawn[i].top_left * TILE))
	shader.set_shader_parameter("sight_count", _drawn.size())

## True if any living player sees this tile (in sight and lit) or feels it (touch). Minion
## spawning skips these, so nothing appears in front of the party.
func is_tile_seen(tile: Vector2i) -> bool:
	for view: View in _views.values():
		if view.ghost:
			continue
		if view.touched.has(tile):
			return true
		if view.seen.has(tile):
			for cell in LightMap.half_cells(tile):
				if light_map.level_at(cell) != LightMap.Level.DARK:
					return true
	return false

## Every 8px cell the local player's team sees, with its LightMap.Level (a cell only felt by
## touch is DIM). What the debug "show-vision" overlay draws.
func team_levels() -> Dictionary:
	var levels := {}
	for view in _drawn:
		for tile in view.seen:
			for cell in LightMap.half_cells(tile):
				var level := light_map.level_at(cell, Viewer.local_is_ghost())
				if level != LightMap.Level.DARK:
					levels[cell] = maxi(levels.get(cell, LightMap.Level.DARK), level)
		for tile in view.touched:
			for cell in LightMap.half_cells(tile):
				levels[cell] = maxi(levels.get(cell, LightMap.Level.DARK), LightMap.Level.DIM)
	return levels

## The drawn teammates' views, for the per-sense debug overlays.
func drawn_views() -> Array[View]:
	return _drawn
