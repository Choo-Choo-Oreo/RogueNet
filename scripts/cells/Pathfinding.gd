class_name Pathfinding
extends RefCounted

## Shortest 4-directional path from `from` to `to`, built on Godot's own
## AStarGrid2D rather than a hand-rolled search. Bounded to a max_radius-tile
## region around `from` (not the whole dungeon) and rebuilt fresh each call
## -- walls don't move, but callers do, and a bounded region is cheap enough
## to just re-scan rather than cache here (see EnemyController's own
## per-enemy path cache, which caches the *result* of this across frames
## instead). Cell units and the blocked-check are the same shape as
## LineOfSight/LightFlood's, so callers can reuse whatever is_blocked they
## already have (e.g. GridMover.is_tile_blocked). Returns the full route
## (path[0] is `from` itself), or an empty array if already at `to`, `to` is
## outside max_radius, or no path exists within the region.
## `terrain_cost` (optional, tile -> float, 1.0 = normal ground, never below
## 1.0) sets each tile's AStarGrid2D weight, so the route detours around slow
## ground when that is cheaper. Leave unset for a mover that ignores terrain.
static func full_path(from: Vector2i, to: Vector2i, is_blocked: Callable, max_radius: int, terrain_cost: Callable = Callable()) -> Array[Vector2i]:
	if from == to:
		return []
	var region := Rect2i(from - Vector2i.ONE * max_radius, Vector2i.ONE * (max_radius * 2 + 1))
	if not region.has_point(to):
		return []
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if is_blocked.call(cell):
				grid.set_point_solid(cell)
			elif terrain_cost.is_valid():
				var cost: float = terrain_cost.call(cell)
				if cost != 1.0:
					grid.set_point_weight_scale(cell, cost)
	var path := grid.get_id_path(from, to)
	if path.size() < 2:
		return []
	var result: Array[Vector2i] = []
	for cell in path:
		result.append(cell)
	return result
