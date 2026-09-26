class_name ItemDatabase
extends RefCounted

## Every item in game/items/<folder>/<id>.json, loaded once. The filename (minus
## .json) is the item's id, same rule as minions. Gear has a "slot" it goes in, an
## optional set, and "art", the path of its sheets minus the "-<Direction>.png"
## ending; things that aren't worn (potions, materials) have a "type" instead
## (see README.md). Rarity, sound and lore come from the item, else its set.

const ITEMS_DIR := "res://game/items"
## One <set>.json per set: its rarity, sound and lore, and its full-set bonus if it
## has one (see game/sets/README.md).
const SETS_DIR := "res://game/sets"

## The eleven equipment slots, in the order the inventory shows them.
const SLOTS: Array[String] = ["head", "chest", "gloves", "legs", "feet", "neck", "back", "main_hand", "off_hand", "ring_1", "ring_2"]
## An item's "slot" is the kind of slot it goes in. Most slots take the kind of the
## same name; these share one kind, so a ring fits either ring slot.
const SLOT_KINDS := {"ring_1": "ring", "ring_2": "ring"}
## By kind (see slot_kind), so both ring slots are called "Ring".
const SLOT_NAMES := {
	"head": "Head", "chest": "Chest", "gloves": "Gloves", "legs": "Legs", "feet": "Feet",
	"neck": "Neck", "back": "Back", "main_hand": "Main hand", "off_hand": "Off hand", "ring": "Ring",
}
const SET_ORDER: Array[String] = ["heavy_iron", "arcane", "cleric", "necromancer"]
## What an item without a "slot" is. The storage tabs sort by slot kind or by this.
const TYPES: Array[String] = ["potion", "material", "item"]
## How many of one item fit in one bag or storage cell, by type. Gear never stacks.
## An item's own "stack" overrides this.
const STACK_SIZES := {"potion": 10, "material": 50}
## Lowest first. An item's "rarity", else its set's, else "common".
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
## What an item sounds like when picked up or put down (ItemSounds.MATERIALS): its own
## "sound", else by its slot kind here, else its set's, else by its type, else cloth.
const SLOT_SOUNDS := {"neck": "jewel", "ring": "jewel"}
const TYPE_SOUNDS := {"potion": "glass", "material": "stone", "item": "paper"}
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

## Facing left the body is its right-facing art mirrored (flip_h). Held items mirrored
## along with it would change hands, so they don't simply follow (see held_left):
## facing left the main hand is the far hand and the off hand the near one.
const LEFT_SHEETS := {"Right": "Left", "DownRight": "DownLeft", "UpRight": "UpLeft"}
const HELD_SLOTS: Array[String] = ["main_hand", "off_hand"]
## What a held item shows facing left. Down-left and up-left: its plain front and back
## views, unmirrored (each hand is on the same side as facing straight down or up).
## Left: its own "-Left" art when drawn (a shield in the near hand shows its face),
## else its right-facing art mirrored.
const HELD_LEFT := {"Left": "Left", "DownLeft": "Down", "UpLeft": "Up"}

## How a held weapon attacks, from a word in its id (first match wins): the menu battle
## picks its attack by this and CombatSounds its swing sound. An item's own "weapon"
## overrides it, for one whose id doesn't say.
const WEAPON_WORDS := [
	["staff", "staff"], ["wand", "staff"], ["bow", "bow"],
	["sword", "sword"], ["blade", "sword"], ["knife", "knife"], ["fang", "knife"], ["dagger", "knife"],
	["mace", "blunt"], ["club", "blunt"], ["wrench", "blunt"], ["scepter", "blunt"], ["hammer", "blunt"],
	["spear", "spear"], ["trident", "spear"],
]

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
			if slots_for(data.get("slot", "")).is_empty() and not TYPES.has(data.get("type", "")):
				push_error("ItemDatabase: %s has no valid slot or type" % file_name)
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

## The kind of slot the item goes in ("ring" for either ring slot).
static func item_slot(item_id: String) -> String:
	return get_item(item_id).get("slot", "")

## The kind of item an equipment slot takes: "ring" for ring_1 and ring_2, else the slot itself.
static func slot_kind(slot: String) -> String:
	return SLOT_KINDS.get(slot, slot)

## "potion", "material" or "item" for things that aren't worn; "" for gear.
static func item_type(item_id: String) -> String:
	return get_item(item_id).get("type", "")

## Where the item belongs for sorting and the storage tabs: its slot kind for gear
## ("head", "ring"), else its type ("potion").
static func category(item_id: String) -> String:
	var slot := item_slot(item_id)
	return slot if slot != "" else item_type(item_id)

