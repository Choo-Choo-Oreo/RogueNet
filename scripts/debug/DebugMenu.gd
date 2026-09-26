class_name DebugMenu
extends CanvasLayer

## In-dungeon debug tools, built entirely in code (Dungeon.gd adds one).
##   F4  open / close the debug settings panel
##   F5  debug view on / off
## The panel is modelled on Factorio's debug settings:
##   always  overlays that draw whenever ticked
##   debug   the same overlays, drawn only while F5 is toggled on
##   tools   god mode, no clip, see all, spawn, teleport, kill all, doors, heal, game speed
## Performance capture: tick it, play, press save. The capture (build info,
## the debug log, one sample per second) is written to Godot's user folder,
## and "open" jumps to that folder. Nothing here is sent to chat.
## Root layer, not UI: it draws at real screen pixels, off the 640x360 grid. Its transform undoes
## the window's stretch, and `_screen` is the real window size (kept up to date), so the panel
## and overlay anchor to the whole window. It lives next to DebugDraw, outside the world's viewport.

const TILE := 16
const REFRESH_SECONDS := 0.25
const SAMPLE_SECONDS := 1.0

## Listed identically on the "always" and "debug" tabs (see DebugState.on). A one-item entry
## is a section heading. Protagonist = what your team senses; Antagonist = the minions' side.
const OPTIONS := [
	["General"],
	["show-fps", "FPS and frame time"],
	["show-coordinates", "Your tile and the mouse tile"],
	["show-room-under-mouse", "Room under you and the mouse"],
	["show-time-usage", "Process / physics time and node count"],
	["show-session-info", "Players, network, seed, biome, doors"],
	["show-system-time", "Time per system (minion AI, light, vision)"],
	["log-bodies-in-walls", "Log a creature on a wall / void / no-floor tile"],
	["Protagonist (your team)"],
	["show-vision", "Team vision, what the darkness leaves: yellow bright, blue dim (lit and in sight, or touched)"],
	["show-torch-light", "Each torch's reach: orange bright, brown dim (only players holding one)"],
	["show-adventurer-sight", "Each teammate's sight: tiles in range and line of sight, lit or not (green)"],
	["show-adventurer-touch", "Each teammate's touch: the tiles they feel (pink outline)"],
	["Antagonist (minions)"],
	["show-minion-counts", "Minion counts by state"],
	["show-minion-state", "Minion state and target"],
	["show-minion-routes", "Minion routes"],
	["show-sight", "Minion sight: range, and a line to you (green sees you, red blocked, grey too far)"],
	["show-sound", "Sound: each noise's spread (bright near, faint at its edge), what each minion hears from (dB), noise spots"],
	["show-touch", "Minion touch: range (solid while touching)"],
	["show-smell", "Minion smell (not built yet: draws nothing)"],
	["show-taste", "Minion taste (not built yet: draws nothing)"],
	["show-minion-inspector", "Inspector: everything the minion under the mouse is tracking"],
	["show-active-minions", "Minions thinking (green) vs waiting (grey)"],
	["show-flow-field", "Flow field to you: tiles away + step direction"],
	["World"],
	["show-room-outlines", "Room outlines"],
	["show-room-ids", "Room ids, roles and depth"],
	["show-connectors", "Connectors (green joined, red sealed)"],
	["show-doors", "Doors"],
	["show-tile-grid", "Tile grid (bright line every 8 tiles)"],
	["show-mesh-grid", "Mesh (dual) grid, half a tile off the tile grid"],
	["show-mesh-tiles", "Debug tile overlay on the mesh cells (50%)"],
	["show-collision-rectangles", "What blocks you (red) / shots only (orange)"],
]

# Fixed sizes so the panel never resizes when the tab or the hint text changes.
const PANEL_SIZE := Vector2(330, 620)
const TABS_SIZE := Vector2(310, 400)
const HINT_HEIGHT := 36.0
const FONT_SIZE := 10

