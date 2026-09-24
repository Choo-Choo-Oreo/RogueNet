class_name ItemSlot
extends Panel

## One cell of the inventory: an equipment slot, a bag cell or a storage cell.
## It shows whatever PlayerInventory holds at `at`. Items move by dragging one
## slot onto another (Godot's built-in drag and drop: _get_drag_data /
## _can_drop_data / _drop_data), or by right-click / double-click, which calls
## `quick_action` -- the panel that owns the slot decides what that does.

const SIZE := 40
const ICON_BOX := 32

const COLOR_BG := Color("#15131b")
const COLOR_BORDER := Color("#2e2938")
const COLOR_HOVER := Color("#5a5068")
const COLOR_FITS := Color("#58a15a")
const COLOR_REFUSES := Color("#a14a4a")

var at: Dictionary
var placeholder: Texture2D
var quick_action: Callable
var quick_hint := ""

var _icon := TextureRect.new()
var _style := StyleBoxFlat.new()
var _hover := false
var _drag_color := Color.TRANSPARENT

func _init(place: Dictionary, empty_icon: Texture2D = null) -> void:
	at = place
	placeholder = empty_icon
	custom_minimum_size = Vector2(SIZE, SIZE)
	_style.bg_color = COLOR_BG
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", _style)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_icon)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_update_border()

func _set_hover(on: bool) -> void:
	_hover = on
	_update_border()

func item_id() -> String:
	return PlayerInventory.get_at(at)

func refresh() -> void:
	var item := item_id()
	var texture := ItemDatabase.icon(item) if item != "" else placeholder
	_icon.texture = texture
	_icon.modulate = Color(1, 1, 1, 1) if item != "" else Color(1, 1, 1, 0.16)
	if texture:
		# Biggest whole-number scale that fits the box, so pixels stay square.
		var factor := maxi(1, floori(ICON_BOX / maxf(texture.get_width(), texture.get_height())))
		_icon.custom_minimum_size = texture.get_size() * factor
	tooltip_text = _tooltip(item)

func _tooltip(item: String) -> String:
	if item == "":
		return ItemDatabase.SLOT_NAMES[at["key"]] + ": empty" if at["where"] == PlayerInventory.EQUIP else ""
	var data := ItemDatabase.get_item(item)
	var line: String = ItemDatabase.SLOT_NAMES.get(data.get("slot", ""), "")
	if data.has("set"):
		line += ", %s set" % String(data["set"]).replace("_", " ").capitalize()
	return "%s\n%s%s" % [data.get("name", item), line, ("\n" + quick_hint) if quick_hint != "" else ""]

func _update_border() -> void:
	if _drag_color != Color.TRANSPARENT:
		_style.border_color = _drag_color
	else:
		_style.border_color = COLOR_HOVER if _hover else COLOR_BORDER

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var right_click: bool = event.button_index == MOUSE_BUTTON_RIGHT
	var double_click: bool = event.button_index == MOUSE_BUTTON_LEFT and event.double_click
	if (right_click or double_click) and item_id() != "" and quick_action.is_valid():
		quick_action.call(at)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item := item_id()
	if item == "":
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = _icon.custom_minimum_size
	preview.position = -preview.size / 2.0
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"inventory_from": at}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory_from") and PlayerInventory.can_move(data["inventory_from"], at)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	PlayerInventory.move(data["inventory_from"], at)

# While anything is being dragged, equipment slots light up green where it fits and red where it doesn't.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and at["where"] == PlayerInventory.EQUIP:
		var data = get_viewport().gui_get_drag_data()
		if data is Dictionary and data.has("inventory_from"):
			var dragged := PlayerInventory.get_at(data["inventory_from"])
			_drag_color = COLOR_FITS if PlayerInventory.fits(dragged, at) else COLOR_REFUSES
			_update_border()
	elif what == NOTIFICATION_DRAG_END:
		_drag_color = Color.TRANSPARENT
		_update_border()
