class_name StoragePanel
extends PanelContainer

## The town storage, in the same wooden panel as the inventory, with parchment
## buttons and a parchment lore page. Items drag between here, the bag and the
## equipment slots; right-click or double-click puts one on, Shift+click sends it to
## the bag, Ctrl+click locks it.
##
## - Tabs along the top (TABS) show one group of items, each with how many it
##   holds. A tab is worked out from the item's slot or type (ItemDatabase.category),
##   nothing is stored for it.
## - Search filters by name as you type (Ctrl+F jumps to it).
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
## Screen pixels per art pixel, as ItemSlot.
const PX := ItemSlot.PX
const MAX_VISIBLE_ROWS := 8
const CELL_GAP := 4
const PAGE_WIDTH := 186
## The page's text sizes: the description, the set's lore, the set line.
const PAGE_FONTS := {"text": 14, "lore": 12, "set": 13}
const PAGE_MIN_FONT := 10

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
var _tab_group := ButtonGroup.new()
var _count: CapacityBar
var _search_box: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer
var _page: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", Parchment.wood_panel())
	add_to_group("item_details")
	_build()
	InventoryPanel.block_clicks(self)
	PlayerInventory.changed.connect(refresh)
	refresh()

# ---------------------------------------------------------------- building

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_count = CapacityBar.new()
	column.add_child(Parchment.heading("Storage", 18, _count))

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
	_search_box = search

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

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	column.add_child(tab_row)
	for i in TABS.size():
		tab_row.add_child(_make_tab(i))

	# grid | lore page
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	_scroll = DropArea.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cell := ItemSlot.SIZE + CELL_GAP
	_scroll.custom_minimum_size = Vector2(PlayerInventory.STORAGE_COLUMNS * cell + 10, MAX_VISIBLE_ROWS * cell)
	_brass_scrollbar(_scroll.get_v_scroll_bar())
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	body.add_child(_build_page())

	column.add_child(InventoryPanel._label("Drag to move  ·  right-click to equip  ·  Shift+click to take  ·  Ctrl+click to lock  ·  Ctrl+F to search", InventoryPanel.COLOR_DIM, 12))

# A parchment tab with the group's icon and how many items it holds; the chosen one
# has a gold edge (one ButtonGroup, so only one is down).
func _make_tab(i: int) -> Button:
	var tab := Button.new()
	tab.toggle_mode = true
	tab.button_group = _tab_group
	tab.button_pressed = i == _tab
	tab.icon = Parchment.pixel_texture(UI_DIR + TABS[i]["icon"] + ".png")
	tab.tooltip_text = TABS[i]["name"]
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Parchment.button_look(tab)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box: StyleBoxFlat = tab.get_theme_stylebox(state)
		box.content_margin_left = 5
		box.content_margin_right = 5
	tab.add_theme_constant_override("h_separation", 4)
	tab.add_theme_font_size_override("font_size", 14)
	tab.pressed.connect(func():
		if _tab != i:
			_tab = i
			ItemSounds.play(self, ItemSounds.TAB)
			refresh()
			_fade_in())
	_tabs.append(tab)
	return tab

# The lore page: a sheet of parchment with the hovered item's picture, rarity,
# set and flavour text.
func _build_page() -> Control:
	var page := PanelContainer.new()
	var style := Parchment.page_style()
	page.add_theme_stylebox_override("panel", style)
	page.custom_minimum_size.x = PAGE_WIDTH
	# The words sit in a holder with no size of its own, so a long lore text can't make
	# the page (and the whole screen) taller; _fit_page shrinks the words instead. Without
	# it the screen jumped about while scrolling, as each item passed under the mouse.
	var holder := Control.new()
	holder.clip_contents = true
	page.add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(column)

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
	_fit_page()

# Long lore: the smaller words, a step at a time, until it all fits on the page.
func _fit_page() -> void:
	var column: Control = _page["name"].get_parent()
	var room: float = column.get_parent().size.y
	var shrink := 0
	while true:
		for key in PAGE_FONTS:
			_page[key].add_theme_font_size_override("font_size", maxi(PAGE_MIN_FONT, PAGE_FONTS[key] - shrink))
		if room <= 0.0 or column.get_combined_minimum_size().y <= room or PAGE_FONTS["text"] - shrink <= PAGE_MIN_FONT:
			return
		shrink += 1

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
	_count.set_count(storage.size() - storage.count(""), storage.size())
	for i in TABS.size():
		var n := 0
		for id in storage:
			if id != "" and _in_tab(id, i) and _found(id):
				n += 1
		_tabs[i].text = str(n)
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
			cell.shift_action = func(at: Dictionary): PlayerInventory.send_to(at, PlayerInventory.BAG)
			cell.shift_hint = "Shift+click to take"
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

# Ctrl+F: straight to the search box.
func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_F:
		_search_box.grab_focus()
		_search_box.select_all()
		get_viewport().set_input_as_handled()

func _in_tab(item_id: String, tab: int) -> bool:
	var holds: Array = TABS[tab]["holds"]
	return holds.is_empty() or holds.has(ItemDatabase.category(item_id))

func _found(item_id: String) -> bool:
	return _search == "" or ItemDatabase.item_name(item_id).to_lower().contains(_search)

func _fade_in() -> void:
	_list.modulate.a = 0.0
	create_tween().tween_property(_list, "modulate:a", 1.0, 0.15)

# A dark groove with a brass handle, to match the frame's corners.
static func _brass_scrollbar(bar: ScrollBar) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("#140d0c")
	groove.content_margin_left = 3
	groove.content_margin_right = 3
	bar.add_theme_stylebox_override("scroll", groove)
	bar.add_theme_stylebox_override("scroll_focus", groove)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var handle := StyleBoxFlat.new()
		handle.bg_color = {"grabber": GOLD.darkened(0.35), "grabber_highlight": GOLD, "grabber_pressed": GOLD.lightened(0.2)}[state]
		handle.border_color = OUTLINE
		handle.set_border_width_all(1)
		bar.add_theme_stylebox_override(state, handle)

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
