extends Control

@onready var panel_main: Panel = $PanelMain
@onready var panel_guild: Panel = $PanelGuild
@onready var panel_character: Panel = $PanelCharacter
@onready var current_character_label: Label = $PanelCharacter/VBoxContainer/CurrentLabel
@onready var player_list: VBoxContainer = $HSplitContainer/PlayerListPanel/PlayersBox/PlayerList
@onready var sidebar: Panel = $Sidebar
@onready var player_list_panel: VSplitContainer = $HSplitContainer/PlayerListPanel
@onready var chat_log: RichTextLabel = $HSplitContainer/PlayerListPanel/ChatPanel/ChatLog
@onready var chat_input: LineEdit = $HSplitContainer/PlayerListPanel/ChatPanel/ChatInputRow/ChatInput
@onready var send_button: Button = $HSplitContainer/PlayerListPanel/ChatPanel/ChatInputRow/SendButton

func _ready() -> void:
	MusicManager.stop()
	refresh_player_list()
	refresh_character_label()
	_apply_session_mode()
	chat_log.scroll_following = true
	send_button.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text): _send_chat())

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

func _apply_session_mode() -> void:
	match NetworkSync.session_mode:
		NetworkSync.SessionMode.SINGLEPLAYER:
			sidebar.hide()
			player_list_panel.hide()
		NetworkSync.SessionMode.HOST, NetworkSync.SessionMode.CLIENT:
			sidebar.show()
			player_list_panel.show()

func refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for peer_id in NetworkSync.peer_names:
		var label := Label.new()
		label.text = NetworkSync.peer_names[peer_id]
		player_list.add_child(label)

func _on_guild_button_pressed() -> void:
	if not NetworkSync.is_dedicated:
		if multiplayer.is_server():
			NetworkSync._join_shared_party(1)
		else:
			NetworkSync.report_join_shared_party.rpc_id(1)
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

func refresh_character_label() -> void:
	var character_id: String = NetworkSync.peer_characters.get(multiplayer.get_unique_id(), "knight")
	current_character_label.text = "Current: " + character_id.capitalize()

func _on_swap_characters_button_pressed() -> void:
	panel_main.hide()
	panel_character.show()

func _on_character_back_button_pressed() -> void:
	panel_character.hide()
	panel_main.show()

func _choose_character(character_id: String) -> void:
	if multiplayer.is_server():
		NetworkSync._set_character(1, character_id)
	else:
		NetworkSync.report_player_character.rpc_id(1, character_id)
	refresh_character_label()

func _on_knight_button_pressed() -> void:
	_choose_character("knight")

func _on_dwarf_button_pressed() -> void:
	_choose_character("dwarf")

func _on_human_button_pressed() -> void:
	_choose_character("human")
