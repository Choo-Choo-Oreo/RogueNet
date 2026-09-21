extends Control

@onready var panel_settings: Panel = $PanelSettings
@onready var panel: Panel = $Panel
@onready var buttons: VBoxContainer = $Panel/VBoxContainer
@onready var end_mission_button: Button = $Panel/VBoxContainer/EndMissionButton

const TOWN_SCENE := "res://scenes/ui/town/MainTown.tscn"
const PANEL_PADDING := Vector2(60, 60)

func _ready() -> void:
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_close()
		else:
			_open()

# Only the host, and only during a mission, can end it for everyone.
func _open() -> void:
	end_mission_button.visible = multiplayer.is_server() and get_tree().current_scene.scene_file_path.ends_with("Dungeon.tscn")
	show()
	_fit_panel.call_deferred()

# The panel is anchored to the centre, so growing it by half the size each way keeps it centred
# however many buttons are showing.
func _fit_panel() -> void:
	var size := buttons.get_combined_minimum_size() + PANEL_PADDING
	panel.offset_left = -size.x / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_bottom = size.y / 2.0

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
	_return_to_town.rpc()

@rpc("authority", "call_local", "reliable")
func _return_to_town() -> void:
	if multiplayer.is_server():
		NetworkSync.missions.clear()
	get_tree().change_scene_to_file(TOWN_SCENE)

func _on_main_menu_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	NetworkSync.reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _close_settings_panel() -> void:
	for child in panel_settings.get_children():
		child.queue_free()
	panel_settings.hide()