## "Head", "Ring", "Potion": what the item is, for tooltips.
static func category_name(item_id: String) -> String:
	var slot := item_slot(item_id)
	return SLOT_NAMES.get(slot, "") if slot != "" else item_type(item_id).capitalize()

static func stack_size(item_id: String) -> int:
	return int(get_item(item_id).get("stack", STACK_SIZES.get(item_type(item_id), 1)))

static func rarity(item_id: String) -> String:
	var item := get_item(item_id)
	return item.get("rarity", set_info(item.get("set", "")).get("rarity", RARITIES[0]))

## 0 for common up to 4 for legendary.
static func rarity_rank(item_id: String) -> int:
	return maxi(0, RARITIES.find(rarity(item_id)))

static func sound(item_id: String) -> String:
	var item := get_item(item_id)
	if item.has("sound"):
		return item["sound"]
	if SLOT_SOUNDS.has(item.get("slot", "")):
		return SLOT_SOUNDS[item["slot"]]
	return set_info(item.get("set", "")).get("sound", TYPE_SOUNDS.get(item_type(item_id), "cloth"))

## "sword", "knife", "blunt", "spear", "staff" or "bow" for a held weapon (WEAPON_WORDS);
## "" for anything else, and for "".
static func weapon_kind(item_id: String) -> String:
	var item := get_item(item_id)
	if item.has("weapon"):
		return item["weapon"]
	if item.get("slot", "") != "main_hand":
		return ""
	for pair in WEAPON_WORDS:
		if item_id.contains(pair[0]):
			return pair[1]
	return ""

## The item's own flavour text ("" when it has none; its set's lore is set_info()).
static func description(item_id: String) -> String:
	return get_item(item_id).get("description", "")

## A set's game/sets JSON ({} for a set without one, or for "").
static func set_info(set_id: String) -> Dictionary:
	_load()
	return _sets.get(set_id, {})

## "heavy_iron" -> "Heavy Iron".
static func set_title(set_id: String) -> String:
	return set_id.replace("_", " ").capitalize()

## The equipment slots that take items of `kind`, in SLOTS order.
static func slots_for(kind: String) -> Array[String]:
	var result: Array[String] = []
	for slot in SLOTS:
		if slot_kind(slot) == kind:
			result.append(slot)
	return result

## What wearing this one item adds ({} for most items): a "bonus" block in the same
## format as a set's (game/sets/README.md), e.g. a legendary ring's particles.
static func item_bonus(item_id: String) -> Dictionary:
	return get_item(item_id).get("bonus", {})

## All item ids: the four sets first (each in slot order), then everything else,
## then the things that aren't worn (by type).
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
	return [set_index if set_index >= 0 else SET_ORDER.size(), category_index(item_id), item_id]

## Gear in SLOTS order, then the TYPES, so sorting by slot follows the inventory.
static func category_index(item_id: String) -> int:
	var slots := slots_for(item_slot(item_id))
	if not slots.is_empty():
		return SLOTS.find(slots[0])
	return SLOTS.size() + TYPES.find(item_type(item_id))

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
	return set_info(set_id).get("bonus", {})

static func sheet_path(item_id: String, sheet: String) -> String:
	return "%s-%s.png" % [get_item(item_id).get("art", ""), sheet]

## Paint order for a DRAW_ORDER sheet or a LEFT_SHEETS one. Facing left is the mirrored
## right-facing order with the two hands swapped: the main hand goes where the off hand was.
static func draw_order(sheet: String) -> Array:
	var right = LEFT_SHEETS.find_key(sheet)
	if right == null:
		return DRAW_ORDER[sheet]
	var order: Array = DRAW_ORDER[right].duplicate()
	var main := order.find("main_hand")
	order[order.find("off_hand")] = "main_hand"
	order[main] = "off_hand"
	return order

## Which sheet a held item draws facing `left_sheet` (a LEFT_SHEETS value), and whether mirrored.
static func held_left(item_id: String, left_sheet: String) -> Array:
	var sheet: String = HELD_LEFT[left_sheet]
	if ResourceLoader.exists(sheet_path(item_id, sheet)):
		return [sheet, false]
	return [LEFT_SHEETS.find_key(left_sheet), true]

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
	# own left-facing art (held items only, see HELD_LEFT), as an animation named after its sheet
	var left := sheet_path(item_id, "Left")
	if ResourceLoader.exists(left):
		var texture: Texture2D = load(left)
		frames.add_animation("Left")
		for i in FRAME_COUNT:
			frames.add_frame("Left", frame_texture(texture, i))
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
