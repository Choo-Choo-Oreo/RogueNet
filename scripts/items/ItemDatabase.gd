class_name ItemDatabase
extends RefCounted

## Every item in game/items/<slot>/<id>.json, loaded once. The filename (minus
## .json) is the item's id, same rule as minions. Items are only cosmetic gear
## for now: a name, the slot it goes in, an optional set, and "art", the path
## of its sheets minus the "-<Direction>.png" ending (see README.md).

const ITEMS_DIR := "res://game/items"
## One <set>.json per set that has a full-set bonus (see game/sets/README.md).
const SETS_DIR := "res://game/sets"

## The nine equipment slots, in the order the inventory shows them.
const SLOTS: Array[String] = ["head", "chest", "gloves", "legs", "feet", "neck", "back", "main_hand", "off_hand"]
const SLOT_NAMES := {
	"head": "Head", "chest": "Chest", "gloves": "Gloves", "legs": "Legs", "feet": "Feet",
	"neck": "Neck", "back": "Back", "main_hand": "Main hand", "off_hand": "Off hand",
}
const SET_ORDER: Array[String] = ["heavy_iron", "arcane", "cleric", "necromancer"]
## The slots a full set has to fill. Held items and the amulet don't count, so
## any weapon can be used with a set's bonus.
const FULL_SET_SLOTS: Array[String] = ["head", "chest", "gloves", "legs", "feet"]

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
static var _sets: Dictionary = {}   # set id -> its game/sets JSON
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
	for file_name in DirAccess.get_files_at(SETS_DIR):
		if file_name.ends_with(".json"):
			_sets[file_name.get_basename()] = JsonOnloading.load_dict(SETS_DIR + "/" + file_name)

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

## The set that fills every FULL_SET_SLOTS slot of worn (slot -> item id), or ""
## when one is empty or they come from different sets.
static func full_set(worn: Dictionary) -> String:
	var set_id := ""
	for slot in FULL_SET_SLOTS:
		var item_set: String = get_item(worn.get(slot, "")).get("set", "")
		if item_set == "" or (set_id != "" and item_set != set_id):
			return ""
		set_id = item_set
	return set_id

## What wearing the full set adds ({} for a set without a bonus).
static func set_bonus(set_id: String) -> Dictionary:
	_load()
	return _sets.get(set_id, {}).get("bonus", {})

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
