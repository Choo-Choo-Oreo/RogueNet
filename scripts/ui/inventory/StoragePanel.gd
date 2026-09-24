class_name StoragePanel
extends PanelContainer

## The town storage: a grid of PlayerInventory.storage. Items drag between here,
## the bag and the equipment slots; right-click or double-click puts one on.

const MAX_VISIBLE_ROWS := 8

var _slots: Array[ItemSlot] = []
var _count: Label

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = InventoryPanel.COLOR_PANEL
	style.border_color = InventoryPanel.COLOR_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	_build()
	InventoryPanel.block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(InventoryPanel._label("Storage", InventoryPanel.COLOR_TEXT, 20))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_count = InventoryPanel._label("", InventoryPanel.COLOR_DIM, 14)
	header.add_child(_count)

	var grid := GridContainer.new()
	grid.columns = PlayerInventory.STORAGE_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
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
		scroll.custom_minimum_size.y = MAX_VISIBLE_ROWS * (ItemSlot.SIZE + 4)
		scroll.add_child(grid)
		column.add_child(scroll)
	else:
		column.add_child(grid)

	column.add_child(InventoryPanel._label("Drag gear onto your character, or right-click it", InventoryPanel.COLOR_DIM, 12))

func refresh() -> void:
	for cell in _slots:
		cell.refresh()
	_count.text = "%d / %d" % [PlayerInventory.storage.size() - PlayerInventory.storage.count(""), PlayerInventory.storage.size()]
