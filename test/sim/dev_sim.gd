extends SceneTree

## Headless playtest of the development biome (test/lab/development/). For each test cell it
## rebuilds the dungeon, puts an invincible player at the cell's entry tile, opens the cell's
## door, lets the game run, and reports how each creature from that cell behaved: closest it got
## to the player, whether it stalled, and whether it ever stood on a wall, void or no-floor tile.
## Exits 1 if any creature stood on a bad tile, so it can also gate a run.
##
##   godot --headless -s res://test/sim/dev_sim.gd -- [seconds=15] [natural] [cell_name ...]
##
## Creatures are told where the player is at the start (the same call a taunt uses), so a wall
## between them tests their pathfinding instead of their eyesight. Pass `natural` to leave them
## to notice the player through their own senses.
##
## With no cell names it runs the bug cells. Cell names and door/entry tiles come from
## test/sim/dev_cells.json, which test/lab/development/generate_hub.py writes.
## Real time, not simulated: minion timers use the wall clock, so 15 s takes 15 s per cell.

const CELLS_FILE := "res://test/sim/dev_cells.json"
const DEFAULT_CELLS := ["minion_minotaur", "bug1_spawn_fit", "bug1_no_room_for_boss", "bug1_hole_band",
	"bug2_two_wide_gap", "bug2_one_wide_gap", "bug6_boss_blocks_gap", "bug3_smash_plain", "bug3_smash_door", "bug3_smash_pillar",
	"bug4_corridor_archer", "bug4_open_archer", "bug5_boss_crowd", "terrain_lava", "terrain_water", "terrain_acid",
	"hearing_rock_behind_wall", "hearing_range"]
const SAMPLE_SECONDS := 0.25
## A creature that moved less than this (tiles) over STALL_SECONDS while the player was farther
## than STALL_MIN_DISTANCE is reported as stalled.
## A creature in a cell's `reach` list must get this close (tiles) to the player.
const REACH_TILES := 3.0
const STALL_SECONDS := 4.0
const STALL_MOVE := 0.6
const STALL_MIN_DISTANCE := 2.5

var _meta := {}
var _cells: Array = []
var _queue: Array = []
var _seconds := 15.0
var _natural := false
var _cell := {}
var _state := "load"
var _state_msec := 0
var _watch: Array = []  # [{node, id, start, closest, last_pos, last_moved_msec, stalled, bad}]
var _player: Node2D
var _noise_pos := Vector2.ZERO
var _next_sample := 0.0
var _started_msec := 0
var _center := Vector2i.ZERO
var _bad_total := 0
var _failed: Array = []
var _expected := 0
var _walls_at_start := {}
var _area := Rect2i()
var _spawn_ids := {}  # hub spawn tile -> minion id, from the room file
# Loaded at run time, not named directly: a script named here would be compiled before the
# autoloads exist, and every game script that mentions NetworkSync would then fail to load.
var _doors
var _log

func _initialize() -> void:
	_doors = load("res://scripts/cells/DoorRegistry.gd")
	_log = load("res://scripts/debug/DebugLog.gd")
	var args := OS.get_cmdline_user_args()
	var names: Array = []
	for a in args:
		if a == "natural":
			_natural = true
		elif a.is_valid_float():
			_seconds = float(a)
		else:
			names.append(a)
	_meta = JSON.parse_string(FileAccess.get_file_as_string(CELLS_FILE))
	_cells = _meta["cells"]
	_center = Vector2i(int(_meta["width"] / 2), int(_meta["height"] / 2))
	var hub = JSON.parse_string(FileAccess.get_file_as_string("res://test/lab/development/%s.json" % _meta["hub"]))
	for s in hub["spawn_cells"]:
		_spawn_ids[Vector2i(int(s["position"]["x"]), int(s["position"]["y"])) - _center] = str(s.get("minion", "?"))
	var wanted: Array = names if not names.is_empty() else DEFAULT_CELLS
	for n in wanted:
		var found := false
		for c in _cells:
			if c["name"] == n:
				_queue.append(c)
				found = true
		if not found:
			print("UNKNOWN CELL ", n)
	_next_cell()

