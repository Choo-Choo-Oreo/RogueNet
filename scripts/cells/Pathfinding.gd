class_name Pathfinding
extends RefCounted

## Shortest 4-directional path step from `from` toward `to`, built on Godot's
## own AStarGrid2D rather than a hand-rolled search. Bounded to a
## max_radius-tile region around `from` (not the whole dungeon) and rebuilt
## fresh each call -- walls don't move, but callers do, and a bounded region
## is cheap enough to just re-scan rather than cache. Cell units and the
## blocked-check are the same shape as LineOfSight/LightFlood's, so callers
## can reuse whatever is_blocked they already have (e.g. GridMover.is_tile_
## blocked). Returns the first step's direction (one of the 4 cardinal
## Vector2i, matching GridMover's move set), or Vector2i.ZERO if already at
## `to`, `to` is outside max_radius, or no path exists within the region.

static func next_step(from: Vector2i, to: Vector2i, is_blocked: Callable, max_radius: int) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var region := Rect2i(from - Vector2i.ONE * max_radius, Vector2i.ONE * (max_radius * 2 + 1))
	if not region.has_point(to):
		return Vector2i.ZERO
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if is_blocked.call(cell):
				grid.set_point_solid(cell)
	var path := grid.get_id_path(from, to)
	if path.size() < 2:
		return Vector2i.ZERO
	return path[1] - path[0]
