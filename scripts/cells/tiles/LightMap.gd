extends Node2D
class_name LightMap

const CELL := 8
const TILE := 16
const DIRS := LightFlood.DIRS
const STRAIGHT := LightFlood.STRAIGHT
const DIAGONAL := LightFlood.DIAGONAL
const PATH_SLACK := LightFlood.PATH_SLACK

@export var tile_initialize: TileInitialize
@export var player_root: Node
@export var light_radius := 128.0
@export var view_half := 320

var _wall_data: TileMapLayer
var _floor_data: TileMapLayer
const MAX_OTHERS := 3

# One light per player: its own window of cells and the flood results inside it.
class Light:
	var image: Image
	var texture: ImageTexture
	var top_left := Vector2i.ZERO
	var reached: Array[Vector2i] = []
	var cost := {}
	var last_origin := Vector2i(-99999, -99999)
	var last_light_pos := Vector2(INF, INF)
	var light_pos := Vector2.ZERO

var _local: Light
var _others := {}  # other player's node -> Light (vision is shared; at most MAX_OTHERS are drawn)
var _side := 0
var _sprite: Sprite2D
var _blocked_cache := {}
var _door_version := 0
var _glow_cost := {}
var _glow_from := {}
var _glow_seed := {}
var _glow_sources: Array = []
var _glow_reached: Array[Vector2i] = []
var _glow_image: Image
var _glow_texture: ImageTexture
var _tint: Sprite2D
var _glow_top_left := Vector2i.ZERO

var _shading: ShaderMaterial = load("res://resources/shaders/normal_lit_material.tres")

