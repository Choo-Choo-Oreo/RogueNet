extends Control

@onready var panel_settings: Panel = $PanelSettings

func _ready() -> void:
	MusicManager.play_menu()

func _on_play_pressed() -> void:
	_pick_character(_open_multiplayer)

func _on_singleplayer_pressed() -> void:
	_pick_character(_start_singleplayer)

func _open_multiplayer() -> void:
	_close_settings_panel()
	panel_settings.visible = true
	var settings_scene = preload("res://scenes/ui/MultiplayerMenu.tscn").instantiate()
	panel_settings.add_child(settings_scene)

func _start_singleplayer() -> void:
	# No listen socket: nobody can join a singleplayer game, and it works without Steam.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkSync.reset_session()
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID() if SteamManager.online else 0
	NetworkSync.peer_names[1] = NetworkSync.account_name()
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

## Singleplayer and Multiplayer both go through the Characters screen (the last hero picked
## is already selected): `then` runs once one is picked; Back cancels.
func _pick_character(then: Callable) -> void:
	_close_settings_panel()
	panel_settings.visible = true
	var select = preload("res://scenes/ui/protagonist/CharacterSelect.tscn").instantiate()
	panel_settings.add_child(select)
	select.picked.connect(func(_hero): then.call_deferred())

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
