extends Node

var config = ConfigFile.new()
const SETTINGS_FILE_PATH = "user://settings.ini"

func _ready() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		config.set_value("audio", "Master_volume", 1.0)
		config.set_value("audio", "Music_volume", 1.0)
		config.set_value("audio", "SFX_volume", 1.0)
		config.set_value("audio", "UI_volume", 1.0)

		config.set_value("video", "Fullscreen", true)
		config.set_value("video", "Vsync", true)

		config.save(SETTINGS_FILE_PATH)
	else:
		config.load(SETTINGS_FILE_PATH)

func save_audio_setting(key: String, value) -> void:
	config.set_value("audio", key, value)
	config.save(SETTINGS_FILE_PATH)

func load_audio_settings() -> Dictionary:
	var audio_settings := {}
	for key in config.get_section_keys("audio"):
		audio_settings[key] = config.get_value("audio", key)
	return audio_settings

func save_video_setting(key: String, value) -> void:
	config.set_value("video", key, value)
	config.save(SETTINGS_FILE_PATH)

func load_video_settings() -> Dictionary:
	var video_settings := {}
	for key in config.get_section_keys("video"):
		video_settings[key] = config.get_value("video", key)
	return video_settings
