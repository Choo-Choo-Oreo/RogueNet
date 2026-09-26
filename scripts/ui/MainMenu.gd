extends Control

@onready var panel_settings: MenuPanel = $PanelSettings

func _ready() -> void:
	MusicManager.play_menu()

func _on_play_pressed() -> void:
	_pick_character(_open_multiplayer)

func _on_singleplayer_pressed() -> void:
	_pick_character(_start_singleplayer)

func _open_multiplayer() -> void:
	panel_settings.open(preload("res://scenes/ui/MultiplayerMenu.tscn"))

func _start_singleplayer() -> void:
	# No listen socket: nobody can join a singleplayer game, and it works without Steam.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkSync.reset_session()
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID() if SteamManager.online else 0
	NetworkSync.peer_names[1] = NetworkSync.account_name()
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

## Singleplayer and Multiplayer both go through the Characters screen (the last adventurer picked
## is already selected): `then` runs once one is picked; Back cancels.
func _pick_character(then: Callable) -> void:
	var select = panel_settings.open(preload("res://scenes/ui/CharacterSelect.tscn"))
	select.picked.connect(func(_adventurer): then.call_deferred())

func _on_dungeon_maker_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonMaker.tscn")

func _on_options_pressed() -> void:
	panel_settings.open(preload("res://scenes/ui/SettingsMenu.tscn"))

func _on_exit_pressed() -> void:
	get_tree().quit()
