class_name InventoryPanel
extends PanelContainer

## The inventory window: the Human wearing the current gear in a candlelit alcove
## (DollStage: drag to turn them, drop gear on them to wear it), the eleven equipment
## slots around them, and the bag. Built in code so the dungeon (InventoryHud) and the
## town storage (TownStorage) share one copy.
##
## Right-click or double-click: a bag item goes on, a worn item comes off -- into the
## storage when `storage_open` (the town), else into the bag. In the town, Shift+click
## sends a bag item to the storage, and a Shift sweep across the bag sends each one.

signal close_requested

const UI_DIR := "res://resources/gfx/ui/inventory/"
const BAG_COLUMNS := 7
const SLOT_GAP := 6

const COLOR_TEXT := Color("#ecdcb8")
const COLOR_DIM := Color("#a8927a")

## The slots down each side of the figure, top to bottom, and the two hands under it.
const EQUIP_LEFT: Array[String] = ["head", "chest", "gloves", "legs", "feet"]
const EQUIP_RIGHT: Array[String] = ["neck", "back", "ring_1", "ring_2"]
const EQUIP_HANDS: Array[String] = ["main_hand", "off_hand"]

## Every open panel, so a click on one doesn't also swing the player's weapon
## (see PlayerController._attack_blocked). Other controls that should swallow
## clicks the same way (the backpack button) register with block_clicks().
static var _click_blockers: Array[Control] = []

static func block_clicks(control: Control) -> void:
	_click_blockers.append(control)
	control.tree_exiting.connect(func(): _click_blockers.erase(control))

static func mouse_over_open_panel(viewport: Viewport) -> bool:
	var mouse := viewport.get_mouse_position()
	for control in _click_blockers:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(mouse):
			return true
	return false

## Set in the town, where worn gear comes off into the storage instead of the bag.
@export var storage_open := false
## Shows the x button in the header (the dungeon HUD closes it; the town screen has Back).
@export var closable := true

var _slots: Array[ItemSlot] = []
var _stage: DollStage
var _bag_count: CapacityBar

func _ready() -> void:
	add_theme_stylebox_override("panel", Parchment.wood_panel())
	_build()
	block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var close: Button = null
	if closable:
		close = Button.new()
		close.text = "x"
		close.tooltip_text = "Close (Esc)"
		Parchment.button_look(close)
		close.pressed.connect(func(): close_requested.emit())
	column.add_child(Parchment.heading("Equipment", 18, close))

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	top.add_child(_slot_column(EQUIP_LEFT))
	_stage = DollStage.new()
	top.add_child(_stage)
	top.add_child(_slot_column(EQUIP_RIGHT))

	var hands := HBoxContainer.new()
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	hands.add_theme_constant_override("separation", ItemSlot.SIZE * 2)
	for slot in EQUIP_HANDS:
		hands.add_child(_equip_slot(slot))
	column.add_child(hands)

	_bag_count = CapacityBar.new()
	column.add_child(Parchment.heading("Bag", 16, _bag_count))
	var bag_grid := GridContainer.new()
	bag_grid.columns = BAG_COLUMNS
	bag_grid.add_theme_constant_override("h_separation", 4)
	bag_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(bag_grid)
	for i in PlayerInventory.BAG_SIZE:
		var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.BAG, i))
		cell.quick_action = _quick_action
		if storage_open:
			cell.shift_action = func(at: Dictionary): PlayerInventory.send_to(at, PlayerInventory.STORAGE)
			cell.shift_hint = "Shift+click to store (hold and sweep for more)"
		bag_grid.add_child(cell)
		_slots.append(cell)

	var hint := "Right-click: wear or take off  ·  Shift+click or sweep: store" if storage_open else "Right-click: wear or take off  ·  drop gear on yourself"
	column.add_child(_label(hint, COLOR_DIM, 12))

func _slot_column(slots: Array[String]) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", SLOT_GAP)
	list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for slot in slots:
		list.add_child(_equip_slot(slot))
	return list

func _equip_slot(slot: String) -> ItemSlot:
	# the empty-slot picture is per kind: both ring slots show slot_ring.png
	var picture: Texture2D = load(UI_DIR + "slot_%s.png" % ItemDatabase.slot_kind(slot))
	var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.EQUIP, slot), picture)
	cell.quick_action = _quick_action
	_slots.append(cell)
	return cell

func refresh() -> void:
	for cell in _slots:
		cell.quick_hint = _hint_for(cell.at)
		cell.refresh()
	_bag_count.set_count(PlayerInventory.BAG_SIZE - PlayerInventory.bag.count(""), PlayerInventory.BAG_SIZE)
	_stage.refresh()

func _hint_for(at: Dictionary) -> String:
	if at["where"] != PlayerInventory.EQUIP:
		return "Right-click to equip" if ItemDatabase.item_slot(PlayerInventory.get_at(at)) != "" else ""
	return "Right-click to put in storage" if storage_open else "Right-click to put in bag"

func _quick_action(at: Dictionary) -> void:
	if at["where"] != PlayerInventory.EQUIP:
		PlayerInventory.equip_from(at)
	elif storage_open:
		if not PlayerInventory.send_to(at, PlayerInventory.STORAGE):
			PlayerInventory.send_to(at, PlayerInventory.BAG)
	else:
		PlayerInventory.send_to(at, PlayerInventory.BAG)

static func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
