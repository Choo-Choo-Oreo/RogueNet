class_name InventoryPanel
extends PanelContainer

## The inventory window: a preview of the Human wearing the current gear (turn
## it with the arrows), the nine equipment slots, and the bag. Built in code so
## the dungeon (InventoryHud) and the town storage (TownStorage) share one copy.
##
## Right-click or double-click: a bag item goes on, a worn item comes off --
## into the storage when `storage_open` (the town), else into the bag.

const UI_DIR := "res://resources/gfx/ui/inventory/"
const BODY_SHEET := "res://resources/gfx/entities/entities.protagonist/human/Human-%s.png"
const DOLL_SCALE := 4
const BAG_COLUMNS := 7


## Two columns, the way the slots sit in the mockup: worn pieces on the left,
## neck / back / hands on the right.
const EQUIP_LAYOUT: Array[String] = ["head", "neck", "chest", "back", "gloves", "main_hand", "legs", "off_hand", "feet"]

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
## The dungeon menu's layout: equipment on both sides of the character, bag to the
## right, so it is wide and short and fits between the party frames and the hotbar.
## The town keeps the tall layout (character and equipment on top, bag under them).
@export var wide_layout := false
## Inside the dungeon menu (GameMenu), which draws the frame, the tabs and the
## prompts itself: no own frame, header or hint line.
@export var embedded := false

## The character preview is drawn this many times bigger (the wide layout uses a
## smaller one so the panel stays short).
const DOLL_SCALE_WIDE := 3

var _slots: Array[ItemSlot] = []
var _facing := 0
var _doll: Control
var _facing_label: Label
var _bag_count: Label
var _body_sheets: Dictionary = {}

func _ready() -> void:
	# The purple frame is InventoryFrame in UiTheme.tres (shared with storage and the GameMenu).
	if embedded:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		theme_type_variation = &"InventoryFrame"
	for sheet in ItemDatabase.DRAW_ORDER:
		_body_sheets[sheet] = load(BODY_SHEET % sheet)
	_build()
	block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)

	if not embedded:
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		column.add_child(header)
		header.add_child(_pixel_icon(load(UI_DIR + "backpack.png"), 1))
		header.add_child(_label("Inventory", &"InventoryHeading"))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 9 if wide_layout else 7)
	column.add_child(top)

	# Wide: [worn pieces] [character] [neck/back/hands], each a column of slots.
	var paper := HBoxContainer.new()
	paper.add_theme_constant_override("separation", 5)
	top.add_child(paper)
	var left_slots: VBoxContainer = null
	if wide_layout:
		left_slots = _slot_column()
		paper.add_child(left_slots)

	var doll_column := VBoxContainer.new()
	paper.add_child(doll_column)
	var doll_frame := PanelContainer.new()
	doll_frame.theme_type_variation = &"DollFrame"
	doll_column.add_child(doll_frame)
	_doll = Control.new()
	_doll.custom_minimum_size = Vector2.ONE * ItemDatabase.FRAME_SIZE * (DOLL_SCALE_WIDE if wide_layout else DOLL_SCALE)
	doll_frame.add_child(_doll)
	var turn_row := HBoxContainer.new()
	turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	doll_column.add_child(turn_row)
	var left := _flat_button("<")
	left.pressed.connect(_turn.bind(-1))
	turn_row.add_child(left)
	_facing_label = _label("", &"InventoryDim")
	_facing_label.custom_minimum_size.x = 50
	_facing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_row.add_child(_facing_label)
	var right := _flat_button(">")
	right.pressed.connect(_turn.bind(1))
	turn_row.add_child(right)

	# EQUIP_LAYOUT is two columns read row by row: even entries are the left
	# column (worn pieces), odd entries the right one (neck, back, hands).
	if wide_layout:
		var right_slots := _slot_column()
		paper.add_child(right_slots)
		for i in EQUIP_LAYOUT.size():
			_add_equip_cell(left_slots if i % 2 == 0 else right_slots, EQUIP_LAYOUT[i])
	else:
		var equip_grid := GridContainer.new()
		equip_grid.columns = 2
		equip_grid.add_theme_constant_override("h_separation", 3)
		equip_grid.add_theme_constant_override("v_separation", 3)
		top.add_child(equip_grid)
		for slot in EQUIP_LAYOUT:
			_add_equip_cell(equip_grid, slot)

	# Wide: the bag sits right of the character; tall: under it.
	var bag_parent := column
	if wide_layout:
		bag_parent = VBoxContainer.new()
		bag_parent.add_theme_constant_override("separation", 4)
		top.add_child(bag_parent)

	var bag_header := HBoxContainer.new()
	bag_parent.add_child(bag_header)
	bag_header.add_child(_label("Bag", &"InventoryText"))
	var bag_spacer := Control.new()
	bag_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_header.add_child(bag_spacer)
	_bag_count = _label("", &"InventoryDim")
	bag_header.add_child(_bag_count)

	var bag_grid := GridContainer.new()
	bag_grid.columns = BAG_COLUMNS
	bag_grid.theme_type_variation = &"ItemGrid"
	bag_parent.add_child(bag_grid)
	for i in PlayerInventory.BAG_SIZE:
		var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.BAG, i))
		cell.quick_action = _quick_action
		bag_grid.add_child(cell)
		_slots.append(cell)

	if not embedded:   # the GameMenu shows its own prompts, for keyboard and controller
		var hint := _label("Drag, right-click or double-click to equip and unequip", &"InventoryDim")
		column.add_child(hint)

func _slot_column() -> VBoxContainer:
	var slots := VBoxContainer.new()
	slots.add_theme_constant_override("separation", 3)
	return slots

func _add_equip_cell(parent: Container, slot: String) -> void:
	var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.EQUIP, slot), load(UI_DIR + "slot_%s.png" % slot))
	cell.quick_action = _quick_action
	parent.add_child(cell)
	_slots.append(cell)

## Controller use: slots take focus (the left stick moves between them) and the
## first one is selected. Off for keyboard + mouse, where a focused slot would
## grab Space and Enter.
func set_pad_focus(on: bool) -> void:
	for cell in _slots:
		cell.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if on and not _slots.is_empty():
		_slots[0].grab_focus()
	elif not on:
		var owner_control := get_viewport().gui_get_focus_owner()
		if owner_control in _slots:
			owner_control.release_focus()

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

## `variation`: its colour (and size) from UiTheme.tres: InventoryText, InventoryDim or
## InventoryHeading (MenuHeading's size).
static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label

static func _pixel_icon(texture: Texture2D, factor: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = texture.get_size() * factor
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect
