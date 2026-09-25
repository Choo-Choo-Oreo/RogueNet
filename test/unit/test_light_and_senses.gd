extends GutTest

## A player's light comes from a torch in either hand (ItemDatabase.light_of), and their senses
## from adventurer.json "senses" (false = doesn't have it).

func test_no_gear_gives_no_light() -> void:
	assert_eq(ItemDatabase.light_of({}), {})

func test_a_torch_in_the_off_hand_gives_its_light() -> void:
	var light := ItemDatabase.light_of({"off_hand": "poacher_torch"})
	assert_eq(light, ItemDatabase.get_item("poacher_torch"))
	assert_true(light.has("glow_radius"))

func test_a_torch_in_the_main_hand_counts_too() -> void:
	assert_eq(ItemDatabase.light_of({"main_hand": "poacher_torch"}), ItemDatabase.get_item("poacher_torch"))

func test_a_torch_on_the_back_gives_no_light() -> void:
	assert_eq(ItemDatabase.light_of({"back": "poacher_torch"}), {})

func test_a_sword_in_the_main_hand_does_not_hide_the_off_hand_torch() -> void:
	var light := ItemDatabase.light_of({"main_hand": "fallback_sword", "off_hand": "fallback_torch"})
	assert_eq(light, ItemDatabase.get_item("fallback_torch"))

func test_player_senses_come_from_adventurer_json() -> void:
	var player: PlayerController = autofree(preload("res://scenes/entities/PlayerController.tscn").instantiate())
	var senses: Dictionary = JsonOnloading.load_dict(PlayerController.ADVENTURER_DATA_PATH)["senses"]
	player._senses = senses
	for sense in senses:
		var entry = senses[sense]
		var want: float = entry["range_tiles"] if entry is Dictionary else 0.0
		assert_eq(player.sense_range(sense), want, sense)
	assert_eq(player.sense_range("sixth"), 0.0, "an unknown sense is one it doesn't have")
