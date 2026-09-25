extends Control

class_name SettingsMenu

## The settings screen: a parchment scroll that unrolls over whatever opened it (the main menu or
## the pause menu) and rolls back up on Close or Esc. Ribbon tabs down its right edge switch pages.
## Each setting is its own small script in scripts/settings/ that reads, applies and saves its
## value (and has restore_default()); this file only builds the look and the previews.
## - A slider is an ink line with a candle for a handle: out at 0, the flame grows to the right.
## - An on/off setting is a wax seal: stamped = on.
## - Hovering or focusing a line puts its note at the bottom of the paper.
## - Combat feel previews itself: shake jolts the scroll, the red edge flashes, hit-stop
##   freezes the candles for a blink.
## Art: resources/gfx/ui/settings/ (colours from Parchment.gd and the main menu scrolls).

const ART := "res://resources/gfx/ui/settings/"
const AUDIO_CONTROL := preload("res://scripts/settings/AudioControl.gd")
const FULLSCREEN_CONTROL := preload("res://scripts/settings/FullscreenControl.gd")
const VSYNC_CONTROL := preload("res://scripts/settings/VSyncControl.gd")
const FEEDBACK_CONTROL := preload("res://scripts/settings/FeedbackControl.gd")

const PX := Parchment.PX
## The things you handle (candles, seals, ribbons) are drawn a size up from the paper, so
## they read at a glance and are easy to hit.
const HANDLE_PX := 3
const INK := Parchment.INK
const INK_SOFT := Color("#6b4a32")
const SHEET_WIDTH := 520.0
const LABEL_WIDTH := 120.0
## One candle frame in Candle.png, in art pixels. The sheet is 6 levels x 2 flicker frames:
## level 0 is out, 1-5 are the flame sizes.
const CANDLE := Vector2i(11, 20)
const CANDLE_LEVELS := 6
## Art row the wax's middle sits on; the ink line runs through it.
const CANDLE_WAX_MIDDLE := 15.5
const FLICKER_SECONDS := 0.17
const HIT_STOP_PREVIEW_MSEC := 450
const OPEN_SECONDS := 0.45
const SHAKE_PX := 6.0
const SHAKE_SECONDS := 0.22
const NOTE_REST := "Hover a line for its note."

const PAGES := [
	{"id": "sound", "title": "Sound"},
	{"id": "screen", "title": "Screen"},
	{"id": "feel", "title": "Combat feel"},
	{"id": "controls", "title": "Controls"},
]

## 0 = rolled up, 1 = open. _layout reads it.
var _open := 0.0
var _closing := false
var _page := ""
var _pages := {}                      # page id -> its VBoxContainer
var _tabs := {}                       # page id -> its ribbon Button
var _sliders: Array[HSlider] = []
var _candles: Array = []              # [level][frame] -> AtlasTexture
var _frozen_until := 0
var _shake_left := 0.0
var _shake_px := 0.0

var _backdrop: ColorRect
var _scroll: Control
var _ribbons: Control
var _clip: Control
var _paper: NinePatchRect
var _content: MarginContainer
var _title: Label
var _note: Label
var _restore: Button
var _roller_top: NinePatchRect
var _roller_bottom: NinePatchRect
var _flash: Panel
var _row_lit: StyleBoxFlat
var _ribbon_style: StyleBoxTexture
var _ribbon_active_style: StyleBoxTexture

