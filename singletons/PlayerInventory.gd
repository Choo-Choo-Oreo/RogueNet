extends Node

## This machine's own player: what they wear, their bag, and their storage in
## the town. Filled from the adventurer's save (ProtagonistSave) when one is picked and
## written back by save_adventurer(): on arriving in and leaving the town, and when the
## game window closes. Other players only ever learn what you wear, through
## NetworkSync.peer_equipment -- bag and storage stay local.
##
## A place in the inventory is a Dictionary {"where": EQUIP/BAG/STORAGE, "key": ...}:
## the key is a slot name for EQUIP and an index for BAG and STORAGE. An empty
## place holds "".

signal changed

const EQUIP := "equip"
const BAG := "bag"
const STORAGE := "storage"

const BAG_SIZE := 21
const STORAGE_COLUMNS := 8
const MIN_STORAGE_SIZE := 48

## The adventurer being played (a ProtagonistSave character), picked on the main menu's
## Characters screen; {} until one is picked. Set it through use_adventurer().
var adventurer: Dictionary = {}

var equipped: Dictionary = {}
var bag: Array[String] = []
var storage: Array[String] = []

func _ready() -> void:
	# The adventurer picked last time, so a restart starts where the player left off.
	var saves := ProtagonistSave.new()
	adventurer = saves.load_character(saves.last_id())
	_fill(adventurer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_adventurer()

## Plays `new_adventurer` and fills the inventory from its save; {} empties it. The adventurer being
## left is saved first (a swap in town keeps what it carried) and the new one is remembered.
func use_adventurer(new_adventurer: Dictionary) -> void:
	save_adventurer()
	var saves := ProtagonistSave.new()
	var id: String = new_adventurer.get("id", "")
	# Read back from its file: the caller's copy may predate the save just made (same adventurer).
	var saved := saves.load_character(id) if id != "" else {}
	adventurer = saved if not saved.is_empty() else new_adventurer
	saves.remember(id)
	_fill(adventurer)
	# Not shared: adventurers are picked on the main menu, with no session to share with.
	# The town shares what the adventurer wears on arrival (MainTown._ready).
	changed.emit()

## Writes the inventory into the adventurer's save file. Does nothing with no adventurer picked.
func save_adventurer() -> void:
	if adventurer.is_empty():
		return
	adventurer["equipped"] = worn()
	adventurer["bag"] = bag.duplicate()
	adventurer["storage"] = storage.duplicate()
	if ProtagonistSave.new().save(adventurer) != OK:
		push_warning("Could not save the character %s." % adventurer["name"])

## Item ids no longer in ItemDatabase are dropped, and so is worn gear that no longer
## fits its slot. Storage keeps every saved cell; the bag is always BAG_SIZE.
func _fill(saved: Dictionary) -> void:
	var saved_equipped: Dictionary = saved.get("equipped", {})
	equipped.clear()
	for slot in ItemDatabase.SLOTS:
		var item_id := _known(saved_equipped.get(slot, ""))
		equipped[slot] = item_id if fits(item_id, place(EQUIP, slot)) else ""
	bag = _cells(saved.get("bag", []), BAG_SIZE)
	var saved_storage: Array = saved.get("storage", [])
	var rows := ceili(float(maxi(saved_storage.size(), MIN_STORAGE_SIZE)) / STORAGE_COLUMNS)
	storage = _cells(saved_storage, rows * STORAGE_COLUMNS)

func _cells(saved: Array, size: int) -> Array[String]:
	var cells: Array[String] = []
	cells.resize(size)
	cells.fill("")
	for i in mini(saved.size(), size):
		cells[i] = _known(saved[i])
	return cells

func _known(item_id) -> String:
	return item_id if item_id is String and ItemDatabase.has_item(item_id) else ""

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

func _set_at(at: Dictionary, item_id: String) -> void:
	match at["where"]:
		EQUIP:
			equipped[at["key"]] = item_id
		BAG:
			bag[at["key"]] = item_id
		STORAGE:
			storage[at["key"]] = item_id

## Whether item_id may sit at `at`: anything fits a bag or storage cell, an
## equipment slot only takes items made for it.
func fits(item_id: String, at: Dictionary) -> bool:
	return item_id == "" or at["where"] != EQUIP or ItemDatabase.item_slot(item_id) == at["key"]

## Dragging from `from` onto `to` swaps the two, so both items have to fit where they land.
func can_move(from: Dictionary, to: Dictionary) -> bool:
	var item_id := get_at(from)
	return item_id != "" and fits(item_id, to) and fits(get_at(to), from)

func move(from: Dictionary, to: Dictionary) -> bool:
	if from == to or not can_move(from, to):
		return false
	var item_id := get_at(from)
	_set_at(from, get_at(to))
	_set_at(to, item_id)
	_after_change(from["where"] == EQUIP or to["where"] == EQUIP)
	return true

## Puts the item at `at` on, and whatever was worn in that slot goes where it came from.
func equip_from(at: Dictionary) -> bool:
	var item_id := get_at(at)
	if item_id == "" or at["where"] == EQUIP:
		return false
	return move(at, place(EQUIP, ItemDatabase.item_slot(item_id)))

## Moves the item at `at` into the first free cell of `where` (BAG or STORAGE).
func send_to(at: Dictionary, where: String) -> bool:
	var cells: Array[String] = bag if where == BAG else storage
	var free := cells.find("")
	if free < 0 or get_at(at) == "":
		return false
	return move(at, place(where, free))

## Puts each of item_ids the adventurer does not own yet into storage, adding whole rows when
## it is full. Returns how many were added. For the editor-only debug buttons (StoragePanel).
func add_to_storage(item_ids: Array[String]) -> int:
	var owned := worn().values() + bag + storage
	var added := 0
	for item_id in item_ids:
		if owned.has(item_id):
			continue
		if not storage.has(""):
			for i in STORAGE_COLUMNS:
				storage.append("")
		storage[storage.find("")] = item_id
		added += 1
	if added > 0:
		_after_change(false)
	return added

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
