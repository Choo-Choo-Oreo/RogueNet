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
	NetworkSync.session_mode = NetworkSync.SessionMode.HOST
	NetworkSync.reset_session()
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID()
	NetworkSync.peer_names[1] = Steam.getPersonaName()
	print("Hosting. My Steam ID: ", Steam.getSteamID())
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _on_join_button_pressed():
	var host_id_text = $HSplitContainer/ConnectPanel/LineEdit.text.strip_edges()
	if host_id_text.is_empty() or not host_id_text.is_valid_int():
		print("Enter a valid host Steam ID before joining.")
		return
	var peer = SteamMultiplayerPeer.new()
	var host_steam_id = host_id_text.to_int()
	var error = peer.create_client(host_steam_id, 0)

	if error != OK:
		print("Failed to join: ", error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	print("Joining host: ", host_steam_id)

func _on_connected_to_server():
	NetworkSync.session_mode = NetworkSync.SessionMode.CLIENT
	NetworkSync.report_player_name.rpc_id(1, Steam.getPersonaName())
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _on_back_pressed() -> void:
	get_parent().hide()
	queue_free()
