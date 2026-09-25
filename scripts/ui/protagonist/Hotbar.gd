class_name Hotbar
extends Control

## Hotbar display: 10 slots (keys 1-0, or LB/RB on a controller) naming the local
## player's actions (from worn gear, see PlayerController._update_attacks). Highlights
## whichever slot PlayerController.active_slot says is equipped. Hooks for later:
## set_cooldown() (the dark sweep while an attack recharges), set_consumable() (the
## X slot right of the bar).

@onready var _slots: Array[Node] = $Column/Row/SlotsPanel/Slots.get_children()
@onready var _consumable_name: Label = $Column/Row/Consumable/Column/Name
@onready var _consumable_count: Label = $Column/Row/Consumable/Column/Count

var _stats: EntityStats
var _player: Node2D
var _shown_slot := -1

func _ready() -> void:
	InputDevice.changed.connect(_show_keys)
	_show_keys(InputDevice.using_pad)

func _process(_delta: float) -> void:
	if _player == null:
		_player = PlayerLookup.find_local(get_tree())
		if _player:
			_stats = _player.stats
			_stats.health_changed.connect(_on_health_changed)
			_player.attacks_changed.connect(_show_attacks)
			_show_attacks()
	if _player and _player.active_slot != _shown_slot:
		_shown_slot = _player.active_slot
		for i in _slots.size():
			_restyle(i)

func _show_attacks() -> void:
	for i in _slots.size():
		var actions: Array = _player.hotbar_actions()
		var attack: Dictionary = actions[i] if i < actions.size() else {}
		set_slot(i, str(attack.get("id", "")).capitalize())

func _on_health_changed(current: int, _max_health: int) -> void:
	visible = current > 0

## The 1-0 labels only mean something on a keyboard; on a controller LB/RB pick the slot.
func _show_keys(using_pad: bool) -> void:
	for slot in _slots:
		slot.get_node("Key").visible = not using_pad

func _restyle(index: int) -> void:
	var slot: Panel = _slots[index]
	if index == _shown_slot:
		slot.theme_type_variation = &"HudSlotActive"
	elif slot.get_node("Name").text == "":
		slot.theme_type_variation = &"HudSlotEmpty"
	else:
		slot.theme_type_variation = &"HudSlot"

func set_slot(index: int, text: String) -> void:
	_slots[index].get_node("Name").text = text
	_restyle(index)

## `fraction` of the cooldown still to go: 1.0 just used, 0.0 ready (hidden).
func set_cooldown(index: int, fraction: float) -> void:
	var cover: ColorRect = _slots[index].get_node("Cooldown")
	cover.visible = fraction > 0.0
	cover.anchor_top = 1.0 - clampf(fraction, 0.0, 1.0)

func set_consumable(item_name: String, count: int) -> void:
	_consumable_name.text = item_name if item_name != "" else "Consumable"
	_consumable_count.text = "x%d" % count if count > 0 else "none"
