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

## Tile-coordinate version of the same wall/void/door check, for grid
## algorithms (LineOfSight, LightFlood) that work in cell units rather than
## world positions.
func is_tile_blocked(tile: Vector2i) -> bool:
	return _is_blocked(Vector2(tile) * tile_size)

## Pixel-position version, for anything that moves through continuous space
## rather than snapping tile to tile (e.g. a flying projectile) -- avoids
## ever having to round a fractional position to a tile index itself.
func is_position_blocked(global_pos: Vector2) -> bool:
	return _is_blocked(global_pos)

func _is_blocked(target_global: Vector2) -> bool:
	if wall_data == null:
		return false
	var cell: Vector2i = wall_data.local_to_map(wall_data.to_local(target_global))
	var source_id := wall_data.get_cell_source_id(cell)
	if source_id != -1 and source_id != _open_door_source_id:
		return true
	return _floor_source_at(target_global) == _void_source_id

## speed_scale lets a caller slow this one step down (e.g. an enemy that's
## investigating a noise rather than actively chasing, at half speed) without
## touching move_time itself, which stays the entity's normal baseline.
func move_one_tile(direction: Vector2, speed_scale: float = 1.0) -> void:
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
	var ignore_terrain: bool = "stats" in _body and _body.stats != null and _body.stats.is_ghost
	var origin_speed: float = (1.0 if ignore_terrain else _floor_speed.get(_floor_source_at(origin_global), 1.0)) * speed_scale
	var target_speed: float = (1.0 if ignore_terrain else _floor_speed.get(_floor_source_at(target_global), 1.0)) * speed_scale
	var half_time := move_time / 2.0

	var tween := create_tween()
	tween.tween_property(_body, "global_position", midpoint, half_time / origin_speed)
	tween.tween_property(_body, "global_position", target_global, half_time / target_speed)
	tween.finished.connect(func(): is_moving = false)
