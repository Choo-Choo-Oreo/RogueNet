extends GutTest

## The organised storage: every item lands in a tab, rarity / sound / lore fall
## back from the item to its set, potions and materials stack, locked items stay
## put when sorting and "Store all", and sorting keeps every item.

var _saved_bag: Array[String]
var _saved_storage: Array[String]

func before_each() -> void:
	_saved_bag = PlayerInventory.bag.duplicate()
	_saved_storage = PlayerInventory.storage.duplicate()
	PlayerInventory.bag.fill("")
	PlayerInventory.storage.fill("")

func after_each() -> void:
	PlayerInventory.bag = _saved_bag
	PlayerInventory.storage = _saved_storage

func _bag(i: int) -> Dictionary:
	return PlayerInventory.place(PlayerInventory.BAG, i)

func _store(i: int) -> Dictionary:
	return PlayerInventory.place(PlayerInventory.STORAGE, i)

func _total(item_id: String) -> int:
	var n := 0
	for i in PlayerInventory.storage.size():
		if PlayerInventory.storage[i] == item_id:
			n += PlayerInventory.get_count(_store(i))
	return n

func test_every_item_is_in_a_tab_other_than_all() -> void:
	for id in ItemDatabase.all_ids():
		var found := false
		for tab in StoragePanel.TABS.slice(1):
			if tab["holds"].has(ItemDatabase.category(id)):
				found = true
		assert_true(found, "%s (%s) has no tab" % [id, ItemDatabase.category(id)])

func test_every_rarity_and_sound_is_known() -> void:
	for id in ItemDatabase.all_ids():
		assert_true(ItemDatabase.RARITIES.has(ItemDatabase.rarity(id)), id + " rarity")
		assert_true(ItemSounds.MATERIALS.has(ItemDatabase.sound(id)), id + " sound " + ItemDatabase.sound(id))

func test_rarity_and_sound_come_from_the_set_unless_the_item_says_otherwise() -> void:
	assert_eq(ItemDatabase.rarity("infernal_cuirass"), "legendary", "from the set")
	assert_eq(ItemDatabase.sound("heavy_iron_helm"), "metal", "from the set")
	assert_eq(ItemDatabase.sound("arcane_staff"), "wood", "the item's own")
	assert_eq(ItemDatabase.sound("ruby_ring"), "jewel", "rings sound like jewels")
	assert_eq(ItemDatabase.sound("health_potion"), "glass", "potions by type")
	assert_eq(ItemDatabase.rarity("iron_band_ring"), "common", "no set, no rarity: common")

func test_potions_stack_and_gear_does_not() -> void:
	assert_eq(ItemDatabase.stack_size("health_potion"), 10)
	assert_eq(ItemDatabase.stack_size("heavy_iron_helm"), 1)
	assert_eq(PlayerInventory.add_item("health_potion", 14, PlayerInventory.STORAGE), 0)
	assert_eq(PlayerInventory.get_count(_store(0)), 10)
	assert_eq(PlayerInventory.get_count(_store(1)), 4)
	PlayerInventory.add_item("health_potion", 3, PlayerInventory.STORAGE)
	assert_eq(PlayerInventory.get_count(_store(1)), 7, "new ones top up the open stack")

func test_dragging_a_stack_onto_the_same_item_merges_it() -> void:
	PlayerInventory.add_item("iron_ore", 5, PlayerInventory.BAG)
	PlayerInventory.add_item("iron_ore", 5, PlayerInventory.STORAGE)
	assert_true(PlayerInventory.move(_bag(0), _store(0)))
	assert_eq(PlayerInventory.get_count(_store(0)), 10)
	assert_eq(PlayerInventory.bag[0], "", "the bag stack is used up")

func test_a_potion_can_not_be_worn() -> void:
	PlayerInventory.bag[0] = "mana_potion"
	assert_false(PlayerInventory.equip_from(_bag(0)))
	assert_false(PlayerInventory.fits("mana_potion", PlayerInventory.place(PlayerInventory.EQUIP, "head")))

func test_sorting_keeps_every_item_and_leaves_locked_ones_alone() -> void:
	PlayerInventory.storage[5] = "infernal_cuirass"
	PlayerInventory.storage[2] = "militia_rusty_sword"
	PlayerInventory.storage[9] = "ruby_ring"
	PlayerInventory.add_item("glowcap", 3, PlayerInventory.STORAGE)
	PlayerInventory.toggle_lock(_store(9))
	PlayerInventory.sort_storage("rarity")
	assert_eq(PlayerInventory.storage[9], "ruby_ring", "locked: stays in its cell")
	assert_true(PlayerInventory.is_locked(_store(9)))
	assert_eq(PlayerInventory.storage[0], "infernal_cuirass", "legendary first")
	assert_eq(_total("glowcap"), 3)
	assert_eq(_total("militia_rusty_sword"), 1)

func test_sorting_merges_split_stacks() -> void:
	PlayerInventory.storage[3] = "antidote"
	PlayerInventory.storage[7] = "antidote"
	PlayerInventory.sort_storage("name")
	assert_eq(PlayerInventory.storage[0], "antidote")
	assert_eq(PlayerInventory.get_count(_store(0)), 2)
	assert_eq(PlayerInventory.storage.count("antidote"), 1)

func test_store_all_skips_locked_items() -> void:
	PlayerInventory.bag[0] = "backpack"
	PlayerInventory.bag[1] = "voidstar_ring"
	PlayerInventory.toggle_lock(_bag(1))
	assert_eq(PlayerInventory.store_all(), 1)
	assert_eq(PlayerInventory.bag[0], "")
	assert_eq(PlayerInventory.bag[1], "voidstar_ring")
	assert_true(PlayerInventory.storage.has("backpack"))

func test_a_lock_moves_with_its_item() -> void:
	PlayerInventory.bag[0] = "backpack"
	PlayerInventory.toggle_lock(_bag(0))
	PlayerInventory.move(_bag(0), _bag(4))
	assert_true(PlayerInventory.is_locked(_bag(4)))
	assert_false(PlayerInventory.is_locked(_bag(0)))

func test_a_lock_does_not_stick_to_a_different_item() -> void:
	PlayerInventory.bag[0] = "backpack"
	PlayerInventory.toggle_lock(_bag(0))
	PlayerInventory.bag[0] = "crimson_cape"
	assert_false(PlayerInventory.is_locked(_bag(0)))
