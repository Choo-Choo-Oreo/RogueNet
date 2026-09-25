class_name RoomGraph
extends RefCounted

## Coarse, room-level map of the current dungeon, built once right after
## DungeonAssembler.generate_with_retry() places every room (see
## DungeonPainter._ready() -> RoomGraph.build()). A dungeon is usually 20-30
## rooms (DungeonAssembler.MIN/MAX_ROOM_COUNT), so this whole graph is tiny --
## the point isn't to search it fast, it's to let a distant chase (bigger than
## MinionController.PATHFIND_RADIUS_MAX, or PATHFIND_RADIUS_MAX-fed FlowField's
## own radius) aim at the next DOOR instead of either giving up or paying for
## a single huge tile-grid search across the whole dungeon. Generation only
## ever attaches a room to exactly one parent, so this graph is a tree; BFS
## still used over a manual tree-walk since it stays correct even if a future
## change (e.g. a loop-back corridor) adds a second edge between two rooms.

var _room_rects: Array[Rect2i] = []
# _adjacency[i] is this room's neighbors:
# [{"to": int, "door": Vector2i (middle), "cells": Array[Vector2i] (whole joint)}, ...]
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
		graph._adjacency[i].append({"to": p.parent_index, "door": p.door_cell, "cells": p.joint_world})
		graph._adjacency[p.parent_index].append({"to": i, "door": p.door_cell, "cells": p.joint_world})
	current = graph

func room_at(cell: Vector2i) -> int:
	for i in _room_rects.size():
		if _room_rects[i].has_point(cell):
			return i
	return -1

## The room `cell` is in plus every room joined to it by a door (empty when the cell is in no room).
func rooms_near(cell: Vector2i) -> Array[int]:
	var here := room_at(cell)
	var near: Array[int] = []
	if here < 0:
		return near
	near.append(here)
	for edge in _adjacency[here]:
		near.append(edge["to"])
	return near

## True when `cell` is in the same room as one of `player_cells`, or in a room next to it.
func is_near_any(cell: Vector2i, player_cells: Array[Vector2i]) -> bool:
	var here := room_at(cell)
	if here < 0:
		return false
	for player_cell in player_cells:
		if here in rooms_near(player_cell):
			return true
	return false

## The rectangle of the room `cell` is in (an empty Rect2i when it is in none).
func room_rect(cell: Vector2i) -> Rect2i:
	var i := room_at(cell)
	return _room_rects[i] if i >= 0 else Rect2i()

## The world cell of the next door to head for on the way from `from_cell`
## to `to_cell`, or Vector2i.ZERO if hierarchical routing doesn't apply here
## -- either cell isn't inside any known room, they're already in the same
## room (the local flow field / pathfind handles that directly, no need for
## a room-level hop), or no route exists between them at all.
func next_waypoint(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var from_room := room_at(from_cell)
	var to_room := room_at(to_cell)
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
			came_via_door[next_room] = edge
			queue.append(next_room)
	if not came_from.has(to_room):
		return Vector2i.ZERO
	var step_room: int = to_room
	while came_from[step_room] != from_room:
		step_room = came_from[step_room]
	# Head for the joint cell closest to us, not always the middle one.
	var edge: Dictionary = came_via_door[step_room]
	var best: Vector2i = edge["door"]
	var best_dist := INF
	for cell in edge["cells"]:
		var d := Vector2(cell - from_cell).length_squared()
		if d < best_dist:
			best_dist = d
			best = cell
	return best
