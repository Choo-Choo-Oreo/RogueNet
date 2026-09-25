class_name ItemSlot
extends Panel

## One cell of the inventory: an equipment slot, a bag cell or a storage cell.
## It shows whatever PlayerInventory holds at `at`. Items move by dragging one
## slot onto another (Godot's built-in drag and drop: _get_drag_data /
## _can_drop_data / _drop_data), or by right-click / double-click, which calls
## `quick_action` -- the panel that owns the slot decides what that does.
## Ctrl+click locks a bag or storage item (PlayerInventory.toggle_lock).
##
## The frame shows the item's rarity (resources/gfx/ui/storage/frame_<rarity>.png).
## Epic and legendary items float gently and give off sparks, legendary frames
## pulse. Picking up and putting down plays the item's material (ItemSounds) and
## the icon squashes as it lands, harder for heavy things. Hovering an item sends
## it to anything in the "item_details" group (the storage's lore page).

const SIZE := 40
const ICON_BOX := 32
## Screen pixels per art pixel for the frame and badges (the frames are 20x20).
const PX := 2
const UI_DIR := "res://resources/gfx/ui/storage/"

const COLOR_HOVER := Color("#d8c690")
const COLOR_FITS := Color("#58a15a")
const COLOR_REFUSES := Color("#a14a4a")
## Kept for the panels that match their frames to the slots.
const COLOR_BG := Color("#15131b")
const COLOR_BORDER := Color("#2e2938")
## Text colour per rarity, the light edge of each frame.
const RARITY_COLORS := {
	"common": Color("#b4aec4"), "uncommon": Color("#96de78"), "rare": Color("#8cc4ff"),
	"epic": Color("#de98ff"), "legendary": Color("#ffeca0"),
}
## From this rarity up (ItemDatabase.RARITIES index) an icon floats and sparks.
const ANIMATED_RANK := 3

var at: Dictionary
var placeholder: Texture2D
var quick_action: Callable
var quick_hint := ""

var _frame := TextureRect.new()
var _icon := TextureRect.new()
var _count := Label.new()
var _lock := TextureRect.new()
var _outline := Panel.new()
var _outline_style := StyleBoxFlat.new()
var _sparks: CPUParticles2D
var _hover := false
var _drag_color := Color.TRANSPARENT
var _shown := "__none__"
var _icon_home := Vector2.ZERO
var _time := randf() * TAU
var _rank := 0

static var _frames: Dictionary = {}

func _init(place: Dictionary, empty_icon: Texture2D = null) -> void:
	at = place
	placeholder = empty_icon
	custom_minimum_size = Vector2(SIZE, SIZE)
	clip_contents = true
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for rect in [_frame, _icon, _lock]:
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	add_child(_icon)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_color", Color("#f6e8c4"))
	_count.add_theme_color_override("font_outline_color", Color("#140f18"))
	_count.add_theme_constant_override("outline_size", 4)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.position = Vector2(SIZE - 26, SIZE - 19)
	_count.size = Vector2(22, 16)
	add_child(_count)
	_lock.texture = load(UI_DIR + "lock.png")
	_lock.size = _lock.texture.get_size() * PX
	_lock.position = Vector2(3, 3)
	add_child(_lock)
	_outline_style.draw_center = false
	_outline_style.set_border_width_all(2)
	_outline.add_theme_stylebox_override("panel", _outline_style)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_outline)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	set_process(false)
	_update_border()

static func frame_texture(rarity: String) -> Texture2D:
	if not _frames.has(rarity):
		_frames[rarity] = load(UI_DIR + "frame_%s.png" % rarity)
	return _frames[rarity]

func _set_hover(on: bool) -> void:
	_hover = on
	_update_border()
	if on and item_id() != "":
		get_tree().call_group("item_details", "show_item", item_id())

func item_id() -> String:
	return PlayerInventory.get_at(at)

func refresh() -> void:
	var item := item_id()
	var count := PlayerInventory.get_count(at)
	_count.text = str(count) if count > 1 else ""
	_lock.visible = PlayerInventory.is_locked(at)
	tooltip_text = _tooltip(item)
	if item == _shown:
		return
	_shown = item
	_rank = ItemDatabase.rarity_rank(item) if item != "" else 0
	_frame.texture = frame_texture(ItemDatabase.RARITIES[_rank])
	_frame.modulate = Color.WHITE if item != "" else Color(1, 1, 1, 0.55)
	var texture := ItemDatabase.icon(item) if item != "" else placeholder
	_icon.texture = texture
	_icon.modulate = Color(1, 1, 1, 1) if item != "" else Color(1, 1, 1, 0.16)
	if texture:
		# Biggest whole-number scale that fits the box, so pixels stay square.
		var factor := maxi(1, floori(ICON_BOX / maxf(texture.get_width(), texture.get_height())))
		_icon.size = texture.get_size() * factor
	_icon_home = ((Vector2(SIZE, SIZE) - _icon.size) / 2.0).round()
	_icon.position = _icon_home
	_icon.pivot_offset = Vector2(_icon.size.x / 2.0, _icon.size.y)
	_icon.scale = Vector2.ONE
	_set_animated(item != "" and _rank >= ANIMATED_RANK)

