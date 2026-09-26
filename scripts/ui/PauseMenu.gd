extends Control

@onready var panel_settings: Panel = $PanelSettings
@onready var panel: Panel = $Panel
@onready var buttons: VBoxContainer = $Panel/VBoxContainer
@onready var end_mission_button: Button = $Panel/VBoxContainer/EndMissionButton
## Top right in a mission: the other players' Mute and voice volume (the town lists them itself).
@onready var voices: PanelContainer = $Voices
@onready var voice_list: PlayerVoiceList = $Voices/VBoxContainer/List

const PANEL_PADDING := Vector2(60, 60)

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
	var in_mission := get_tree().current_scene.scene_file_path.ends_with("Dungeon.tscn")
	end_mission_button.visible = multiplayer.is_server() and in_mission
	voices.visible = in_mission and voice_list.has_others()
	if voices.visible:
		voice_list.refresh()
	show()
	_fit_panel.call_deferred()

# The panel is anchored to the centre, so growing it by half the size each way keeps it centred
# however many buttons are showing.
func _fit_panel() -> void:
	var panel_size := buttons.get_combined_minimum_size() + PANEL_PADDING
	panel.offset_left = -panel_size.x / 2.0
	panel.offset_right = panel_size.x / 2.0
	panel.offset_top = -panel_size.y / 2.0
	panel.offset_bottom = panel_size.y / 2.0

func _close() -> void:
	_close_settings_panel()
	hide()

func _on_resume_button_pressed() -> void:
	_close()

func _on_settings_button_pressed() -> void:
	_close_settings_panel()
	panel_settings.visible = true
	var settings_scene = preload("res://scenes/ui/SettingsMenu.tscn").instantiate()
	panel_settings.add_child(settings_scene)

func _on_end_mission_button_pressed() -> void:
	if not multiplayer.is_server():
		return
	_close()
	NetworkSync.end_mission()

func _on_main_menu_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	NetworkSync.reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _close_settings_panel() -> void:
	for child in panel_settings.get_children():
		child.queue_free()
	panel_settings.hide()
