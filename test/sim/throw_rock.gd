extends SceneTree

## Regression check for the Throw Rock action end to end: the real verb (ThrowVerb, through
## ActionRunner) lands a rock in the hearing_rock_behind_wall cell, the landing becomes a noise
## marker, and the blind rat on the far side of the wall investigates it (walks through the gap to
## the spot) without attacking. The player stands more than the light's radius from the rat, so only
## the sound can move it.
##
##   godot --headless --fixed-fps 60 -s res://test/sim/throw_rock.gd
##
## Game time (GameTick): about 15 game seconds, a few real ones with --fixed-fps.

const CELL := "hearing_rock_behind_wall"
const THROW_AT_MSEC := 3000
## Stops before the marker expires (15 s after the throw): a creature left standing in the player's
## light (a rock cannot be thrown farther than the light reaches) then walks to the light instead.
const RUN_MSEC := 14000
const REACH_TILES := 3.0

var _frames := 0
var _cell := {}
var _center := Vector2i.ZERO
var _player: Node2D
var _rat: Node2D
var _aim := Vector2i.ZERO
var _thrown := false
var _marker: Node2D
var _closest := 9999.0
var _max_state := 0
var _start_msec := 0

func _initialize() -> void:
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

func _tile(hub: Dictionary) -> Vector2i:
	return Vector2i(int(hub["x"]), int(hub["y"])) - _center

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 120 or current_scene == null:
		return false
	if _player == null:
		return _begin()
	var now: int = root.get_node("GameTick").msec() - _start_msec
	if not _thrown and now >= THROW_AT_MSEC:
		_throw()
	if _thrown and is_instance_valid(_rat) and _marker != null and is_instance_valid(_marker):
		var ts: int = _player.grid_mover.tile_size
		_closest = minf(_closest, _rat.global_position.distance_to(_marker.global_position) / ts)
		_max_state = maxi(_max_state, int(_rat.get("_last_state")))
	elif _thrown and _marker == null:
		var markers := get_nodes_in_group("noise_marker")
		if not markers.is_empty():
			_marker = markers[0]
	if now >= RUN_MSEC:
		return _finish()
	return false

func _begin() -> bool:
	var players := get_nodes_in_group("protagonist")
	if players.is_empty():
		return false
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://test/sim/dev_cells.json"))
	_center = Vector2i(int(meta["width"]) / 2, int(meta["height"]) / 2)
	for c in meta["cells"]:
		if c["name"] == CELL:
			_cell = c
	_player = players[0]
	_player.set("debug_god", true)
	var ts: int = _player.grid_mover.tile_size
	var at := _tile(_cell["player_at"])
	_player.grid_mover.teleport(Vector2(at * ts))
	_aim = at + Vector2i(-2, -7)
	var r: Dictionary = _cell["rect"]
	var area := Rect2i(_tile(r), Vector2i(int(r["w"]), int(r["h"])))
	for m: Node2D in get_nodes_in_group("antagonist"):
		if area.has_point(Vector2i((m.global_position / ts).floor())):
			_rat = m
	_start_msec = root.get_node("GameTick").msec()
	return false

func _throw() -> void:
	_thrown = true
	var attack: Dictionary = load("res://scripts/actions/ActionIndex.gd").resolve(["throw_rock"])[0]
	var ts: int = _player.grid_mover.tile_size
	var landed: bool = load("res://scripts/actions/ActionRunner.gd").perform(_player, Vector2(_aim * ts), attack)
	print("threw at ", _aim, ", verb ran: ", landed)

func _finish() -> bool:
	var problems: Array[String] = []
	if _rat == null:
		problems.append("no rat in the cell")
	if _marker == null or not is_instance_valid(_marker):
		problems.append("the landing left no noise marker")
	else:
		var ts: int = _player.grid_mover.tile_size
		var at := Vector2i((_marker.global_position / ts).floor())
		if (at - _aim).length() > 1.5:
			problems.append("the rock landed at %s, aimed at %s" % [at, _aim])
	if _closest > REACH_TILES:
		problems.append("the rat stopped %.1f tiles from the noise" % _closest)
	if _max_state == 0:
		problems.append("the rat never reacted")
	if _max_state >= 2:
		problems.append("the rat attacked; a noise should only make it investigate")
	print("rat closest to the marker: %.1f tiles, highest state %d" % [_closest, _max_state])
	print("PASS throw_rock" if problems.is_empty() else "FAIL throw_rock: " + "; ".join(problems))
	quit(0 if problems.is_empty() else 1)
	return true
