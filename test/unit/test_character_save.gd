extends GutTest

## CharacterSave (through ProtagonistSave and AntagonistSave): characters written to and
## read back from a test folder, not the player's real saves.

const TEST_ROOT := "user://test_characters"
var _real_root := ""
var adventurers := ProtagonistSave.new()

func before_each() -> void:
	_real_root = CharacterSave.root
	CharacterSave.root = TEST_ROOT
	_clear()

func after_each() -> void:
	_clear()
	CharacterSave.root = _real_root

func _clear() -> void:
	for team in ["protagonist", "antagonist"]:
		var folder := TEST_ROOT.path_join(team)
		if DirAccess.dir_exists_absolute(folder):
			for file_name in DirAccess.get_files_at(folder):
				DirAccess.remove_absolute(folder.path_join(file_name))

## Writes raw text as an adventurer's file, for the cases save() never makes.
func _write_raw(id: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_ROOT.path_join("protagonist"))
	var file := FileAccess.open(TEST_ROOT.path_join("protagonist").path_join(id + ".json"), FileAccess.WRITE)
	file.store_string(text)
	file.close()

func test_saved_adventurer_loads_back() -> void:
	var adventurer := adventurers.create("  Orea ")
	adventurer["bag"] = ["rogue_jerkin", ""]
	adventurer["equipped"] = {"chest": "rogue_jerkin"}
	assert_eq(adventurers.save(adventurer), OK)
	var loaded := adventurers.load_character(adventurer["id"])
	assert_eq(loaded["name"], "Orea", "the name is trimmed")
	assert_eq(loaded["bag"], ["rogue_jerkin", ""])
	assert_eq(loaded["equipped"], {"chest": "rogue_jerkin"})
	assert_eq(loaded["difficulty"], "softcore")
	assert_eq(loaded["skin"], "human")

func test_list_is_sorted_by_name_and_delete_removes() -> void:
	var b := adventurers.create("bravo")
	var a := adventurers.create("Alpha")
	adventurers.save(b)
	adventurers.save(a)
	var names := adventurers.list().map(func(c): return c["name"])
	assert_eq(names, ["Alpha", "bravo"])
	assert_eq(adventurers.delete(a["id"]), OK)
	assert_eq(adventurers.list().size(), 1)

func test_teams_keep_separate_lists() -> void:
	var villains := AntagonistSave.new()
	adventurers.save(adventurers.create("Adventurer"))
	villains.save(villains.create("Villain"))
	assert_eq(adventurers.list().size(), 1)
	assert_eq(villains.list()[0]["name"], "Villain")
	assert_false(villains.list()[0].has("bag"), "an antagonist has only the shared fields")

func test_no_saves_yet_is_an_empty_list() -> void:
	assert_eq(adventurers.list().size(), 0)

func test_missing_or_broken_file_is_empty() -> void:
	assert_eq(adventurers.load_character("nobody"), {})
	_write_raw("broken", "{ not json")
	assert_eq(adventurers.load_character("broken"), {})
	assert_eq(adventurers.list().size(), 0, "a broken file is left out of the list")

func test_old_file_gets_missing_fields() -> void:
	_write_raw("old", JSON.stringify({"id": "old", "name": "Old"}))
	var loaded := adventurers.load_character("old")
	assert_eq(loaded["storage"], [], "a field the file lacks comes from create()")
	assert_eq(loaded["name"], "Old")

func test_newer_version_is_not_loaded() -> void:
	_write_raw("future", JSON.stringify({"id": "future", "name": "F", "version": CharacterSave.VERSION + 1}))
	assert_eq(adventurers.load_character("future"), {})
