extends GutTest

## Character skins (PlayerController.character_ids/character_data): every one to pick loads,
## and a skin "like" the human gets all of the human's animations with its own sheets.

func test_every_character_loads_all_its_sheets() -> void:
	var ids := PlayerController.character_ids()
	assert_eq(ids[0], PlayerController.DEFAULT_CHARACTER, "the default comes first")
	for character_id in ids:
		var data := PlayerController.character_data(character_id)
		var frames := SpriteFramesLoader.build(data["sprite_frames"])
		for animation in frames.get_animation_names():
			assert_not_null(frames.get_frame_texture(animation, 0), "%s %s" % [character_id, animation])
		var blink: String = data.get("idle", {}).get("blink", {}).get("texture", "")
		assert_true(blink == "" or ResourceLoader.exists(blink), character_id + " blink")

func test_a_skin_keeps_the_human_animations_with_its_own_art() -> void:
	var human := PlayerController.character_data("human")
	var elf := PlayerController.character_data("elf_female")
	assert_eq(elf["sprite_frames"]["animations"].keys(), human["sprite_frames"]["animations"].keys())
	assert_string_contains(elf["sprite_frames"]["animations"]["Side"]["texture"], "variants/elf_female/")
	assert_string_contains(elf["idle"]["blink"]["texture"], "variants/elf_female/")

func test_male_before_female() -> void:
	var ids := PlayerController.character_ids()
	assert_lt(ids.find("elf_male"), ids.find("elf_female"))
	assert_eq(PlayerController.character_data("no_such_skin"), PlayerController.character_data("human"), "unknown ids fall back")

func test_gear_shows_only_on_bodies_it_fits() -> void:
	assert_true(PlayerController.character_data("human").get("fits_gear", true), "the Human")
	assert_true(PlayerController.character_data("human_female").get("fits_gear", true), "on the Human's body")
	assert_false(PlayerController.character_data("dwarf_male").get("fits_gear", true), "a body of its own")