func _ready() -> void:
	# Cover the whole screen, whichever inset panel it was opened in.
	top_level = true
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)
	_cut_candles()
	_build()
	_show_page("sound")
	for slider in _sliders:
		_slider_changed(slider)
	var flicker := Timer.new()
	flicker.wait_time = FLICKER_SECONDS
	flicker.timeout.connect(_flicker)
	add_child(flicker)
	flicker.start()
	_backdrop.modulate.a = 0.0
	var unroll := create_tween().set_parallel()
	unroll.tween_method(_set_open, 0.0, 1.0, OPEN_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	unroll.tween_property(_backdrop, "modulate:a", 1.0, OPEN_SECONDS * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

## Rolls the scroll up, then closes the panel it was opened in.
func close_menu() -> void:
	if _closing:
		return
	_closing = true
	var roll_up := create_tween()
	roll_up.tween_method(_set_open, _open, 0.0, OPEN_SECONDS * 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	roll_up.tween_property(_backdrop, "modulate:a", 0.0, 0.12)
	await roll_up.finished
	get_parent().hide()
	queue_free()

func _fit_screen() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size

func _set_open(amount: float) -> void:
	_open = amount
	_layout()

# ---------- building ----------

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.07, 0.05, 0.04, 0.8)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)  # stops clicks reaching the menu underneath

	_scroll = Control.new()
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)

	# Ribbons first, so the paper covers their inner ends.
	_ribbon_style = _ribbon_box("Ribbon.png")
	_ribbon_active_style = _ribbon_box("RibbonActive.png")
	_ribbons = Control.new()
	_ribbons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_ribbons)
	for page in PAGES:
		var tab := _ribbon(page.title)
		tab.pressed.connect(_show_page.bind(page.id))
		_tabs[page.id] = tab
		_ribbons.add_child(tab)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_clip)

	_paper = NinePatchRect.new()
	_paper.texture = Parchment.pixel_texture(ART + "Paper.png")
	_paper.patch_margin_left = 3 * PX
	_paper.patch_margin_right = 3 * PX
	_paper.patch_margin_top = 3 * PX
	_paper.patch_margin_bottom = 2 * PX
	_paper.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_paper.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_paper)

	_content = MarginContainer.new()
	for side in ["left", "right"]:
		_content.add_theme_constant_override("margin_" + side, 28)
	_content.add_theme_constant_override("margin_top", 26)
	_content.add_theme_constant_override("margin_bottom", 16)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_content)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_content.add_child(column)

	_title = Parchment.ink_label("", 26)
	column.add_child(_title)
	var rule := ColorRect.new()
	rule.color = INK
	rule.custom_minimum_size = Vector2(0, PX)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_row_lit = StyleBoxFlat.new()
	_row_lit.bg_color = Color(Parchment.PAPER_DARK, 0.18)
	_row_lit.content_margin_left = 6
	_row_lit.content_margin_right = 6
	_note = Parchment.ink_label(NOTE_REST, 14)
	_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 40)
	_note.add_theme_color_override("font_color", INK_SOFT)
	var italic := FontVariation.new()
	italic.base_font = _note.get_theme_font("font")
	italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	_note.add_theme_font_override("font", italic)

	var pages := VBoxContainer.new()
	column.add_child(pages)
	_pages["sound"] = _page_box([
		_volume_row("Master", "Master", "Everything at once. The other three lines are shares of this one."),
		_volume_row("Music", "Music", "Town and dungeon music."),
		_volume_row("SFX", "Effects", "Hits, spells, doors, footsteps, minions, ambience."),
		_volume_row("UI", "Interface", "Clicks, page turns, the scrolls unrolling."),
	])
	_pages["screen"] = _page_box([
		_seal_row(_setting(CheckButton.new(), FULLSCREEN_CONTROL), "Fullscreen", "Takes over the whole monitor."),
		_seal_row(_setting(CheckButton.new(), VSYNC_CONTROL), "VSync", "Stops the picture tearing. Turn it off if the game feels a little slow to respond."),
	])
	var shake := _candle_slider(0.05)
	var red_edge := CheckButton.new()
	var hit_stop := CheckButton.new()
	_pages["feel"] = _page_box([
		_slider_row(_setting(shake, FEEDBACK_CONTROL, "screen_shake"), "Shake", "How hard the screen jolts when you're hit. Drag it and the scroll shows you."),
		_seal_row(_setting(red_edge, FEEDBACK_CONTROL, "screen_flash"), "Red edge when hurt", "The screen edge flashes red on a big hit."),
		_seal_row(_setting(hit_stop, FEEDBACK_CONTROL, "hit_stop"), "Hit-stop on big hits", "The picture freezes for a blink on a big hit. Game time doesn't stop."),
	])
	var later := Parchment.ink_label("Key bindings get this page once the controls settle.", 15)
	later.add_theme_color_override("font_color", INK_SOFT)
	later.add_theme_font_override("font", italic)
	_pages["controls"] = _page_box([later])
	for id in _pages:
		pages.add_child(_pages[id])
	# Previews, only once the scroll is open (the controls set their saved values on the way in).
	shake.value_changed.connect(func(v: float): if _open >= 1.0: _shake(v))
	red_edge.toggled.connect(func(on: bool): if on: _flash_edge())
	hit_stop.toggled.connect(func(on: bool): if on: _frozen_until = Time.get_ticks_msec() + HIT_STOP_PREVIEW_MSEC)

	var foot := HBoxContainer.new()
	column.add_child(foot)
	_restore = _ink_button("Restore defaults", Parchment.pixel_texture(ART + "InkBlot.png"))
	_restore.pressed.connect(_restore_defaults)
	_restore.mouse_entered.connect(func(): _note.text = "Puts this page back the way it came.")
	foot.add_child(_restore)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var close := _ink_button("Close  (Esc)", null)
	close.pressed.connect(close_menu)
	foot.add_child(close)
	column.add_child(_note)

	_roller_top = _roller()
	_roller_bottom = _roller()
	_scroll.add_child(_roller_top)
	_scroll.add_child(_roller_bottom)

	_flash = Panel.new()
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0, 0, 0, 0)
	edge.border_color = Color(0.77, 0.13, 0.09, 0.8)
	edge.set_border_width_all(70)
	edge.border_blend = true
	_flash.add_theme_stylebox_override("panel", edge)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)

	resized.connect(_layout)
	_content.minimum_size_changed.connect(_layout)

