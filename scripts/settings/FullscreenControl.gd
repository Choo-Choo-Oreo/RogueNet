extends CheckButton

func _ready() -> void:
	set_pressed_no_signal(ConfigFileHandler.video("Fullscreen"))
	toggled.connect(_on_toggled)

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	ConfigFileHandler.save_video_setting("Fullscreen", toggled_on)

func restore_default() -> void:
	button_pressed = ConfigFileHandler.VIDEO_DEFAULTS["Fullscreen"]
