extends Node2D

func _ready() -> void:
	if not multiplayer.is_server():
		return
	multiplayer.peer_disconnected.connect(_despawn_player)
	# Only the players in the mission that was started dive; everyone else stays in the town.
	# Running the dungeon scene directly (no mission) spawns everyone, including late joiners.
	if NetworkSync.dive_members.is_empty():
		multiplayer.peer_connected.connect(_spawn_player)
		_spawn_player(multiplayer.get_unique_id())
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
		return
	for peer_id in NetworkSync.dive_members:
		if peer_id == multiplayer.get_unique_id() or peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)

func _despawn_player(id: int) -> void:
	var player := get_node_or_null(str(id))
	if player:
		player.queue_free()

func _spawn_player(id: int) -> void:
	var player := preload("res://scenes/player/PlayerController.tscn").instantiate()
	player.name = str(id)
	add_child(player)
	player.set_multiplayer_authority(id)