## Full-window Control, in real screen pixels, that the overlay and panel sit in.
var _screen := Control.new()
var _panel: PanelContainer
var _overlay: Label
var _hint: Label
var _search: LineEdit
var _option_checks := {}
var _tabs: TabContainer
var _tools_locked := false
var _free_cam_check: CheckBox
## Game speed steps for the -/+ buttons (GameTick.speed; singleplayer only, like every tool).
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0]
var _speed_label: Label
var _option_boxes: Array[CheckBox] = []
var _option_scrolls: Array[ScrollContainer] = []
var _shared_scroll := 0
var _frames_since_refresh := 0
var _refresh_left := 0.0

var _capturing := false
var _capture_started_msec := 0
var _sample_left := 0.0
var _samples: Array[String] = []
var _capture_box: CheckBox

func _ready() -> void:
	layer = 100
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_fit_screen()
	DebugState.load_settings()
	_build_overlay()
	_build_panel()
	_panel.visible = false
	DebugLog.add("debug menu ready (build: %s)" % _build_kind())

## Undoes the window's stretch (its scale and black-bar offset) and applies GameView.debug_scale,
## so one unit here is one screen pixel of a 720-high window, and sizes `_screen` to the whole
## window. Checked every frame (_process): the root's size_changed does not fire on a window
## resize, since its 640x360 UI area stays the same.
func _fit_screen() -> void:
	var window := get_tree().root
	var factor := GameView.debug_scale(get_tree())
	var screen := Vector2(window.size) / factor
	if _screen.size != screen:
		transform = window.get_final_transform().affine_inverse() * Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2.ZERO)
		_screen.size = screen

# ---------------------------------------------------------------- building

func _build_overlay() -> void:
	_overlay = Label.new()
	_overlay.position = Vector2(8, 8)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_theme_font_size_override("font_size", DebugDraw.LABEL_SIZE)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 4)
	_screen.add_child(_overlay)

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -PANEL_SIZE.x - 8.0
	_panel.offset_right = -8.0
	_panel.offset_top = 8.0
	_panel.offset_bottom = PANEL_SIZE.y + 8.0
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.clip_contents = true
	_panel.mouse_entered.connect(func(): DebugState.mouse_over_menu = true)
	_panel.mouse_exited.connect(func(): DebugState.mouse_over_menu = false)
	_panel.theme = _make_theme()
	_screen.add_child(_panel)
	var root := VBoxContainer.new()
	_panel.add_child(root)

	_heading(root, "Debug settings")
	_capture_box = _check(root, "Capture performance statistics", false, func(on): _set_capture(on))
	var capture_row := HBoxContainer.new()
	_button(capture_row, "save", _save_capture)
	_button(capture_row, "open", func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	_button(capture_row, "reset overlays", _reset_defaults)
	root.add_child(capture_row)
	var warning := Label.new()
	warning.text = "Only for debugging and bug reports. These can cause game issues and slow things down."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(300, 36)
	warning.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	root.add_child(warning)

	_search = LineEdit.new()
	_search.placeholder_text = "search (Ctrl+F)"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_apply_filter)
	_search.text_submitted.connect(func(_text): _search.release_focus())
	root.add_child(_search)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = TABS_SIZE
	tabs.tab_changed.connect(func(_i): _sync_scroll.call_deferred())
	_tabs = tabs
	root.add_child(tabs)

	var always_box := _tab(tabs, "always")
	_options(always_box, "always")

	var debug_box := _tab(tabs, "debug")
	_options(debug_box, "debug")

	var tools_box := _tab(tabs, "tools")
	_check(tools_box, "god-mode (can't be hurt)", DebugState.god_mode, func(on): _set_god(on))
	_check(tools_box, "no-clip (walk through walls)", DebugState.no_clip, func(on): DebugState.no_clip = on)
	_check(tools_box, "see-all (no darkness)", DebugState.see_all, func(on): DebugState.see_all = on)
	_check(tools_box, "unseen (minions cannot see you)", DebugState.unseen, func(on): DebugState.unseen = on)
	_free_cam_check = _check(tools_box, "free-cam (camera detaches, you stand still)", DebugState.free_cam, func(on): DebugState.free_cam = on)
	var types := OptionButton.new()
	for minion_id: String in MinionIndex.ids():
		types.add_item(minion_id)
	if types.item_count > 0:
		if DebugState.spawn_type == "":
			DebugState.spawn_type = types.get_item_text(0)
		types.select(maxi(0, _index_of(types, DebugState.spawn_type)))
	types.item_selected.connect(func(i): DebugState.spawn_type = types.get_item_text(i))
	tools_box.add_child(types)
	_button(tools_box, "Spawn minion (then click the map)", func(): DebugState.click_tool = "spawn")
	_button(tools_box, "Teleport (then click the map)", func(): DebugState.click_tool = "teleport")
	_button(tools_box, "Kill all minions", _kill_all)
	_button(tools_box, "Open all doors", func(): _all_doors(true))
	_button(tools_box, "Close all doors", func(): _all_doors(false))
	_button(tools_box, "Heal me to full", _heal)
	var speed_row := HBoxContainer.new()
	_button(speed_row, "-", func(): _step_speed(-1))
	_speed_label = Label.new()
	speed_row.add_child(_speed_label)
	_button(speed_row, "+", func(): _step_speed(1))
	tools_box.add_child(speed_row)
	_show_speed()
	_button(tools_box, "New dungeon (same biome)", func(): _regenerate(false))
	_button(tools_box, "New dungeon (random biome)", func(): _regenerate(true))
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(300, HINT_HEIGHT)
	root.add_child(_hint)
	_no_focus(_panel)
	tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	_search.focus_mode = Control.FOCUS_CLICK

