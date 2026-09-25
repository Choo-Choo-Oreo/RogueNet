class_name Sound
extends RefCounted

## A sound in the dungeon: a footstep, a thrown rock landing. Host only (minion AI only runs
## there; NetworkSync.report_noise gets a client's noise to it). Every minion that hears it is
## told to go and look at it.
##
## How far a sound gets:
##   budget = the listener's hearing range_tiles * loudness
##   cost   = the cheapest sum of `muffle` over the tiles between the sound and the listener
##            (floor 1, wall 3, closed door DOOR_MUFFLE; a diagonal step costs 1.41x)
##   heard when cost <= budget
## The costs come from one flood fill per sound (flood), spread only as far as the biggest
## budget among the minions close enough to possibly hear it.
##
## Going to look needs somewhere to go, and pathing wants a node, so a noise becomes a
## marker: a bare Node2D left where it was made for MARKER_SECONDS. Minions share markers
## (one per spot, see marker_at), so a crowd that hears the same noise shares one flow field
## instead of paying for one each. A marker is a place, never a player: investigating walks
## to where the sound was, not to whoever made it.

const GROUP := "noise_marker"
const MARKER_SECONDS := 15.0
## A noise this close to a live marker reuses it instead of making another.
const REUSE_TILES := 2.0
const TILE_SIZE := 16.0

## Loudness is clamped to this scale: 1 a footstep, 3 a thrown rock, 10 the loudest there is.
const LOUDNESS_MIN := 1
const LOUDNESS_MAX := 10

## A closed door muffles like a wall (an open door is plain floor).
const DOOR_MUFFLE := 3.0
const DIAGONAL := 1.41421
## Debug (show-sound): the last floods, each {"cells": {cell: cost}, "budget", "msec"}.
const SHOW_SECONDS := 2.0
static var recent: Array = []

static func make(tree: SceneTree, position: Vector2, loudness: float) -> void:
	loudness = clampf(loudness, LOUDNESS_MIN, LOUDNESS_MAX)
	# The path cost is never less than the straight-line distance, so a minion farther away
	# than its budget cannot hear it and is skipped before the flood.
	var listeners: Array = []
	var reach := 0.0
	for minion in tree.get_nodes_in_group("antagonist"):
		if not minion.has_method("hearing_budget"):
			continue
		var budget: float = minion.hearing_budget(loudness)
		if budget > 0.0 and minion.global_position.distance_to(position) <= (budget + minion.size_tiles) * TILE_SIZE:
			listeners.append([minion, budget])
			reach = maxf(reach, budget)
	var showing := DebugState.on("show-sound")
	if listeners.is_empty() and not showing:
		return
	var shown_budget := SenseHearing.DEFAULT_RANGE_TILES * loudness
	if showing:
		reach = maxf(reach, shown_budget)
	var source := Vector2i((position / TILE_SIZE).floor())
	var costs := flood(source, reach, _muffle_reader(tree))
	# Each listener's sum, kept for the debug labels: [where it stood, cost, its budget].
	var sums: Array = []
	if showing:
		recent.append({"cells": costs, "budget": maxf(reach, shown_budget), "loudness": loudness, "source": source, "sums": sums, "msec": Time.get_ticks_msec()})
		while recent.size() > 8:
			recent.pop_front()
	var marker: Node2D = null
	for entry in listeners:
		var minion = entry[0]
		var cost := INF
		for cell in minion.grid_mover.footprint_tiles(Vector2i((minion.global_position / TILE_SIZE).floor())):
			cost = minf(cost, costs.get(cell, INF))
		if showing:
			sums.append([minion.global_position, cost, entry[1]])
		if cost > entry[1]:
			continue
		if marker == null:
			marker = marker_at(tree, position)
			if marker == null:
				return
		minion.hear_noise(marker, cost)

## The cost (budget spent) of every tile a sound from `source` reaches without spending more
## than `budget`. Dijkstra: each step pays the muffle of the tile it enters (INF = sound cannot
## enter, e.g. outside the map); a diagonal step pays DIAGONAL times that.
static func flood(source: Vector2i, budget: float, muffle: Callable) -> Dictionary:
	var costs := {source: 0.0}
	var heap: Array = [[0.0, source]]
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var cell: Vector2i = top[1]
		if top[0] > costs[cell]:
			continue
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue
				var next := cell + Vector2i(x, y)
				var step: float = muffle.call(next) * (DIAGONAL if x != 0 and y != 0 else 1.0)
				var cost: float = top[0] + step
				if cost <= budget and cost < costs.get(next, INF):
					costs[next] = cost
					_heap_push(heap, [cost, next])
	return costs

## Muffle read straight from the dungeon's tile layers: a closed door, else the wall tile's,
## else the floor tile's; a cell with no floor at all is outside the map (INF).
static func _muffle_reader(tree: SceneTree) -> Callable:
	var scene := tree.current_scene
	var walls: TileMapLayer = scene.find_child("WallData", true, false) if scene else null
	var floors: TileMapLayer = scene.find_child("FloorData", true, false) if scene else null
	var tiles := TileType.by_id()
	return func(cell: Vector2i) -> float:
		if DoorRegistry.closed_door_at(cell) != null:
			return DOOR_MUFFLE
		var wall_id := walls.get_cell_source_id(cell) if walls else -1
		if wall_id != -1:
			return tiles[wall_id].muffle if tiles.has(wall_id) else 3.0
		var floor_id := floors.get_cell_source_id(cell) if floors else 0
		if floor_id == -1:
			return INF
		return tiles[floor_id].muffle if tiles.has(floor_id) else 1.0

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

## The live marker within REUSE_TILES of `position` (kept alive another MARKER_SECONDS), or a
## new one there. Null when there is no scene to put it in.
static func marker_at(tree: SceneTree, position: Vector2) -> Node2D:
	var scene := tree.current_scene
	if scene == null:
		return null
	var marker: Node2D = null
	for existing: Node2D in tree.get_nodes_in_group(GROUP):
		if existing.global_position.distance_to(position) <= REUSE_TILES * TILE_SIZE:
			marker = existing
			break
	if marker == null:
		marker = Node2D.new()
		marker.name = "NoiseMarker"
		marker.add_to_group(GROUP)
		scene.add_child(marker)
		marker.global_position = position
		tree.create_timer(MARKER_SECONDS).timeout.connect(_expire.bind(tree, marker))
	marker.set_meta("until_msec", GameTick.msec() + int(MARKER_SECONDS * 1000.0))
	return marker

## Frees the marker once its last refresh has run out (a reuse pushes the deadline back).
static func _expire(tree: SceneTree, marker) -> void:
	if not is_instance_valid(marker):
		return
	var left_msec: int = int(marker.get_meta("until_msec")) - GameTick.msec()
	if left_msec <= 0:
		marker.queue_free()
	else:
		tree.create_timer(left_msec / 1000.0).timeout.connect(_expire.bind(tree, marker))
