extends Control

## One bus's volume on the settings screen: its HSlider child AudioSliderControl (linear,
## 0..1) drives the bus and saves when a drag ends (a keyboard step saves right away).

@export var audio_bus_name: String

@onready var slider: HSlider = $AudioSliderControl

var audio_bus_id: int
var _dragging := false

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

	slider.value = db_to_linear(AudioServer.get_bus_volume_db(audio_bus_id))

	slider.value_changed.connect(_on_value_changed)
	slider.drag_started.connect(func(): _dragging = true)
	slider.drag_ended.connect(func(_changed):
		_dragging = false
		_on_user_finished_input())

func _on_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(value))
	# A keyboard step or Restore defaults saves right away; a slider drag
	# waits for the release so it does not rewrite the file every frame.
	if not _dragging:
		_on_user_finished_input()

func _on_user_finished_input() -> void:
	ConfigFileHandler.save_audio_setting(audio_bus_name + "_volume", slider.value)

## Back to the first-run volume (ConfigFileHandler.AUDIO_DEFAULTS).
func restore_default() -> void:
	slider.value = ConfigFileHandler.AUDIO_DEFAULTS[audio_bus_name]
