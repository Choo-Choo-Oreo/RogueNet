extends Control

@onready var panel_settings: Panel = $PanelSettings
@onready var buttons: VBoxContainer = $CenterContainer/Menu/Buttons
## The sword or staff that points at the hovered scroll and destroys it when clicked.
@onready var weapon: MenuWeapon = $Weapon

## True while a button's cut/burn plays, so a second click can't start another.
var _striking := false

func _ready() -> void:
	MusicManager.play_menu()
	var i := 0
	for button in buttons.get_children():
		if button is MenuScrollButton:
			button.unroll(0.15 + i * 0.08)
			button.mouse_entered.connect(weapon.aim_at.bind(button))
			button.focus_entered.connect(weapon.aim_at.bind(button))
			button.mouse_exited.connect(weapon.lose_aim.bind(button))
			i += 1

## Plays the weapon's attack on `button`; false if another attack is already playing.
func _strike(button: MenuScrollButton) -> bool:
	if _striking:
		return false
	_striking = true
	await weapon.strike(button)
	_striking = false
	return true

func _on_play_pressed() -> void:
	if not await _strike(buttons.get_node("Multiplayer")):
		return
	_close_settings_panel()
	panel_settings.visible = true
	var settings_scene = preload("res://scenes/ui/MultiplayerMenu.tscn").instantiate()
	panel_settings.add_child(settings_scene)
	buttons.get_node("Multiplayer").restore()

func _on_singleplayer_pressed() -> void:
	if not await _strike(buttons.get_node("Singleplayer")):
		return
	# No listen socket: nobody can join a singleplayer game, and it works without Steam.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkSync.session_mode = NetworkSync.SessionMode.SINGLEPLAYER
	NetworkSync.reset_session()
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID() if SteamManager.online else 0
	NetworkSync.peer_names[1] = Steam.getPersonaName() if SteamManager.online else "Player"
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _on_dungeon_maker_pressed() -> void:
	if not await _strike(buttons.get_node("DungeonMaker")):
		return
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonMaker.tscn")

func _on_options_pressed() -> void:
	if not await _strike(buttons.get_node("Options")):
		return
	_close_settings_panel()
	panel_settings.visible = true
	var settings_scene = preload("res://scenes/ui/SettingsMenu.tscn").instantiate()
	panel_settings.add_child(settings_scene)
	buttons.get_node("Options").restore()

func _on_exit_pressed() -> void:
	if not await _strike(buttons.get_node("Exit")):
		return
	get_tree().quit()

func _close_settings_panel() -> void:
	for child in panel_settings.get_children():
		child.queue_free()
	panel_settings.hide()