## One scrolling page of the tab container.
func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

## "always" ticks draw all the time; "debug" ticks only while F5 debug view is on.
## Both tabs scroll together so switching between them keeps your place.
func _options(parent: Control, tab: String) -> void:
	for option in OPTIONS:
		if option.size() == 1:
			var heading := Label.new()
			heading.text = option[0]
			parent.add_child(heading)
			continue
		var key: String = tab + ":" + option[0]
		var box := _check(parent, option[0], DebugState.flags.get(key, false), func(on): DebugState.set_flag(key, on))
		box.tooltip_text = option[1]
		_option_boxes.append(box)
		_option_checks[key] = box
	var scroll := parent.get_parent() as ScrollContainer
	_option_scrolls.append(scroll)
	scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled.bind(scroll))

func _on_scrolled(value: float, source: ScrollContainer) -> void:
	if not source.is_visible_in_tree():
		return
	_shared_scroll = int(value)
	for scroll in _option_scrolls:
		if scroll != source:
			scroll.scroll_vertical = _shared_scroll

func _sync_scroll() -> void:
	for scroll in _option_scrolls:
		scroll.scroll_vertical = _shared_scroll

func _apply_filter(query: String) -> void:
	var wanted := query.strip_edges().to_lower()
	for box in _option_boxes:
		box.visible = wanted == "" or box.text.contains(wanted)

## Smaller text and tighter rows, applied to everything inside the panel.
func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_constant("separation", "VBoxContainer", 1)
	for state in ["normal", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "CheckBox", _row_style(Color.TRANSPARENT))
	for state in ["hover", "hover_pressed"]:
		theme.set_stylebox(state, "CheckBox", _row_style(Color(1, 1, 1, 0.08)))
	return theme

func _row_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

