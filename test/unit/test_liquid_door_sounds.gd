extends GutTest

## Which sound files the liquids and doors find (Wading.liquid_folders, DoorManager.sound_path).
## The sounds are found by file name, so these catch a renamed file or folder.

func test_every_liquid_floor_has_its_sounds() -> void:
	var folders := Wading.liquid_folders()
	var ids := GridMover._tile_ids()
	for liquid in ["water", "lava", "acid"]:
		assert_eq(folders.get(ids.get_id("floor_" + liquid), ""), liquid)
		for sound in ["enter", "exit", "step_1", "step_2", "step_3"]:
			assert_true(ResourceLoader.exists(Wading.SFX_ROOT + liquid + "/" + sound + ".wav"), liquid + "/" + sound)
	assert_false(folders.has(ids.get_id("floor_grass")), "dry floors make no splash")

func test_every_door_type_opens_and_closes_with_a_sound() -> void:
	for type in DoorRegistry.all_types():
		assert_ne(DoorManager.sound_path(type, true), "", type + " open")
		assert_ne(DoorManager.sound_path(type, false), "", type + " close")

func test_a_door_type_without_its_own_sound_uses_its_first_word() -> void:
	assert_eq(DoorManager.sound_path("wood_fold", true), DoorManager.SFX_DIR + "wood_open.wav")
	assert_eq(DoorManager.sound_path("iron_sink", false), DoorManager.SFX_DIR + "iron_sink_close.wav")
	assert_eq(DoorManager.sound_path("no_such_door", true), "")
