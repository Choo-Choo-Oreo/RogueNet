class_name HealthBar
extends Control

## Top-left health bar for the locally-controlled player. Hides itself once
## that player dies (turns into a ghost) -- no more health to track for the
## rest of the run.

@onready var fill: ColorRect = $Background/Fill
@onready var label: Label = $Background/Label

var _stats: EntityStats

func _process(_delta: float) -> void:
	if _stats == null:
		var player := PlayerLookup.find_local(get_tree())
		if player:
			_stats = player.stats
			_stats.health_changed.connect(_on_health_changed)
			_on_health_changed(_stats.current_health, _stats.max_health)

func _on_health_changed(current: int, max_health: int) -> void:
	fill.anchor_right = 0.0 if max_health <= 0 else float(current) / float(max_health)
	label.text = "%d / %d" % [current, max_health]
	visible = current > 0
