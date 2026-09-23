class_name LightFlood
extends RefCounted

## Shared flood-fill: how far something propagates outward from a cell,
## blocked by walls -- used today for player vision (LightMap), and meant to
## be reused later for anything else radius-and-walls shaped (torch objects,
## equipment-based light levels, etc). Cell units and the blocked-check are
## entirely up to the caller, so different callers can flood at different
## granularities without forking this.

const DIRS := [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const STRAIGHT := 10
const DIAGONAL := 14
const PATH_SLACK := 1.1

## Returns {"cost": {Vector2i: int}, "reached": Array[Vector2i]}. is_blocked
## is called with a cell and should return true if it stops the flood there
## (the origin cell itself is always included even if blocked).
static func flood(origin: Vector2i, radius_cells: float, is_blocked: Callable) -> Dictionary:
	var reached: Array[Vector2i] = []
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
			reached.append(cell)
			if cell != origin and is_blocked.call(cell):
				continue
			for dir in DIRS:
				var step := DIAGONAL if dir.x != 0 and dir.y != 0 else STRAIGHT
				if step == DIAGONAL and (is_blocked.call(cell + Vector2i(dir.x, 0)) or is_blocked.call(cell + Vector2i(0, dir.y))):
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
	return {"cost": cost, "reached": reached}
