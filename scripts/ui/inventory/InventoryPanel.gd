class_name InventoryPanel
extends PanelContainer

## The inventory window: a preview of the Human wearing the current gear (turn
## it with the arrows), the eleven equipment slots, and the bag. Built in code so
## the dungeon (InventoryHud) and the town storage (TownStorage) share one copy.
##
## Right-click or double-click: a bag item goes on, a worn item comes off --
## into the storage when `storage_open` (the town), else into the bag.

signal close_requested

const UI_DIR := "res://resources/gfx/ui/inventory/"
const BODY_SHEET := "res://resources/gfx/entities/entities.protagonist/human/Human-%s.png"
const DOLL_SCALE := 8
const BAG_COLUMNS := 7

const COLOR_PANEL := Color("#211d29")
const COLOR_PANEL_BORDER := Color("#3b3447")
const COLOR_TEXT := Color("#d8d2e4")
const COLOR_DIM := Color("#8f879e")

## Two columns: worn pieces on the left, neck / back / rings on the right, and the
## two hands together on the bottom row. "" leaves a cell empty.
const EQUIP_LAYOUT: Array[String] = ["head", "neck", "chest", "back", "gloves", "ring_1", "legs", "ring_2", "feet", "", "main_hand", "off_hand"]

## The 8 ways the preview can face: which drawn sheet, its label, mirrored or not.
const FACINGS := [
	["Down", "front", false], ["DownRight", "front right", false], ["Right", "right", false],
	["UpRight", "back right", false], ["Up", "back", false], ["UpRight", "back left", true],
	["Right", "left", true], ["DownRight", "front left", true],
]

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
var _facing := 0
var _doll: Control
var _facing_label: Label
var _bag_count: Label
var _body_sheets: Dictionary = {}

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	for sheet in ItemDatabase.DRAW_ORDER:
		_body_sheets[sheet] = load(BODY_SHEET % sheet)
	_build()
	block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	header.add_child(_pixel_icon(load(UI_DIR + "backpack.png"), 2))
	header.add_child(_label("Inventory", COLOR_TEXT, 20))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if closable:
		var close := _flat_button("x")
		close.tooltip_text = "Close"
		close.pressed.connect(func(): close_requested.emit())
		header.add_child(close)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	column.add_child(top)

	var doll_column := VBoxContainer.new()
	top.add_child(doll_column)
	var doll_frame := PanelContainer.new()
	var doll_style := StyleBoxFlat.new()
	doll_style.bg_color = ItemSlot.COLOR_BG
	doll_style.border_color = ItemSlot.COLOR_BORDER
	doll_style.set_border_width_all(2)
	doll_style.set_content_margin_all(8)
	doll_frame.add_theme_stylebox_override("panel", doll_style)
	doll_column.add_child(doll_frame)
	_doll = Control.new()
	_doll.custom_minimum_size = Vector2.ONE * ItemDatabase.FRAME_SIZE * DOLL_SCALE
	doll_frame.add_child(_doll)
	var turn_row := HBoxContainer.new()
	turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	doll_column.add_child(turn_row)
	var left := _flat_button("<")
	left.pressed.connect(_turn.bind(-1))
	turn_row.add_child(left)
	_facing_label = _label("", COLOR_DIM, 14)
	_facing_label.custom_minimum_size.x = 100
	_facing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_row.add_child(_facing_label)
	var right := _flat_button(">")
	right.pressed.connect(_turn.bind(1))
	turn_row.add_child(right)

	var equip_grid := GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override("h_separation", 6)
	equip_grid.add_theme_constant_override("v_separation", 6)
	top.add_child(equip_grid)
	for slot in EQUIP_LAYOUT:
		if slot == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2.ONE * ItemSlot.SIZE
			equip_grid.add_child(gap)
			continue
		# the empty-slot picture is per kind: both ring slots show slot_ring.png
		var picture: Texture2D = load(UI_DIR + "slot_%s.png" % ItemDatabase.slot_kind(slot))
		var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.EQUIP, slot), picture)
		cell.quick_action = _quick_action
		equip_grid.add_child(cell)
		_slots.append(cell)

	var bag_header := HBoxContainer.new()
	column.add_child(bag_header)
	bag_header.add_child(_label("Bag", COLOR_TEXT, 16))
	var bag_spacer := Control.new()
	bag_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_header.add_child(bag_spacer)
	_bag_count = _label("", COLOR_DIM, 14)
	bag_header.add_child(_bag_count)

	var bag_grid := GridContainer.new()
	bag_grid.columns = BAG_COLUMNS
	bag_grid.add_theme_constant_override("h_separation", 4)
	bag_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(bag_grid)
	for i in PlayerInventory.BAG_SIZE:
		var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.BAG, i))
		cell.quick_action = _quick_action
		bag_grid.add_child(cell)
		_slots.append(cell)

	var hint := _label("Drag, right-click or double-click to equip and unequip", COLOR_DIM, 12)
	column.add_child(hint)

func refresh() -> void:
	for cell in _slots:
		cell.quick_hint = _hint_for(cell.at)
		cell.refresh()
	_bag_count.text = "%d / %d" % [PlayerInventory.BAG_SIZE - PlayerInventory.bag.count(""), PlayerInventory.BAG_SIZE]
	_draw_doll()

func _hint_for(at: Dictionary) -> String:
	if at["where"] != PlayerInventory.EQUIP:
		return "Right-click to equip"
	return "Right-click to put in storage" if storage_open else "Right-click to put in bag"

func _quick_action(at: Dictionary) -> void:
	if at["where"] != PlayerInventory.EQUIP:
		PlayerInventory.equip_from(at)
	elif storage_open:
		if not PlayerInventory.send_to(at, PlayerInventory.STORAGE):
			PlayerInventory.send_to(at, PlayerInventory.BAG)
	else:
		PlayerInventory.send_to(at, PlayerInventory.BAG)

func _turn(step: int) -> void:
	_facing = posmod(_facing + step, FACINGS.size())
	_draw_doll()

# The same layering the game uses (ItemDatabase.DRAW_ORDER), first frame of each sheet.
func _draw_doll() -> void:
	for child in _doll.get_children():
		child.queue_free()
	var sheet: String = FACINGS[_facing][0]
	var mirrored: bool = FACINGS[_facing][2]
	_facing_label.text = "Human, " + FACINGS[_facing][1]
	for slot in ItemDatabase.DRAW_ORDER[sheet]:
		var texture: Texture2D
		if slot == "body":
			texture = _body_sheets[sheet]
		else:
			var item_id: String = PlayerInventory.equipped.get(slot, "")
			if item_id == "":
				continue
			texture = load(ItemDatabase.sheet_path(item_id, sheet))
		if texture == null:
			continue
		var layer := TextureRect.new()
		layer.texture = ItemDatabase.frame_texture(texture, 0)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.flip_h = mirrored
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_doll.add_child(layer)

# FOCUS_NONE: a focused button is pressed by Space, which is also the attack key.
static func _flat_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	return button

static func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

static func _pixel_icon(texture: Texture2D, factor: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = texture.get_size() * factor
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect
