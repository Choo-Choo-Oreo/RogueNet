class_name ItemDatabase
extends RefCounted

## Every item in game/items/<slot>/<id>.json, loaded once. The filename (minus
## .json) is the item's id, same rule as minions. An item has a name, the slot it
## goes in, an optional set, "art" (the path of its sheets minus the "-<Direction>.png"
## ending) and optional "actions" it gives whoever wears it (see README.md).

const ITEMS_DIR := "res://game/items"

## The nine equipment slots, in the order the inventory shows them.
const SLOTS: Array[String] = ["head", "chest", "gloves", "legs", "feet", "neck", "back", "main_hand", "off_hand"]
const SLOT_NAMES := {
	"head": "Head", "chest": "Chest", "gloves": "Gloves", "legs": "Legs", "feet": "Feet",
	"neck": "Neck", "back": "Back", "main_hand": "Main hand", "off_hand": "Off hand",
}
const SET_ORDER: Array[String] = ["heavy_iron", "arcane", "cleric", "necromancer"]

## The body's animation name -> which gear sheet goes with it. Left-facing
## animations don't exist: the right-facing art is mirrored (flip_h), same as the body.
const ANIMATION_SHEETS := {
	"Front": "Down",
	"FrontRight": "DownRight",
	"Side": "Right",
	"BackRight": "UpRight",
	"Back": "Up",
}
const FRAME_COUNT := 4
const FRAME_SIZE := 16

## Paint order per sheet, bottom first (from the equipment slot map). Slots listed
## before "body" are behind the character when facing that way.
const DRAW_ORDER := {
	"Down": ["back", "body", "head", "chest", "neck", "legs", "feet", "gloves", "off_hand", "main_hand"],
	"DownRight": ["back", "body", "head", "chest", "neck", "legs", "feet", "gloves", "off_hand", "main_hand"],
	"Right": ["off_hand", "back", "body", "head", "chest", "neck", "legs", "feet", "gloves", "main_hand"],
	"UpRight": ["off_hand", "body", "head", "chest", "legs", "feet", "neck", "back", "gloves", "main_hand"],
	"Up": ["main_hand", "off_hand", "body", "head", "chest", "legs", "feet", "neck", "back", "gloves"],
}

static var _items: Dictionary = {}
static var _loaded := false
static var _sprite_frames: Dictionary = {}
static var _icons: Dictionary = {}

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("ItemDatabase: couldn't open " + ITEMS_DIR)
		return
	for folder in dir.get_directories():
		for file_name in DirAccess.get_files_at(ITEMS_DIR + "/" + folder):
			if not file_name.ends_with(".json"):
				continue
			var data := JsonOnloading.load_dict(ITEMS_DIR + "/" + folder + "/" + file_name)
			if not SLOTS.has(data.get("slot", "")):
				push_error("ItemDatabase: %s has no valid slot" % file_name)
				continue
			_items[file_name.get_basename()] = data

static func has_item(item_id: String) -> bool:
	_load()
	return _items.has(item_id)

static func get_item(item_id: String) -> Dictionary:
	_load()
	return _items.get(item_id, {})

static func item_name(item_id: String) -> String:
	return get_item(item_id).get("name", item_id)

static func item_slot(item_id: String) -> String:
	return get_item(item_id).get("slot", "")

## Cosmetic: only changes how you look, it gives no actions.
static func is_cosmetic(item_id: String) -> bool:
	return not get_item(item_id).has("actions")

## The light a wearer gives off: the first item in their hands (main hand, then off hand) with a
## glow_radius, or {} when neither hand holds a light. worn is {slot: item id}, as
## PlayerInventory.worn() and NetworkSync.peer_equipment hold it.
static func light_of(worn: Dictionary) -> Dictionary:
	for slot in ["main_hand", "off_hand"]:
		var item := get_item(str(worn.get(slot, "")))
		if item.has("glow_radius"):
			return item
	return {}

## All item ids: the four sets first (each in slot order), then everything else.
static func all_ids() -> Array[String]:
	_load()
	var ids: Array[String] = []
	ids.assign(_items.keys())
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka := _sort_key(a)
		var kb := _sort_key(b)
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	return ids

static func _sort_key(item_id: String) -> Array:
	var item: Dictionary = _items[item_id]
	var set_index := SET_ORDER.find(item.get("set", ""))
	return [set_index if set_index >= 0 else SET_ORDER.size(), SLOTS.find(item["slot"]), item_id]

static func sheet_path(item_id: String, sheet: String) -> String:
	return "%s-%s.png" % [get_item(item_id).get("art", ""), sheet]

## One frame of one sheet, e.g. the front view in the inventory.
static func frame_texture(sheet_texture: Texture2D, frame: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_texture
	atlas.region = Rect2(frame * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
	return atlas

## Same animation names and frame counts as the Human body, so a gear layer can
## copy the body's animation and frame every tick.
static func sprite_frames(item_id: String) -> SpriteFrames:
	if _sprite_frames.has(item_id):
		return _sprite_frames[item_id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name in ANIMATION_SHEETS:
		var texture: Texture2D = load(sheet_path(item_id, ANIMATION_SHEETS[anim_name]))
		frames.add_animation(anim_name)
		if texture == null:
			continue
		for i in FRAME_COUNT:
			frames.add_frame(anim_name, frame_texture(texture, i))
	_sprite_frames[item_id] = frames
	return frames

## The picture in inventory slots: the item's own "icon" image if it has one,
## else its front view trimmed to the drawn pixels. Worn gloves and boots are
## only a pixel or two each, so those read much better with a drawn icon.
static func icon(item_id: String) -> Texture2D:
	if _icons.has(item_id):
		return _icons[item_id]
	var own_icon: String = get_item(item_id).get("icon", "")
	if own_icon != "":
		_icons[item_id] = load(own_icon)
		return _icons[item_id]
	var texture: Texture2D = load(sheet_path(item_id, "Down"))
	if texture == null:
		return null
	var atlas := frame_texture(texture, 0)
	var used := texture.get_image().get_region(Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE)).get_used_rect()
	if used.size != Vector2i.ZERO:
		atlas.region = Rect2(used)
	_icons[item_id] = atlas
	return atlas
