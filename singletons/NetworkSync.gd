extends Node

var peer_steam_ids: Dictionary = {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(func():
		report_steam_id.rpc_id(1, Steam.getSteamID())
	)

@rpc("any_peer", "reliable")
func report_steam_id(steam_id: int) -> void:
	if not multiplayer.is_server():
		return
	peer_steam_ids[multiplayer.get_remote_sender_id()] = steam_id
	for peer_id in multiplayer.get_peers():
		receive_steam_ids.rpc_id(peer_id, peer_steam_ids)

@rpc("authority", "reliable")
func receive_steam_ids(ids: Dictionary) -> void:
	peer_steam_ids = ids

@rpc("any_peer", "unreliable_ordered")
func report_position(pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	receive_position(sender_id, pos)
	_relay_position(sender_id, pos)

func _relay_position(sender_id: int, pos: Vector2) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id:
			receive_position.rpc_id(peer_id, sender_id, pos)

@rpc("authority", "unreliable_ordered")
func receive_position(player_id: int, pos: Vector2) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player/" + str(player_id))
	if player:
		player.global_position = pos
