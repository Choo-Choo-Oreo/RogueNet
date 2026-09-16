extends PanelContainer
class_name HotbarSlot

@onready var key_label: Label = $KeyLabel
@onready var ability_label: Label = $AbilityLabel

var ability: Ability = null

func set_key_text(text: String) -> void:
	key_label.text = text

func set_ability(new_ability: Ability) -> void:
	ability = new_ability
	ability_label.text = ability.ability_name if ability != null else ""
func _get_drag_data(at_position: Vector2) -> Variant:
	if ability == null:
		return null  # nothing here, so nothing to drag

	var preview := Label.new()
	preview.text = ability.ability_name
	set_drag_preview(preview)  # small label that follows the cursor while dragging

	return {"source_slot": self}  # the "bundle" — just says which slot this drag came from

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("source_slot")

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var source_slot: HotbarSlot = data["source_slot"]
	if source_slot == self:
		return  # dropped on the same slot it came from, do nothing

	var temp := ability
	set_ability(source_slot.ability)
	source_slot.set_ability(temp)