func _tooltip(item: String) -> String:
	if item == "":
		return ItemDatabase.SLOT_NAMES[ItemDatabase.slot_kind(at["key"])] + ": empty" if at["where"] == PlayerInventory.EQUIP else ""
	var data := ItemDatabase.get_item(item)
	var line := "%s %s" % [ItemDatabase.rarity(item).capitalize(), ItemDatabase.category_name(item).to_lower()]
	if data.has("set"):
		line += ", %s set" % ItemDatabase.set_title(data["set"])
	var hints := quick_hint
	if at["where"] != PlayerInventory.EQUIP:
		hints += ("\n" if hints != "" else "") + ("Ctrl+click to unlock" if PlayerInventory.is_locked(at) else "Ctrl+click to lock")
	return "%s\n%s%s" % [data.get("name", item), line, ("\n" + hints) if hints != "" else ""]

func _update_border() -> void:
	if _drag_color != Color.TRANSPARENT:
		_outline_style.border_color = _drag_color
	else:
		_outline_style.border_color = COLOR_HOVER
	_outline.visible = _drag_color != Color.TRANSPARENT or _hover

# ---------------------------------------------------------------- rare items move

func _set_animated(on: bool) -> void:
	set_process(on)
	if _sparks:
		_sparks.queue_free()
		_sparks = null
	if not on:
		_frame.self_modulate = Color.WHITE
		return
	var legendary := _rank >= ItemDatabase.RARITIES.size() - 1
	var color: Color = RARITY_COLORS[ItemDatabase.RARITIES[_rank]]
	_sparks = CPUParticles2D.new()
	_sparks.amount = 5 if legendary else 3
	_sparks.lifetime = 1.4
	_sparks.preprocess = 1.4
	_sparks.position = Vector2(SIZE / 2.0, SIZE - 8)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(12, 4)
	_sparks.direction = Vector2.UP
	_sparks.spread = 15.0
	_sparks.gravity = Vector2(0, -4)
	_sparks.initial_velocity_min = 6.0
	_sparks.initial_velocity_max = 14.0
	_sparks.scale_amount_min = PX
	_sparks.scale_amount_max = PX
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.95))
	fade.set_color(1, Color(color, 0.0))
	_sparks.color_ramp = fade
	add_child(_sparks)
	move_child(_sparks, _icon.get_index())      # behind the icon, over the frame

func _process(delta: float) -> void:
	_time += delta
	# one art pixel up and down, in steps, so the pixels stay on the grid
	_icon.position.y = _icon_home.y + roundf(sin(_time * 1.8)) * PX
	if _rank >= ItemDatabase.RARITIES.size() - 1:
		var glow := 1.0 + 0.18 * (0.5 + 0.5 * sin(_time * 2.6))
		_frame.self_modulate = Color(glow, glow, glow)

# The icon lands: squashes by the item's weight and springs back.
func bump() -> void:
	var w := ItemSounds.weight(item_id())
	_icon.scale = Vector2(1.0 + w, 1.0 - w)
	var tween := create_tween()
	tween.tween_property(_icon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var item := item_id()
	if event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed and item != "" and at["where"] != PlayerInventory.EQUIP:
		PlayerInventory.toggle_lock(at)
		ItemSounds.play(self, ItemSounds.LOCK)
		accept_event()
		return
	var right_click: bool = event.button_index == MOUSE_BUTTON_RIGHT
	var double_click: bool = event.button_index == MOUSE_BUTTON_LEFT and event.double_click
	if (right_click or double_click) and item != "" and quick_action.is_valid():
		ItemSounds.play_item(self, item)
		quick_action.call(at)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item := item_id()
	if item == "":
		return null
	ItemSounds.play_item(self, item)
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = _icon.size
	preview.position = -preview.size / 2.0
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"inventory_from": at}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory_from") and PlayerInventory.can_move(data["inventory_from"], at)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var moving := PlayerInventory.get_at(data["inventory_from"])
	if PlayerInventory.move(data["inventory_from"], at):
		ItemSounds.play_item(self, moving)
		refresh()
		bump()

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
