extends Control

class_name SettingsMenu

@onready var fullscreen_check_button: CheckButton = $MarginContainer/VBoxContainer/FullscreenCheckButton
@onready var v_sync_check_button: CheckButton = $MarginContainer/VBoxContainer/VSyncCheckButton

func _ready():
	# set_pressed_no_signal, not button_pressed = ...: this is reading the
	# already-applied setting back into the UI, not a user action -- setting
	# button_pressed directly fires the same "toggled" signal a real click
	# does, which would immediately re-apply and re-save the value it just
	# read (harmless here since it's the same value, but the wrong pattern
	# to copy for anything that isn't idempotent).
	var video_settings := ConfigFileHandler.load_video_settings()
	fullscreen_check_button.set_pressed_no_signal(video_settings.Fullscreen)
	v_sync_check_button.set_pressed_no_signal(video_settings.Vsync)

	set_process(false)

func _on_back_pressed() -> void:
	get_parent().hide()
	queue_free()
