class_name GridMover
extends Node

## Moves the parent node one tile at a time across the dungeon grid,
## respecting walls/doors and per-tile terrain speed. Shared by anything
## that walks the dungeon tilemap -- players, antagonist, minions.

@export var tile_size := 16
@export var move_time := 0.2

@onready var _body: Node2D = get_parent()

@onready var wall_data: TileMapLayer = get_tree().current_scene.find_child("WallData", true, false)
@onready var floor_data: TileMapLayer = get_tree().current_scene.find_child("FloorData", true, false)

@onready var _void_source_id: int = _tile_ids().get_id("floor_void")

## Emitted when a step finishes, with the tile stepped onto. Not for teleports.
signal stepped(tile: Vector2i)

var is_moving := false
var facing_direction := Vector2.DOWN

## Tiles per side of this mover's body: 1 = a normal creature, 2 = a 2x2 boss. The
## body's position is its TOP-LEFT tile. is_tile_blocked and is_tile_occupied treat
## the tile they are given as that top-left anchor, so pathfinding, flow fields and
## every "can I step there" check work for a big body without knowing about size.
var footprint := 1:
	set(value):
		footprint = maxi(value, 1)
		var owner_body := get_parent()
		if owner_body != null:
			owner_body.set_meta("footprint", footprint)

