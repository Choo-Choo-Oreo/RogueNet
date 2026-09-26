extends Control

@onready var panel_main: Panel = $PanelMain
@onready var panel_guild: Panel = $PanelGuild
@onready var panel_character: Panel = $PanelCharacter
@onready var panel_storage: Panel = $PanelStorage
@onready var player_list: PlayerVoiceList = $HSplitContainer/PlayerListPanel/PlayersBox/PlayerList
@onready var sidebar: Panel = $Sidebar
@onready var player_list_panel: VSplitContainer = $HSplitContainer/PlayerListPanel
@onready var chat_log: RichTextLabel = $HSplitContainer/PlayerListPanel/ChatPanel/ChatLog
@onready var chat_input: LineEdit = $HSplitContainer/PlayerListPanel/ChatPanel/ChatInputRow/ChatInput
@onready var send_button: Button = $HSplitContainer/PlayerListPanel/ChatPanel/ChatInputRow/SendButton

func _ready() -> void:
	MusicManager.stop()
	# The adventurer's saved look; with no adventurer picked (a test going straight here) keep the default.
	if not PlayerInventory.adventurer.is_empty():
		_share_skin(PlayerInventory.adventurer["skin"])
	# Singleplayer has nobody to list or talk to.
	sidebar.visible = NetworkSync.is_online()
	player_list_panel.visible = NetworkSync.is_online()
	# Tell everyone what this player wears: after joining a server, or coming back from a dive.
	NetworkSync.share_equipment(PlayerInventory.worn())
	chat_log.scroll_following = true
	send_button.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text): _send_chat())
	PlayerInventory.save_adventurer()

# Leaving the town any way (Leave, a dive starting, the host going) saves the adventurer.
func _exit_tree() -> void:
	PlayerInventory.save_adventurer()

# Enter in the input box or the Send button both come here.
func _send_chat() -> void:
	var text := chat_input.text.strip_edges()
	chat_input.clear()
	if not text.is_empty():
		NetworkSync.send_chat(text)
	chat_input.grab_focus()

func add_chat_line(line: String) -> void:
	# [lb] stops a player's text from being read as formatting tags.
	chat_log.append_text(line.replace("[", "[lb]") + "\n")

## NetworkSync calls this when someone joins or leaves (the list itself is PlayerVoiceList).
func refresh_player_list() -> void:
	player_list.refresh()

func _on_guild_button_pressed() -> void:
	if not NetworkSync.is_dedicated:
		NetworkSync.ask_host(NetworkSync.report_join_shared_party)
		return
	panel_main.hide()
	panel_guild.show()

func _on_back_button_pressed() -> void:
	panel_guild.hide()
	panel_main.show()

func _on_leave_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	NetworkSync.reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

## The same Characters screen as the main menu's. Picking an adventurer saves the one being left
## (PlayerInventory.use_adventurer), then shows the new one's look and gear to everyone.
func _on_swap_characters_button_pressed() -> void:
	panel_main.hide()
	panel_character.show()
	var select = preload("res://scenes/ui/CharacterSelect.tscn").instantiate()
	select.in_town = true
	panel_character.add_child(select)
	select.picked.connect(func(adventurer: Dictionary):
		_share_skin(adventurer["skin"])
		NetworkSync.share_equipment(PlayerInventory.worn()))
	select.tree_exited.connect(panel_main.show)

func _on_storage_button_pressed() -> void:
	panel_main.hide()
	panel_storage.show()

func _on_storage_back_pressed() -> void:
	panel_storage.hide()
	panel_main.show()

## Tells everyone the adventurer's skin, the look the others see in the dungeon.
func _share_skin(skin_id: String) -> void:
	NetworkSync.ask_host(NetworkSync.report_skin, [skin_id])
