extends CheckButton

func _ready() -> void:
	set_pressed_no_signal(ConfigFileHandler.video("Vsync"))
	toggled.connect(_on_toggled)

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	ConfigFileHandler.save_video_setting("Vsync", toggled_on)

func restore_default() -> void:
	button_pressed = ConfigFileHandler.VIDEO_DEFAULTS["Vsync"]
