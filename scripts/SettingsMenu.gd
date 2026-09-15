extends Control

class_name SettingsMenu

func _ready():
	#var audio_settings = ConfigFileHandler.load_audio_settings()
	#audio_slider_master.value = min(audio_settings.Master_volume, 1.0)
	#audio_slider_music.value = min(audio_settings.Music_volume, 1.0)
	#audio_slider_sfx.value = min(audio_settings.SFX_volume, 1.0)
	#audio_slider_ui.value = min(audio_settings.UI_volume, 1.0)

	#var video_settings = ConfigFileHandler.load_video_settings()
	#fullscreen_check_button.button_pressed = video_settings.Fullscreen
	#v_sync_check_button.button_pressed = video_settings.Vsync

	set_process(false)

func _on_back_pressed() -> void:
	get_parent().hide()
	queue_free()
