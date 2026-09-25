extends Node

## This machine's own player: what they wear, their bag, and their storage in
## the town. Only kept in memory for now (there is no character save yet), so it
## starts over on every launch. Other players only ever learn what you wear,
## through NetworkSync.peer_equipment -- bag and storage stay local.
##
## A place in the inventory is a Dictionary {"where": EQUIP/BAG/STORAGE, "key": ...}:
## the key is a slot name for EQUIP and an index for BAG and STORAGE. An empty
## place holds "".
##
## Bag and storage cells also carry a little extra (_extra): how many are stacked
## there (potions and materials stack, ItemDatabase.stack_size), whether the player
## locked it (sorting and "Store all" leave locked cells alone), and when it arrived
## (for "newest first"). The extra always moves with the item.

signal changed

const EQUIP := "equip"
const BAG := "bag"
const STORAGE := "storage"

const BAG_SIZE := 21
const STORAGE_COLUMNS := 8
const MIN_STORAGE_SIZE := 48
## How many of each stackable item the storage starts with, for trying things out.
const STARTING_STACK := 5

## The ways sort_storage() can order the storage.
const SORTS: Array[String] = ["set", "slot", "rarity", "newest", "name"]

var equipped: Dictionary = {}
var bag: Array[String] = []
var storage: Array[String] = []

## BAG / STORAGE -> one Dictionary per cell: {"count", "locked", "stamp"}, {} when empty.
var _extra := {BAG: [], STORAGE: []}
var _next_stamp := 0

func _ready() -> void:
	for slot in ItemDatabase.SLOTS:
		equipped[slot] = ""
	bag.resize(BAG_SIZE)
	bag.fill("")
	# For now storage starts with one of every item (a few of anything that stacks),
	# so players can try the gear on.
	var ids := ItemDatabase.all_ids()
	var rows := ceili(float(maxi(ids.size(), MIN_STORAGE_SIZE)) / STORAGE_COLUMNS)
	storage.resize(rows * STORAGE_COLUMNS)
	storage.fill("")
	for id in ids:
		add_item(id, STARTING_STACK if ItemDatabase.stack_size(id) > 1 else 1, STORAGE)

func place(where: String, key) -> Dictionary:
	return {"where": where, "key": key}

func get_at(at: Dictionary) -> String:
	match at["where"]:
		EQUIP:
			return equipped.get(at["key"], "")
		BAG:
			return bag[at["key"]]
		STORAGE:
			return storage[at["key"]]
	return ""

## How many of the item are at `at` (0 when empty; a worn item is always 1).
func get_count(at: Dictionary) -> int:
	if get_at(at) == "":
		return 0
	return maxi(1, int(_extra_at(at).get("count", 1)))

func is_locked(at: Dictionary) -> bool:
	return get_at(at) != "" and _extra_at(at).get("locked", false)

## Locks or unlocks the item at `at` (bag and storage only). Returns the new state.
func toggle_lock(at: Dictionary) -> bool:
	if at["where"] == EQUIP or get_at(at) == "":
		return false
	var extra := _extra_at(at)
	extra["locked"] = not extra.get("locked", false)
	_set_extra(at, extra)
	changed.emit()
	return extra["locked"]

func _cells(where: String) -> Array[String]:
	return bag if where == BAG else storage

# The extras keep up with bag / storage even when something (a test) resized them directly.
func _extras(where: String) -> Array:
	var list: Array = _extra[where]
	var size := _cells(where).size()
	while list.size() < size:
		list.append({})
	return list

# Each extra remembers its item, so one left behind by a direct write to bag or
# storage never sticks to a different item.
func _extra_at(at: Dictionary) -> Dictionary:
	if at["where"] == EQUIP:
		return {}
	var extra: Dictionary = _extras(at["where"])[at["key"]]
	return extra if extra.get("id", "") == get_at(at) else {}

func _set_extra(at: Dictionary, extra: Dictionary) -> void:
	if at["where"] != EQUIP:
		extra["id"] = get_at(at)
		_extras(at["where"])[at["key"]] = extra

