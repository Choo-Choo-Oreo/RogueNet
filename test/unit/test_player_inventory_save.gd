extends GutTest

## PlayerInventory filled from a hero's save and written back (test save folder).

const TEST_ROOT := "user://test_inventory_characters"
const ROBE := "apprentice_robe"
const PACK := "backpack"
var _real_root := ""
var heroes := ProtagonistSave.new()

func before_each() -> void:
	_real_root = CharacterSave.root
	CharacterSave.root = TEST_ROOT

func after_each() -> void:
	PlayerInventory.use_hero({})
	DirAccess.remove_absolute(TEST_ROOT.path_join(CharacterSave.LAST_FILE))
	var folder := TEST_ROOT.path_join("protagonist")
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
	CharacterSave.root = _real_root

func test_items_come_back_after_saving() -> void:
	var hero := heroes.create("Keeper")
	PlayerInventory.use_hero(hero)
	PlayerInventory.equipped[ItemDatabase.item_slot(ROBE)] = ROBE
	PlayerInventory.bag[0] = PACK
	PlayerInventory.storage[5] = PACK
	PlayerInventory.save_hero()

	PlayerInventory.use_hero(heroes.load_character(hero["id"]))
	assert_eq(PlayerInventory.equipped[ItemDatabase.item_slot(ROBE)], ROBE)
	assert_eq(PlayerInventory.bag[0], PACK)
	assert_eq(PlayerInventory.storage[5], PACK)

func test_unknown_items_and_wrong_slot_gear_are_dropped() -> void:
	var hero := heroes.create("Lost")
	hero["equipped"] = {ItemDatabase.item_slot(PACK): ROBE}
	hero["bag"] = ["no_such_item", PACK, 7]
	PlayerInventory.use_hero(hero)
	assert_eq(PlayerInventory.equipped[ItemDatabase.item_slot(PACK)], "")
	assert_eq(PlayerInventory.bag.slice(0, 3), ["", PACK, ""])
	assert_eq(PlayerInventory.bag.size(), PlayerInventory.BAG_SIZE)

func test_storage_keeps_every_saved_cell() -> void:
	var hero := heroes.create("Hoarder")
	var cells := []
	cells.resize(PlayerInventory.MIN_STORAGE_SIZE + 3)
	cells.fill("")
	cells[-1] = PACK
	hero["storage"] = cells
	PlayerInventory.use_hero(hero)
	assert_eq(PlayerInventory.storage.size() % PlayerInventory.STORAGE_COLUMNS, 0)
	assert_eq(PlayerInventory.storage[cells.size() - 1], PACK)

func test_no_hero_means_empty_and_nothing_saved() -> void:
	PlayerInventory.use_hero({})
	PlayerInventory.save_hero()
	assert_eq(PlayerInventory.storage.count(""), PlayerInventory.storage.size())
	assert_eq(heroes.list().size(), 0)

func test_populate_skips_owned_items_and_grows_storage() -> void:
	PlayerInventory.use_hero(heroes.create("Collector"))
	PlayerInventory.bag[0] = PACK
	var all := ItemDatabase.all_ids()
	var owned := all.filter(func(item_id): return PlayerInventory.bag.has(item_id))
	var added := PlayerInventory.add_to_storage(all)
	assert_eq(added, all.size() - owned.size(), "what is in the bag (starter kits, the backpack) is not added again")
	assert_false(PlayerInventory.storage.has(PACK))
	assert_eq(PlayerInventory.storage.size() % PlayerInventory.STORAGE_COLUMNS, 0)
	assert_eq(PlayerInventory.add_to_storage(all), 0, "a second press adds nothing")

func test_new_hero_gets_every_starter_kit_in_the_bag() -> void:
	var kits := JsonOnloading.load_dict(ProtagonistSave.STARTER_KITS_PATH)
	assert_eq(kits.size(), 3)
	PlayerInventory.use_hero(heroes.create("Rookie"))
	for kit in kits.values():
		for item_id in kit:
			assert_true(ItemDatabase.has_item(item_id), "%s is a real item" % item_id)
			assert_true(PlayerInventory.bag.has(item_id), "%s made it into the bag" % item_id)
		var gives_action: bool = kit.any(func(item_id): return not ItemDatabase.is_cosmetic(item_id))
		assert_true(gives_action, "every kit has something to attack with")

func test_the_last_hero_played_is_remembered_until_deleted() -> void:
	var hero := heroes.create("Regular")
	heroes.save(hero)
	PlayerInventory.use_hero(hero)
	assert_eq(heroes.last_id(), hero["id"], "remembered for the next start")
	PlayerInventory.use_hero({})
	heroes.remember(hero["id"])
	heroes.delete(hero["id"])
	assert_eq(heroes.last_id(), "", "a deleted hero is not remembered")
