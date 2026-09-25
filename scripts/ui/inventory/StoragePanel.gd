class_name StoragePanel
extends PanelContainer

## The town storage, dressed like the main menu (parchment on wooden rollers,
## brown ink). Items drag between here, the bag and the equipment slots;
## right-click or double-click puts one on, Ctrl+click locks it.
##
## - Tabs down the left (TABS) show one group of items, each with how many it
##   holds. A tab is worked out from the item's slot or type (ItemDatabase.category),
##   nothing is stored for it.
## - Search filters by name as you type.
## - Sort tidies the storage for real (PlayerInventory.sort_storage), merging
##   stacks; locked items stay where they are. "Store all" empties the bag into
##   storage, except locked items.
## - Sets groups what's shown by set, with how many armour pieces of each set you
##   own and whether its full-set bonus is ready.
## - The page on the right is the lore of the last item hovered.
##
## With the All tab and no search the grid is the storage itself, empty cells
## included. Anything filtered shows only its matches, then a row of free cells to
## drop into (and a drop anywhere on the grid sends the item into storage).

const UI_DIR := "res://resources/gfx/ui/storage/"
const MENU_DIR := Parchment.MENU_DIR
## Screen pixels per art pixel, as ItemSlot.
const PX := ItemSlot.PX
const MAX_VISIBLE_ROWS := 8
const CELL_GAP := 4
const TAB_WIDTH := 80
## How far the chosen tab sticks out towards the grid.
const TAB_SHIFT := 8
const PAGE_WIDTH := 210

## The parchment look is shared with the other paper screens (Parchment.gd).
const INK := Parchment.INK
const PAPER := Parchment.PAPER
const PAPER_LIGHT := Parchment.PAPER_LIGHT
const PAPER_DARK := Parchment.PAPER_DARK
const OUTLINE := Parchment.OUTLINE
const GOLD := Parchment.GOLD

## Each tab shows the items whose ItemDatabase.category is in "holds" ([] = all).
## Every slot kind and type is in one of them.
const TABS := [
	{"name": "All", "icon": "tab_all", "holds": []},
	{"name": "Armour", "icon": "tab_armour", "holds": ItemDatabase.FULL_SET_SLOTS},
	{"name": "Weapons", "icon": "tab_weapons", "holds": ["main_hand", "off_hand"]},
	{"name": "Jewellery", "icon": "tab_jewellery", "holds": ["neck", "ring"]},
	{"name": "Back", "icon": "tab_back", "holds": ["back"]},
	{"name": "Potions", "icon": "tab_potions", "holds": ["potion"]},
	{"name": "Items", "icon": "tab_items", "holds": ["item"]},
	{"name": "Materials", "icon": "tab_materials", "holds": ["material"]},
]
## Menu text for each of PlayerInventory.SORTS.
const SORT_NAMES := {"set": "By set", "slot": "By slot", "rarity": "By rarity", "newest": "Newest first", "name": "By name"}

var _tab := 0
var _search := ""
var _set_view := false
var _slots: Array[ItemSlot] = []
var _shown_key := ""
var _tabs: Array[Button] = []
var _tab_counts: Array[Label] = []
var _count: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _page: Dictionary = {}


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = InventoryPanel.COLOR_PANEL
	style.border_color = InventoryPanel.COLOR_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	add_to_group("item_details")
	_build()
	InventoryPanel.block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

