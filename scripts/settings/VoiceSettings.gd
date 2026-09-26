extends VBoxContainer

## Settings > Audio, the Voice part (under the volumes, all in one scrolling tab). Which mic
## the game records (MicInput) and which speaker plays, its gain, switches for each clean-up step (auto gain, rumble filter), push to talk or voice activation,
## the gate (auto or by hand, marked on the meter), stereo voices, a live meter, and the
## calibration: the player talks normally once, and that mic level becomes talking in the
## dungeon (VoiceChat.voice_db), louder and quieter one dB for one dB, whatever the mic. The
## Voice Chat volume slider is in the scene; the rest is built here. Every change is saved at
## once (VoiceChat.set_*). The meter keeps the mic on while the Audio tab is open (monitoring),
## sending nothing.

const METER_FLOOR_DB := -60.0
const CALIBRATE_SECONDS := 3.0
## A calibration take counts only the chunks this far over the background: the talking in it.
const OVER_BACKGROUND_DB := 6.0

## VoiceChat's script, for its static functions (the VoiceChat autoload is an instance).
const VoiceChatScript := preload("res://singletons/VoiceChat.gd")
## No chunk from the mic for this long: it isn't working.
const NO_SOUND_MSEC := 1000

var _devices: OptionButton
var _gain: HSlider
var _meter: ProgressBar
var _meter_label: Label
var _gate_mark: ColorRect
var _gate_slider: HSlider
var _gate_label: Label
var _calibration_label: Label
var _status: Label
## Whether a take is being recorded, its levels (VoiceChat.envelope_db per chunk), when it ends.
var _take := false
var _take_levels: Array[float] = []
var _take_until_msec := 0
## The background when the take began: during it, quiet talking under the gate would pull the
## live background up to itself and filter itself out.
var _take_floor_db := METER_FLOOR_DB
## When the mic last handed over a chunk (the tab opening counts, so it gets a moment to start).
var _last_chunk_msec := Time.get_ticks_msec()

func _ready() -> void:
	_devices = OptionButton.new()
	var current := AudioServer.input_device
	for device in MicInput.devices():
		_devices.add_item(device)
		if device == current:
			_devices.select(_devices.item_count - 1)
	_devices.item_selected.connect(func(i: int): VoiceChat.set_device(_devices.get_item_text(i)))
	_row("Microphone", _devices)
	var speakers := OptionButton.new()
	for device in VoiceChatScript.output_devices():
		speakers.add_item(device)
		if device == AudioServer.output_device:
			speakers.select(speakers.item_count - 1)
	speakers.item_selected.connect(func(i: int): VoiceChat.set_output_device(speakers.get_item_text(i)))
	_row("Speaker (all sound)", speakers)

	var activation := OptionButton.new()
	activation.add_item("Push to talk")
	activation.add_item("Voice (V mutes)")
	activation.select(1 if VoiceChat.voice_activation else 0)
	activation.item_selected.connect(func(i: int): VoiceChat.set_voice_activation(i == 1))
	_row("Activation", activation)

	_gain = HSlider.new()
	_gain.min_value = -20.0
	_gain.max_value = 20.0
	_gain.step = 1.0
	_gain.value = VoiceChat.mic.gain_db
	_gain.custom_minimum_size = Vector2(200, 0)
	_gain.scrollable = false  # the wheel scrolls the tab, not the setting
	_gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gain.value_changed.connect(_on_gain_changed)
	_row("Mic gain", _with_number(_gain))

	var hear := _switch("Hear yourself", VoiceChat.loopback, func(on: bool): VoiceChat.loopback = on)
	# Or only while held down; the switch shows it, and goes back to how it was on letting go.
	var hold := Button.new()
	hold.text = "Hold to hear yourself"
	var was_on := [false]
	hold.button_down.connect(func(): was_on[0] = hear.button_pressed; hear.button_pressed = true)
	hold.button_up.connect(func(): hear.button_pressed = was_on[0])
	add_child(hold)
	_switch("Auto gain (your talking played as loud as everyone's)", VoiceChat.auto_gain, VoiceChat.set_auto_gain)
	_switch("Rumble filter (cuts hum and knocks under %.0f Hz)" % MicInput.HIGH_PASS_HZ, VoiceChat.mic.rumble_filter, VoiceChat.set_rumble_filter)
	_switch("Stereo voices (left/right from where they stand)", VoiceChat.stereo, VoiceChat.set_stereo)

	_meter = ProgressBar.new()
	_meter.min_value = METER_FLOOR_DB
	_meter.max_value = 0.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(200, 16)
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row("Mic level", _meter)
	_gate_mark = ColorRect.new()
	_gate_mark.color = Color.RED
	_gate_mark.size = Vector2(2, 16)
	_meter.add_child(_gate_mark)
	_meter_label = Label.new()
	# Wraps rather than widening the tab when the message is long.
	_meter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_meter_label)

	var gate := HBoxContainer.new()
	var auto := CheckButton.new()
	auto.text = "Auto"
	auto.button_pressed = VoiceChat.auto_gate
	auto.toggled.connect(func(on: bool): VoiceChat.set_gate(on, _gate_slider.value))
	gate.add_child(auto)
	_gate_slider = HSlider.new()
	_gate_slider.min_value = METER_FLOOR_DB
	_gate_slider.max_value = 0.0
	_gate_slider.step = 1.0
	_gate_slider.scrollable = false
	_gate_slider.value = VoiceChat.manual_gate_db
	_gate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gate_slider.value_changed.connect(func(db: float): VoiceChat.set_gate(false, db); auto.button_pressed = false)
	gate.add_child(_with_number(_gate_slider))
	gate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gate_label = _row("Talking from", gate)

	var explain := Label.new()
	explain.text = "Calibrate: record yourself talking normally. That becomes talking (%.0f dB) in the dungeon, whatever your mic; a whisper is about %.0f dB, a yell about %.0f." % [VoiceChat.TALK_DB, VoiceChat.WHISPER_DB, VoiceChat.YELL_DB]
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explain)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	for b in [["Record talking", _start_take], ["Reset", _reset_calibration]]:
		var button := Button.new()
		button.text = b[0]
		button.pressed.connect(b[1])
		buttons.add_child(button)
	_calibration_label = Label.new()
	add_child(_calibration_label)
	_status = Label.new()
	add_child(_status)

	VoiceChat.mic.chunk.connect(_on_chunk)
	visibility_changed.connect(_update_monitoring)
	tree_exiting.connect(func(): VoiceChat.set_monitoring(false))
	_update_monitoring()