func _next_cell() -> void:
	if _queue.is_empty():
		print("== ", "FAILED: " + ", ".join(_failed) if not _failed.is_empty() else "all cells passed")
		quit(1 if not _failed.is_empty() else 0)
		return
	_cell = _queue.pop_front()
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	_log.lines.clear()
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")
	_state = "wait_scene"
	_state_msec = Time.get_ticks_msec()

func _world_tile(hub: Dictionary) -> Vector2i:
	return Vector2i(int(hub["x"]), int(hub["y"])) - _center

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	match _state:
		"wait_scene":
			if current_scene != null and current_scene.name == "Dungeon" \
					and not get_nodes_in_group("protagonist").is_empty() \
					and not get_nodes_in_group("antagonist").is_empty() and now - _state_msec > 500:
				_begin_run()
			elif now - _state_msec > 20000:
				print("!! ", _cell["name"], ": dungeon did not come up")
				_bad_total += 1
				_next_cell()
		"run":
			if (now - _started_msec) / 1000.0 >= _next_sample:
				_next_sample += SAMPLE_SECONDS
				_sample(now)
			if (now - _started_msec) / 1000.0 >= _seconds:
				_finish()
	return false

func _begin_run() -> void:
	_player = get_nodes_in_group("protagonist")[0]
	_player.set("debug_god", true)
	var tile_size: int = _player.grid_mover.tile_size
	var rect: Dictionary = _cell["rect"]
	var top_left := _world_tile(rect)
	var area := Rect2i(top_left, Vector2i(int(rect["w"]), int(rect["h"])))
	_area = area
	_walls_at_start = _wall_ids()
	_watch.clear()
	for m: Node2D in get_nodes_in_group("antagonist"):
		var tile := Vector2i(floori(m.global_position.x / tile_size), floori(m.global_position.y / tile_size))
		if area.has_point(tile):
			_watch.append({"node": m, "id": _label(m, tile), "start": tile, "zone": null, "zone_changes": 0, "state": 0, "attack_msec": -1, "closest": 9999.0, "closest_noise": 9999.0,
				"last_pos": m.global_position, "last_moved_msec": Time.get_ticks_msec(), "stalled": false, "bad": "", "waded": 0, "wade_first": ""})
	_expected = 0
	for s in _spawn_ids:
		if area.has_point(s):
			_expected += 1
	var door_tile := _world_tile(_cell["door"])
	for door in _doors.doors:
		if door.cells.has(door_tile):
			_doors.set_open(door.id, true)
	_player.grid_mover.teleport(Vector2(_world_tile(_cell["player_at"] if _cell.get("player_at") != null else _cell["entry"]) * tile_size))
	var noise = _cell.get("noise_at")
	# A hearing cell is left alone: only its noise (made here, like a thrown rock or a footstep) may move them.
	if noise != null:
		_noise_pos = (Vector2(_world_tile(noise)) + Vector2(0.5, 0.5)) * tile_size
		root.get_node("NetworkSync").report_noise(_noise_pos, float(noise["loudness"]))
	elif not _natural:
		for w in _watch:
			w["node"].force_target(_player, _seconds)
	_started_msec = Time.get_ticks_msec()
	_next_sample = 0.0
	_state = "run"

## A big body is just marked by size (the sim's REACH lists say "big"); the rest go by minion id.
func _label(m: Node2D, _tile: Vector2i) -> String:
	var size := int(m.get("size_tiles"))
	return "big %dx%d" % [size, size] if size > 1 else str(m.get("minion_id"))