# ---------------------------------------------------------------- building

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	# the title, on a scroll like the main menu's buttons
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	column.add_child(title_row)
	var title := Parchment.ink_label("Storage", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var banner := Parchment.strip(MENU_DIR + "ScrollPaper.png", title)
	var banner_holder := Control.new()
	banner_holder.custom_minimum_size = Vector2(220, 20 * PX)
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_holder.add_child(banner)
	title_row.add_child(banner_holder)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	_count = InventoryPanel._label("", InventoryPanel.COLOR_DIM, 14)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_count)

	# search, sort, sets, store all
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	column.add_child(tools)
	var search := LineEdit.new()
	search.placeholder_text = "Search..."
	search.right_icon = Parchment.pixel_texture(UI_DIR + "tool_search.png")
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 170
	search.clear_button_enabled = true
	Parchment.parchment(search, ["normal", "focus", "read_only"])
	search.add_theme_color_override("font_color", INK)
	search.add_theme_color_override("font_placeholder_color", PAPER_DARK)
	search.add_theme_color_override("caret_color", INK)
	search.add_theme_color_override("clear_button_color", INK)
	search.text_changed.connect(func(text: String):
		_search = text.strip_edges().to_lower()
		refresh())
	tools.add_child(search)

	var sort := MenuButton.new()
	sort.text = "Sort"
	sort.icon = Parchment.pixel_texture(UI_DIR + "tool_sort.png")
	sort.tooltip_text = "Tidy the storage. Locked items stay put."
	sort.flat = false
	Parchment.button_look(sort)
	for i in PlayerInventory.SORTS.size():
		sort.get_popup().add_item(SORT_NAMES[PlayerInventory.SORTS[i]], i)
	sort.get_popup().id_pressed.connect(func(id: int):
		PlayerInventory.sort_storage(PlayerInventory.SORTS[id])
		ItemSounds.play(self, ItemSounds.SORT)
		_fade_in())
	tools.add_child(sort)

	var sets := _tool_button("Sets", "tool_sets", "Group by set")
	sets.toggle_mode = true
	sets.toggled.connect(func(on: bool):
		_set_view = on
		ItemSounds.play(self, ItemSounds.TAB)
		refresh()
		_fade_in())
	tools.add_child(sets)

	var store := _tool_button("Store all", "tool_store_all", "Put everything from your bag in storage, except locked items")
	store.pressed.connect(func():
		if PlayerInventory.store_all() > 0:
			ItemSounds.play(self, ItemSounds.SORT)
		else:
			ItemSounds.play(self, ItemSounds.REFUSE))
	tools.add_child(store)

	# tabs | grid | lore page
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	column.add_child(body)
	var tab_column := VBoxContainer.new()
	tab_column.add_theme_constant_override("separation", 4)
	body.add_child(tab_column)
	for i in TABS.size():
		tab_column.add_child(_make_tab(i))

	_scroll = DropArea.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cell := ItemSlot.SIZE + CELL_GAP
	_scroll.custom_minimum_size = Vector2(PlayerInventory.STORAGE_COLUMNS * cell + 10, MAX_VISIBLE_ROWS * cell)
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	body.add_child(_build_page())

	column.add_child(InventoryPanel._label("Drag to move  ·  right-click to equip  ·  Ctrl+click to lock", InventoryPanel.COLOR_DIM, 12))

# A bookmark tab: a small scroll with the group's icon and how many items it holds.
func _make_tab(i: int) -> Button:
	var tab := Button.new()
	tab.focus_mode = Control.FOCUS_NONE
	tab.custom_minimum_size = Vector2(TAB_WIDTH + TAB_SHIFT, 20 * PX)
	tab.tooltip_text = TABS[i]["name"]
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		tab.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Parchment.pixel_texture(UI_DIR + TABS[i]["icon"] + ".png")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var count := Parchment.ink_label("", 14)
	count.custom_minimum_size.x = 22
	content.add_child(count)
	_tab_counts.append(count)
	var strip := Parchment.strip(UI_DIR + "TabPaperDim.png", content)
	strip.size = Vector2(TAB_WIDTH, 20 * PX)
	tab.add_child(strip)
	tab.set_meta("strip", strip)
	tab.pressed.connect(func():
		if _tab != i:
			_tab = i
			ItemSounds.play(self, ItemSounds.TAB)
			refresh()
			_fade_in())
	tab.mouse_entered.connect(func(): strip.modulate = Color(1.08, 1.08, 1.08))
	tab.mouse_exited.connect(func(): strip.modulate = Color.WHITE)
	_tabs.append(tab)
	return tab

# The lore page: a sheet of parchment with the hovered item's picture, rarity,
# set and flavour text.
func _build_page() -> Control:
	var page := PanelContainer.new()
	var style := Parchment.page_style()
	page.add_theme_stylebox_override("panel", style)
	page.custom_minimum_size.x = PAGE_WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	page.add_child(column)

	var picture := Control.new()
	picture.custom_minimum_size = Vector2(80, 80)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.add_child(frame)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(8, 8)
	icon.size = Vector2(64, 64)
	picture.add_child(icon)
	column.add_child(picture)

	var name_label := Parchment.ink_label("", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var kind := Parchment.ink_label("", 13)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kind)
	var rule := ColorRect.new()
	rule.color = PAPER_DARK
	rule.custom_minimum_size = Vector2(0, PX)
	column.add_child(rule)
	var text := Parchment.ink_label("", 14)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = PAGE_WIDTH - 24
	column.add_child(text)
	var lore := Parchment.ink_label("", 12)
	lore.add_theme_color_override("font_color", PAPER_DARK.darkened(0.25))
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size.x = PAGE_WIDTH - 24
	column.add_child(lore)
	var set_line := Parchment.ink_label("", 13)
	set_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_line.custom_minimum_size.x = PAGE_WIDTH - 24
	column.add_child(set_line)
	_page = {"frame": frame, "icon": icon, "name": name_label, "kind": kind, "text": text, "lore": lore, "set": set_line}
	_clear_page()
	return page

