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

## True for a mover that flies: terrain never slows it, and its pathfinding
## ignores terrain cost. Set from the enemy JSON's "flying" (EnemyController).
var flies := false

func _ignores_terrain() -> bool:
	return flies or _is_ghost()

## How much slower than normal ground stepping onto `cell` is: 1.0 normal,
## 1.25 rough, 2.0 difficult, 5.0 severe (1 / the tile's speed). Feeds
## pathfinding's costs; never below 1.0.
func tile_cost(cell: Vector2i) -> float:
	if floor_data == null or _ignores_terrain():
		return 1.0
	return 1.0 / _floor_speed.get(floor_data.get_cell_source_id(cell), 1.0)

func _floor_source_at(target_global: Vector2) -> int:
	if floor_data == null:
		return -1
	var cell: Vector2i = floor_data.local_to_map(floor_data.to_local(target_global))
	return floor_data.get_cell_source_id(cell)

## Set by whatever owns this mover if it may only open SOME doors (an idle
## enemy leaves solid doors shut). Called with the DoorRegistry.Door, returns
## true if this mover may open it. Unset = opens any door, like a player.
var open_predicate := Callable()

func _can_open(door: DoorRegistry.Door) -> bool:
	return not open_predicate.is_valid() or open_predicate.call(door)

## True for a mover that passes through closed doors without opening them
## (a wraith). Ghost players always do.
var phases_doors := false

func _ignores_doors() -> bool:
	return phases_doors or _is_ghost() or _no_clip()

## Debug: this machine's own player ignores walls, void and doors.
func _no_clip() -> bool:
	return DebugState.no_clip and _body.is_in_group("protagonist") and _body.is_multiplayer_authority()

var _tween: Tween

