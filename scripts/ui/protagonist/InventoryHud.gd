extends Control

## The dungeon's menu buttons (bottom-left) and the GameMenu they open: tabs
## (Inventory, Character, Skills, Help, System) over the inventory window.
## "inventory" (I, Tab, Y) opens it on Inventory; Esc / B closes it.
## Only the Inventory tab has content; the other pages are placeholders to hook up.

@onready var menu_buttons: HBoxContainer = $MenuButtons
@onready var backpack_button: Button = $MenuButtons/BackpackButton
@onready var menu_button: Button = $MenuButtons/MenuButton
@onready var pad_strip: PanelContainer = $PadStrip
@onready var game_menu: PanelContainer = $GameMenu
@onready var tabs: TabBar = $GameMenu/Column/Tabs/TabBar
@onready var pages: Array[Node] = $GameMenu/Column/Pages.get_children()
@onready var close_button: Button = $GameMenu/Column/Tabs/CloseButton
@onready var inventory_panel: InventoryPanel = $GameMenu/Column/Pages/InventoryPanel

## Tab index of System: picking it opens the pause menu instead of a page.
const SYSTEM_TAB := 4

func _ready() -> void:
	game_menu.add_theme_stylebox_override("panel", InventoryPanel.frame_style())
	for control in [menu_buttons, pad_strip, game_menu]:
		InventoryPanel.block_clicks(control)
	backpack_button.pressed.connect(toggle)
	menu_button.pressed.connect(_open_pause_menu)
	close_button.pressed.connect(game_menu.hide)
	tabs.tab_changed.connect(_show_page)
	InputDevice.changed.connect(_on_device_changed)
	_on_device_changed(InputDevice.using_pad)
	game_menu.hide()

func toggle() -> void:
	if game_menu.visible:
		game_menu.hide()
	else:
		tabs.current_tab = 0
		_show_page(0)
		game_menu.show()
		inventory_panel.set_pad_focus(InputDevice.using_pad)

func _show_page(index: int) -> void:
	if index == SYSTEM_TAB:
		_open_pause_menu()
		return
	for i in pages.size():
		pages[i].visible = i == index

func _open_pause_menu() -> void:
	game_menu.hide()
	get_tree().call_group("pause_menu", "open")

func _on_device_changed(using_pad: bool) -> void:
	menu_buttons.visible = not using_pad
	pad_strip.visible = using_pad
	inventory_panel.set_pad_focus(using_pad and game_menu.visible)

# _input runs before the pause menu's _unhandled_input, so with the menu open
# Esc / B closes it instead of opening the pause menu.
func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return   # typing in the chat
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif not game_menu.visible:
		return
	elif event.is_action_pressed("ui_cancel"):
		game_menu.hide()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_tab_prev"):
		tabs.current_tab = posmod(tabs.current_tab - 1, tabs.tab_count)
	elif event.is_action_pressed("menu_tab_next"):
		tabs.current_tab = posmod(tabs.current_tab + 1, tabs.tab_count)