func _clear_page() -> void:
	_page["frame"].texture = ItemSlot.frame_texture(ItemDatabase.RARITIES[0])
	_page["icon"].texture = null
	_page["name"].text = "Storage"
	_page["name"].add_theme_color_override("font_color", INK)
	_page["kind"].text = ""
	_page["text"].text = "Hover over an item to read about it."
	_page["lore"].text = ""
	_page["set"].text = ""

## Called through the "item_details" group by any ItemSlot the mouse is over.
func show_item(item_id: String) -> void:
	var rarity := ItemDatabase.rarity(item_id)
	var item := ItemDatabase.get_item(item_id)
	var set_id: String = item.get("set", "")
	_page["frame"].texture = ItemSlot.frame_texture(rarity)
	_page["icon"].texture = ItemDatabase.icon(item_id)
	_page["name"].text = ItemDatabase.item_name(item_id)
	_page["name"].add_theme_color_override("font_color", _rarity_ink(rarity))
	_page["kind"].text = "%s %s" % [rarity.capitalize(), ItemDatabase.category_name(item_id).to_lower()]
	_page["kind"].add_theme_color_override("font_color", _rarity_ink(rarity))
	var own := ItemDatabase.description(item_id)
	var set_lore: String = ItemDatabase.set_info(set_id).get("description", "")
	_page["text"].text = "\"%s\"" % own if own != "" else ("\"%s\"" % set_lore if set_lore != "" else "")
	_page["lore"].text = set_lore if own != "" and set_lore != "" else ""
	_page["set"].text = _set_line(set_id)

func _set_line(set_id: String) -> String:
	if set_id == "":
		return ""
	var owned := PlayerInventory.owned_set_pieces(set_id)
	var line := "%s set: %d/%d armour pieces" % [ItemDatabase.set_title(set_id), owned, ItemDatabase.FULL_SET_SLOTS.size()]
	if not ItemDatabase.set_bonus(set_id).is_empty():
		line += "\nSet bonus " + ("ready: wear all five" if owned == ItemDatabase.FULL_SET_SLOTS.size() else "when all five are worn")
	return line

# ---------------------------------------------------------------- showing the storage

func refresh() -> void:
	var storage := PlayerInventory.storage
	_count.text = "%d / %d" % [storage.size() - storage.count(""), storage.size()]
	for i in TABS.size():
		var n := 0
		for id in storage:
			if id != "" and _in_tab(id, i) and _found(id):
				n += 1
		_tab_counts[i].text = str(n)
		var strip: Control = _tabs[i].get_meta("strip")
		var chosen := i == _tab
		strip.position.x = TAB_SHIFT if chosen else 0
		strip.get_meta("paper").texture = Parchment.pixel_texture(MENU_DIR + "ScrollPaper.png" if chosen else UI_DIR + "TabPaperDim.png")
	var layout := _layout()
	var key := var_to_str(layout)
	if key == _shown_key:
		for cell in _slots:
			cell.refresh()
		return
	_shown_key = key
	var scroll_at := _scroll.scroll_vertical
	for child in _list.get_children():
		child.queue_free()
	_slots.clear()
	for section in layout:
		if section["title"] != "":
			_list.add_child(_section_header(section["title"]))
		var grid := GridContainer.new()
		grid.columns = PlayerInventory.STORAGE_COLUMNS
		grid.add_theme_constant_override("h_separation", CELL_GAP)
		grid.add_theme_constant_override("v_separation", CELL_GAP)
		for i in section["cells"]:
			var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.STORAGE, i))
			cell.quick_action = PlayerInventory.equip_from
			cell.quick_hint = "Right-click to equip" if ItemDatabase.item_slot(PlayerInventory.storage[i]) != "" else ""
			grid.add_child(cell)
			cell.refresh()
			_slots.append(cell)
		_list.add_child(grid)
	if layout.is_empty():
		var none := InventoryPanel._label("Nothing here yet.", InventoryPanel.COLOR_DIM, 14)
		_list.add_child(none)
	_scroll.set_deferred("scroll_vertical", scroll_at)