func _set_at(at: Dictionary, item_id: String, extra: Dictionary = {}) -> void:
	match at["where"]:
		EQUIP:
			equipped[at["key"]] = item_id
		BAG:
			bag[at["key"]] = item_id
		STORAGE:
			storage[at["key"]] = item_id
	_set_extra(at, extra if item_id != "" else {})

## Whether item_id may sit at `at`: anything fits a bag or storage cell, an
## equipment slot only takes items made for its kind (a ring fits either ring slot).
func fits(item_id: String, at: Dictionary) -> bool:
	return item_id == "" or at["where"] != EQUIP or ItemDatabase.item_slot(item_id) == ItemDatabase.slot_kind(at["key"])

## Dragging from `from` onto `to` swaps the two, so both items have to fit where they land.
func can_move(from: Dictionary, to: Dictionary) -> bool:
	var item_id := get_at(from)
	return item_id != "" and fits(item_id, to) and fits(get_at(to), from)

## Moves the item at `from` onto `to`. Onto the same stackable item it tops that
## stack up (whatever doesn't fit stays behind); otherwise the two swap.
func move(from: Dictionary, to: Dictionary) -> bool:
	if from == to or not can_move(from, to):
		return false
	var item_id := get_at(from)
	if get_at(to) == item_id and _room(to) > 0:
		_pour(from, to)
		_after_change(false)
		return true
	var extra := _extra_at(from)
	_set_at(from, get_at(to), _extra_at(to))
	_set_at(to, item_id, extra)
	_after_change(from["where"] == EQUIP or to["where"] == EQUIP)
	return true

# How many more of its item the stack at `at` can take.
func _room(at: Dictionary) -> int:
	return ItemDatabase.stack_size(get_at(at)) - get_count(at) if at["where"] != EQUIP else 0

# Moves as many as fit from one stack onto another stack of the same item.
func _pour(from: Dictionary, to: Dictionary) -> void:
	var amount := mini(get_count(from), _room(to))
	var into := _extra_at(to)
	into["count"] = get_count(to) + amount
	_set_extra(to, into)
	var left := get_count(from) - amount
	if left <= 0:
		_set_at(from, "")
	else:
		var extra := _extra_at(from)
		extra["count"] = left
		_set_extra(from, extra)

## Puts the item at `at` on, and whatever was worn in that slot goes where it came from.
## With two slots for its kind (rings) it takes the first empty one, else swaps with the first.
func equip_from(at: Dictionary) -> bool:
	var item_id := get_at(at)
	if item_id == "" or at["where"] == EQUIP:
		return false
	var slots := ItemDatabase.slots_for(ItemDatabase.item_slot(item_id))
	if slots.is_empty():
		return false
	var slot := slots[0]
	for free in slots:
		if equipped.get(free, "") == "":
			slot = free
			break
	return move(at, place(EQUIP, slot))

## Moves the item at `at` into `where` (BAG or STORAGE): onto stacks of the same
## item that have room first, then into the first free cell. False when nothing moved.
func send_to(at: Dictionary, where: String) -> bool:
	var item_id := get_at(at)
	if item_id == "" or at["where"] == where:
		return false
	var cells := _cells(where)
	var before := get_count(at)
	for i in cells.size():
		if cells[i] == item_id and get_at(at) == item_id:
			var to := place(where, i)
			if _room(to) > 0:
				_pour(at, to)
	if get_at(at) == "":
		_after_change(at["where"] == EQUIP)
		return true
	var free := cells.find("")
	if free < 0:
		if get_count(at) != before:
			_after_change(false)
			return true
		return false
	return move(at, place(where, free))

