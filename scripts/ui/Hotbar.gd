class_name Hotbar
extends Control

## Hotbar display -- 4 slots, still placeholder text/icons, but now tracks
## and highlights whichever slot PlayerController.active_slot says is
## equipped (switched with number keys 1-4). set_slot() is the hook real
## inventory code will need later to change what a slot's label shows.

@onready var _labels: Array[Label] = [
	$Slots/Slot1/Label,
	$Slots/Slot2/Label,
	$Slots/Slot3/Label,
	$Slots/Slot4/Label,
]

@onready var _panels: Array[Panel] = [
	$Slots/Slot1,
	$Slots/Slot2,
	$Slots/Slot3,
	$Slots/Slot4,
]

const ACTIVE_COLOR := Color(1.4, 1.4, 1.4)
const INACTIVE_COLOR := Color(1, 1, 1)

var _stats: EntityStats
var _player: Node2D
var _shown_slot := -1

func _process(_delta: float) -> void:
	if _player == null:
		_player = PlayerLookup.find_local(get_tree())
		if _player:
			_stats = _player.stats
			_stats.health_changed.connect(_on_health_changed)
	if _player and _player.active_slot != _shown_slot:
		_shown_slot = _player.active_slot
		for i in _panels.size():
			_panels[i].self_modulate = ACTIVE_COLOR if i == _shown_slot else INACTIVE_COLOR

func _on_health_changed(current: int, _max_health: int) -> void:
	visible = current > 0

func set_slot(index: int, text: String) -> void:
	_labels[index].text = text