# What to show: sections of {title, cells (storage indices)}.
func _layout() -> Array:
	var storage := PlayerInventory.storage
	var everything := _tab == 0 and _search == ""
	var matches: Array[int] = []
	for i in storage.size():
		if storage[i] != "" and _in_tab(storage[i], _tab) and _found(storage[i]):
			matches.append(i)
	if _set_view:
		var by_set := {}
		for i in matches:
			var set_id: String = ItemDatabase.get_item(storage[i]).get("set", "")
			if not by_set.has(set_id):
				by_set[set_id] = []
			by_set[set_id].append(i)
		var ids: Array = by_set.keys()
		ids.sort_custom(func(a: String, b: String) -> bool:
			return PlayerInventory._before(_set_order(a), _set_order(b)))
		var sections := []
		for set_id in ids:
			sections.append({"title": set_id if set_id != "" else "-", "cells": by_set[set_id]})
		return sections
	if everything:
		return [{"title": "", "cells": range(storage.size())}]
	# the matches, then free cells to the end of their row and one more row
	var cells: Array = matches.duplicate()
	var columns := PlayerInventory.STORAGE_COLUMNS
	var want := (ceili(float(cells.size()) / columns) + 1) * columns
	for i in storage.size():
		if cells.size() >= want:
			break
		if storage[i] == "":
			cells.append(i)
	return [{"title": "", "cells": cells}]

# Sets rarest first, then by name; items without a set last.
func _set_order(set_id: String) -> Array:
	if set_id == "":
		return [1, 0, ""]
	return [0, -ItemDatabase.RARITIES.find(ItemDatabase.set_info(set_id).get("rarity", "common")), set_id]

func _section_header(set_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if set_id == "-":
		row.add_child(InventoryPanel._label("No set", InventoryPanel.COLOR_TEXT, 14))
		return row
	var rarity: String = ItemDatabase.set_info(set_id).get("rarity", "common")
	var title := InventoryPanel._label(ItemDatabase.set_title(set_id), ItemSlot.RARITY_COLORS[rarity], 14)
	row.add_child(title)
	var owned := PlayerInventory.owned_set_pieces(set_id)
	var full := ItemDatabase.FULL_SET_SLOTS.size()
	row.add_child(InventoryPanel._label("%d/%d" % [owned, full], InventoryPanel.COLOR_DIM, 12))
	if not ItemDatabase.set_bonus(set_id).is_empty():
		var bonus := InventoryPanel._label("bonus ready" if owned == full else "has a set bonus", GOLD if owned == full else InventoryPanel.COLOR_DIM, 12)
		row.add_child(bonus)
	return row

func _in_tab(item_id: String, tab: int) -> bool:
	var holds: Array = TABS[tab]["holds"]
	return holds.is_empty() or holds.has(ItemDatabase.category(item_id))

func _found(item_id: String) -> bool:
	return _search == "" or ItemDatabase.item_name(item_id).to_lower().contains(_search)

func _fade_in() -> void:
	_list.modulate.a = 0.0
	create_tween().tween_property(_list, "modulate:a", 1.0, 0.15)

func _tool_button(text: String, icon_name: String, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = Parchment.pixel_texture(UI_DIR + icon_name + ".png")
	button.tooltip_text = tip
	Parchment.button_look(button)
	return button

# Rarity colours are made for dark slots; on parchment the same hue is inked deep
# and strong (common stays a plain grey ink).
static func _rarity_ink(rarity: String) -> Color:
	var light: Color = ItemSlot.RARITY_COLORS[rarity]
	return Color.from_hsv(light.h, minf(1.0, light.s * 1.8 + 0.25) if rarity != "common" else light.s, 0.42)

## The grid's scroll area: anything dropped on it (not on a cell) goes into storage.
class DropArea extends ScrollContainer:
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("inventory_from") and data["inventory_from"]["where"] != PlayerInventory.STORAGE

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var item := PlayerInventory.get_at(data["inventory_from"])
		if PlayerInventory.send_to(data["inventory_from"], PlayerInventory.STORAGE):
			ItemSounds.play_item(self, item)
