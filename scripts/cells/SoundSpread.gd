class_name SoundSpread
extends RefCounted

## How a sound spreads through the map, in decibels. A sound starts at its source level and
## loses dB on every step across the 8px quads (4 per tile, LightMap.CELL): what a tile costs
## is its TileType `muffle` (dB per tile, so half of it per quad), a closed door DOOR_DB_PER_TILE,
## and a step that turns beside a wall or door (the sound bending round a corner) more: CORNER_DB
## for a right angle, half that per 45 degrees, so cutting a corner diagonally costs the same.
## It takes the cheapest way, so it goes round a wall through a doorway when that loses less
## than going through. Whoever still gets at least their hearing threshold hears it
## (SenseHearing). Map data only: who listens is the caller's business (Sound, for minions).

const QUAD := LightMap.CELL
const TILE := 16
## What open floor and a wall cost when their tile JSON has no "muffle" (TileType).
const AIR_DB_PER_TILE := 1.0
const WALL_DB_PER_TILE := 35.0
const DOOR_DB_PER_TILE := 20.0
## Bending 90 degrees round a wall or door.
const CORNER_DB := 3.0
const DIAGONAL := 1.41421
## Quieter than any ear hears: a flood nobody listens to (the debug view) stops here.
const FLOOR_DB := 10.0
## A quad costing more than this per step is solid (wall, door): turning beside one is a corner.
const SOLID_DB_PER_QUAD := 1.0

static func quad_at(position: Vector2) -> Vector2i:
	return Vector2i((position / QUAD).floor())

## Every quad a body covers: `size_tiles` tiles a side, `tile` its top-left one.
static func quads_of(tile: Vector2i, size_tiles := 1) -> Array[Vector2i]:
	var quads: Array[Vector2i] = []
	for y in size_tiles * 2:
		for x in size_tiles * 2:
			quads.append(tile * 2 + Vector2i(x, y))
	return quads

## The level a body at `tile` hears: the loudest of its quads, -INF if the sound never got there.
static func level_at(levels: Dictionary, tile: Vector2i, size_tiles := 1) -> float:
	var best := -INF
	for quad in quads_of(tile, size_tiles):
		best = maxf(best, levels.get(quad, -INF))
	return best

## quad -> dB left, for every quad a sound of `source_db` at `source` reaches still at
## `stop_db` or louder. `loss` gives what one straight step onto a quad costs (INF: the
## sound cannot go there, e.g. outside the map); a diagonal step costs DIAGONAL times that.
## Dijkstra on the dB lost. A quad remembers the step that reached it, so a turn is seen.
## With `targets` (one listener's quads) it stops as soon as the loudest of them is settled:
## that one's level is final, the rest of the map is left half done.
static func flood(source: Vector2i, source_db: float, stop_db: float, loss: Callable, targets: Array[Vector2i] = []) -> Dictionary:
	var budget := source_db - stop_db
	if budget < 0.0:
		return {}
	var lost := {source: 0.0}
	var came := {source: Vector2i.ZERO}
	var solid := {}
	var heap: Array = [[0.0, source]]
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var quad: Vector2i = top[1]
		if top[0] > lost[quad]:
			continue
		if targets.has(quad):
			break
		var before: Vector2i = came[quad]
		var turn_costs := before != Vector2i.ZERO and _beside_solid(quad, loss, solid)
		for x in range(-1, 2):
			for y in range(-1, 2):
				var dir := Vector2i(x, y)
				if dir == Vector2i.ZERO:
					continue
				var next := quad + dir
				var step: float = loss.call(next) * (DIAGONAL if x != 0 and y != 0 else 1.0)
				if turn_costs and dir != before:
					step += CORNER_DB * _eighths(before, dir) / 2.0
				var cost: float = top[0] + step
				if cost <= budget and cost < lost.get(next, INF):
					lost[next] = cost
					came[next] = dir
					_heap_push(heap, [cost, next])
	var levels := {}
	for quad in lost:
		levels[quad] = source_db - lost[quad]
	return levels

## How many 45-degree turns lie between two of the 8 step directions (0 to 4).
static func _eighths(a: Vector2i, b: Vector2i) -> int:
	return roundi(absf(Vector2(a).angle_to(Vector2(b))) / (PI / 4.0))

static func _beside_solid(quad: Vector2i, loss: Callable, cache: Dictionary) -> bool:
	if not cache.has(quad):
		var found := false
		for x in range(-1, 2):
			for y in range(-1, 2):
				if (x != 0 or y != 0) and loss.call(quad + Vector2i(x, y)) > SOLID_DB_PER_QUAD:
					found = true
		cache[quad] = found
	return cache[quad]

## What a straight step onto each quad costs, read from the dungeon's tile layers: a closed
## door, else the wall tile's muffle, else the floor tile's; no floor at all is outside the map.
static func reader(tree: SceneTree) -> Callable:
	var scene := tree.current_scene
	var walls: TileMapLayer = scene.find_child("WallData", true, false) if scene else null
	var floors: TileMapLayer = scene.find_child("FloorData", true, false) if scene else null
	var tiles := TileType.by_id()
	return func(quad: Vector2i) -> float:
		var cell := Vector2i(floori(quad.x / 2.0), floori(quad.y / 2.0))
		if DoorRegistry.closed_door_at(cell) != null:
			return DOOR_DB_PER_TILE / 2.0
		var wall_id := walls.get_cell_source_id(cell) if walls else -1
		if wall_id != -1:
			return (tiles[wall_id].muffle if tiles.has(wall_id) else WALL_DB_PER_TILE) / 2.0
		var floor_id := floors.get_cell_source_id(cell) if floors else 0
		if floor_id == -1:
			return INF
		return (tiles[floor_id].muffle if tiles.has(floor_id) else AIR_DB_PER_TILE) / 2.0

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")  # whole index on purpose
		var parent := (i - 1) / 2
		if heap[parent][0] <= heap[i][0]:
			break
		var swap = heap[parent]
		heap[parent] = heap[i]
		heap[i] = swap
		i = parent

static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var smallest := i
			for child in [i * 2 + 1, i * 2 + 2]:
				if child < heap.size() and heap[child][0] < heap[smallest][0]:
					smallest = child
			if smallest == i:
				break
			var swap = heap[smallest]
			heap[smallest] = heap[i]
			heap[i] = swap
			i = smallest
	return top
