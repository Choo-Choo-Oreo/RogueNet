class_name FlowField
extends RefCounted

## Shared per-target step field: one flood from the target's tile
## outward, reused by every minion chasing that same target this frame,
## instead of each one solving its own from-scratch A* search (see
## Pathfinding.gd, and MinionController's MAX_PATHFINDS_PER_FRAME budget /
## _try_direct_step bypass -- this is the third tier alongside them). A whole
## pursuing crowd shares one search: the swarm-room stress test is the
## textbook "many agents, one target" case flow fields are for.
##
## Only walls are baked in (grid.is_blocked, same shape LineOfSight/
## Pathfinding use) -- NOT occupancy, since occupancy changes every time any
## creature in the crowd moves and would make the shared field stale
## constantly. Callers still need their own occupancy check before actually
## stepping onto the field's suggested tile (see MinionController._try_
## pursue_step), same reasoning _try_direct_step already documents.

const RADIUS := 20

# key (target instance id, and the body size in tiles: see MinionController._flow_key) -> {"target_cell": Vector2i, "grid": StepCache, plus each
# map once something has asked for it (_field_for): "directions" (flyers),
# "terrain_directions" (walkers) and "distances" (get_distances). A directions
# map sends a reachable cell to the Vector2i step that moves 1 tile closer to
# target_cell along the flood's shortest path.
static var _fields := {}

const NEIGHBOR_STEPS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## How long a diagonal step takes compared to a straight one (it covers
## sqrt(2) ~= 1.41 tiles; GridMover scales its tween time the same way).
const DIAGONAL_LENGTH := 1.4142135623730951

const _BLOCKED := 1
const _DOOR := 2

## One field's memory of the grid. A flood asks about each tile many times (as
## a neighbour of up to 8 cells, and as the corner a diagonal squeezes past),
## and is_blocked is a real tile-map lookup, so each tile is looked up once and
## each cell's open steps are worked out once -- all of a field's floods share one.
class StepCache:
	var is_blocked: Callable
	var _tiles := {}  # tile -> _BLOCKED | _DOOR bits
	var _steps := {}  # cell -> the NEIGHBOR_STEPS open out of it

	func _init(blocked_check: Callable) -> void:
		is_blocked = blocked_check

	## The steps a mover can take between `cell` and a neighbour (either way).
	## The same rule GridMover.can_step_diagonally applies to a real step: a
	## diagonal needs both straight tiles beside it open (no cutting wall
	## corners) and no door on any of the four tiles it passes (no slipping
	## through a doorway's edge).
	func open_steps(cell: Vector2i) -> Array:
		var steps = _steps.get(cell)
		if steps != null:
			return steps
		# The 3x3 block around `cell`, at index (x + 1) + (y + 1) * 3; 4 is `cell`.
		var around: Array[int] = []
		for y in range(-1, 2):
			for x in range(-1, 2):
				var tile := cell + Vector2i(x, y)
				var bits = _tiles.get(tile)
				if bits == null:
					bits = (_BLOCKED if is_blocked.call(tile) else 0) | (_DOOR if DoorRegistry.is_door_cell(tile) else 0)
					_tiles[tile] = bits
				around.append(bits)
		steps = []
		for step in NEIGHBOR_STEPS:
			var onto := around[(step.x + 1) + (step.y + 1) * 3]
			if onto & _BLOCKED:
				continue
			if step.x != 0 and step.y != 0:
				var side_x := around[(step.x + 1) + 3]
				var side_y := around[1 + (step.y + 1) * 3]
				if (side_x | side_y) & _BLOCKED or (around[4] | onto | side_x | side_y) & _DOOR:
					continue
			steps.append(step)
		_steps[cell] = steps
		return steps

## Called once per fresh dungeon load (DungeonPainter._ready(), alongside
## RoomGraph.build()) -- _fields is static and keyed by target instance id,
## and PlayerSpawner gives players a new instance id every dive, so without
## this it would just grow forever across a play session. Also guards
## against a same-id coincidence reusing a stale field built from the
## PREVIOUS dungeon's totally different wall layout.
static func clear() -> void:
	_fields.clear()

## Next step direction from `from_cell` toward `target_cell` for this
## `target_id` (Object.get_instance_id() of whatever's being chased), or
## Vector2i.ZERO if `from_cell` isn't reachable within RADIUS -- callers fall
## back to their own direct-step/pathfind handling in that case, same as
## Pathfinding.full_path returning an empty path for "no route found."
## `target_id` is really any dictionary key -- MinionController's surround
## slots pass [target id, slot offset] so each slot gets its own field.
##
## `terrain_cost` (optional, tile -> float, 1.0 = normal ground) makes the
## flood cost-weighted, so the step leads around slow ground (lava, water)
## when a detour is cheaper. Leave it unset for a mover that ignores terrain
## (flyers); those share the plain map. Walkers share one weighted map per
## target, so every mover passing a terrain_cost must use the same costs.
static func get_step(target_id: Variant, target_cell: Vector2i, from_cell: Vector2i, is_blocked: Callable, terrain_cost: Callable = Callable()) -> Vector2i:
	var field := _field_for(target_id, target_cell, is_blocked)
	var map_name := "terrain_directions" if terrain_cost.is_valid() else "directions"
	if not field.has(map_name):
		var times := {}
		field[map_name] = _build_directions(target_cell, terrain_cost, field["grid"], times)
		if terrain_cost.is_valid():
			field["terrain_times"] = times
	var directions: Dictionary = field[map_name]
	return directions.get(from_cell, Vector2i.ZERO)

