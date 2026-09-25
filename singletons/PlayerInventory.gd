extends Node

## This machine's own player: what they wear, their bag, and their storage in
## the town. Only kept in memory for now (there is no character save yet), so it
## starts over on every launch. Other players only ever learn what you wear,
## through NetworkSync.peer_equipment -- bag and storage stay local.
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

var equipped: Dictionary = {}
var bag: Array[String] = []
var storage: Array[String] = []

func _ready() -> void:
	for slot in ItemDatabase.SLOTS:
		equipped[slot] = ""
	bag.resize(BAG_SIZE)
	bag.fill("")
	# For now storage starts with one of every item, so players can try the gear on.
	var ids := ItemDatabase.all_ids()
	var rows := ceili(float(maxi(ids.size(), MIN_STORAGE_SIZE)) / STORAGE_COLUMNS)
	storage.resize(rows * STORAGE_COLUMNS)
	storage.fill("")
	for i in ids.size():
		storage[i] = ids[i]

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
