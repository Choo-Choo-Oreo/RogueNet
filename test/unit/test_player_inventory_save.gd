extends GutTest

## PlayerInventory filled from an adventurer's save and written back (test save folder).

const TEST_ROOT := "user://test_inventory_characters"
const ROBE := "apprentice_robe"
const PACK := "backpack"
var _real_root := ""
var adventurers := ProtagonistSave.new()

func before_each() -> void:
	_real_root = CharacterSave.root
	CharacterSave.root = TEST_ROOT

func after_each() -> void:
	PlayerInventory.use_adventurer({})
	DirAccess.remove_absolute(TEST_ROOT.path_join(CharacterSave.LAST_FILE))
	var folder := TEST_ROOT.path_join("protagonist")
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
	CharacterSave.root = _real_root

func test_items_come_back_after_saving() -> void:
	var adventurer := adventurers.create("Keeper")
	PlayerInventory.use_adventurer(adventurer)
	PlayerInventory.equipped[ItemDatabase.item_slot(ROBE)] = ROBE
	PlayerInventory.bag[0] = PACK
	PlayerInventory.storage[5] = PACK
	PlayerInventory.save_adventurer()

	PlayerInventory.use_adventurer(adventurers.load_character(adventurer["id"]))
	assert_eq(PlayerInventory.equipped[ItemDatabase.item_slot(ROBE)], ROBE)
	assert_eq(PlayerInventory.bag[0], PACK)
	assert_eq(PlayerInventory.storage[5], PACK)

func test_unknown_items_and_wrong_slot_gear_are_dropped() -> void:
	var adventurer := adventurers.create("Lost")
	adventurer["equipped"] = {ItemDatabase.item_slot(PACK): ROBE}
	adventurer["bag"] = ["no_such_item", PACK, 7]
	PlayerInventory.use_adventurer(adventurer)
	assert_eq(PlayerInventory.equipped[ItemDatabase.item_slot(PACK)], "")
	assert_eq(PlayerInventory.bag.slice(0, 3), ["", PACK, ""])
	assert_eq(PlayerInventory.bag.size(), PlayerInventory.BAG_SIZE)

func test_storage_keeps_every_saved_cell() -> void:
	var adventurer := adventurers.create("Hoarder")
	var cells := []
	cells.resize(PlayerInventory.MIN_STORAGE_SIZE + 3)
	cells.fill("")
	cells[-1] = PACK
	adventurer["storage"] = cells
	PlayerInventory.use_adventurer(adventurer)
	assert_eq(PlayerInventory.storage.size() % PlayerInventory.STORAGE_COLUMNS, 0)
	assert_eq(PlayerInventory.storage[cells.size() - 1], PACK)

func test_no_adventurer_means_empty_and_nothing_saved() -> void:
	PlayerInventory.use_adventurer({})
	PlayerInventory.save_adventurer()
	assert_eq(PlayerInventory.storage.count(""), PlayerInventory.storage.size())
	assert_eq(adventurers.list().size(), 0)

func test_populate_skips_owned_items_and_grows_storage() -> void:
	PlayerInventory.use_adventurer(adventurers.create("Collector"))
	PlayerInventory.bag[0] = PACK
	var all := ItemDatabase.all_ids()
	var owned := all.filter(func(item_id): return PlayerInventory.bag.has(item_id) or PlayerInventory.worn().values().has(item_id))
	var added := PlayerInventory.add_to_storage(all)
	assert_eq(added, all.size() - owned.size(), "what is worn or in the bag (starter gear and kits, the backpack) is not added again")
	assert_false(PlayerInventory.storage.has(PACK))
	assert_eq(PlayerInventory.storage.size() % PlayerInventory.STORAGE_COLUMNS, 0)
	assert_eq(PlayerInventory.add_to_storage(all), 0, "a second press adds nothing")

func test_new_adventurer_gets_every_starter_kit_in_the_bag() -> void:
	var kits: Dictionary = JsonOnloading.load_dict(ProtagonistSave.STARTER_KITS_PATH)["bag"]
	assert_eq(kits.size(), 3)
	PlayerInventory.use_adventurer(adventurers.create("Rookie"))
	for kit in kits.values():
		for item_id in kit:
			assert_true(ItemDatabase.has_item(item_id), "%s is a real item" % item_id)
			assert_true(PlayerInventory.bag.has(item_id), "%s made it into the bag" % item_id)
		var gives_action: bool = kit.any(func(item_id): return not ItemDatabase.is_cosmetic(item_id))
		assert_true(gives_action, "every kit has something to attack with")

func test_new_adventurer_wears_the_starter_gear() -> void:
	PlayerInventory.use_adventurer(adventurers.create("Rookie"))
	var worn := PlayerInventory.worn()
	for item_id in JsonOnloading.load_dict(ProtagonistSave.STARTER_KITS_PATH)["worn"]:
		assert_eq(worn.get(ItemDatabase.item_slot(item_id)), item_id, "%s is worn in its slot" % item_id)
	assert_false(ItemDatabase.light_of(worn).is_empty(), "a new adventurer starts with light")

func test_the_last_adventurer_played_is_remembered_until_deleted() -> void:
	var adventurer := adventurers.create("Regular")
	adventurers.save(adventurer)
	PlayerInventory.use_adventurer(adventurer)
	assert_eq(adventurers.last_id(), adventurer["id"], "remembered for the next start")
	PlayerInventory.use_adventurer({})
	adventurers.remember(adventurer["id"])
	adventurers.delete(adventurer["id"])
	assert_eq(adventurers.last_id(), "", "a deleted adventurer is not remembered")
