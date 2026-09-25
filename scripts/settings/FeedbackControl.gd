extends Control

## One "how hard getting hit feels" setting (ConfigFileHandler.FEEDBACK_DEFAULTS) on the
## settings screen: a CheckButton for an on/off key, or an HSlider (0..1) for screen_shake.
## Reads the saved value on open and saves every change.

@export var key: String

func _ready() -> void:
	var value = ConfigFileHandler.feedback(key)
	var node: Node = self
	if node is CheckButton:
		node.set_pressed_no_signal(bool(value))
		node.toggled.connect(func(on: bool): ConfigFileHandler.save_feedback_setting(key, on))
	elif node is Range:
		node.set_value_no_signal(float(value))
		node.value_changed.connect(func(v: float): ConfigFileHandler.save_feedback_setting(key, v))
