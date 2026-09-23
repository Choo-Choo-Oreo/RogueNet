class_name Hotbar
extends Control

## Placeholder hotbar -- 4 static slots, no equip/switch logic yet, just
## labeled text so we can see them on screen while testing. set_slot() is
## the one hook real inventory/weapon-switching code will need later.

@onready var _labels: Array[Label] = [
	$Slots/Slot1/Label,
	$Slots/Slot2/Label,
	$Slots/Slot3/Label,
	$Slots/Slot4/Label,
]

var _stats: EntityStats

func _process(_delta: float) -> void:
	if _stats == null:
		var player := PlayerLookup.find_local(get_tree())
		if player:
			_stats = player.stats
			_stats.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, _max_health: int) -> void:
	visible = current > 0

func set_slot(index: int, text: String) -> void:
	_labels[index].text = text