## Adds `count` of item_id to `where` (BAG or STORAGE) as a new arrival: onto its
## stacks first, then into free cells. Returns how many didn't fit (0 = all of them did).
func add_item(item_id: String, count: int = 1, where: String = BAG) -> int:
	var cells := _cells(where)
	var left := count
	var stack := ItemDatabase.stack_size(item_id)
	for i in cells.size():
		if left <= 0:
			break
		if cells[i] == item_id and _room(place(where, i)) > 0:
			var at := place(where, i)
			var amount := mini(left, _room(at))
			var extra := _extra_at(at)
			extra["count"] = get_count(at) + amount
			_set_extra(at, extra)
			left -= amount
	while left > 0:
		var free := cells.find("")
		if free < 0:
			break
		var amount := mini(left, stack)
		_set_at(place(where, free), item_id, {"count": amount, "stamp": _next_stamp})
		left -= amount
	_next_stamp += 1
	if left != count:
		changed.emit()
	return left

## Every unlocked item in the bag goes into storage. Returns how many cells emptied.
func store_all() -> int:
	var moved := 0
	for i in bag.size():
		var at := place(BAG, i)
		if bag[i] != "" and not is_locked(at) and send_to(at, STORAGE) and bag[i] == "":
			moved += 1
	return moved

## Tidies the storage (by: one of SORTS). Stacks of the same item merge; locked
## cells don't move and nothing moves into them.
func sort_storage(by: String) -> void:
	var free_cells: Array[int] = []
	var totals := {}           # item id -> [count, newest stamp]
	for i in storage.size():
		var at := place(STORAGE, i)
		if is_locked(at):
			continue
		free_cells.append(i)
		if storage[i] == "":
			continue
		var total: Array = totals.get(storage[i], [0, -1])
		totals[storage[i]] = [total[0] + get_count(at), maxi(total[1], int(_extra_at(at).get("stamp", 0)))]
		_set_at(at, "")
	var ids: Array = totals.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _before(_sort_key(a, by, totals[a][1]), _sort_key(b, by, totals[b][1])))
	var next := 0
	for id in ids:
		var left: int = totals[id][0]
		while left > 0 and next < free_cells.size():
			var amount := mini(left, ItemDatabase.stack_size(id))
			_set_at(place(STORAGE, free_cells[next]), id, {"count": amount, "stamp": totals[id][1]})
			left -= amount
			next += 1
	changed.emit()

func _sort_key(item_id: String, by: String, stamp: int) -> Array:
	var set_id: String = ItemDatabase.get_item(item_id).get("set", "")
	var no_set := 1 if set_id == "" else 0          # items without a set go last
	var by_set := [no_set, -ItemDatabase.rarity_rank(item_id), set_id]
	match by:
		"slot":
			return [ItemDatabase.category_index(item_id), -ItemDatabase.rarity_rank(item_id), item_id]
		"rarity":
			return [-ItemDatabase.rarity_rank(item_id), no_set, set_id, ItemDatabase.category_index(item_id), item_id]
		"newest":
			return [-stamp] + by_set + [ItemDatabase.category_index(item_id), item_id]
		"name":
			return [ItemDatabase.item_name(item_id).to_lower(), item_id]
	return by_set + [ItemDatabase.category_index(item_id), item_id]

# Compares two sort keys element by element.
func _before(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return a.size() < b.size()

## How many pieces of set_id's FULL_SET_SLOTS the player has anywhere (worn, bag
## or storage), each slot counted once.
func owned_set_pieces(set_id: String) -> int:
	var have := {}
	for list in [equipped.values(), bag, storage]:
		for id in list:
			if id != "" and ItemDatabase.get_item(id).get("set", "") == set_id:
				have[ItemDatabase.item_slot(id)] = true
	var count := 0
	for slot in ItemDatabase.FULL_SET_SLOTS:
		if have.has(slot):
			count += 1
	return count

## Slot -> item id for the slots that hold something, the form NetworkSync shares.
func worn() -> Dictionary:
	var result := {}
	for slot in equipped:
		if equipped[slot] != "":
			result[slot] = equipped[slot]
	return result

func _after_change(equipment_changed: bool) -> void:
	changed.emit()
	if equipment_changed:
		NetworkSync.share_equipment(worn())
