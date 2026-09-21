extends Node2D
class_name LightMap

# Minecraft-style light: flood outward from the local player through open cells only.
# Walls get lit where light touches them but never pass it on. Everything else is black.

const CELL := 8
const TILE := 16
const DIRS := [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const STRAIGHT := 10
const DIAGONAL := 14
const PATH_SLACK := 1.1

@export var tile_initialize: TileInitialize
@export var player_root: Node
@export var light_radius := 128.0
@export var view_half := 320

var _wall_data: TileMapLayer
var _floor_data: TileMapLayer
var _void_id: int
var _open_door_id: int
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _blocked_cache := {}
var _last_origin := Vector2i(-99999, -99999)
var _last_light_pos := Vector2(INF, INF)
var _top_left := Vector2i.ZERO
var _reached: Array[Vector2i] = []
var _cost := {}

var _shading: ShaderMaterial = load("res://resources/shaders/normal_lit_material.tres")

func _ready() -> void:
	_wall_data = tile_initialize.get_node("WallData")
	_floor_data = tile_initialize.get_node("FloorData")
	_void_id = tile_initialize.tile_registry.get_id("floor_void")
	_open_door_id = tile_initialize.tile_registry.get_id("wall_door_open")
	var side := int(view_half * 2.0 / CELL) + 1
	_image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.centered = false
	_sprite.scale = Vector2(CELL, CELL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var smooth := ShaderMaterial.new()
	smooth.shader = load("res://resources/shaders/light_smooth.gdshader")
	smooth.set_shader_parameter("cell_size", float(CELL))
	_sprite.material = smooth
	_sprite.z_index = 2000
	add_child(_sprite)

func _process(_delta: float) -> void:
	var player := _local_player()
	if player == null:
		return
	var light_pos: Vector2 = (player.global_position + Vector2(TILE / 2.0, TILE / 2.0)).round()
	var origin := Vector2i((light_pos / CELL).floor())
	if origin != _last_origin:
		_last_origin = origin
		_flood(origin)
		_last_light_pos = Vector2(INF, INF)
	if light_pos != _last_light_pos:
		_last_light_pos = light_pos
		_shading.set_shader_parameter("light_pos", light_pos)
		_paint(light_pos)

func _local_player() -> Node2D:
	for child in player_root.get_children():
		if child.is_multiplayer_authority():
			return child as Node2D
	return null

func _paint(light_pos: Vector2) -> void:
	_image.fill(Color(1, 0, 0, 1))
	var gap := ((Vector2(_last_origin) + Vector2(0.5, 0.5)) * CELL - light_pos).length()
	for cell in _reached:
		var pixel := cell - _top_left
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= _image.get_width() or pixel.y >= _image.get_height():
			continue
		var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
		var straight := (centre - light_pos).length()
		var walked: float = _cost[cell] * CELL / (STRAIGHT * 1.0824) - gap
		var fraction := maxf(straight, walked) / light_radius
		_image.set_pixelv(pixel, Color(minf(fraction, 1.0), 0, 0, 1))
	_texture.update(_image)

func _flood(origin: Vector2i) -> void:
	_blocked_cache.clear()
	_reached.clear()
	var half := int(_image.get_width() / 2.0)
	_top_left = origin - Vector2i(half, half)
	_sprite.position = Vector2(_top_left * CELL)
	var radius_cells := light_radius / CELL
	var max_cost := int(radius_cells * STRAIGHT * PATH_SLACK)
	var cost := {origin: 0}
	var buckets: Array = []
	buckets.resize(max_cost + DIAGONAL + 1)
	buckets[0] = [origin]
	for level in range(max_cost + 1):
		if buckets[level] == null:
			continue
		for cell: Vector2i in buckets[level]:
			if cost[cell] != level:
				continue
			if Vector2(cell - origin).length() > radius_cells + 1.0:
				continue
			_reached.append(cell)
			if cell != origin and _is_blocked(cell):
				continue
			for dir in DIRS:
				var step := DIAGONAL if dir.x != 0 and dir.y != 0 else STRAIGHT
				if step == DIAGONAL and (_is_blocked(cell + Vector2i(dir.x, 0)) or _is_blocked(cell + Vector2i(0, dir.y))):
					continue
				var next: Vector2i = cell + dir
				var next_cost: int = level + step
				if next_cost > max_cost:
					continue
				if cost.has(next) and cost[next] <= next_cost:
					continue
				cost[next] = next_cost
				if buckets[next_cost] == null:
					buckets[next_cost] = []
				buckets[next_cost].append(next)
	_cost = cost

func _is_blocked(cell: Vector2i) -> bool:
	var tile := Vector2i(floori(cell.x * CELL / float(TILE)), floori(cell.y * CELL / float(TILE)))
	if _blocked_cache.has(tile):
		return _blocked_cache[tile]
	var wall_id := _wall_data.get_cell_source_id(tile)
	var floor_id := _floor_data.get_cell_source_id(tile)
	var blocked := (wall_id != -1 and wall_id != _open_door_id) or floor_id == -1 or floor_id == _void_id
	_blocked_cache[tile] = blocked
	return blocked
