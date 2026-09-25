extends GutTest

## Every liquid a body can wade in gets its own look, worked out from its floor tile
## (Wading.liquid_look): its colour, a paler rim, and how see-through it is.

func test_every_liquid_has_a_look_of_its_own() -> void:
	var looks := {}
	for folder in Wading.liquid_folders().values():
		var look := Wading.liquid_look(folder)
		assert_true(look.rim.get_luminance() > look.colour.get_luminance(), folder + ": the rim is paler than the liquid")
		assert_between(look.see_through, 0.0, 1.0, folder)
		looks[folder] = look
	assert_true(looks.has("water") and looks.has("lava") and looks.has("acid"))
	assert_ne(looks.water.colour, looks.lava.colour)
	assert_ne(looks.water.colour, looks.acid.colour)

func test_the_liquid_colour_comes_from_the_tile_art() -> void:
	var water := Wading.liquid_look("water")
	assert_true(water.colour.b > water.colour.r, "water is blue")
	var lava := Wading.liquid_look("lava")
	assert_true(lava.colour.r > lava.colour.b, "lava is red")

func test_lava_hides_more_of_a_body_than_water() -> void:
	var water := Wading.liquid_look("water")
	var lava := Wading.liquid_look("lava")
	assert_lt(lava.see_through, water.see_through)
	assert_gt(lava.tint, water.tint, "a murkier liquid tints what shows more strongly")
