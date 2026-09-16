extends Node

@rpc("any_peer", "unreliable_ordered")
func report_position(pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	_relay_position(multiplayer.get_remote_sender_id(), pos)

func _relay_position(sender_id: int, pos: Vector2) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id:
			receive_position.rpc_id(peer_id, sender_id, pos)

@rpc("authority", "unreliable_ordered")
func receive_position(player_id: int, pos: Vector2) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player/" + str(player_id))
	if player:
		player.global_position = pos
