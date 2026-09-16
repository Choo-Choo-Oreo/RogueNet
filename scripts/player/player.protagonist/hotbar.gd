extends CanvasLayer

@onready var slots: Array[HotbarSlot] = [
	$Slots/Slot1, $Slots/Slot2, $Slots/Slot3, $Slots/Slot4, $Slots/Slot5
]

var hotbar_actions := ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5"]

func _ready() -> void:
	for i in slots.size():
		slots[i].set_key_text(str(i + 1))

	# TEMPORARY: seeds slot 1 with a test ability so drag/drop and key-press
	# can be verified before a real ability-granting system exists.
	# Remove this block once that system is in place.
	var atk := Ability.new()
	atk.ability_name = "Attack"
	slots[0].set_ability(atk)

func _unhandled_input(event: InputEvent) -> void:
	for i in hotbar_actions.size():
		if event.is_action_pressed(hotbar_actions[i]):
			_trigger_slot(i)

func _trigger_slot(index: int) -> void:
	var slot := slots[index]
	if slot.ability:
		print("Triggered: ", slot.ability.ability_name)
