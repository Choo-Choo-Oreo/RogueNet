class_name FlowField
extends RefCounted

## Shared per-target step field: one BFS flood from the target's tile
## outward, reused by every enemy chasing that same target this frame,
## instead of each one solving its own from-scratch A* search (see
## Pathfinding.gd, and EnemyController's MAX_PATHFINDS_PER_FRAME budget /
## _try_direct_step bypass -- this is the third tier alongside them). A whole
## pursuing crowd shares one search: the swarm-room stress test is the
## textbook "many agents, one target" case flow fields are for.
##
## Only walls are baked in (grid.is_blocked, same shape LineOfSight/
## Pathfinding use) -- NOT occupancy, since occupancy changes every time any
## creature in the crowd moves and would make the shared field stale
## constantly. Callers still need their own occupancy check before actually
## stepping onto the field's suggested tile (see EnemyController._try_
## pursue_step), same reasoning _try_direct_step already documents.

const RADIUS := 20

# target instance id -> {"target_cell": Vector2i, "directions": Dictionary}
# directions maps a reachable cell to the Vector2i step that moves 1 tile
# closer to target_cell along the flood's shortest path.
static var _fields := {}

const NEIGHBOR_STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

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
## `target_id` is really any dictionary key -- EnemyController's surround
## slots pass [target id, slot offset] so each slot gets its own field.
##
## `terrain_cost` (optional, tile -> float, 1.0 = normal ground) makes the
## flood cost-weighted, so the step leads around slow ground (lava, water)
## when a detour is cheaper. Leave it unset for a mover that ignores terrain
## (flyers); those share the plain field. Walkers share one weighted field
## per target, so every mover passing a terrain_cost must use the same costs.
static func get_step(target_id: Variant, target_cell: Vector2i, from_cell: Vector2i, is_blocked: Callable, terrain_cost: Callable = Callable()) -> Vector2i:
	var key: Variant = target_id if not terrain_cost.is_valid() else [target_id, "terrain"]
	var field: Dictionary = _fields.get(key, {})
	if field.get("target_cell") != target_cell:
		field = _build(target_cell, is_blocked) if not terrain_cost.is_valid() else _build_weighted(target_cell, is_blocked, terrain_cost)
		_fields[key] = field
	var directions: Dictionary = field["directions"]
	return directions.get(from_cell, Vector2i.ZERO)

## Walking distance (in tiles, walls only) from each reachable cell to
## `target_cell`, from the same shared flood get_step uses -- lets a caller
## tell "closer / same layer / farther" apart instead of only getting the one
## recommended step. Cells outside RADIUS are absent.
static func get_distances(target_id: Variant, target_cell: Vector2i, is_blocked: Callable) -> Dictionary:
	var field: Dictionary = _fields.get(target_id, {})
	if field.get("target_cell") != target_cell:
		field = _build(target_cell, is_blocked)
		_fields[target_id] = field
	return field["distances"]

## Same shape as _build, but each step costs the average of the two tiles'
## terrain costs (a step spends half its time on each, see GridMover), so the
## flood is a shortest-cost search instead of a plain BFS. A cell can be
## reached again by a cheaper route, so it is re-queued when improved. Only
## "directions" is filled: `distances` stays the plain step count from _build,
## which the surround logic relies on (one tile closer = exactly one less).
static func _build_weighted(target_cell: Vector2i, is_blocked: Callable, terrain_cost: Callable) -> Dictionary:
	var directions := {target_cell: Vector2i.ZERO}
	var best := {target_cell: 0.0}
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
		if not costs.has(cell):
			costs[cell] = terrain_cost.call(cell)
		for step in NEIGHBOR_STEPS:
			var neighbor := cell + step
			if is_blocked.call(neighbor):
				continue
			if not costs.has(neighbor):
				costs[neighbor] = terrain_cost.call(neighbor)
			var total: float = best[cell] + (costs[cell] + costs[neighbor]) * 0.5
			if total < best.get(neighbor, INF):
				best[neighbor] = total
				directions[neighbor] = -step
				if not queued.has(neighbor):
					queued[neighbor] = true
					queue.append(neighbor)
	return {"target_cell": target_cell, "directions": directions, "distances": {}}

static func _build(target_cell: Vector2i, is_blocked: Callable) -> Dictionary:
	# BFS outward from the target -- the direction stored for each newly
	# reached cell is simply "back the way the flood came from," which is,
	# by construction, one step closer to target_cell than that cell was.
	var directions := {target_cell: Vector2i.ZERO}
	var distances := {target_cell: 0}
	var queue: Array[Vector2i] = [target_cell]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if maxi(absi(cell.x - target_cell.x), absi(cell.y - target_cell.y)) >= RADIUS:
			continue
		for step in NEIGHBOR_STEPS:
			var neighbor := cell + step
			if directions.has(neighbor) or is_blocked.call(neighbor):
				continue
			directions[neighbor] = -step
			distances[neighbor] = distances[cell] + 1
			queue.append(neighbor)
	return {"target_cell": target_cell, "directions": directions, "distances": distances}
