extends Control

@onready var panel_settings: Panel = $PanelSettings

func _on_play_pressed() -> void:
	_close_settings_panel()
	panel_settings.visible = true
	var settings_scene = preload("res://scenes/ui/MultiplayerMenu.tscn").instantiate()
	panel_settings.add_child(settings_scene)

func _on_dungeon_maker_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonMaker.tscn")

func _on_options_pressed() -> void:
	_close_settings_panel()
	panel_settings.visible = true
	var settings_scene = preload("res://scenes/ui/SettingsMenu.tscn").instantiate()
	panel_settings.add_child(settings_scene)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _close_settings_panel() -> void:
	for child in panel_settings.get_children():
		child.queue_free()
	panel_settings.hide()