func _ready() -> void:
	_wall_data = tile_initialize.get_node("WallData")
	_floor_data = tile_initialize.get_node("FloorData")
	_side = int(view_half * 2.0 / CELL) + 1
	_local = _make_light()
	_glow_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_glow_image.fill(Color(0, 0, 0, 1))
	_glow_texture = ImageTexture.create_from_image(_glow_image)
	_sprite = Sprite2D.new()
	_sprite.texture = _local.texture
	_sprite.centered = false
	_sprite.scale = Vector2(CELL, CELL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var smooth := ShaderMaterial.new()
	smooth.shader = load("res://resources/shaders/light_smooth.gdshader")
	smooth.set_shader_parameter("cell_size", float(CELL))
	smooth.set_shader_parameter("glow_map", _glow_texture)
	_sprite.material = smooth
	_sprite.z_index = 2000
	add_child(_sprite)
	_tint = Sprite2D.new()
	_tint.texture = _glow_texture
	_tint.centered = false
	_tint.scale = Vector2(CELL, CELL)
	_tint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tint := ShaderMaterial.new()
	tint.shader = load("res://resources/shaders/glow_tint.gdshader")
	tint.set_shader_parameter("cell_size", float(CELL))
	_tint.material = tint
	_tint.z_index = 2001
	add_child(_tint)
	bake_glow()

func bake_glow() -> void:
	_blocked_cache.clear()
	var tiles := _floor_data.get_used_rect().merge(_wall_data.get_used_rect())
	_scan_glow_sources(tiles)
	_glow_top_left = tiles.position * 2
	_glow_image = Image.create(tiles.size.x * 2, tiles.size.y * 2, false, Image.FORMAT_RGBA8)
	_glow_texture = ImageTexture.create_from_image(_glow_image)
	_flood_glow()
	_paint_glow()
	_tint.texture = _glow_texture
	_tint.position = Vector2(_glow_top_left * CELL)
	var smooth: ShaderMaterial = _sprite.material
	smooth.set_shader_parameter("glow_map", _glow_texture)
	smooth.set_shader_parameter("glow_origin", _tint.position)
	smooth.set_shader_parameter("glow_size", Vector2(_glow_image.get_size()))

func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	_process_inner()
	DebugState.add_time("light", Time.get_ticks_usec() - started)

func _process_inner() -> void:
	var player := _local_player()
	if player == null:
		return
	_sprite.visible = not DebugState.see_all
	if DoorRegistry.version != _door_version:
		# A door opened or closed: every light re-floods next update.
		_door_version = DoorRegistry.version
		_local.last_origin = Vector2i(-99999, -99999)
		for other: Light in _others.values():
			other.last_origin = Vector2i(-99999, -99999)
	_update_light(_local, player, true)
	_shading.set_shader_parameter("light_pos", _local.light_pos)
	_update_others()

## True if any of this tile's four half-tile (CELL) cells are part of the
## local player's currently-flooded vision. Used by minion spawning to decide
## whether a spawn cell is still in view (skip it) or safe to roll into.
## Only cells the light actually shows count (not the dark fringe past its edge, see _level).
func is_tile_lit(tile: Vector2i) -> bool:
	var gap := _gap(_local)
	for dy in 2:
		for dx in 2:
			var cell := tile * 2 + Vector2i(dx, dy)
			if _local.cost.has(cell) and _level(_fraction(_local, cell, gap)) != Level.DARK:
				return true
	return false

func _local_player() -> Node2D:
	for child in player_root.get_children():
		if child.is_multiplayer_authority():
			return child as Node2D
	return null

func _make_light() -> Light:
	var light := Light.new()
	light.image = Image.create(_side, _side, false, Image.FORMAT_RGBA8)
	light.image.fill(Color(1, 0, 0, 1))
	light.texture = ImageTexture.create_from_image(light.image)
	return light

# Floods and paints one player's light, only when they moved to a new cell or moved within it.
func _update_light(light: Light, player: Node2D, is_local: bool) -> void:
	light.light_pos = (player.global_position + Vector2(TILE / 2.0, TILE / 2.0)).round()
	var origin := Vector2i((light.light_pos / CELL).floor())
	if origin != light.last_origin:
		light.last_origin = origin
		_flood(light, origin, is_local)
		light.last_light_pos = Vector2(INF, INF)
	if light.light_pos != light.last_light_pos:
		light.last_light_pos = light.light_pos
		_paint(light)

# Vision is shared: every other player carries their own light, however far from the local player
# (a ranger can see through a frontliner's eyes). The shaders take the brightest of all the lights,
# so up to MAX_OTHERS others are drawn.
func _update_others() -> void:
	var present: Array[Node2D] = []
	for child in player_root.get_children():
		if child.is_multiplayer_authority():
			continue
		# A dead player's light is only visible to other ghosts.
		if child.stats.is_ghost and not PlayerController.local_is_ghost:
			continue
		present.append(child as Node2D)
	for player in _others.keys():
		if not is_instance_valid(player) or not present.has(player):
			_others.erase(player)
	var smooth: ShaderMaterial = _sprite.material
	var positions := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var count := 0
	for player in present:
		if count >= MAX_OTHERS:
			break
		if not _others.has(player):
			_others[player] = _make_light()
		var light: Light = _others[player]
		_update_light(light, player, false)
		count += 1
		smooth.set_shader_parameter("other_map_%d" % count, light.texture)
		smooth.set_shader_parameter("other_origin_%d" % count, Vector2(light.top_left * CELL))
		positions[count - 1] = light.light_pos
	smooth.set_shader_parameter("other_count", count)
	_shading.set_shader_parameter("other_lights", positions)
	_shading.set_shader_parameter("other_light_count", count)

func _scan_glow_sources(tiles: Rect2i) -> void:
	_glow_sources.clear()
	var glowing := tile_initialize.glow_sources
	if glowing.is_empty():
		return
	for ty in range(tiles.position.y, tiles.end.y):
		for tx in range(tiles.position.x, tiles.end.x):
			var tile := Vector2i(tx, ty)
			var id := _floor_data.get_cell_source_id(tile)
			if not glowing.has(id):
				id = _wall_data.get_cell_source_id(tile)
			if glowing.has(id):
				var type: TileType = glowing[id]
				_glow_sources.append({"tile": tile, "radius": type.glow_radius, "color": type.glow_color})

func _paint(light: Light) -> void:
	var image := light.image
	image.fill(Color(1, 0, 0, 1))
	var gap := _gap(light)
	for cell in light.reached:
		var pixel := cell - light.top_left
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
			continue
		image.set_pixelv(pixel, Color(_fraction(light, cell, gap), 0, 0, 1))
	light.texture.update(image)

## How far out a lit cell is: 0 at the light, 1 at the edge of light_radius (farther of the
## straight line and the way round walls). What the darkness is shaded by, and what levels use.
func _fraction(light: Light, cell: Vector2i, gap: float) -> float:
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var straight := (centre - light.light_pos).length()
	var walked: float = light.cost[cell] * CELL / (STRAIGHT * 1.0824) - gap
	return minf(maxf(straight, walked) / light_radius, 1.0)

func _gap(light: Light) -> float:
	return ((Vector2(light.last_origin) + Vector2(0.5, 0.5)) * CELL - light.light_pos).length()

## Light levels, for seeing by: BRIGHT out to BRIGHT_FRACTION of light_radius, DIM from there
## to the edge, DARK where the light does not reach.
enum Level { DARK, DIM, BRIGHT }
const BRIGHT_FRACTION := 0.5

## Every cell (CELL-sized) the local player's light reaches, with its Level.
func local_levels() -> Dictionary:
	var levels := {}
	if _local == null:
		return levels
	var gap := _gap(_local)
	for cell in _local.reached:
		var level := _level(_fraction(_local, cell, gap))
		if level != Level.DARK:
			levels[cell] = level
	return levels

## The flood runs a little past light_radius (PATH_SLACK, and one cell of rounding); those cells
## are painted fully dark (fraction 1), so they are DARK here too.
static func _level(fraction: float) -> Level:
	if fraction >= 1.0:
		return Level.DARK
	return Level.BRIGHT if fraction <= BRIGHT_FRACTION else Level.DIM

func _paint_glow() -> void:
	_glow_image.fill(Color(0, 0, 0, 1))
	for cell in _glow_reached:
		var pixel := cell - _glow_top_left
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= _glow_image.get_width() or pixel.y >= _glow_image.get_height():
			continue
		var source: Dictionary = _glow_sources[_glow_from[cell]]
		var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
		var source_centre: Vector2 = (Vector2(source["tile"]) + Vector2(0.5, 0.5)) * TILE
		var beyond := (centre - source_centre).abs() - Vector2(TILE / 2.0, TILE / 2.0)
		var straight := Vector2(maxf(beyond.x, 0.0), maxf(beyond.y, 0.0)).length()
		var walked: float = (_glow_cost[cell] - source["head"]) * CELL / (STRAIGHT * 1.0824) - CELL * 0.75
		var fraction: float = maxf(straight, walked) / source["radius"]
		var color: Color = source["color"]
		_glow_image.set_pixelv(pixel, Color(color.r, color.g, color.b, minf(fraction, 1.0)))
	_glow_texture.update(_glow_image)

func _flood(light: Light, origin: Vector2i, is_local: bool) -> void:
	_blocked_cache.clear()
	var half := int(_side / 2.0)
	light.top_left = origin - Vector2i(half, half)
	if is_local:
		_sprite.position = Vector2(light.top_left * CELL)
		_sprite.material.set_shader_parameter("window_origin", _sprite.position)
	var radius_cells := light_radius / CELL
	var flood := LightFlood.flood(origin, radius_cells, _is_blocked)
	_reveal_doors(flood)
	light.cost = flood["cost"]
	light.reached = flood["reached"]

# The flood stops at the first cell of a closed solid door, so the rest of it (the far half of a
# vertical door, the overhang above a horizontal one) would stay dark. Once any part of a door is
# lit, light all of it at the same cost, so it draws whole from whichever side it is seen.
func _reveal_doors(flood: Dictionary) -> void:
	var cost: Dictionary = flood["cost"]
	var reached: Array = flood["reached"]
	for door: DoorRegistry.Door in DoorRegistry.doors:
		if door.is_open or door.transparent:
			continue
		var best := -1
		for tile in door.cells:
			for c in _half_cells(tile):
				if cost.has(c) and (best < 0 or cost[c] < best):
					best = cost[c]
		if best < 0:
			continue
		var shown: Array[Vector2i] = door.cells.duplicate()
		for entry in door.pieces:
			shown.append(entry["cell"] + Vector2i(0, -1))
		for tile in shown:
			for c in _half_cells(tile):
				if not cost.has(c):
					cost[c] = best
					reached.append(c)

# The four half-tile (CELL) cells that make up one tile.
func _half_cells(tile: Vector2i) -> Array[Vector2i]:
	var base := tile * 2
	return [base, base + Vector2i(1, 0), base + Vector2i(0, 1), base + Vector2i(1, 1)]

func _flood_glow() -> void:
	_glow_cost.clear()
	_glow_from.clear()
	_glow_seed.clear()
	_glow_reached.clear()
	if _glow_sources.is_empty():
		return
	var biggest := 0.0
	for source in _glow_sources:
		biggest = maxf(biggest, source["radius"])
	var max_cost := int(biggest / CELL * STRAIGHT * PATH_SLACK)
	var buckets: Array = []
	buckets.resize(max_cost + DIAGONAL + 1)
	for i in _glow_sources.size():
		var source: Dictionary = _glow_sources[i]
		var head := max_cost - int(source["radius"] / CELL * STRAIGHT * PATH_SLACK)
		source["head"] = head
		for dy in 2:
			for dx in 2:
				var cell: Vector2i = source["tile"] * 2 + Vector2i(dx, dy)
				_glow_cost[cell] = head
				_glow_from[cell] = i
				_glow_seed[cell] = true
				if buckets[head] == null:
					buckets[head] = []
				buckets[head].append(cell)
	var bounds := _glow_image.get_size()
	for level in range(max_cost + 1):
		if buckets[level] == null:
			continue
		for cell: Vector2i in buckets[level]:
			if _glow_cost[cell] != level:
				continue
			_glow_reached.append(cell)
			if _is_blocked(cell) and not _glow_seed.has(cell):
				continue
			if _glow_seed.has(cell) and _is_interior_seed(cell):
				continue
			for dir in DIRS:
				var step := DIAGONAL if dir.x != 0 and dir.y != 0 else STRAIGHT
				if step == DIAGONAL and (_is_blocked(cell + Vector2i(dir.x, 0)) or _is_blocked(cell + Vector2i(0, dir.y))):
					continue
				var next: Vector2i = cell + dir
				var next_cost: int = level + step
				var pixel := next - _glow_top_left
				if next_cost > max_cost or pixel.x < 0 or pixel.y < 0 or pixel.x >= bounds.x or pixel.y >= bounds.y:
					continue
				if _glow_cost.has(next) and _glow_cost[next] <= next_cost:
					continue
				_glow_cost[next] = next_cost
				_glow_from[next] = _glow_from[cell]
				if buckets[next_cost] == null:
					buckets[next_cost] = []
				buckets[next_cost].append(next)

func _is_interior_seed(cell: Vector2i) -> bool:
	for dir in DIRS:
		if not _glow_seed.has(cell + dir):
			return false
	return true

func _is_blocked(cell: Vector2i) -> bool:
	var tile := Vector2i(floori(cell.x * CELL / float(TILE)), floori(cell.y * CELL / float(TILE)))
	if _blocked_cache.has(tile):
		return _blocked_cache[tile]
	var blocked := TileSolid.is_solid(_wall_data, _floor_data, tile) or DoorRegistry.blocks_sight(tile)
	_blocked_cache[tile] = blocked
	return blocked
