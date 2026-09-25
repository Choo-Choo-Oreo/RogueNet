extends GutTest

## A biome's ambience (MusicManager): the loop its defines.json names in "ambience", playing
## under the music for the dive and gone when the biome has none or the music stops.

const LOOP := "res://resources/sfx/effects/lava/loop.wav"   # any loop will do

func after_each() -> void:
	MusicManager.stop()

func test_a_biome_with_ambience_plays_it() -> void:
	MusicManager.play_for_biome({"ambience": LOOP})
	assert_eq(MusicManager._ambience.stream, load(LOOP))
	assert_true(MusicManager._ambience.playing)

func test_it_goes_with_a_biome_without_one_and_with_the_music() -> void:
	MusicManager.play_for_biome({"ambience": LOOP})
	MusicManager.play_for_biome({})
	assert_eq(MusicManager._ambience_path, "", "no entry: none")
	MusicManager.play_for_biome({"ambience": LOOP})
	MusicManager.play_menu()
	assert_eq(MusicManager._ambience_path, "", "the menu has none")

func test_every_biome_ambience_exists() -> void:
	var named := 0
	for biome in DirAccess.get_directories_at("res://game/rooms/"):
		var path: String = DungeonAssembler.load_defines(biome).get("ambience", "")
		if path != "":
			named += 1
			assert_true(ResourceLoader.exists(path), biome + ": " + path)
	if named == 0:
		pass_test("no biome names an ambience yet")
