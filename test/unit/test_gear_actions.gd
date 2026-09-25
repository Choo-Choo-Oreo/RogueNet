extends GutTest

## The player's hotbar comes from worn gear (item "actions"), weapons first, then the
## player's own actions from player.json.

var player: PlayerController

# Kept out of the tree: its GridMover needs a dungeon. So player.json's own actions are
# read here the way _load_player_data() does.
func before_each() -> void:
	player = autofree(preload("res://scenes/entities/PlayerController.tscn").instantiate())
	player._own_actions = JsonOnloading.load_dict(PlayerController.PLAYER_DATA_PATH)["actions"]

func _ids() -> Array:
	return player.hotbar_actions().map(func(attack): return attack["id"])

func test_no_gear_leaves_only_the_players_own_actions() -> void:
	player.set_equipment({})
	assert_eq(_ids(), ["taunt", "throw_rock"])

func test_weapon_actions_come_first_with_the_items_numbers() -> void:
	player.set_equipment({"off_hand": "fallback_torch", "main_hand": "fallback_bow"})
	assert_eq(_ids(), ["arrow_shot", "taunt", "throw_rock"])
	assert_eq(player.hotbar_actions()[0]["interval"], 0.8, "the bow's override, not arrow_shot's own")

func test_taking_a_weapon_off_moves_the_active_slot_back() -> void:
	player.set_equipment({"main_hand": "fallback_sword"})
	player.active_slot = 2
	player.set_equipment({})
	assert_eq(player.active_slot, 0)
