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
static func get_step(target_id: Variant, target_cell: Vector2i, from_cell: Vector2i, is_blocked: Callable) -> Vector2i:
	var field: Dictionary = _fields.get(target_id, {})
	if field.get("target_cell") != target_cell:
		field = _build(target_cell, is_blocked)
		_fields[target_id] = field
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
