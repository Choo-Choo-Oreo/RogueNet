extends Control

func _ready():
	multiplayer.peer_connected.connect(func(id): print ("Peer connected: ", id))
	multiplayer.connection_failed.connect(func(): print ("Connection failed"))

func _on_host_button_pressed():
	var peer = SteamMultiplayerPeer.new()
	var error = peer.create_host(0)

	if error != OK:
		print("Failed to host: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Hosting. My Steam ID: ", Steam.getSteamID())

func _on_join_button_pressed():
	var peer = SteamMultiplayerPeer.new()
	var host_steam_id = $HSplitContainer/LineEdit.text.to_int()
	var error = peer.create_client(host_steam_id, 0)

	if error != OK:
		print("Failed to join: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Joining host: ", host_steam_id)
