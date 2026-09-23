class_name GridMover
extends Node

## Moves the parent node one tile at a time across the dungeon grid,
## respecting walls/doors and per-tile terrain speed. Shared by anything
## that walks the dungeon tilemap -- players, antagonist, enemies.

@export var tile_size := 16
@export var move_time := 0.2

@onready var _body: Node2D = get_parent()

@onready var wall_data: TileMapLayer = get_tree().current_scene.find_child("WallData", true, false)
@onready var floor_data: TileMapLayer = get_tree().current_scene.find_child("FloorData", true, false)

@onready var _open_door_source_id: int = TileTypeRegistry.new().get_id("wall_door_open")
@onready var _void_source_id: int = TileTypeRegistry.new().get_id("floor_void")

var is_moving := false
var facing_direction := Vector2.DOWN

var _floor_speed := {}

func _ready() -> void:
	_build_floor_speeds()

func _build_floor_speeds() -> void:
	var registry := TileTypeRegistry.new()
	var dir := DirAccess.open("res://game/tiles/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var tile := TileType.new()
		tile.load_from_file("res://game/tiles/" + file_name)
		if tile.category == TileType.Category.FLOOR:
			_floor_speed[registry.get_id(tile.tile_name)] = tile.move_speed()

func _floor_source_at(target_global: Vector2) -> int:
	if floor_data == null:
		return -1
	var cell: Vector2i = floor_data.local_to_map(floor_data.to_local(target_global))
	return floor_data.get_cell_source_id(cell)

func _is_blocked(target_global: Vector2) -> bool:
	if wall_data == null:
		return false
	var cell: Vector2i = wall_data.local_to_map(wall_data.to_local(target_global))
	var source_id := wall_data.get_cell_source_id(cell)
	if source_id != -1 and source_id != _open_door_source_id:
		return true
	return _floor_source_at(target_global) == _void_source_id

func move_one_tile(direction: Vector2) -> void:
	var origin_global: Vector2 = _body.global_position
	var target_global := origin_global + direction * tile_size
	if _is_blocked(target_global):
		return
	facing_direction = direction
	is_moving = true

	# Terrain speed is decided by whichever tile has the majority of the body
	# on it, not the destination tile the instant the step starts -- so the
	# first half of the step (still mostly on the old tile) uses the old
	# tile's speed, and only the second half uses the new tile's.
	var midpoint: Vector2 = origin_global.lerp(target_global, 0.5)
	var origin_speed: float = _floor_speed.get(_floor_source_at(origin_global), 1.0)
	var target_speed: float = _floor_speed.get(_floor_source_at(target_global), 1.0)
	var half_time := move_time / 2.0

	var tween := create_tween()
	tween.tween_property(_body, "global_position", midpoint, half_time / origin_speed)
	tween.tween_property(_body, "global_position", target_global, half_time / target_speed)
	tween.finished.connect(func(): is_moving = false)