## Every tile a body of this size covers when its top-left tile is `anchor`.
func _footprint_tiles(anchor: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in footprint:
		for x in footprint:
			tiles.append(anchor + Vector2i(x, y))
	return tiles

## Floor tile id -> move speed, read from game/tiles/ once and shared by every mover. Each
## mover used to read the registry and all the tile files itself, which with hundreds of
## minions was thousands of file reads while a dungeon loaded.
static var _floor_speed := {}
## Floor tile id -> its TileType, from the same read (floor_type()).
static var _floor_types := {}
static var _registry: TileTypeRegistry = null

static func _tile_ids() -> TileTypeRegistry:
	if _registry == null:
		_registry = TileTypeRegistry.new()
	return _registry

func _ready() -> void:
	if _floor_speed.is_empty():
		_build_floor_speeds()

static func _build_floor_speeds() -> void:
	var dir := DirAccess.open("res://game/tiles/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var tile := TileType.new()
		tile.load_from_file("res://game/tiles/" + file_name)
		if tile.category == TileType.Category.FLOOR:
			_floor_speed[_tile_ids().get_id(tile.tile_name)] = tile.move_speed()
			_floor_types[_tile_ids().get_id(tile.tile_name)] = tile

## The floor tile with this id (a TileMapLayer's source id), or null.
static func floor_type(id: int) -> TileType:
	if _floor_types.is_empty():
		_build_floor_speeds()
	return _floor_types.get(id)

## True for a mover that flies: terrain never slows it, and its pathfinding
## ignores terrain cost. Set from the minion JSON's "flying" (MinionController).
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
## minion leaves solid doors shut). Called with the DoorRegistry.Door, returns
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

## How this body last got where it is, for the debug body sweep (BodySweep): kind is
## "step", "teleport" or "network" (a position a peer sent), dir the step, msec when.
var last_move := {"kind": "", "dir": Vector2.ZERO, "msec": 0}

func note_move(kind: String, dir: Vector2 = Vector2.ZERO) -> void:
	last_move = {"kind": kind, "dir": dir, "msec": Time.get_ticks_msec()}

## Debug (BodySweep): why a body should not be standing on `tile` -- "wall", "void" or
## "no floor" -- or "" if it is fine. Reads the layers directly, so it also catches a
## cell with no floor at all, which _is_blocked lets through.
func bad_tile_reason(tile: Vector2i) -> String:
	if wall_data != null and wall_data.get_cell_source_id(tile) != -1:
		return "wall"
	if floor_data == null:
		return ""
	var floor_id := floor_data.get_cell_source_id(tile)
	if floor_id == -1:
		return "no floor"
	return "void" if floor_id == _void_source_id else ""

## Debug: put the body on a spot right now, cancelling any step in progress.
func teleport(pos: Vector2) -> void:
	note_move("teleport")
	if _tween != null and _tween.is_valid():
		_tween.kill()
	is_moving = false
	for tile in _reserved.keys():
		if _reserved[tile] == _body:
			_reserved.erase(tile)
	_body.global_position = pos

## Only set for the length of swap_step: the creature this one is trading tiles with, which
## must not count as standing in the way.
var _swap_partner: Node2D = null

## Two creatures trade tiles in one step: this body steps `direction`, the partner the opposite
## way, and they walk through each other. Returns false if either step is refused.
func swap_step(direction: Vector2, partner: GridMover) -> bool:
	_swap_partner = partner._body
	partner._swap_partner = _body
	var swapped := not is_moving and not partner.is_moving and move_one_tile(direction) and partner.move_one_tile(-direction)
	_swap_partner = null
	partner._swap_partner = null
	return swapped

func _is_ghost() -> bool:
	return "stats" in _body and _body.stats != null and _body.stats.is_ghost

## Tile-coordinate version of the same wall/void/door check, for grid
## algorithms (Pathfinding, FlowField) and step checks that work in cell units
## rather than world positions. A closed door only counts as blocked for a
## mover that can't open it -- one that can just walks into it (move_one_tile
## opens it), so paths and flow fields route straight through.
func is_tile_blocked(tile: Vector2i) -> bool:
	if footprint > 1:
		for covered in _footprint_tiles(tile):
			if _tile_blocked_single(covered):
				return true
		return false
	return _tile_blocked_single(tile)

func _tile_blocked_single(tile: Vector2i) -> bool:
	if _is_blocked(Vector2(tile) * tile_size):
		return true
	var door := DoorRegistry.closed_door_at(tile)
	return door != null and not _ignores_doors() and not _can_open(door)

## Walls, void and closed opaque doors: what stops SIGHT (LineOfSight,
## minion senses). Bars (transparent doors) let you see through.
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
## hundreds of minions now calling this unthrottled every frame (see
## MinionController._try_direct_step, added once pathfinding itself got
## throttled), that added up to O(n^2) per frame and became the new
## bottleneck. Building the tile -> occupants map once per frame instead
## (Godot 4 script statics, shared by every GridMover instance regardless of
## which one triggers the rebuild) turns it back into O(n) total. Assumes
## every mover uses the same tile_size, true everywhere in this project
## today.
static var _occupancy_frame: int = -1
static var _occupancy_index: Dictionary = {}  # Vector2i -> Array[Node2D]

## Every living creature on `tile` this frame (ghosts excluded).
func occupants_at(tile: Vector2i) -> Array:
	return _tile_occupants(tile)

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
				var body_size: int = body.get_meta("footprint", 1)
				for y in body_size:
					for x in body_size:
						var covered := body_tile + Vector2i(x, y)
						if not _occupancy_index.has(covered):
							_occupancy_index[covered] = []
						_occupancy_index[covered].append(body)
	return _occupancy_index.get(tile, [])

## True if some other creature (any protagonist or antagonist besides this
## mover's own body) is currently standing on `tile` -- lets a mover refuse
## to step onto an already-occupied tile instead of stacking on it. Ghost
## players (PlayerController.die()) are intangible and don't count, same as
## they already don't count as attack targets or collide with minions.
func is_tile_occupied(tile: Vector2i) -> bool:
	if footprint > 1:
		for covered in _footprint_tiles(tile):
			if _tile_occupied_single(covered):
				return true
		return false
	return _tile_occupied_single(tile)

func _tile_occupied_single(tile: Vector2i) -> bool:
	# Boss privilege: a boss walks through the antagonists that are not bosses
	# (they step aside, see MinionController._yield_to_boss). Players still block it.
	var is_boss: bool = _body.get_meta("is_boss", false)
	for body in _tile_occupants(tile):
		if body == _body or body == _swap_partner:
			continue
		if is_boss and body.is_in_group("antagonist") and not body.get_meta("is_boss", false):
			continue
		return true
	var holder = _reserved.get(tile)
	if holder == null or not is_instance_valid(holder) or holder == _body or holder == _swap_partner:
		return false
	return not (is_boss and holder.is_in_group("antagonist") and not holder.get_meta("is_boss", false))

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

## A diagonal step squeezes past the corner its two straight steps share, so
## both of those straight steps' tiles must be open -- no cutting past a wall
## corner (the same corner rule LineOfSight and LightFlood use). It also never
## slips through a doorway: a door is a thin line between tiles, and a diagonal
## would cross it at its very end. Movers that ignore doors skip that part.
## `step` is the diagonal itself, e.g. Vector2i(1, -1) for up-right.
func can_step_diagonally(origin_tile: Vector2i, step: Vector2i) -> bool:
	if is_tile_blocked(origin_tile + Vector2i(step.x, 0)) or is_tile_blocked(origin_tile + Vector2i(0, step.y)):
		return false
	if _ignores_doors():
		return true
	for covered in _footprint_tiles(origin_tile):
		for tile in [covered, covered + step, covered + Vector2i(step.x, 0), covered + Vector2i(0, step.y)]:
			if DoorRegistry.is_door_cell(tile):
				return false
	return true

## speed_scale lets a caller slow this one step down (e.g. a minion that's
## investigating a noise rather than actively chasing, at half speed) without
## touching move_time itself, which stays the entity's normal baseline.
## `direction` is one of the 8 neighbouring tiles; a diagonal takes longer (it
## covers ~1.41 tiles of distance). Returns false if the step was refused
## (wall, a corner or doorway a diagonal can't squeeze past, or another living
## creature on or already stepping onto the destination -- ghosts are exempt
## both ways).
func move_one_tile(direction: Vector2, speed_scale: float = 1.0) -> bool:
	var origin_global: Vector2 = _body.global_position
	var target_global := origin_global + direction * tile_size
	var target_tile := Vector2i(floori(target_global.x / tile_size), floori(target_global.y / tile_size))
	if footprint > 1:
		for covered in _footprint_tiles(target_tile):
			if _is_blocked(Vector2(covered) * tile_size):
				return false
	elif _is_blocked(target_global):
		return false
	if direction.x != 0.0 and direction.y != 0.0:
		var from_tile := Vector2i(floori(origin_global.x / tile_size), floori(origin_global.y / tile_size))
		if not can_step_diagonally(from_tile, Vector2i(direction.round())):
			return false
	var is_ghost := _is_ghost()
	# A door is a thin line, not a tile. Trying to cross that line while the door
	# is closed (or still swinging) opens it (if this mover may) but doesn't step
	# this call. Stepping ONTO a door cell from the front is fine and just starts
	# it opening, so you can stand in the doorway while it swings.
	# Ghosts and door-phasing minions drift through closed doors.
	if not _ignores_doors():
		var origin_tile := Vector2i(floori(origin_global.x / tile_size), floori(origin_global.y / tile_size))
		# A big body enters a whole row or column of new tiles at once: every one of
		# them is checked, each against the tile it steps in from.
		var entered: Array[Vector2i] = [target_tile]
		var came_from: Array[Vector2i] = [origin_tile]
		if footprint > 1:
			entered.clear()
			came_from.clear()
			var already := _footprint_tiles(origin_tile)
			var step := Vector2i(direction.round())
			for covered in _footprint_tiles(target_tile):
				if not already.has(covered):
					entered.append(covered)
					came_from.append(covered - step)
		for i in entered.size():
			var seam := DoorRegistry.crossing_door(came_from[i], entered[i])
			if seam != null and DoorRegistry.is_blocking(seam):
				if _can_open(seam):
					NetworkSync.open_door(seam.id)
				return false
			var onto := DoorRegistry.closed_door_at(entered[i])
			if onto != null:
				if not _can_open(onto):
					return false
				NetworkSync.open_door(onto.id)
	if not is_ghost and is_tile_occupied(target_tile):
		return false
	facing_direction = direction
	is_moving = true
	note_move("step", direction)
	var reserved_tiles: Array[Vector2i] = _footprint_tiles(target_tile)
	if not is_ghost:
		for covered in reserved_tiles:
			_reserved[covered] = _body

	# Terrain speed is decided by whichever tile has the majority of the body
	# on it, not the destination tile the instant the step starts -- so the
	# first half of the step (still mostly on the old tile) uses the old
	# tile's speed, and only the second half uses the new tile's.
	var midpoint: Vector2 = origin_global.lerp(target_global, 0.5)
	var ignore_terrain := _ignores_terrain()
	var origin_speed: float = (1.0 if ignore_terrain else _floor_speed.get(_floor_source_at(origin_global), 1.0)) * speed_scale
	var target_speed: float = (1.0 if ignore_terrain else _floor_speed.get(_floor_source_at(target_global), 1.0)) * speed_scale
	var half_time := move_time * direction.length() / 2.0

	var tween := create_tween()
	_tween = tween
	tween.tween_property(_body, "global_position", midpoint, half_time / origin_speed)
	tween.tween_property(_body, "global_position", target_global, half_time / target_speed)
	tween.finished.connect(func():
		is_moving = false
		for covered in reserved_tiles:
			if _reserved.get(covered) == _body:
				_reserved.erase(covered)
		stepped.emit(target_tile))
	return true