## WASD are also the ui_* focus keys, so a focused button would steal them and
## walk the focus around the panel. Only the search box may take focus.
func _no_focus(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not child is LineEdit:
			child.focus_mode = Control.FOCUS_NONE
		_no_focus(child)

func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	parent.add_child(label)

func _check(parent: Control, text: String, initial: bool, on_toggle: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = initial
	box.clip_text = true
	box.toggled.connect(on_toggle)
	parent.add_child(box)
	return box

func _button(parent: Control, text: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	parent.add_child(button)

func _index_of(options: OptionButton, text: String) -> int:
	for i in options.item_count:
		if options.get_item_text(i) == text:
			return i
	return -1

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# A click anywhere outside the search box gives the keyboard back to the game.
	if event is InputEventMouseButton and event.pressed and _search.has_focus() \
			and not _search.get_global_rect().has_point(_search.get_global_mouse_position()):
		_search.release_focus()
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F4:
		_panel.visible = not _panel.visible
		if not _panel.visible:
			DebugState.mouse_over_menu = false
			_search.release_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F5:
		DebugState.debug_view = not DebugState.debug_view
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F and event.ctrl_pressed and _panel.visible:
		_search.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _search.has_focus():
		_search.release_focus()
		get_viewport().set_input_as_handled()

## Clicks that reach here weren't taken by the panel or anything else in the UI.
func _unhandled_input(event: InputEvent) -> void:
	if DebugState.click_tool == "":
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		DebugState.click_tool = ""
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_run_click_tool(_mouse_tile())
		DebugState.click_tool = ""
	else:
		return
	get_viewport().set_input_as_handled()

## The world position under the mouse. In a GameView this menu is outside the world's viewport,
## so it uses the debug layer's world-to-screen mapping (the one DebugDraw draws with, snapped
## camera included). A scene loaded on its own (a test) uses its viewport's camera.
func _mouse_world() -> Vector2:
	var view := GameView.of(self)
	if view:
		return view.debug_layer.transform.affine_inverse() * view.get_viewport().get_mouse_position()
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()

func _mouse_tile() -> Vector2i:
	var pos := _mouse_world()
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))

func _run_click_tool(tile: Vector2i) -> void:
	match DebugState.click_tool:
		"spawn":
			if DebugState.spawn_type != "":
				DebugLog.add("spawn %s at %s" % [DebugState.spawn_type, tile])
				NetworkSync.debug_spawn_minion(DebugState.spawn_type, tile)
		"teleport":
			var player := PlayerLookup.find_local(get_tree())
			if player != null:
				DebugLog.add("teleport to %s" % tile)
				player.grid_mover.teleport(Vector2(tile) * TILE)

# ---------------------------------------------------------------- actions

## Puts every overlay tick back to the shipped default set.
func _reset_defaults() -> void:
	DebugState.reset_defaults()
	for key in _option_checks:
		_option_checks[key].set_pressed_no_signal(DebugState.flags.get(key, false))
	DebugLog.add("overlay settings reset to defaults")

## Real multiplayer (NetworkSync.is_online) has no tools: the tab disappears and
## everything on it is switched off.

func _update_tools_lock() -> void:
	var locked := NetworkSync.is_online()
	if locked == _tools_locked:
		return
	_tools_locked = locked
	var tools_index := _tabs.get_tab_count() - 1
	_tabs.set_tab_hidden(tools_index, locked)
	if locked:
		if _tabs.current_tab == tools_index:
			_tabs.current_tab = 0
		_set_god(false)
		DebugState.no_clip = false
		DebugState.see_all = false
		DebugState.unseen = false
		DebugState.free_cam = false
		_free_cam_check.set_pressed_no_signal(false)
		DebugState.click_tool = ""
		GameTick.speed = 1.0
		_show_speed()
		DebugLog.add("tools locked (multiplayer)")

func _step_speed(direction: int) -> void:
	var i := SPEEDS.find(GameTick.speed)
	if i < 0:
		i = SPEEDS.find(1.0)
	GameTick.speed = SPEEDS[clampi(i + direction, 0, SPEEDS.size() - 1)]
	_show_speed()
	DebugLog.add("game speed %sx" % GameTick.speed)

func _show_speed() -> void:
	_speed_label.text = "game speed %sx" % GameTick.speed

## Leaving the dungeon (back to town, a new mission) puts time back to normal.
func _exit_tree() -> void:
	GameTick.speed = 1.0

## Rebuilds the dungeon from a fresh seed without going back through the town:
## the same path a mission start takes, minus the menus. Tools only exist in
## singleplayer, so there is no other peer to keep in step.
func _regenerate(new_biome: bool) -> void:
	if NetworkSync.is_online():
		return
	NetworkSync.dungeon_seed = randi()
	if new_biome or NetworkSync.dungeon_biome == "":
		NetworkSync.dungeon_biome = DungeonAssembler.pick_biome(NetworkSync.dungeon_seed)
	DebugLog.add("regenerating dungeon: seed %d, biome %s" % [NetworkSync.dungeon_seed, NetworkSync.dungeon_biome])
	DebugState.click_tool = ""
	GameView.reload(get_tree())

func _set_god(on: bool) -> void:
	DebugState.god_mode = on
	DebugLog.add("god mode %s" % ("on" if on else "off"))
	NetworkSync.set_god_mode(on)

func _kill_all() -> void:
	DebugLog.add("kill all minions")
	for minion in get_tree().get_nodes_in_group("antagonist"):
		NetworkSync.report_minion_hit(int(str(minion.name)), 9999, "")

func _all_doors(open: bool) -> void:
	DebugLog.add("%s all doors" % ("open" if open else "close"))
	NetworkSync.debug_all_doors(open)

func _heal() -> void:
	var player := PlayerLookup.find_local(get_tree())
	if player != null:
		player.stats.heal_to_full()

# ---------------------------------------------------------------- capture

func _set_capture(on: bool) -> void:
	_capturing = on
	if on:
		_samples.clear()
		_capture_started_msec = Time.get_ticks_msec()
		_sample_left = 0.0
		DebugLog.add("performance capture started")
	else:
		DebugLog.add("performance capture stopped (%d samples)" % _samples.size())

func _sample() -> void:
	var seconds := (Time.get_ticks_msec() - _capture_started_msec) / 1000.0
	_samples.append("%.1f,%d,%.2f,%.2f,%d,%d,%d" % [
		seconds,
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		get_tree().get_nodes_in_group("antagonist").size(),
		get_tree().get_nodes_in_group("protagonist").size()])

func _build_kind() -> String:
	return "editor/debug" if OS.is_debug_build() else "release export"

## Writes build info, the debug log and the samples to user://, and says where.
func _save_capture() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://debug_capture_%s.txt" % stamp
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_hint.text = "Could not write %s" % path
		return
	file.store_line("RogueNet debug capture")
	file.store_line("saved: %s" % Time.get_datetime_string_from_system())
	file.store_line("build: %s   godot %s   os %s   renderer %s" % [
		_build_kind(), Engine.get_version_info()["string"], OS.get_name(), RenderingServer.get_video_adapter_name()])
	file.store_line("dungeon: seed %d   biome %s   rooms %d   doors %d" % [
		NetworkSync.dungeon_seed, NetworkSync.dungeon_biome, DebugState.placements.size(), DoorRegistry.doors.size()])
	file.store_line("")
	file.store_line("--- log")
	for line in DebugLog.lines:
		file.store_line(line)
	file.store_line("")
	file.store_line("--- performance (one sample per second)")
	file.store_line("seconds,fps,process_ms,physics_ms,nodes,minions,players")
	for row in _samples:
		file.store_line(row)
	file.close()
	var full := ProjectSettings.globalize_path(path)
	DebugLog.add("saved capture to %s" % full)
	_hint.text = "Saved to %s" % full

# ---------------------------------------------------------------- overlay

func _process(delta: float) -> void:
	_fit_screen()
	if _hint != null and DebugState.click_tool != "":
		if DebugState.click_tool == "spawn":
			_hint.text = "Click the map to spawn %s. Right click cancels." % DebugState.spawn_type
		else:
			_hint.text = "Click the map to teleport there. Right click cancels."
	if _capturing:
		_sample_left -= delta
		if _sample_left <= 0.0:
			_sample_left = SAMPLE_SECONDS
			_sample()
	_frames_since_refresh += 1
	_update_tools_lock()
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		for key in DebugState.time_acc:
			DebugState.usage_ms[key] = DebugState.time_acc[key] / 1000.0 / maxi(_frames_since_refresh, 1)
		DebugState.time_acc.clear()
		_frames_since_refresh = 0
		_overlay.text = _overlay_text()

func _overlay_text() -> String:
	var lines: Array[String] = []
	if DebugState.debug_view:
		lines.append("DEBUG VIEW (F5)" + ("   CAPTURING" if _capturing else ""))
	elif _capturing:
		lines.append("CAPTURING")
	if DebugState.on("show-fps"):
		lines.append("FPS %d   frame %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)])
	if DebugState.on("show-time-usage"):
		lines.append("process %.1f ms   physics %.1f ms   nodes %d" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if DebugState.on("show-minion-counts"):
		var counts := [0, 0, 0]
		var minions := get_tree().get_nodes_in_group("antagonist")
		for minion in minions:
			if "_last_state" in minion:
				counts[clampi(int(minion._last_state), 0, 2)] += 1
		lines.append("Minions %d   patrol %d   investigate %d   attack %d" % [minions.size(), counts[0], counts[1], counts[2]])
	if DebugState.on("show-active-minions"):
		var thinking := 0
		var all := get_tree().get_nodes_in_group("antagonist")
		for minion in all:
			if minion.has_method("is_thinking") and minion.is_thinking():
				thinking += 1
		lines.append("Minions thinking %d   waiting %d" % [thinking, all.size() - thinking])
	if DebugState.on("show-system-time"):
		var parts: Array[String] = []
		for key in DebugState.usage_ms:
			parts.append("%s %.2f ms" % [key, DebugState.usage_ms[key]])
		lines.append("Per frame: " + ("   ".join(parts) if not parts.is_empty() else "(no data yet)"))
	if DebugState.on("show-session-info"):
		lines.append_array(_session_lines())
	if DebugState.on("show-coordinates") or DebugState.on("show-room-under-mouse"):
		lines.append_array(_position_lines())
	var active: Array[String] = []
	if DebugState.god_mode: active.append("god")
	if DebugState.no_clip: active.append("no clip")
	if DebugState.see_all: active.append("see all")
	if DebugState.unseen: active.append("unseen")
	if DebugState.free_cam: active.append("free cam")
	if not active.is_empty():
		lines.append("Active: " + ", ".join(active))
	return "\n".join(lines)

func _session_lines() -> Array[String]:
	var lines: Array[String] = []
	var players := get_tree().get_nodes_in_group("protagonist")
	var alive := PlayerLookup.living(get_tree()).size()
	var net := "offline"
	if multiplayer.multiplayer_peer != null:
		net = "host" if multiplayer.is_server() else "client"
	lines.append("Players %d (alive %d)   %s   peers %d" % [players.size(), alive, net, multiplayer.get_peers().size()])
	lines.append("Seed %d   biome %s   rooms %d" % [NetworkSync.dungeon_seed, NetworkSync.dungeon_biome, DebugState.placements.size()])
	var open_doors := 0
	for door: DoorRegistry.Door in DoorRegistry.doors:
		if door.is_open:
			open_doors += 1
	lines.append("Doors %d (open %d)" % [DoorRegistry.doors.size(), open_doors])
	return lines

func _position_lines() -> Array[String]:
	var lines: Array[String] = []
	var show_tiles := DebugState.on("show-coordinates")
	var show_rooms := DebugState.on("show-room-under-mouse")
	var local := PlayerLookup.find_local(get_tree())
	if local != null:
		var own := Vector2i(floori(local.global_position.x / TILE), floori(local.global_position.y / TILE))
		lines.append("You" + (" at %s" % own if show_tiles else "") + (_room_text(own) if show_rooms else ""))
	var mouse := _mouse_tile()
	lines.append("Mouse" + (" at %s" % mouse if show_tiles else "") + (_room_text(mouse) if show_rooms else ""))
	return lines

func _room_text(tile: Vector2i) -> String:
	var index := DebugState.room_index_at(tile)
	if index < 0:
		return "   (no room)"
	var p = DebugState.placements[index]
	var room: Dictionary = DebugState.rooms.get(p.room_id, {})
	return "   room #%d %s (%s, depth %d)" % [index, p.room_id, room.get("role", "normal"), p.depth]