func _sample(now: int) -> void:
	var tile_size: int = _player.grid_mover.tile_size
	for w in _watch:
		var m: Node2D = w["node"]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			continue
		var d := m.global_position.distance_to(_player.global_position) / tile_size
		var state: int = int(m.get("_last_state"))
		w["state"] = maxi(int(w["state"]), state)
		# A boss standing still should keep the same zone (MinionController.boss_zone); count how
		# often it changes between samples while the boss did not move.
		if bool(m.get("is_boss")):
			var zone: Rect2i = m.boss_zone()
			if w["zone"] != null and zone != w["zone"] and w["last_pos"] == m.global_position and not m.grid_mover.is_moving:
				w["zone_changes"] += 1
			w["zone"] = zone
		if state == 2 and int(w["attack_msec"]) < 0:
			w["attack_msec"] = now - _started_msec
		w["closest"] = minf(w["closest"], d)
		w["closest_noise"] = minf(w["closest_noise"], m.global_position.distance_to(_noise_pos) / tile_size)
		if w["last_pos"].distance_to(m.global_position) / tile_size >= STALL_MOVE:
			w["last_pos"] = m.global_position
			w["last_moved_msec"] = now
		elif state == 2 and d > STALL_MIN_DISTANCE and now - int(w["last_moved_msec"]) >= int(STALL_SECONDS * 1000.0):
			w["stalled"] = true
		# Standing on terrain that costs more than plain ground (water, acid, lava) while it could
		# walk round: counted per sample, and a cell can require none (WADE_MAX in generate_hub.py).
		if not m.grid_mover.flies and m.grid_mover.tile_cost(Vector2i(floori(m.global_position.x / tile_size), floori(m.global_position.y / tile_size))) > 1.5:
			w["waded"] += 1
			if w["wade_first"] == "":
				w["wade_first"] = "first at (%d,%d) after %.1fs" % [floori(m.global_position.x / tile_size), floori(m.global_position.y / tile_size), (now - _started_msec) / 1000.0]
		if w["bad"] == "":
			var mover = m.get("grid_mover")
			var fp: int = mover.footprint
			var tl := Vector2i(floori(m.global_position.x / tile_size), floori(m.global_position.y / tile_size))
			var br := Vector2i(floori((m.global_position.x + fp * tile_size - 0.01) / tile_size),
				floori((m.global_position.y + fp * tile_size - 0.01) / tile_size))
			for y in range(tl.y, br.y + 1):
				for x in range(tl.x, br.x + 1):
					var why: String = mover.bad_tile_reason(Vector2i(x, y))
					if why != "" and w["bad"] == "":
						w["bad"] = "%s at (%d,%d) after %.1fs" % [why, x, y, (now - _started_msec) / 1000.0]

## Wall tile id by cell over the cell's area (to see which walls a creature broke).
func _wall_ids() -> Dictionary:
	var wall_data := current_scene.find_child("WallData", true, false) as TileMapLayer
	var ids := {}
	for y in range(_area.position.y, _area.end.y):
		for x in range(_area.position.x, _area.end.x):
			var id := wall_data.get_cell_source_id(Vector2i(x, y))
			if id != -1:
				ids[Vector2i(x, y)] = id
	return ids

