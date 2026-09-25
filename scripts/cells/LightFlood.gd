class_name LightFlood
extends RefCounted

## Shared flood-fill: how far something propagates outward from a cell,
## blocked by walls -- used for torch light and glowing tiles (LightMap) and for
## sight (PlayerVision). Cell units and the blocked-check are entirely up to the
## caller, so different callers can flood at different granularities without
## forking this.

const DIRS := [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const STRAIGHT := 10
const DIAGONAL := 14
const PATH_SLACK := 1.1

## One source. Returns {"cost": {Vector2i: int}, "reached": Array[Vector2i]}. is_blocked
## is called with a cell and should return true if it stops the flood there
## (the origin cell itself is always included even if blocked).
static func flood(origin: Vector2i, radius_cells: float, is_blocked: Callable) -> Dictionary:
	var keep := func(cell: Vector2i) -> bool: return Vector2(cell - origin).length() <= radius_cells + 1.0
	return flood_sources({origin: [0, 0]}, max_cost(radius_cells), is_blocked, keep)

## The highest cost a flood of this radius walks to.
static func max_cost(radius_cells: float) -> int:
	return int(radius_cells * STRAIGHT * PATH_SLACK)

## Several sources at once (every glowing tile). seeds maps a cell to [start cost, source
## index]; a source with a smaller radius starts at a higher cost, so each one stops at its own
## radius. A seed spreads even when it is blocked (lava in a wall still glows), unless it is
## surrounded by other seeds. keep(cell) false means the cell is never reached.
## Returns {"cost", "reached", "from": {cell: source index}}.
static func flood_sources(seeds: Dictionary, highest: int, is_blocked: Callable, keep: Callable) -> Dictionary:
	var reached: Array[Vector2i] = []
	var cost := {}
	var from := {}
	var buckets: Array = []
	buckets.resize(highest + DIAGONAL + 1)
	for cell: Vector2i in seeds:
		var start: int = seeds[cell][0]
		cost[cell] = start
		from[cell] = seeds[cell][1]
		if buckets[start] == null:
			buckets[start] = []
		buckets[start].append(cell)
	for level in range(highest + 1):
		if buckets[level] == null:
			continue
		for cell: Vector2i in buckets[level]:
			if cost[cell] != level or not keep.call(cell):
				continue
			reached.append(cell)
			if seeds.has(cell):
				if _is_interior(cell, seeds):
					continue
			elif is_blocked.call(cell):
				continue
			for dir in DIRS:
				var step := DIAGONAL if dir.x != 0 and dir.y != 0 else STRAIGHT
				if step == DIAGONAL and (is_blocked.call(cell + Vector2i(dir.x, 0)) or is_blocked.call(cell + Vector2i(0, dir.y))):
					continue
				var next: Vector2i = cell + dir
				var next_cost: int = level + step
				if next_cost > highest:
					continue
				if cost.has(next) and cost[next] <= next_cost:
					continue
				cost[next] = next_cost
				from[next] = from[cell]
				if buckets[next_cost] == null:
					buckets[next_cost] = []
				buckets[next_cost].append(next)
	return {"cost": cost, "reached": reached, "from": from}

static func _is_interior(cell: Vector2i, seeds: Dictionary) -> bool:
	for dir in DIRS:
		if not seeds.has(cell + dir):
			return false
	return true
