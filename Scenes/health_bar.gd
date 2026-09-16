extends CanvasLayer

@onready var bar: ProgressBar = $Bar

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player == null:
		return

	var health: Health = player.get_node("Health")
	bar.max_value = health.max_health
	bar.value = health.current_health
	health.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = current