func _finish() -> void:
	var ps: int = _player.grid_mover.tile_size
	print("--- ", _cell["name"], " (", _watch.size(), " creatures, ", _seconds, "s), player at (", floori(_player.global_position.x / ps), ",", floori(_player.global_position.y / ps), ")")
	var alive := 0
	for w in _watch:
		var m: Node2D = w["node"]
		var gone: bool = not is_instance_valid(m) or m.is_queued_for_deletion()
		if not gone:
			alive += 1
		var tile_size: int = _player.grid_mover.tile_size
		var final_d := -1.0 if gone else m.global_position.distance_to(_player.global_position) / tile_size
		var flags := ""
		if w["stalled"]:
			flags += "  STALLED"
		if int(w["zone_changes"]) > 0:
			flags += "  boss zone changed %d times while standing still" % w["zone_changes"]
		if int(w["waded"]) > 0:
			flags += "  waded in costly terrain for %.1fs (%s)" % [int(w["waded"]) * SAMPLE_SECONDS, w["wade_first"]]
		if w["bad"] != "":
			flags += "  BAD TILE: " + w["bad"]
			_bad_total += 1
		if gone:
			flags += "  (removed)"
		var heard: String = ["never noticed you", "investigated", "attacked"][int(w["state"])]
		if int(w["attack_msec"]) >= 0:
			heard += " at %.1fs" % (int(w["attack_msec"]) / 1000.0)
		if not gone:
			flags += "  [%s%s]" % ["locked on player" if is_instance_valid(m.get("_lock")) else "no target lock", ", boxed in" if bool(m.get("_stuck")) else ""]
		var end_tile := Vector2i.ZERO if gone else Vector2i(floori(m.global_position.x / tile_size), floori(m.global_position.y / tile_size))
		print("  %-16s (%d,%d) -> (%d,%d)  %s; closest %.1f, final %.1f tiles%s" % [w["id"], w["start"].x, w["start"].y,
			end_tile.x, end_tile.y, heard, w["closest"] if w["closest"] < 9999.0 else -1.0, final_d, flags])
	var walls_now := _wall_ids()
	var broken: Array = []
	for c in _walls_at_start:
		if not walls_now.has(c):
			broken.append("%s(%d,%d)" % [_walls_at_start[c], c.x, c.y])
	if not broken.is_empty():
		print("  walls broken in this cell (tile id, x, y): ", " ".join(broken))
	for line in _log.lines:
		if line.contains("BODY ON BAD TILE") or line.contains("WARNING") or line.contains("ERROR"):
			print("  log: ", line)
	var problems: Array = []
	if _watch.size() > _expected or (_watch.size() < _expected and not _cell.get("may_skip", false)):
		problems.append("%d pinned, %d spawned" % [_expected, _watch.size()])
	for w in _watch:
		if w["bad"] != "":
			problems.append("%s stood on a bad tile" % w["id"])
	if int(_cell.get("wade_max", -1)) >= 0:
		for w in _watch:
			if int(w["waded"]) > int(_cell["wade_max"]):
				problems.append("%s waded through slow or harmful ground when it could go round" % w["id"])
	var zone_max: int = int(_cell.get("zone_changes_max", -1))
	for w in _watch:
		if zone_max >= 0 and int(w["zone_changes"]) > zone_max:
			problems.append("%s's boss zone changed %d times while it stood still" % [w["id"], w["zone_changes"]])
	for want in _cell.get("reach", []):
		var found := false
		var reached := false
		for w in _watch:
			var label: String = w["id"]
			if label.begins_with(want) or (want == "big" and label.begins_with("big")):
				found = true
				if w["closest"] <= REACH_TILES:
					reached = true
				else:
					problems.append("%s stopped %.1f tiles away" % [label, w["closest"]])
		if not found:
			problems.append("no %s in the cell" % want)
	for want in _cell.get("hear", []):
		for w in _watch:
			if str(w["id"]).begins_with(want):
				if w["closest_noise"] > REACH_TILES:
					problems.append("%s heard the noise but stopped %.1f tiles from it" % [w["id"], w["closest_noise"]])
				if int(w["state"]) >= 2:
					problems.append("%s attacked; a noise should only make it investigate" % w["id"])
	for deaf in _cell.get("no_hear", []):
		for w in _watch:
			if str(w["id"]) == deaf and int(w["state"]) > 0:
				problems.append("%s reacted to a noise it is too far away to hear" % w["id"])
	if problems.is_empty():
		print("  PASS ", _cell["name"])
	else:
		print("  FAIL ", _cell["name"], ": ", "; ".join(problems))
		_failed.append(_cell["name"])
	_state = "idle"
	_next_cell.call_deferred()
