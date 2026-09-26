extends SceneTree

## How far each sound a player makes carries in a real generated dungeon: a footstep (the only
## walking sound, PlayerController.FOOTSTEP_DB) and a voice whispering, talking and yelling
## (VoiceChat.WHISPER_DB / TALK_DB / YELL_DB, the dB VoiceChat reports while you talk), and a
## fight: every action with a `db` (game/actions, the noise its attack makes, AttackEffect) and a
## death (game/sounds.json death_db, which only players hear, shown for comparison). Rats are
## placed along the longest straight run of floor from the player, at DISTANCES tiles, frozen in
## place (their AI is off, so nobody walks); each sound is made the way the game makes it
## (NetworkSync.report_noise -> Sound.make) and a rat that heard it has senses.last_heard_db set.
## The table also shows, from the same spread (SoundSpread), which other creatures would hear it
## at each spot, by their hearing threshold (game/entities/.../<creature>.json "hearing").
##
##   godot --headless --fixed-fps 60 -s res://test/sim/hearing_distances.gd -- [seed=N]
##
## No seed: a random one (printed, to run the same dungeon again). Always exits 0: it is a
## report for tuning, not a pass/fail check; except FAIL when a rat's reaction disagrees with
## the spread (a bug in Sound.make's hearing).

const DISTANCES := [1, 2, 3, 4, 6, 8, 10, 13, 16, 20, 25, 30, 35, 40]
## [name, dB]: what a player makes and a fight's sounds, from the game's own numbers (_initialize).
var SOUNDS := []
## [creature, hearing threshold dB], from the creature JSONs; filled in _initialize.
var _creatures: Array = []

var _tick
var _frames := 0
var _seed := 0
var _player: Node2D
var _start := Vector2i.ZERO
var _rats: Array = []   # [distance, cell, rat]
var _before: Array = []  # the dungeon's own minions, not part of the test
var _frozen := false
var _sound := -1
var _sound_msec := 0
var _problems: Array[String] = []

func _initialize() -> void:
	var voice = load("res://singletons/VoiceChat.gd")
	SOUNDS = [["footstep", load("res://scripts/entities/entities.protagonist/player/PlayerController.gd").FOOTSTEP_DB],
		["whisper", voice.WHISPER_DB], ["talking", voice.TALK_DB], ["yell", voice.YELL_DB]]
	_tick = root.get_node("GameTick")
	_seed = randi() % 100000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			_seed = arg.trim_prefix("seed=").to_int()
	for id in ["rat", "hamster", "bat", "bat_echo", "spider"]:
		_creatures.append([id, _threshold(id)])
	var fight: Array = []
	for file in DirAccess.get_files_at("res://game/actions/"):
		if file.ends_with(".json"):
			var action: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/actions/" + file))
			if float(action.get("db", 0.0)) > 0.0:
				fight.append([file.get_basename(), float(action["db"])])
	fight.sort_custom(func(a, b): return a[1] < b[1])
	SOUNDS.append_array(fight)
	var sounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/sounds.json"))
	SOUNDS.append(["death", float(sounds.get("death_db", 0.0))])
	root.get_node("NetworkSync").dungeon_seed = _seed
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

## A creature's hearing threshold from its JSON (the default when it gives none).
func _threshold(id: String) -> float:
	for folder in ["minions", "bosses"]:
		var path := "res://game/entities/entities.antagonist/%s/%s.json" % [folder, id]
		if FileAccess.file_exists(path):
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var hearing = data.get("senses", {}).get("hearing", {})
			if hearing is Dictionary:
				return float(hearing.get("threshold_db", 27.0))
	return 27.0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 120 or current_scene == null:
		return false
	if _player == null:
		_begin()
		return false
	if not _frozen:
		_collect_rats()
		if _frames > 600 and not _frozen:
			_problems.append("the rats did not all spawn")
			return _finish()
		return false
	var now: int = _tick.msec()
	if _sound == -1 or now - _sound_msec >= 1000:
		if _sound >= 0:
			_report(_sound)
		_sound += 1
		if _sound >= SOUNDS.size():
			return _finish()
		_make(_sound)
		_sound_msec = now
	return false

