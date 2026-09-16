extends CanvasLayer

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player == null:
		return

	var health: Health = player.get_node("Health")
	health.died.connect(_on_player_died)

func _on_player_died() -> void:
	show()
