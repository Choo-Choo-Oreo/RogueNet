class_name LabPanel
extends CanvasLayer

## The Test Lab panel: which test cell you are at, what it is for, what to do, what counts as a
## bug, a live readout of the creatures, and a button that copies a bug report. Built in code,
## like DebugMenu. Cell text comes from test/sim/dev_cells.json (written by
## test/lab/development/generate_hub.py, where the text lives beside each cell).
##
##   [ or PageUp    previous cell            ] or PageDown  next cell
##   '  or F6       open the door            Enter or F7    open the door and wake everything in the cell
##   \  or F8       step inside the cell     Backspace / F9 reset cell (rebuild)
##   N  or F5       make the cell's noise    (a footstep or a rock landing where the cell says; see NOISE_AT)
##   /  or F10      copy bug report          F3             hide / show this panel
##   M              start the mic check      (only in voice_mic_check, see LabMicCheck)
## A voice_* cell has a fake teammate talking in it (LabVoice) while you are at that cell.
## Every key is also a button. It removes itself if you leave the dungeon.

const CELLS_FILE := "res://test/sim/dev_cells.json"
const REFRESH_SECONDS := 0.25
const STALL_SECONDS := 4.0
const STALL_MOVE := 0.6

var _cells: Array = []
var _center := Vector2i.ZERO
var _index := 0
var _pending := -1  # cell to arrive at once the (re)built dungeon has a player
var _player: Node2D
var _box: PanelContainer
var _title: Label
var _info: RichTextLabel
var _readout: Label
var _next_refresh := 0.0
var _track := {}  # creature -> {pos, moved}
var _started_msec := 0
var _voice: LabVoice  # the fake talker of a voice_* cell (voice_at), null elsewhere
var _mic: LabMicCheck  # the mic check of voice_mic_check, null elsewhere

func _ready() -> void:
	layer = 60
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CELLS_FILE))
	_cells = meta["cells"]
	_cells.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))
	_center = Vector2i(int(meta["width"]) / 2, int(meta["height"]) / 2)
	_build_ui()
	_pending = 0

func _build_ui() -> void:
	_box = PanelContainer.new()
	_box.position = Vector2(8, 8)
	_box.custom_minimum_size = Vector2(420, 0)
	add_child(_box)
	var v := VBoxContainer.new()
	_box.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	v.add_child(_title)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(400, 0)
	v.add_child(_info)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 12)
	v.add_child(_readout)
	for row in [[["Prev [", _step.bind(-1)], ["Next ]", _step.bind(1)], ["Reset Bksp", _reset]],
			[["Open door '", _open_door], ["Wake them Enter", _taunt], ["Noise N", _make_noise], ["Inside \\", _step_inside], ["Report /", _copy_report]]]:
		var h := HBoxContainer.new()
		v.add_child(h)
		for b in row:
			var btn := Button.new()
			btn.text = b[0]
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(b[1])
			h.add_child(btn)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_PAGEUP, KEY_BRACKETLEFT: _step(-1)
		KEY_PAGEDOWN, KEY_BRACKETRIGHT: _step(1)
		KEY_F6, KEY_APOSTROPHE: _open_door()
		KEY_F7, KEY_ENTER, KEY_KP_ENTER: _taunt()
		KEY_F5, KEY_N: _make_noise()
		KEY_F8, KEY_BACKSLASH: _step_inside()
		KEY_F9, KEY_BACKSPACE: _reset()
		KEY_F10, KEY_SLASH: _copy_report()
		KEY_F3: _box.visible = not _box.visible
		KEY_M: _start_mic_check()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.name != "Dungeon":
		if scene.name != "TestLab":  # TestLab is still there for the frame before the dungeon replaces it
			queue_free()  # went back to a menu
		return
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("protagonist")
		if players.is_empty():
			return
		_player = players[0]
		_player.set("debug_god", true)
		_track.clear()
		if _pending >= 0:
			_goto.call_deferred(_pending)
			_pending = -1
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _next_refresh:
		_next_refresh = now + REFRESH_SECONDS
		_refresh_readout()

