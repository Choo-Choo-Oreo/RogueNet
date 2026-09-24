extends Node2D

# Every player who dives spawns the whole party on their own machine, from the member list the
# start message carried. There is no MultiplayerSpawner: it announced each spawn to every connected
# peer, including players still in the town, whose game has no dungeon to put them in.

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_despawn_player)
	var party: Array = NetworkSync.dive_members
	if party.is_empty():
		# Running the dungeon scene directly, with no mission: just the local player.
		party = [multiplayer.get_unique_id()]
	for peer_id in party:
		_spawn_player(peer_id)

func _despawn_player(id: int) -> void:
	var player := get_node_or_null(str(id))
	if player:
		player.queue_free()

func _spawn_player(id: int) -> void:
	var player := preload("res://scenes/entities/PlayerController.tscn").instantiate()
	player.name = str(id)
	add_child(player)
	player.set_multiplayer_authority(id)
	player.set_character(NetworkSync.peer_characters.get(id, ""))
	player.set_equipment(NetworkSync.peer_equipment.get(id, {}))
