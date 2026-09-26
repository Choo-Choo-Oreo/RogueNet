extends Control

@export var audio_bus_name: String

@onready var slider: HSlider = $AudioSliderControl
@onready var spinbox: SpinBox = $AudioTypeControl

var audio_bus_id: int
var _dragging := false

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

	# The box can go past the slider's end (typed); the slider just sits at its end then.
	spinbox.value = db_to_linear(AudioServer.get_bus_volume_db(audio_bus_id))
	slider.value = spinbox.value

	slider.value_changed.connect(_on_value_changed)
	spinbox.value_changed.connect(_on_value_changed)
	spinbox.focus_exited.connect(_on_user_finished_input)
	slider.drag_started.connect(func(): _dragging = true)
	slider.drag_ended.connect(func(_changed):
		_dragging = false
		_on_user_finished_input())

func _on_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)

	slider.value = value
	spinbox.value = value
	# A typed value (Enter) or a keyboard step saves right away; a slider drag
	# waits for the release so it does not rewrite the file every frame.
	if not _dragging:
		_on_user_finished_input()

func _on_user_finished_input() -> void:
	ConfigFileHandler.save_audio_setting(audio_bus_name + "_volume", spinbox.value)