func _step(delta: int) -> void:
	_goto(posmod(_index + delta, _cells.size()))

## Moves you to the hub side of the cell's door, door shut, so you can watch it wake up.
func _goto(i: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_index = i
	var c: Dictionary = _cells[_index]
	var door := _world(c["door"])
	var entry := _world(c["entry"])
	var outside := door + Vector2i(0, signi(door.y - entry.y)) * 2
	_player.grid_mover.teleport(Vector2(outside * _player.grid_mover.tile_size))
	_track.clear()
	_started_msec = Time.get_ticks_msec()
	_title.text = "%d / %d   %s" % [_index + 1, _cells.size(), c["name"]]
	var kind := "One creature, for looking at"
	if _is_regression(c):
		kind = "Regression cell: the headless sim checks it too"
	elif str(c["name"]).begins_with("manual_"):
		kind = "Manual cell: only you can judge this one"
	var checks := ""
	if not (c["reach"] as Array).is_empty():
		checks = "\n[b]Sim expects[/b] " + ", ".join(c["reach"]) + " to get within 3 tiles of you."
	_info.text = "[i]%s[/i]\n\n[b]What it is[/b] %s\n[b]Try[/b] %s\n[b]Look for[/b] %s%s" % [kind, c["what"], c["try"], c["look"], checks]
	_set_up_voice(c)

func _start_mic_check() -> void:
	if is_instance_valid(_mic):
		_mic.start()

## The fake talker (in the dungeon scene, so a reset rebuilds it) and the mic check: only at
## the cell that has one.
func _set_up_voice(c: Dictionary) -> void:
	if is_instance_valid(_voice):
		_voice.queue_free()
	if is_instance_valid(_mic):
		_mic.queue_free()
	_voice = null
	_mic = null
	if c.get("voice_at") != null:
		_voice = LabVoice.new()
		_voice.db = float(c["voice_at"]["db"])
		get_tree().current_scene.add_child(_voice)
		_voice.global_position = (Vector2(_world(c["voice_at"])) + Vector2(0.5, 0.5)) * _player.grid_mover.tile_size
	if c.get("mic_check", false):
		_mic = LabMicCheck.new()
		add_child(_mic)

func _is_regression(c: Dictionary) -> bool:
	return str(c["name"]).begins_with("bug") or not (c["reach"] as Array).is_empty()

func _reset() -> void:
	_pending = _index
	_player = null
	get_tree().reload_current_scene.call_deferred()

func _open_door() -> void:
	var door_tile := _world(_cells[_index]["door"])
	for door in DoorRegistry.doors:
		if door.cells.has(door_tile):
			DoorRegistry.set_open(door.id, true)

func _step_inside() -> void:
	if _player != null:
		var c: Dictionary = _cells[_index]
		_player.grid_mover.teleport(Vector2(_world(c["player_at"] if c.get("player_at") != null else c["entry"]) * _player.grid_mover.tile_size))

## The same call a taunt makes: every creature in the cell knows where you are, so a wall
## between you tests their pathfinding instead of their eyesight.
func _taunt() -> void:
	_open_door()
	for m in _creatures():
		m.force_target(_player, 30.0)

## The noise the sim makes for this cell (a footstep or a rock landing, see NOISE_AT in
## generate_hub.py), or a rock landing where you stand if the cell has none.
func _make_noise() -> void:
	var c: Dictionary = _cells[_index]
	var ts: int = _player.grid_mover.tile_size
	var at: Vector2 = _player.global_position
	var db: float = ActionIndex.resolve(["throw_rock"])[0].get("loudness_db", 0.0)
	if c.get("noise_at") != null:
		at = (Vector2(_world(c["noise_at"])) + Vector2(0.5, 0.5)) * ts
		db = float(c["noise_at"]["db"])
	NetworkSync.report_noise(at, db)
	DebugLog.add("Test Lab: noise (%.0f dB) at %s" % [db, Vector2i((at / ts).floor())])

func _cell_rect() -> Rect2i:
	var r: Dictionary = _cells[_index]["rect"]
	return Rect2i(_world(r), Vector2i(int(r["w"]), int(r["h"])))

func _world(hub: Dictionary) -> Vector2i:
	return Vector2i(int(hub["x"]), int(hub["y"])) - _center

func _tile_of(n: Node2D) -> Vector2i:
	var ts: int = _player.grid_mover.tile_size
	return Vector2i(floori(n.global_position.x / ts), floori(n.global_position.y / ts))

func _creatures() -> Array:
	var out := []
	var area := _cell_rect()
	for m: Node2D in get_tree().get_nodes_in_group("antagonist"):
		if is_instance_valid(m) and not m.is_queued_for_deletion() and area.has_point(_tile_of(m)):
			out.append(m)
	return out

func _lines() -> Array[String]:
	var out: Array[String] = []
	var now := Time.get_ticks_msec()
	var ts: int = _player.grid_mover.tile_size
	for m in _creatures():
		var t: Dictionary = _track.get(m, {})
		if t.is_empty() or t["pos"].distance_to(m.global_position) / ts >= STALL_MOVE:
			t = {"pos": m.global_position, "moved": now}
			_track[m] = t
		var d: float = m.global_position.distance_to(_player.global_position) / ts
		var state: int = int(m.get("_last_state"))
		var stalled: bool = state == 2 and d > 2.5 and now - int(t["moved"]) >= int(STALL_SECONDS * 1000.0)
		var bad: String = m.grid_mover.bad_tile_reason(_tile_of(m))
		var line := "%s %s: %s, %.1f tiles away" % [m.minion_id, _tile_of(m), ["patrol", "investigate", "attack"][state], d]
		if state == 1 and is_instance_valid(m.senses.investigate_marker):
			line += ", -> going to %s" % _tile_of(m.senses.investigate_marker)
		if is_instance_valid(m.get("_lock")):
			line += ", locked on you"
		if stalled:
			line += "  ** STALLED **"
		if bad != "":
			line += "  ** ON BAD TILE: %s **" % bad
		out.append(line)
	return out

func _refresh_readout() -> void:
	if _cells.is_empty() or _player == null:
		return
	var lines := _lines()
	if is_instance_valid(_voice):
		var reaches := "under your hearing" if _voice.heard_volume_db == VoiceChat.SILENT_DB else "reaches you at %.0f dB" % (_voice.db + _voice.heard_volume_db)
		lines.append("talker at %s: %.0f dB, %s (you hear from %.0f)" % [_tile_of(_voice), _voice.db, reaches, _player.viewer.hearing])
	if is_instance_valid(_mic):
		lines.append(_mic.status)
		lines.append_array(_mic.results)
	_readout.text = "You: %s\n%s" % [_tile_of(_player), "\n".join(lines) if not lines.is_empty() else "(no creatures in this cell)"]

func _copy_report() -> void:
	var c: Dictionary = _cells[_index]
	var text := "Bug report from the Test Lab\ncell: %s (seed %d, hub test/lab/development)\nyou: %s, %.0fs after arriving\n" % [
		c["name"], NetworkSync.dungeon_seed, _tile_of(_player), (Time.get_ticks_msec() - _started_msec) / 1000.0]
	text += "creatures:\n  " + "\n  ".join(_lines()) + "\n"
	text += "debug log (last lines):\n  " + "\n  ".join(DebugLog.lines.slice(-8)) + "\n"
	text += "what I saw: \n"
	DisplayServer.clipboard_set(text)
	DebugLog.add("Test Lab: report copied to the clipboard")
