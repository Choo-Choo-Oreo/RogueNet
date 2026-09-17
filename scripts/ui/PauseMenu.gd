extends Control

@onready var panel_settings: Panel = $PanelSettings

func _ready() -> void:
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_close()
		else:
			show()

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

func _on_main_menu_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _close_settings_panel() -> void:
	for child in panel_settings.get_children():
		child.queue_free()
	panel_settings.hide()
