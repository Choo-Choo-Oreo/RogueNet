extends Node

var config = ConfigFile.new()
const SETTINGS_FILE_PATH = "user://settings.ini"

## First-run volumes (linear, 0..1). Music is loud next to everything else.
const DEFAULT_MUSIC_VOLUME := 0.5

func _ready() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		config.set_value("audio", "Master_volume", 1.0)
		config.set_value("audio", "Music_volume", DEFAULT_MUSIC_VOLUME)
		config.set_value("audio", "SFX_volume", 1.0)
		config.set_value("audio", "UI_volume", 1.0)

		config.set_value("video", "Fullscreen", true)
		config.set_value("video", "Vsync", true)

		config.save(SETTINGS_FILE_PATH)
	else:
		config.load(SETTINGS_FILE_PATH)

	# Apply the saved volumes to the buses now: the sliders only ever read the
	# bus, so without this a saved volume was never loaded on the next launch.
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus == -1:
			continue
		var fallback: float = DEFAULT_MUSIC_VOLUME if bus_name == "Music" else 1.0
		var volume: float = config.get_value("audio", bus_name + "_volume", fallback)
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))

	var vsync_on: bool = config.get_value("video", "Vsync", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)

	var fullscreen_on: bool = config.get_value("video", "Fullscreen", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_on else DisplayServer.WINDOW_MODE_WINDOWED)

func save_audio_setting(key: String, value) -> void:
	config.set_value("audio", key, value)
	config.save(SETTINGS_FILE_PATH)

func save_video_setting(key: String, value) -> void:
	config.set_value("video", key, value)
	config.save(SETTINGS_FILE_PATH)

func load_video_settings() -> Dictionary:
	var video_settings := {}
	for key in config.get_section_keys("video"):
		video_settings[key] = config.get_value("video", key)
	return video_settings
