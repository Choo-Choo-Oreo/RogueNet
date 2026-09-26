class_name StoragePanel
extends PanelContainer

## The town storage: a grid of PlayerInventory.storage. Items drag between here,
## the bag and the equipment slots; right-click or double-click puts one on.
## Run from the editor, it also has debug buttons that fill the storage.

const MAX_VISIBLE_ROWS := 8

var _slots: Array[ItemSlot] = []
var _count: Label

func _ready() -> void:
	theme_type_variation = &"InventoryFrame"
	_build()
	InventoryPanel.block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(InventoryPanel._label("Storage", &"InventoryHeading"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_count = InventoryPanel._label("", &"InventoryDim")
	header.add_child(_count)
	if OS.has_feature("editor"):
		_debug_button(column, "Populate all items", ItemDatabase.all_ids)
		_debug_button(column, "Populate cosmetics",
			func(): return ItemDatabase.all_ids().filter(ItemDatabase.is_cosmetic))

	var grid := GridContainer.new()
	grid.columns = PlayerInventory.STORAGE_COLUMNS
	grid.theme_type_variation = &"ItemGrid"
	for i in PlayerInventory.storage.size():
		var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.STORAGE, i))
		cell.quick_action = PlayerInventory.equip_from
		cell.quick_hint = "Right-click to equip"
		grid.add_child(cell)
		_slots.append(cell)

	# More rows than fit on screen scroll instead of pushing the panel off it.
	var rows := ceili(float(_slots.size()) / grid.columns)
	if rows > MAX_VISIBLE_ROWS:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size.y = MAX_VISIBLE_ROWS * (ItemSlot.SIZE + grid.get_theme_constant("v_separation"))
		scroll.add_child(grid)
		column.add_child(scroll)
	else:
		column.add_child(grid)

	column.add_child(InventoryPanel._label("Drag gear onto your character, or right-click it", &"InventoryDim"))

## Adds one of each item `ids` returns that the adventurer lacks (PlayerInventory.add_to_storage).
func _debug_button(column: VBoxContainer, text: String, ids: Callable) -> void:
	var button := InventoryPanel._flat_button("[debug] " + text)
	button.pressed.connect(func():
		var list: Array[String] = []
		list.assign(ids.call())
		PlayerInventory.add_to_storage(list))
	column.add_child(button)

func refresh() -> void:
	# Storage grew (a debug button): the grid is built for a fixed number of cells.
	if _slots.size() != PlayerInventory.storage.size():
		for child in get_children():
			child.queue_free()
		_slots.clear()
		_build()
	for cell in _slots:
		cell.refresh()
	_count.text = "%d / %d" % [PlayerInventory.storage.size() - PlayerInventory.storage.count(""), PlayerInventory.storage.size()]
