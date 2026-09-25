extends GutTest

## The two ring slots: both are of kind "ring", so any ring fits either one and
## nothing else does. Equipping from the bag fills the first empty ring slot.

var _saved_equipped: Dictionary
var _saved_bag: Array[String]

func before_each() -> void:
	_saved_equipped = PlayerInventory.equipped.duplicate()
	_saved_bag = PlayerInventory.bag.duplicate()
	for slot in ItemDatabase.SLOTS:
		PlayerInventory.equipped[slot] = ""
	PlayerInventory.bag.fill("")

func after_each() -> void:
	PlayerInventory.equipped = _saved_equipped
	PlayerInventory.bag = _saved_bag

func _equip(slot: String) -> Dictionary:
	return PlayerInventory.place(PlayerInventory.EQUIP, slot)

func test_both_ring_slots_are_of_kind_ring() -> void:
	assert_eq(ItemDatabase.slot_kind("ring_1"), "ring")
	assert_eq(ItemDatabase.slot_kind("ring_2"), "ring")
	assert_eq(ItemDatabase.slot_kind("neck"), "neck", "other slots are their own kind")
	assert_eq(ItemDatabase.slots_for("ring"), ["ring_1", "ring_2"] as Array[String])

func test_a_ring_fits_either_ring_slot_but_not_the_neck() -> void:
	assert_true(PlayerInventory.fits("ruby_ring", _equip("ring_1")))
	assert_true(PlayerInventory.fits("ruby_ring", _equip("ring_2")))
	assert_false(PlayerInventory.fits("ruby_ring", _equip("neck")))

func test_an_amulet_does_not_fit_a_ring_slot() -> void:
	assert_false(PlayerInventory.fits("abyssal_pearl_amulet", _equip("ring_1")))

func test_equipping_two_rings_fills_both_slots() -> void:
	PlayerInventory.bag[0] = "ruby_ring"
	PlayerInventory.bag[1] = "voidstar_ring"
	PlayerInventory.equip_from(PlayerInventory.place(PlayerInventory.BAG, 0))
	PlayerInventory.equip_from(PlayerInventory.place(PlayerInventory.BAG, 1))
	assert_eq(PlayerInventory.equipped["ring_1"], "ruby_ring")
	assert_eq(PlayerInventory.equipped["ring_2"], "voidstar_ring")

func test_only_legendary_rings_have_a_bonus() -> void:
	assert_true(ItemDatabase.item_bonus("voidstar_ring").has("particles"))
	assert_true(ItemDatabase.item_bonus("ruby_ring").is_empty())
	assert_eq(ItemDatabase.get_item("ruby_ring").get("art", ""), "", "rings are never drawn on the body")
