class_name RoomGraph
extends RefCounted

## Coarse, room-level map of the current dungeon, built once right after
## DungeonAssembler.generate_with_retry() places every room (see
## DungeonPainter._ready() -> RoomGraph.build()). A dungeon is usually 20-30
## rooms (DungeonAssembler.MIN/MAX_ROOM_COUNT), so this whole graph is tiny --
## the point isn't to search it fast, it's to let a distant chase (bigger than
## EnemyController.PATHFIND_RADIUS_MAX, or PATHFIND_RADIUS_MAX-fed FlowField's
## own radius) aim at the next DOOR instead of either giving up or paying for
## a single huge tile-grid search across the whole dungeon. Generation only
## ever attaches a room to exactly one parent, so this graph is a tree; BFS
## still used over a manual tree-walk since it stays correct even if a future
## change (e.g. a loop-back corridor) adds a second edge between two rooms.

var _room_rects: Array[Rect2i] = []
# _adjacency[i] is this room's neighbors: [{"to": int, "door": Vector2i}, ...]
var _adjacency: Array = []

## Set by DungeonPainter._ready() once a dungeon's rooms are placed; null
## until then (e.g. a non-dungeon scene), which every caller must check for.
static var current: RoomGraph = null

static func build(rooms: Dictionary, placements: Array) -> void:
	var graph := RoomGraph.new()
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		graph._room_rects.append(Rect2i(p.offset, Vector2i(room["width"], room["height"])))
		graph._adjacency.append([])
	for i in placements.size():
		var p = placements[i]
		if p.parent_index < 0:
			continue
		graph._adjacency[i].append({"to": p.parent_index, "door": p.door_cell})
		graph._adjacency[p.parent_index].append({"to": i, "door": p.door_cell})
	current = graph

func _room_at(cell: Vector2i) -> int:
	for i in _room_rects.size():
		if _room_rects[i].has_point(cell):
			return i
	return -1

## The world cell of the next door to head for on the way from `from_cell`
## to `to_cell`, or Vector2i.ZERO if hierarchical routing doesn't apply here
## -- either cell isn't inside any known room, they're already in the same
## room (the local flow field / pathfind handles that directly, no need for
## a room-level hop), or no route exists between them at all.
func next_waypoint(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var from_room := _room_at(from_cell)
	var to_room := _room_at(to_cell)
	if from_room < 0 or to_room < 0 or from_room == to_room:
		return Vector2i.ZERO
	var came_from := {from_room: -1}
	var came_via_door := {}
	var queue: Array[int] = [from_room]
	var head := 0
	while head < queue.size():
		var room: int = queue[head]
		head += 1
		if room == to_room:
			break
		for edge in _adjacency[room]:
			var next_room: int = edge["to"]
			if came_from.has(next_room):
				continue
			came_from[next_room] = room
			came_via_door[next_room] = edge["door"]
			queue.append(next_room)
	if not came_from.has(to_room):
		return Vector2i.ZERO
	var step_room: int = to_room
	while came_from[step_room] != from_room:
		step_room = came_from[step_room]
	return came_via_door[step_room]
