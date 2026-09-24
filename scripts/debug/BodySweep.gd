class_name BodySweep
extends Node

## Debug: twice a second, checks that no creature overlaps a wall, void or a cell with
## no floor, and writes a DebugLog line the first time one does (the log is saved with
## the performance capture). The line says which tile, and how the body last moved
## (GridMover.last_move: a step, a teleport, or a position a peer sent) and whether the
## map changed lately (TileDestruction), so a body that walked into a wall can be traced
## to the code path that let it. Reads the tile layers itself instead of asking
## GridMover's step checks, so a hole in those checks cannot hide from it.
## On unless its tick in the debug menu is turned off; cheap (bodies x footprint tiles).

const OPTION := "log-bodies-in-walls"
const INTERVAL := 0.5
## A map change this recent (seconds) is mentioned in the line.
const RECENT_CHANGE := 5.0

var _timer := 0.0
var _reported := {}  # body instance id -> the problem last logged for it

func _process(delta: float) -> void:
	_timer += delta
	if _timer < INTERVAL:
		return
	_timer = 0.0
	if not _enabled():
		return
	var started := Time.get_ticks_usec()
	for group in ["protagonist", "antagonist"]:
		for body: Node2D in get_tree().get_nodes_in_group(group):
			_check(body)
	DebugState.add_time("body sweep", Time.get_ticks_usec() - started)

## Never ticked or unticked in the menu = on.
func _enabled() -> bool:
	if not (DebugState.flags.has("always:" + OPTION) or DebugState.flags.has("debug:" + OPTION)):
		return true
	return DebugState.on(OPTION)

func _check(body: Node2D) -> void:
	var mover = body.get("grid_mover")
	if mover == null or body.is_queued_for_deletion():
		return
	if DebugState.no_clip and body.is_in_group("protagonist") and body.is_multiplayer_authority():
		return
	var tile_size: int = mover.tile_size
	var top_left := Vector2i(floori(body.global_position.x / tile_size), floori(body.global_position.y / tile_size))
	var reach := Vector2(body.global_position) + Vector2(mover.footprint, mover.footprint) * tile_size - Vector2(0.01, 0.01)
	var bottom_right := Vector2i(floori(reach.x / tile_size), floori(reach.y / tile_size))
	var problem := ""
	for y in range(top_left.y, bottom_right.y + 1):
		for x in range(top_left.x, bottom_right.x + 1):
			var reason: String = mover.bad_tile_reason(Vector2i(x, y))
			if reason != "":
				problem = "%s at (%d, %d)" % [reason, x, y]
				break
		if problem != "":
			break
	var id := body.get_instance_id()
	if problem == "":
		_reported.erase(id)
		return
	if _reported.get(id, "") == problem:
		return
	_reported[id] = problem
	DebugLog.add(_describe(body, mover, top_left, problem))

func _describe(body: Node2D, mover: GridMover, top_left: Vector2i, problem: String) -> String:
	var label := str(body.name)
	var kind = body.get("enemy_id")
	if kind != null and str(kind) != "":
		label += " (%s)" % kind
	var now := Time.get_ticks_msec()
	var move: Dictionary = mover.last_move
	var how := str(move["kind"])
	if how == "":
		how = "unknown"
	elif how == "step":
		how += " %s" % move["dir"]
	var text := "BODY ON BAD TILE: %s, %dx%d body at tile (%d, %d) overlaps %s; last move: %s %.1fs ago; authority peer %d" % [
		label, mover.footprint, mover.footprint, top_left.x, top_left.y, problem,
		how, (now - int(move["msec"])) / 1000.0, body.get_multiplayer_authority()]
	if TileDestruction.last_applied_msec > 0 and (now - TileDestruction.last_applied_msec) / 1000.0 <= RECENT_CHANGE:
		text += "; tiles were broken %.1fs ago" % ((now - TileDestruction.last_applied_msec) / 1000.0)
	if mover.is_moving:
		text += "; mid-step"
	return text