## `node` with a scripts/settings/ script on it (and its settings key, for FeedbackControl).
func _setting(node: Control, script: Script, key := "") -> Control:
	node.set_script(script)
	if key != "":
		node.set("key", key)
	return node

func _page_box(rows: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for row in rows:
		box.add_child(row)
	return box

func _volume_row(bus: String, text: String, note: String) -> PanelContainer:
	var line := _line(text)
	line.set_script(AUDIO_CONTROL)
	line.set("audio_bus_name", bus)
	var slider := _candle_slider(0.01)
	slider.name = "AudioSliderControl"
	line.add_child(slider)
	line.add_child(_readout(slider))
	return _row(line, slider, note)

func _slider_row(slider: HSlider, text: String, note: String) -> PanelContainer:
	var line := _line(text)
	line.add_child(slider)
	line.add_child(_readout(slider))
	return _row(line, slider, note)

func _seal_row(button: CheckButton, text: String, note: String) -> PanelContainer:
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 13 * HANDLE_PX + 8
	var sheet := Parchment.pixel_texture(ART + "Seal.png", HANDLE_PX)
	var on := _cut(sheet, Rect2(0, 0, 11 * HANDLE_PX, 13 * HANDLE_PX))
	var off := _cut(sheet, Rect2(11 * HANDLE_PX, 0, 11 * HANDLE_PX, 13 * HANDLE_PX))
	for state in ["checked", "checked_disabled", "checked_mirrored", "checked_disabled_mirrored"]:
		button.add_theme_icon_override(state, on)
	for state in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
		button.add_theme_icon_override(state, off)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_font_size_override("font_size", 16)
	var line := HBoxContainer.new()
	line.add_child(button)
	return _row(line, button, note)

## A label and room for a control after it.
func _line(text: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var label := Parchment.ink_label(text, 16)
	label.custom_minimum_size.x = LABEL_WIDTH
	line.add_child(label)
	return line

## Wraps a line so it lights up (and shows its note) while `control` is hovered or focused.
func _row(line: Control, control: Control, note: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unlit := StyleBoxEmpty.new()
	unlit.content_margin_left = 6
	unlit.content_margin_right = 6
	row.add_theme_stylebox_override("panel", unlit)
	row.add_child(line)
	var light := func(on: bool):
		row.add_theme_stylebox_override("panel", _row_lit if on else unlit)
		if on:
			_note.text = note
	control.mouse_entered.connect(light.bind(true))
	control.focus_entered.connect(light.bind(true))
	control.mouse_exited.connect(func(): if not control.has_focus(): light.call(false))
	control.focus_exited.connect(light.bind(false))
	return row

func _candle_slider(step: float) -> HSlider:
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Room for the wax; a tall flame reaches up past the row, into the gap above it.
	slider.custom_minimum_size.y = 50
	slider.tick_count = 11
	slider.ticks_on_borders = true
	slider.add_theme_stylebox_override("slider", _ink_line(Parchment.PAPER_DARK))
	slider.add_theme_stylebox_override("grabber_area", _ink_line(INK))
	slider.add_theme_stylebox_override("grabber_area_highlight", _ink_line(INK))
	slider.add_theme_icon_override("tick", Parchment.pixel_texture(ART + "Tick.png"))
	# The candle is drawn centred on the line; lift it so the wax, not the flame, sits on it.
	slider.add_theme_constant_override("grabber_offset", roundi((CANDLE.y / 2.0 - CANDLE_WAX_MIDDLE) * HANDLE_PX))
	slider.value_changed.connect(func(_v: float): _slider_changed(slider))
	_sliders.append(slider)
	return slider

func _ink_line(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_top = 1.5
	box.content_margin_bottom = 1.5
	return box

## How far a ribbon's inner end hides under the paper.
const RIBBON_TUCK := 12.0

## The value in ink after a slider, 0-100.
func _readout(slider: HSlider) -> Label:
	var label := Parchment.ink_label("", 16)
	label.custom_minimum_size.x = 40
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.set_meta("readout", label)
	return label

func _slider_changed(slider: HSlider) -> void:
	_set_candle(slider, 0)
	var readout: Label = slider.get_meta("readout", null)
	if readout:
		readout.text = str(roundi(slider.value * 100.0))

func _cut_candles() -> void:
	var sheet := Parchment.pixel_texture(ART + "Candle.png", HANDLE_PX)
	for level in CANDLE_LEVELS:
		var frames := []
		for frame in 2:
			frames.append(_cut(sheet, Rect2((level * 2 + frame) * CANDLE.x * HANDLE_PX, 0, CANDLE.x * HANDLE_PX, CANDLE.y * HANDLE_PX)))
		_candles.append(frames)

func _cut(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas

## Out at the far left, then one flame size per fifth of the range.
func _set_candle(slider: HSlider, frame: int) -> void:
	var share := (slider.value - slider.min_value) / (slider.max_value - slider.min_value)
	var level := 0 if share <= 0.0 else mini(CANDLE_LEVELS - 1, ceili(share * (CANDLE_LEVELS - 1)))
	var icon: Texture2D = _candles[level][frame]
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(state, icon)

func _flicker() -> void:
	if Time.get_ticks_msec() < _frozen_until:
		return
	for slider in _sliders:
		if randf() < 0.5:
			_set_candle(slider, randi() % 2)

func _ribbon_box(file: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = Parchment.pixel_texture(ART + file, HANDLE_PX)
	box.texture_margin_left = 2 * HANDLE_PX
	box.texture_margin_right = 5 * HANDLE_PX
	box.content_margin_left = RIBBON_TUCK + 10
	box.content_margin_right = 4 * HANDLE_PX + 8
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box

func _ribbon(text: String) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.focus_mode = Control.FOCUS_NONE
	tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tab.custom_minimum_size.y = 9 * HANDLE_PX
	tab.add_theme_font_size_override("font_size", 14)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		tab.add_theme_color_override(state, Parchment.PAPER_LIGHT)
	return tab

func _ink_button(text: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	var underline := StyleBoxFlat.new()
	underline.bg_color = Color(0, 0, 0, 0)
	underline.border_color = INK
	underline.border_width_bottom = PX
	for state in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["hover", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, underline)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_font_size_override("font_size", 15)
	return button

func _roller() -> NinePatchRect:
	var roller := NinePatchRect.new()
	roller.texture = Parchment.pixel_texture(ART + "Roller.png")
	roller.patch_margin_left = 4 * PX
	roller.patch_margin_right = 4 * PX
	roller.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	roller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return roller

# ---------- pages and layout ----------

func _show_page(id: String) -> void:
	_page = id
	for page_id in _pages:
		_pages[page_id].visible = page_id == id
	for page_id in _tabs:
		var style: StyleBoxTexture = _ribbon_active_style if page_id == id else _ribbon_style
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			_tabs[page_id].add_theme_stylebox_override(state, style)
	for page in PAGES:
		if page.id == id:
			_title.text = page.title
	_restore.visible = id != "controls"
	_note.text = NOTE_REST
	_layout()
	# The page's minimum size settles a frame later.
	_layout.call_deferred()

## Places the paper, rollers and ribbons for the screen size and how far the scroll is open.
## The paper stays put while the clip around it grows from the middle, rollers on its edges.
func _layout() -> void:
	if _clip == null:
		return
	var w := minf(SHEET_WIDTH, size.x - 160.0)
	_content.custom_minimum_size.x = w
	var h := ceilf(_content.get_combined_minimum_size().y / PX) * PX
	var corner := ((size - Vector2(w, h)) / 2.0 / PX).floor() * PX
	var shown := roundf(h * _open / PX) * PX
	_clip.position = Vector2(corner.x, corner.y + (h - shown) / 2.0)
	_clip.size = Vector2(w, shown)
	var inner := Vector2(0, -(h - shown) / 2.0)
	_paper.position = inner
	_paper.size = Vector2(w, h)
	_content.position = inner
	_content.size = Vector2(w, h)
	for roller in [_roller_top, _roller_bottom]:
		roller.size = Vector2(w + 6 * PX, 9 * PX)
	_roller_top.position = Vector2(corner.x - 3 * PX, _clip.position.y - 6 * PX)
	_roller_bottom.position = Vector2(corner.x - 3 * PX, _clip.position.y + shown - 3 * PX)
	var y := corner.y + 34.0
	for page in PAGES:
		var tab: Button = _tabs[page.id]
		tab.size = tab.get_combined_minimum_size()
		tab.position = Vector2(corner.x + w - RIBBON_TUCK - (0.0 if page.id == _page else 3.0 * HANDLE_PX), y)
		y += tab.size.y + 6.0
	_ribbons.modulate.a = clampf(_open * 2.0 - 1.0, 0.0, 1.0)

func _restore_defaults() -> void:
	for node in _pages[_page].find_children("*", "", true, false):
		if node.has_method("restore_default"):
			node.restore_default()

# ---------- previews ----------

func _shake(strength: float) -> void:
	_shake_px = SHAKE_PX * strength
	_shake_left = SHAKE_SECONDS

func _flash_edge() -> void:
	_flash.modulate.a = 1.0
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.35)

func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	var reach := _shake_px * maxf(_shake_left, 0.0) / SHAKE_SECONDS
	_scroll.position = Vector2(randf_range(-reach, reach), randf_range(-reach, reach)).round() if _shake_left > 0.0 else Vector2.ZERO
