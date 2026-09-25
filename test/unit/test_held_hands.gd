extends GutTest

## Facing left the body is its right-facing art mirrored, but held items keep to their own
## hand (ItemDatabase.held_left, GearLayers): the sword stays in the main hand, the shield in
## the off hand, on whichever side of the body that hand is.

const SWORD := "militia_rusty_sword"   # no left art: mirrored, behind the body
const SHIELD := "militia_wooden_shield"   # own -Left art: its face, in front of the body

var _sprite: AnimatedSprite2D
var _gear: GearLayers

func before_each() -> void:
	var data := JsonOnloading.load_dict(PlayerController.CHARACTERS["human"])
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])
	add_child_autofree(_sprite)
	_gear = GearLayers.new()
	add_child_autofree(_gear)
	_gear.setup(_sprite)
	_gear.set_equipment({"main_hand": SWORD, "off_hand": SHIELD, "head": "heavy_iron_helm"})

func _face(animation: String, mirrored: bool) -> void:
	_sprite.play(animation)
	_sprite.flip_h = mirrored
	_gear._process(0.0)

func _layer(slot: String) -> AnimatedSprite2D:
	return _sprite.get_node("Gear_" + slot)

func test_left_order_swaps_the_hands() -> void:
	var right := ItemDatabase.draw_order("Right")
	var left := ItemDatabase.draw_order("Left")
	assert_eq(left.find("main_hand"), right.find("off_hand"))
	assert_eq(left.find("off_hand"), right.find("main_hand"))
	assert_eq(left.find("head"), right.find("head"), "only the hands move")

func test_facing_right_everything_follows_the_body() -> void:
	_face("Side", false)
	assert_eq(_layer("main_hand").animation, &"Side")
	assert_gt(_layer("main_hand").z_index, 0, "the main hand is the near hand facing right")
	assert_lt(_layer("off_hand").z_index, 0)

func test_facing_left_the_hands_keep_their_items() -> void:
	_face("Side", true)
	assert_true(_layer("main_hand").flip_h, "the sword has no left art, so it is mirrored")
	assert_lt(_layer("main_hand").z_index, 0, "the main hand is the far hand facing left")
	assert_eq(_layer("off_hand").animation, &"Left", "the shield shows its own left art")
	assert_false(_layer("off_hand").flip_h)
	assert_gt(_layer("off_hand").z_index, 0, "the off hand is the near hand facing left")
	assert_true(_layer("head").flip_h, "worn gear still mirrors with the body")

func test_diagonals_left_use_the_front_and_back_views() -> void:
	_face("FrontRight", true)
	assert_eq(_layer("main_hand").animation, &"Front")
	assert_false(_layer("main_hand").flip_h)
	_face("BackRight", true)
	assert_eq(_layer("off_hand").animation, &"Back")
	assert_false(_layer("off_hand").flip_h)
	_face("BackRight", false)
	assert_eq(_layer("off_hand").animation, &"BackRight", "facing right is unchanged")
