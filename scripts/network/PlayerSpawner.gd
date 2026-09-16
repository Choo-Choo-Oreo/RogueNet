extends Node2D

func _ready() -> void:
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(_spawn_player)
	_spawn_player(multiplayer.get_unique_id())

func _spawn_player(id: int) -> void:
	var player := preload("res://scenes/player/PlayerController.tscn").instantiate()
	player.name = str(id)
	add_child(player)
	player.set_multiplayer_authority(id)
