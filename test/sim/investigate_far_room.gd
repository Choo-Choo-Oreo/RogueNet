extends SceneTree

## Regression check: a minion that hears a noise two rooms away walks there (Investigate is never
## kept in its room), and once it calms down walks back to the room it started in (patrol home).
## Bug seen 2026-09-25: the minion's own path search only covers a box around it, the way through
## the doors left the box, the search failed and the minion never left its room.
##
##   godot --headless --fixed-fps 60 -s res://test/sim/investigate_far_room.gd
##
## A real generated dungeon (seed 1), not the lab: the lab hub is one big room. The minion's sight
## and touch are switched off so only the noise moves it; the player stands in the middle room so
## patrol stays awake the whole way (a patrol with no player near sleeps where it is).

## Re-heard this often while walking: one noise only holds Investigate for 10 s.
const REHEAR_MSEC := 5000
const REACH_MSEC := 40000
const HOME_MSEC := 60000
const REACH_TILES := 3.0

var _graph
var _tick
var _minion: Node2D
var _player: Node2D
var _home_room := -1
var _far_room := -1
var _spot := Vector2i.ZERO
var _phase := "load"
var _phase_msec := 0
var _heard_msec := -REHEAR_MSEC
var _frames := 0
var _problems: Array[String] = []

func _initialize() -> void:
	_tick = root.get_node("GameTick")
	_graph = load("res://scripts/cells/RoomGraph.gd")
	root.get_node("NetworkSync").dungeon_seed = 1
	load("res://scripts/entities/entities.antagonist/minions/ai/MinionController.gd").patrol_enabled = true
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 120 or current_scene == null:
		return false
	var now: int = _tick.msec()
	match _phase:
		"load":
			if _begin():
				_phase = "walk"
				_phase_msec = now
		"walk":
			if now - _heard_msec >= REHEAR_MSEC:
				_heard_msec = now
				var ts: int = _player.grid_mover.tile_size
				_minion.senses.hear(load("res://scripts/entities/entities.senses/Sound.gd").marker_at(self, (Vector2(_spot) + Vector2(0.5, 0.5)) * ts))
			if _tiles_from_spot() <= REACH_TILES:
				print("reached the noise after %.1fs" % ((now - _phase_msec) / 1000.0))
				_phase = "home"
				_phase_msec = now
			elif now - _phase_msec > REACH_MSEC:
				_problems.append("never reached the noise two rooms away: ended in room %d, %.1f tiles from it" % [_room(), _tiles_from_spot()])
				return _finish()
		"home":
			if _room() == _home_room:
				print("back in its home room after %.1fs" % ((now - _phase_msec) / 1000.0))
				return _finish()
			if now - _phase_msec > HOME_MSEC:
				_problems.append("did not walk back to its home room %d: ended in room %d" % [_home_room, _room()])
				return _finish()
	return false

## Picks a home room and a room two doors from it (not touching it), and places a rat.
func _begin() -> bool:
	var players := get_nodes_in_group("protagonist")
	var graph = _graph.current
	if players.is_empty() or graph == null:
		return false
	_player = players[0]
	_player.set("debug_god", true)
	var ts: int = _player.grid_mover.tile_size
	# The route that turns most in the middle room (a straight line of rooms is easy: the
	# minion's own search box covers it). A rat is placed there: few minions exist at the start.
	var best := []
	var best_score := INF
	for home in graph._room_rects.size():
		for edge in graph._adjacency[home]:
			var middle: int = edge["to"]
			for far_edge in graph._adjacency[middle]:
				var far: int = far_edge["to"]
				if far == home or _touches(graph, home, far):
					continue
				var a := Vector2(graph._room_rects[middle].get_center() - graph._room_rects[home].get_center()).normalized()
				var b := Vector2(graph._room_rects[far].get_center() - graph._room_rects[middle].get_center()).normalized()
				if a.dot(b) < best_score:
					best_score = a.dot(b)
					best = [home, middle, far]
	if best.is_empty():
		_problems.append("no room with a room two doors away")
		_finish()
		return false
	_home_room = best[0]
	_far_room = best[2]
	var rects: Array = graph._room_rects
	var before := get_nodes_in_group("antagonist").size()
	root.get_node("NetworkSync").debug_spawn_minion("rat", _free_cell(_player, rects[_home_room]))
	var spawned := get_nodes_in_group("antagonist")
	if spawned.size() == before:
		_problems.append("could not place a rat in room %d" % _home_room)
		_finish()
		return false
	_minion = spawned[spawned.size() - 1]
	_minion.senses.sight.enabled = false
	_minion.senses.touch.enabled = false
	_spot = _free_cell(_player, rects[_far_room])
	# In a corner of the middle room, out of the way through it.
	_player.grid_mover.teleport(Vector2(_free_cell(_player, rects[best[1]], rects[best[1]].position) * ts))
	_heard_msec = -REHEAR_MSEC
	print("minion %s in room %d, noise at %s in room %d via room %d (%d tiles away)" % [_minion.name, _home_room, _spot, _far_room, best[1], _cheb(_spot - _cell_of(_minion))])
	return true

func _touches(graph, a: int, b: int) -> bool:
	for edge in graph._adjacency[a]:
		if edge["to"] == b:
			return true
	return false

## The free cell of `rect` nearest `centre` (its middle by default).
func _free_cell(m: Node2D, rect: Rect2i, centre := Vector2i(-99999, -99999)) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	if centre.x == -99999:
		centre = rect.get_center()
	for y in range(rect.position.y + 1, rect.end.y - 1):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			var cell := Vector2i(x, y)
			if m.grid_mover.is_tile_blocked(cell):
				continue
			if best.x == -99999 or _cheb(cell - centre) < _cheb(best - centre):
				best = cell
	return best

func _cell_of(node: Node2D) -> Vector2i:
	return Vector2i((node.global_position / _player_ts(node)).floor())

func _player_ts(node: Node2D) -> int:
	return node.grid_mover.tile_size

func _room() -> int:
	return _graph.current.room_at(_cell_of(_minion))

func _tiles_from_spot() -> float:
	return Vector2(_cell_of(_minion) - _spot).length()


func _finish() -> bool:
	print("PASS investigate_far_room" if _problems.is_empty() else "FAIL investigate_far_room: " + "; ".join(_problems))
	quit(0 if _problems.is_empty() else 1)
	return true

## FlowField.cheb, loaded when first used: an -s script cannot name classes that use autoloads.
func _cheb(v: Vector2i) -> int:
	return load("res://scripts/cells/FlowField.gd").cheb(v)
