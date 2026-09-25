extends VBoxContainer

## Settings > Voice. Which mic the game records (MicInput), its gain, a live meter, and the
## calibration: the player whispers and yells once, and those two mic levels become the
## quietest and loudest voice in the dungeon (VoiceChat.voice_db), whatever the mic. The
## Voice Chat volume slider is in the scene; the rest is built here. Every change is saved at
## once (VoiceChat.set_*). The meter keeps the mic on while this tab is open (monitoring),
## sending nothing.

const METER_FLOOR_DB := -60.0
const CALIBRATE_SECONDS := 3.0
## A calibration take counts only the chunks this far over the background: the talking in it.
const OVER_BACKGROUND_DB := 6.0
## A yell must be at least this much louder than the whisper, or the take is refused.
const MIN_RANGE_DB := 6.0

var _devices: OptionButton
var _gain: HSlider
var _gain_label: Label
var _meter: ProgressBar
var _meter_label: Label
var _calibration_label: Label
var _status: Label
## The take being recorded ("whisper" / "yell", "" when none), its chunk levels, when it ends.
var _take := ""
var _take_levels: Array[float] = []
var _take_until_msec := 0

func _ready() -> void:
	_devices = OptionButton.new()
	var current := AudioServer.input_device
	for device in MicInput.devices():
		_devices.add_item(device)
		if device == current:
			_devices.select(_devices.item_count - 1)
	_devices.item_selected.connect(func(i: int): VoiceChat.set_device(_devices.get_item_text(i)))
	_row("Microphone", _devices)

	_gain = HSlider.new()
	_gain.min_value = -20.0
	_gain.max_value = 20.0
	_gain.step = 1.0
	_gain.value = VoiceChat.mic.gain_db
	_gain.custom_minimum_size = Vector2(200, 0)
	_gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gain.value_changed.connect(_on_gain_changed)
	_gain_label = _row("Mic gain", _gain)

	var test := CheckButton.new()
	test.text = "Hear yourself"
	test.button_pressed = VoiceChat.loopback
	test.toggled.connect(func(on: bool): VoiceChat.loopback = on)
	add_child(test)

	_meter = ProgressBar.new()
	_meter.min_value = METER_FLOOR_DB
	_meter.max_value = 0.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(200, 16)
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row("Mic level", _meter)
	_meter_label = Label.new()
	add_child(_meter_label)

	var explain := Label.new()
	explain.text = "Calibrate: record your quietest whisper and your loudest yell. They become a whisper (%.0f dB) and a yell (%.0f dB) in the dungeon, whatever your mic." % [VoiceChat.WHISPER_DB, VoiceChat.YELL_DB]
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explain)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	for b in [["Record whisper", _start_take.bind("whisper")], ["Record yell", _start_take.bind("yell")], ["Reset", _reset_calibration]]:
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
	_on_gain_changed(_gain.value, false)

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

func _on_gain_changed(db: float, save := true) -> void:
	_gain_label.text = "%+.0f dB" % db
	if save:
		VoiceChat.set_gain(db)

func _process(_delta: float) -> void:
	var level := VoiceChat.level_db
	_meter.value = maxf(level, METER_FLOOR_DB)
	var talking := "silent" if level < VoiceChat.gate_db() else "in the dungeon %.0f dB" % VoiceChat.my_voice_db(level)
	_meter_label.text = "%s   (mic %.0f dB, background %.0f dB, under %.0f dB is not talking)" % [talking, level, VoiceChat.background_db, VoiceChat.gate_db()]
	_calibration_label.text = "Whisper at %.0f dB, yell at %.0f dB (mic levels)%s" % [VoiceChat.whisper_mic_db, VoiceChat.yell_mic_db, "" if VoiceChat.is_calibrated() else ", the defaults"]
	if _take != "":
		var left := (_take_until_msec - Time.get_ticks_msec()) / 1000.0
		_status.text = "%s now... %d" % [_take.to_upper(), ceili(left)]
		if left <= 0.0:
			_finish_take()

func _start_take(take: String) -> void:
	_take = take
	_take_levels.clear()
	_take_until_msec = Time.get_ticks_msec() + int(CALIBRATE_SECONDS * 1000.0)

func _on_chunk(pcm: PackedByteArray) -> void:
	if _take != "":
		_take_levels.append(VoiceChat.mic_level_db(pcm))

func _finish_take() -> void:
	var take := _take
	_take = ""
	var floor_db := VoiceChat.background_db + OVER_BACKGROUND_DB if VoiceChat.background_db > -INF else METER_FLOOR_DB
	var talking := _take_levels.filter(func(level: float) -> bool: return level >= floor_db)
	if talking.is_empty():
		_status.text = "Didn't hear you. Check the microphone above and try again."
		return
	var level := VoiceChat.average_db(talking)
	var whisper := level if take == "whisper" else VoiceChat.whisper_mic_db
	var yell := level if take == "yell" else VoiceChat.yell_mic_db
	if yell - whisper < MIN_RANGE_DB:
		_status.text = "That %s (%.0f dB) is too close to your %s. Try again, quieter or louder." % [take, level, "yell" if take == "whisper" else "whisper"]
		return
	VoiceChat.set_calibration(whisper, yell)
	_status.text = "Saved your %s: %.0f dB." % [take, level]

func _reset_calibration() -> void:
	VoiceChat.set_calibration(VoiceChat.DEFAULT_WHISPER_MIC_DB, VoiceChat.DEFAULT_YELL_MIC_DB)
	_status.text = "Back to the defaults."
