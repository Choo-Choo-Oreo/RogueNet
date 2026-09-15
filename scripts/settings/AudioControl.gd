extends Control

@export var audio_bus_name: String

@onready var slider: HSlider = $AudioSliderControl
@onready var spinbox: SpinBox = $AudioTypeControl

var audio_bus_id: int

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

	slider.value = db_to_linear(AudioServer.get_bus_volume_db(audio_bus_id))
	spinbox.value = slider.value

	slider.value_changed.connect(_on_value_changed)
	spinbox.value_changed.connect(_on_value_changed)
	spinbox.focus_exited.connect(_on_user_finished_input)

func _on_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)

	slider.value = value
	spinbox.value = value

func _on_user_finished_input() -> void:
	ConfigFileHandler.save_audio_setting(audio_bus_name + "_volume", slider.value)