## The player at the start of the longest straight run of floor; a rat at each distance on it.
func _begin() -> void:
	var players := get_nodes_in_group("protagonist")
	var graph = load("res://scripts/cells/RoomGraph.gd").current
	if players.is_empty() or graph == null:
		return
	_player = players[0]
	_player.set("debug_god", true)
	load("res://scripts/debug/DebugState.gd").unseen = true  # the player's own steps while placing are not part of the test
	var best_len := 0
	var best_dir := Vector2i.RIGHT
	for rect: Rect2i in graph._room_rects:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if _blocked(cell):
					continue
				for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var n := 0
					while n < DISTANCES.back() and not _blocked(cell + dir * (n + 1)):
						n += 1
					if n > best_len:
						best_len = n
						_start = cell
						best_dir = dir
	var ts: int = _player.grid_mover.tile_size
	_player.grid_mover.teleport(Vector2(_start * ts))
	_before = get_nodes_in_group("antagonist")
	for d in DISTANCES:
		if d <= best_len:
			var cell: Vector2i = _start + best_dir * d
			root.get_node("NetworkSync").debug_spawn_minion("rat", cell)
			_rats.append([d, cell, null])
	print("seed %d: player at %s, %d tiles of straight floor %s, rats at %s" % [_seed, _start, best_len, best_dir, DISTANCES.filter(func(d): return d <= best_len)])

func _blocked(cell: Vector2i) -> bool:
	return _player.grid_mover.is_tile_blocked(cell)

## Finds the spawned rats by where they stand and freezes them (no AI, no walking); their
## senses still get told when they hear something (Sound.make calls hear_noise directly).
func _collect_rats() -> void:
	var ts: int = _player.grid_mover.tile_size
	for m: Node2D in get_nodes_in_group("antagonist"):
		if m in _before:
			continue
		for entry in _rats:
			if (m.global_position / ts).distance_to(Vector2(entry[1])) < 1.0:
				entry[2] = m
	for entry in _rats:
		if entry[2] == null:
			return
	_frozen = true
	for entry in _rats:
		var rat: Node = entry[2]
		rat.process_mode = Node.PROCESS_MODE_DISABLED
		rat.senses.sight.enabled = false
		rat.senses.touch.enabled = false
	# The other minions in the dungeon stay out of it: only the placed rats count.

func _make(i: int) -> void:
	var ts: int = _player.grid_mover.tile_size
	for entry in _rats:
		# Back on its spot (a step it was taking when frozen, or spawning beside a taken tile,
		# can leave it a tile off), and nothing heard yet.
		entry[2].grid_mover.teleport(Vector2(entry[1] * ts))
		entry[2].senses.last_heard_db = 0.0
		entry.resize(3)
		entry.append(Vector2i((entry[2].global_position / ts).floor()))
	var at := (Vector2(_start) + Vector2(0.5, 0.5)) * ts
	if SOUNDS[i][0] == "footstep":
		load("res://scripts/debug/DebugState.gd").unseen = false
		_player._on_stepped(_start)  # the real footstep, the way a step makes it
		load("res://scripts/debug/DebugState.gd").unseen = true
	else:
		root.get_node("NetworkSync").report_noise(at, SOUNDS[i][1])  # what VoiceChat and an attack do

func _report(i: int) -> void:
	var name: String = SOUNDS[i][0]
	var db: float = SOUNDS[i][1]
	var ts: int = _player.grid_mover.tile_size
	var levels: Dictionary = _spread().flood(_spread().quad_at((Vector2(_start) + Vector2(0.5, 0.5)) * ts), db, _spread().FLOOR_DB, _spread().reader(self))
	var header := "  tiles   reaches   rat heard?"
	for c in _creatures:
		header += "  %s(%.0f)" % c
	print("\n%s, %.0f dB:" % [name.to_upper(), db])
	print(header)
	for entry in _rats:
		var rat: Node = entry[2]
		# Where the rat stood when the sound was made, the way Sound.make finds it.
		var tile: Vector2i = entry[3]
		var level: float = _spread().level_at(levels, tile, rat.grid_mover.footprint)
		var heard: bool = rat.senses.last_heard_db > 0.0
		var line := "  %5d   %5.1f dB  %-10s" % [entry[0], level, ("YES %.1f" % rat.senses.last_heard_db) if heard else "no"]
		if tile != entry[1]:
			line += "  (stood at %s, placed %s)" % [tile, entry[1]]
		for c in _creatures:
			line += "  %s" % ("hears".rpad(len("%s(%.0f)" % c)) if level >= c[1] else "-".rpad(len("%s(%.0f)" % c)))
		print(line)
		if heard != (level >= _creatures[0][1]):
			_problems.append("%s: the rat at %d tiles %s but %.1f dB reached it (hears from %.0f)" % [name, entry[0], "heard it" if heard else "did not hear it", level, _creatures[0][1]])

## SoundSpread, loaded when first used: an -s script cannot name classes that use autoloads.
func _spread():
	return load("res://scripts/cells/SoundSpread.gd")

func _finish() -> bool:
	print("\nPASS hearing_distances (a report; seed %d)" % _seed if _problems.is_empty() else "\nFAIL hearing_distances: " + "; ".join(_problems))
	quit(0 if _problems.is_empty() else 1)
	return true