## Travel time (see _build_directions) from each reachable cell to `target_cell` for a walker
## whose terrain costs are `terrain_cost`. Lets a caller pick steps that get closer in TIME,
## so it does not wade through slow ground where going round is quicker.
static func get_times(target_id: Variant, target_cell: Vector2i, is_blocked: Callable, terrain_cost: Callable) -> Dictionary:
	var field := _field_for(target_id, target_cell, is_blocked)
	if not field.has("terrain_times"):
		get_step(target_id, target_cell, target_cell, is_blocked, terrain_cost)
	return field["terrain_times"]

## Walking distance (in steps, walls only; a diagonal step counts as one) from
## each reachable cell to `target_cell`, from the same shared field get_step
## uses -- lets a caller tell "closer / same layer / farther" apart instead of
## only getting the one recommended step. Cells outside RADIUS are absent.
static func get_distances(target_id: Variant, target_cell: Vector2i, is_blocked: Callable) -> Dictionary:
	var field := _field_for(target_id, target_cell, is_blocked)
	if not field.has("distances"):
		field["distances"] = _step_counts(target_cell, field["grid"])
	return field["distances"]

## The shared field for `target_id`, started over when its target has moved.
## Each of its maps is built the first time something asks for it (see
## _fields) -- plenty of chases only ever need one or two. They all share the
## field's StepCache, which takes the newest caller's is_blocked (the caller
## that started the field may have died since).
static func _field_for(target_id: Variant, target_cell: Vector2i, is_blocked: Callable) -> Dictionary:
	var field: Dictionary = _fields.get(target_id, {})
	if field.get("target_cell") != target_cell:
		field = {"target_cell": target_cell, "grid": StepCache.new(is_blocked)}
		_fields[target_id] = field
	else:
		var grid: StepCache = field["grid"]
		grid.is_blocked = is_blocked
	return field

## Shortest-TIME flood: each step costs its length (1, or ~1.41 for a
## diagonal) times the average of the two tiles' terrain costs (a step spends
## half its time on each, see GridMover), so routes take diagonals where they
## save time and detour around slow ground when that is cheaper. Leave
## terrain_cost unset for plain ground everywhere. A cell can be reached again
## by a cheaper route, so it is re-queued when improved. Returns cell -> the
## step to take from it.
static func _build_directions(target_cell: Vector2i, terrain_cost: Callable, grid: StepCache, times_out: Dictionary) -> Dictionary:
	var weighted := terrain_cost.is_valid()
	var directions := {target_cell: Vector2i.ZERO}
	var best := {target_cell: 0.0}
	times_out[target_cell] = 0.0
	var costs := {}
	var queued := {target_cell: true}
	var queue: Array[Vector2i] = [target_cell]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		queued.erase(cell)
		if maxi(absi(cell.x - target_cell.x), absi(cell.y - target_cell.y)) >= RADIUS:
			continue
		if weighted and not costs.has(cell):
			costs[cell] = terrain_cost.call(cell)
		for step: Vector2i in grid.open_steps(cell):
			var neighbor := cell + step
			var step_cost := DIAGONAL_LENGTH if step.x != 0 and step.y != 0 else 1.0
			if weighted:
				if not costs.has(neighbor):
					costs[neighbor] = terrain_cost.call(neighbor)
				step_cost *= (costs[cell] + costs[neighbor]) * 0.5
			var total: float = best[cell] + step_cost
			if total < best.get(neighbor, INF):
				best[neighbor] = total
				times_out[neighbor] = total
				directions[neighbor] = -step
				if not queued.has(neighbor):
					queued[neighbor] = true
					queue.append(neighbor)
	return directions

## BFS outward from the target: how many steps (diagonal or straight, each
## counting one) every reachable cell is from it. Neighbouring cells differ by
## at most one, so the cells at the same count form a square-ish ring around
## the target -- the surround logic's "layers".
static func _step_counts(target_cell: Vector2i, grid: StepCache) -> Dictionary:
	var distances := {target_cell: 0}
	var queue: Array[Vector2i] = [target_cell]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if maxi(absi(cell.x - target_cell.x), absi(cell.y - target_cell.y)) >= RADIUS:
			continue
		for step: Vector2i in grid.open_steps(cell):
			var neighbor := cell + step
			if distances.has(neighbor):
				continue
			distances[neighbor] = distances[cell] + 1
			queue.append(neighbor)
	return distances
