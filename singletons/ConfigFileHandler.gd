extends Node

var config = ConfigFile.new()
const SETTINGS_FILE_PATH = "user://settings.ini"

## First-run volumes (linear, 0..1), by bus. Music is loud next to everything else.
const AUDIO_DEFAULTS := {"Master": 1.0, "Music": 0.5, "SFX": 1.0, "UI": 1.0}
const VIDEO_DEFAULTS := {"Fullscreen": true, "Vsync": true}

## How hard getting hit feels (HitFeedback, HurtOverlay, MouseFollowCamera). Some players need
## these lower or off. screen_shake is a strength, 0..1; the others are on/off.
const FEEDBACK_DEFAULTS := {"screen_shake": 1.0, "screen_flash": true, "hit_stop": true}

func _ready() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		for bus_name in AUDIO_DEFAULTS:
			config.set_value("audio", bus_name + "_volume", AUDIO_DEFAULTS[bus_name])
		for key in VIDEO_DEFAULTS:
			config.set_value("video", key, VIDEO_DEFAULTS[key])

		for key in FEEDBACK_DEFAULTS:
			config.set_value("feedback", key, FEEDBACK_DEFAULTS[key])

		config.save(SETTINGS_FILE_PATH)
	else:
		config.load(SETTINGS_FILE_PATH)

	# Apply the saved volumes to the buses now: the sliders only ever read the
	# bus, so without this a saved volume was never loaded on the next launch.
	for bus_name in AUDIO_DEFAULTS:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus == -1:
			continue
		var volume: float = config.get_value("audio", bus_name + "_volume", AUDIO_DEFAULTS[bus_name])
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))

	var vsync_on: bool = video("Vsync")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)

	var fullscreen_on: bool = video("Fullscreen")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_on else DisplayServer.WINDOW_MODE_WINDOWED)

func save_audio_setting(key: String, value) -> void:
	config.set_value("audio", key, value)
	config.save(SETTINGS_FILE_PATH)

func save_video_setting(key: String, value) -> void:
	config.set_value("video", key, value)
	config.save(SETTINGS_FILE_PATH)

func save_feedback_setting(key: String, value) -> void:
	config.set_value("feedback", key, value)
	config.save(SETTINGS_FILE_PATH)

## One feedback setting (FEEDBACK_DEFAULTS), its default if never saved.
func feedback(key: String):
	return config.get_value("feedback", key, FEEDBACK_DEFAULTS.get(key))

## One video setting (VIDEO_DEFAULTS), its default if never saved.
func video(key: String) -> bool:
	return config.get_value("video", key, VIDEO_DEFAULTS.get(key))
