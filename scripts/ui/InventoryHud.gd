extends Control

## The inventory in the dungeon: a backpack button next to the health bar, and
## the inventory window it opens. The "inventory" input action (I or Tab) does
## the same, and Esc closes the window.

@onready var backpack_button: Button = $BackpackButton
@onready var inventory_panel: InventoryPanel = $InventoryPanel

func _ready() -> void:
	InventoryPanel.block_clicks(backpack_button)
	backpack_button.pressed.connect(toggle)
	inventory_panel.close_requested.connect(inventory_panel.hide)
	inventory_panel.hide()

func toggle() -> void:
	inventory_panel.visible = not inventory_panel.visible

# _input runs before the pause menu's _unhandled_input, so with the inventory
# open Esc closes it instead of opening the pause menu.
func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return   # typing in the chat
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and inventory_panel.visible:
		inventory_panel.hide()
		get_viewport().set_input_as_handled()