## Debug: put the body on a spot right now, cancelling any step in progress.
func teleport(pos: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	is_moving = false
	for tile in _reserved.keys():
		if _reserved[tile] == _body:
			_reserved.erase(tile)
	_body.global_position = pos

func _is_ghost() -> bool:
	return "stats" in _body and _body.stats != null and _body.stats.is_ghost

## Tile-coordinate version of the same wall/void/door check, for grid
## algorithms (Pathfinding, FlowField) and step checks that work in cell units
## rather than world positions. A closed door only counts as blocked for a
## mover that can't open it -- one that can just walks into it (move_one_tile
## opens it), so paths and flow fields route straight through.
func is_tile_blocked(tile: Vector2i) -> bool:
	if _is_blocked(Vector2(tile) * tile_size):
		return true
	var door := DoorRegistry.closed_door_at(tile)
	return door != null and not _ignores_doors() and not _can_open(door)

## Walls, void and closed opaque doors: what stops SIGHT (LineOfSight,
## enemy senses). Bars (transparent doors) let you see through.
func blocks_sight(tile: Vector2i) -> bool:
	return _is_blocked(Vector2(tile) * tile_size) or DoorRegistry.blocks_sight(tile)

## Walls, void and any closed door: what stops a SHOT (ranged attack range).
func blocks_shot(tile: Vector2i) -> bool:
	return _is_blocked(Vector2(tile) * tile_size) or DoorRegistry.closed_door_at(tile) != null

## Pixel-position version, for anything that moves through continuous space
## rather than snapping tile to tile (e.g. a flying projectile) -- avoids
## ever having to round a fractional position to a tile index itself. A closed
## door stops a projectile the same as a wall.
func is_position_blocked(global_pos: Vector2) -> bool:
	if _is_blocked(global_pos):
		return true
	var tile := Vector2i(floori(global_pos.x / tile_size), floori(global_pos.y / tile_size))
	return DoorRegistry.closed_door_at(tile) != null

## Shared per-frame index backing is_tile_occupied() -- rescanning every
## protagonist/antagonist on every single query was O(n) per call, and with
## hundreds of enemies now calling this unthrottled every frame (see
## EnemyController._try_direct_step, added once pathfinding itself got
## throttled), that added up to O(n^2) per frame and became the new
## bottleneck. Building the tile -> occupants map once per frame instead
## (Godot 4 script statics, shared by every GridMover instance regardless of
## which one triggers the rebuild) turns it back into O(n) total. Assumes
## every mover uses the same tile_size, true everywhere in this project
## today.
static var _occupancy_frame: int = -1
static var _occupancy_index: Dictionary = {}  # Vector2i -> Array[Node2D]

func _tile_occupants(tile: Vector2i) -> Array:
	var frame := Engine.get_process_frames()
	if frame != _occupancy_frame:
		_occupancy_frame = frame
		_occupancy_index.clear()
		for group in ["protagonist", "antagonist"]:
			for body: Node2D in get_tree().get_nodes_in_group(group):
				if "stats" in body and body.stats != null and body.stats.is_ghost:
					continue
				var body_tile := Vector2i(floori(body.global_position.x / tile_size), floori(body.global_position.y / tile_size))
				if not _occupancy_index.has(body_tile):
					_occupancy_index[body_tile] = []
				_occupancy_index[body_tile].append(body)
	return _occupancy_index.get(tile, [])

## True if some other creature (any protagonist or antagonist besides this
## mover's own body) is currently standing on `tile` -- lets a mover refuse
## to step onto an already-occupied tile instead of stacking on it. Ghost
## players (PlayerController.die()) are intangible and don't count, same as
## they already don't count as attack targets or collide with enemies.
func is_tile_occupied(tile: Vector2i) -> bool:
	for body in _tile_occupants(tile):
		if body != _body:
			return true
	var holder = _reserved.get(tile)
	return holder != null and is_instance_valid(holder) and holder != _body

## Destination tiles of steps already in progress (tile -> the body stepping
## onto it). A body only counts as standing on a tile once its position floors
## into it, which for a multi-frame step happens late -- so without this, two
## creatures could both see the same tile as free and both step onto it.
## Claimed in move_one_tile, released when that step's tween finishes; an entry
## whose body was freed mid-step is ignored (is_instance_valid) rather than
## needing cleanup. Ghosts never reserve, same as they never count as occupants.
static var _reserved: Dictionary = {}  # Vector2i -> Node2D

func _is_blocked(target_global: Vector2) -> bool:
	if wall_data == null or _no_clip():
		return false
	var cell: Vector2i = wall_data.local_to_map(wall_data.to_local(target_global))
	var source_id := wall_data.get_cell_source_id(cell)
	if source_id != -1:
		return true
	return _floor_source_at(target_global) == _void_source_id

## speed_scale lets a caller slow this one step down (e.g. an enemy that's
## investigating a noise rather than actively chasing, at half speed) without
## touching move_time itself, which stays the entity's normal baseline.
## Returns false if the step was refused (wall, or another living creature on or
## already stepping onto the destination -- ghosts are exempt both ways).
func move_one_tile(direction: Vector2, speed_scale: float = 1.0) -> bool:
	var origin_global: Vector2 = _body.global_position
	var target_global := origin_global + direction * tile_size
	if _is_blocked(target_global):
		return false
	var is_ghost := _is_ghost()
	var target_tile := Vector2i(floori(target_global.x / tile_size), floori(target_global.y / tile_size))
	# A door is a thin line, not a tile. Trying to cross that line while the door
	# is closed (or still swinging) opens it (if this mover may) but doesn't step
	# this call. Stepping ONTO a door cell from the front is fine and just starts
	# it opening, so you can stand in the doorway while it swings.
	# Ghosts and door-phasing enemies drift through closed doors.
	if not _ignores_doors():
		var origin_tile := Vector2i(floori(origin_global.x / tile_size), floori(origin_global.y / tile_size))
		var seam := DoorRegistry.crossing_door(origin_tile, target_tile)
		if seam != null and DoorRegistry.is_blocking(seam):
			if _can_open(seam):
				NetworkSync.open_door(seam.id)
			return false
		var onto := DoorRegistry.closed_door_at(target_tile)
		if onto != null:
			if not _can_open(onto):
				return false
			NetworkSync.open_door(onto.id)
	if not is_ghost and is_tile_occupied(target_tile):
		return false
	facing_direction = direction
	is_moving = true
	if not is_ghost:
		_reserved[target_tile] = _body

	# Terrain speed is decided by whichever tile has the majority of the body
	# on it, not the destination tile the instant the step starts -- so the
	# first half of the step (still mostly on the old tile) uses the old
	# tile's speed, and only the second half uses the new tile's.
	var midpoint: Vector2 = origin_global.lerp(target_global, 0.5)
	var ignore_terrain := _ignores_terrain()
	var origin_speed: float = (1.0 if ignore_terrain else _floor_speed.get(_floor_source_at(origin_global), 1.0)) * speed_scale
	var target_speed: float = (1.0 if ignore_terrain else _floor_speed.get(_floor_source_at(target_global), 1.0)) * speed_scale
	var half_time := move_time / 2.0

	var tween := create_tween()
	_tween = tween
	tween.tween_property(_body, "global_position", midpoint, half_time / origin_speed)
	tween.tween_property(_body, "global_position", target_global, half_time / target_speed)
	tween.finished.connect(func():
		is_moving = false
		if _reserved.get(target_tile) == _body:
			_reserved.erase(target_tile))
	return true