## A switch that calls `changed` with its new state.
func _switch(text: String, on: bool, changed: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.button_pressed = on
	button.toggled.connect(changed)
	add_child(button)
	return button

## `slider` with a box beside it to type the number in (the two share one value, so either one
## changing fires the slider's value_changed).
func _with_number(slider: HSlider) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(slider)
	var number := SpinBox.new()
	number.suffix = "dB"
	# slider.share(number) gives the number the slider's range and value (the other way round
	# would reset the slider to an empty box's 0, and save it).
	slider.share(number)
	box.add_child(number)
	return box

## A label and a control side by side; returns the label at the end of the row (for a value).
func _row(title: String, control: Control) -> Label:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	row.add_child(control)
	var value := Label.new()
	value.custom_minimum_size = Vector2(60, 0)
	row.add_child(value)
	add_child(row)
	return value

## The mic runs for the meter only while this tab is showing.
func _update_monitoring() -> void:
	VoiceChat.set_monitoring(is_visible_in_tree())
	_last_chunk_msec = Time.get_ticks_msec()

func _on_gain_changed(db: float) -> void:
	VoiceChat.set_gain(db)
	# set_gain moved the manual gate with the gain; show it (without saving it again).
	_gate_slider.set_value_no_signal(VoiceChat.manual_gate_db)

func _process(_delta: float) -> void:
	var level := VoiceChat.envelope_db
	_meter.value = maxf(level, METER_FLOOR_DB)
	var gate := VoiceChat.gate_db()
	_gate_mark.position.x = _meter.size.x * inverse_lerp(METER_FLOOR_DB, 0.0, clampf(gate, METER_FLOOR_DB, 0.0))
	# The number box shows a manual gate; the label only the automatic one.
	_gate_label.text = "auto: %.0f dB" % gate if VoiceChat.auto_gate else ""
	var talking := "in the dungeon %.0f dB" % VoiceChat.my_voice_db(level) if VoiceChat.gate_open else "silent"
	_meter_label.text = "%s   (mic %.0f dB, background %.0f dB, under %.0f dB is not talking)" % [talking, level, VoiceChat.background_db, VoiceChat.gate_db()]
	# A mic that isn't working: nothing comes in at all. (Exact zeros are not flagged: a noise-cancelling
	# mic sends them whenever you're quiet.)
	var listening := "Listening to: %s. " % AudioServer.input_device
	if Time.get_ticks_msec() - _last_chunk_msec > NO_SOUND_MSEC:
		_meter_label.text = listening + "Nothing is coming in from this mic. Pick it again, or another one."
	_calibration_label.text = "Talking at %.0f dB (mic level)%s" % [VoiceChat.talk_mic_db, "" if VoiceChat.is_calibrated() else ", the default"]
	if _take:
		var left := (_take_until_msec - Time.get_ticks_msec()) / 1000.0
		_status.text = "TALK now... %d" % ceili(left)
		if left <= 0.0:
			_finish_take()

func _start_take() -> void:
	_take = true
	_take_floor_db = VoiceChat.background_db + OVER_BACKGROUND_DB if VoiceChat.background_db > -INF else METER_FLOOR_DB
	_take_levels.clear()
	_take_until_msec = Time.get_ticks_msec() + int(CALIBRATE_SECONDS * 1000.0)

func _on_chunk(_pcm: PackedByteArray) -> void:
	_last_chunk_msec = Time.get_ticks_msec()
	if _take:
		_take_levels.append(VoiceChat.envelope_db)

func _finish_take() -> void:
	_take = false
	var talking := _take_levels.filter(func(chunk_db: float) -> bool: return chunk_db >= _take_floor_db)
	if talking.is_empty():
		_status.text = "Didn't hear you. Check the microphone above and try again."
		return
	# The typical chunk, not the average: an average of power is dragged up by a few loud chunks,
	# which once saved a yell of -4.5 when the yell was really about -22.
	var heard := VoiceChatScript.median_db(talking)
	var level := VoiceChatScript.allowed_talk_mic(heard, VoiceChat.mic.gain_db)
	VoiceChat.set_calibration(level)
	_status.text = "Saved your talking: %.0f dB." % level
	if level != heard:
		_status.text += " (you were %.0f; that is as far as it goes, the mic gain can make up the rest)" % heard

func _reset_calibration() -> void:
	VoiceChat.set_calibration(VoiceChat.DEFAULT_TALK_MIC_DB, false)
	_status.text = "Back to the defaults."
