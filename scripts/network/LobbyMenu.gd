extends Control

func _ready():
	multiplayer.peer_connected.connect(func(id): print ("Peer connected: ", id))
	multiplayer.connection_failed.connect(func(): print ("Connection failed"))

func _on_copy_id_button_pressed():
	pass

func _on_host_button_pressed():
	var peer = SteamMultiplayerPeer.new()
	var error = peer.create_host(0)

	if error != OK:
		print("Failed to host: ", error)
		return

	multiplayer.multiplayer_peer = peer
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID()
	print("Hosting. My Steam ID: ", Steam.getSteamID())
	get_tree().change_scene_to_file("res://scenes/dev/HubMPTest.tscn")

func _on_join_button_pressed():
	var peer = SteamMultiplayerPeer.new()
	var host_steam_id = $HSplitContainer/ConnectPanel/LineEdit.text.to_int()
	var error = peer.create_client(host_steam_id, 0)

	if error != OK:
		print("Failed to join: ", error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	print("Joining host: ", host_steam_id)

func _on_connected_to_server():
	get_tree().change_scene_to_file("res://scenes/dev/HubMPTest.tscn")

func _on_back_pressed() -> void:
	get_parent().hide()
	queue_free()

@rpc("any_peer", "call_local")
func _receive_chat_message(text: String):
	$HSplitContainer/ChatPanel/ChatLog.add_text(text + "\n")

func _on_send_button_pressed():
	var message = $HSplitContainer/ChatPanel/ChatInputRow/ChatInput.text
	_receive_chat_message.rpc(message)
	$HSplitContainer/ChatPanel/ChatInputRow/ChatInput.clear()
