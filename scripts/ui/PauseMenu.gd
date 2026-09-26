extends Control

@onready var panel_settings: MenuPanel = $PanelSettings
@onready var end_mission_button: Button = $Center/Panel/Margin/VBoxContainer/EndMissionButton
## Top right in a mission: the other players' Mute and voice volume (the town lists them itself).
@onready var voices: PanelContainer = $Voices
@onready var voice_list: PlayerVoiceList = $Voices/VBoxContainer/List

func _ready() -> void:
	add_to_group("pause_menu")   # the HUD's Menu button and System tab open it
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		if visible:
			_close()
		else:
			_open()

func open() -> void:
	if not visible:
		_open()

# Only the host, and only during a mission, can end it for everyone.
func _open() -> void:
	var in_mission := GameView.world_scene(get_tree()).scene_file_path.ends_with("Dungeon.tscn")
	end_mission_button.visible = multiplayer.is_server() and in_mission
	voices.visible = in_mission and voice_list.has_others()
	if voices.visible:
		voice_list.refresh()
	# The panel fits its buttons and the CenterContainer keeps it centred on whole UI pixels,
	# however many are showing.
	show()

func _close() -> void:
	panel_settings.close()
	hide()

func _on_resume_button_pressed() -> void:
	_close()

func _on_settings_button_pressed() -> void:
	panel_settings.open(preload("res://scenes/ui/SettingsMenu.tscn"))

func _on_end_mission_button_pressed() -> void:
	if not multiplayer.is_server():
		return
	_close()
	NetworkSync.end_mission()

func _on_main_menu_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	NetworkSync.reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
