extends SceneTree

## Smoke check for the Characters screen (saves go to a test folder, not the player's):
## Singleplayer opens the screen instead of the town; creating a hero lists it; Play picks it,
## remembers it and carries on to the town; Swap Characters in town opens the same screen,
## saves the hero being left and plays the new one; leaving the town saves the bag.
## Prints PASS or FAIL and exits 1 on failure.
##
##   godot --headless -s res://test/sim/character_select.gd

const TEST_ROOT := "user://test_characters_select"

var _frames := 0
var _menu: Node
var _first_id := ""
var _problems: Array[String] = []

func _initialize() -> void:
	CharacterSave.root = TEST_ROOT
	_clear()
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	var inventory := root.get_node("PlayerInventory")
	if _frames == 10:
		_menu = current_scene
		_menu._on_singleplayer_pressed()
	elif _frames == 20:
		var select := _select_screen(_menu.panel_settings)
		if select == null:
			return _finish("Singleplayer did not open the Characters screen")
		if current_scene != _menu:
			return _finish("Singleplayer left the main menu before a hero was picked")
		if not _pick(select, "Test Hero"):
			return _finish("the new hero is not listed and selected")
	elif _frames == 40:
		_first_id = inventory.hero.get("id", "")
		if inventory.hero.get("name", "") != "Test Hero":
			_problems.append("Play did not set PlayerInventory.hero")
		if ProtagonistSave.new().last_id() != _first_id:
			_problems.append("the picked hero is not remembered for the next start")
		if current_scene == null or current_scene.scene_file_path != "res://scenes/ui/town/MainTown.tscn":
			return _finish("picking the hero did not carry on into the town")
		inventory.bag[0] = "backpack"
		current_scene._on_swap_characters_button_pressed()
	elif _frames == 45:
		var select := _select_screen(current_scene.panel_character)
		if select == null:
			return _finish("Swap Characters did not open the Characters screen")
		if select._play_button.text != "Back to Town":
			_problems.append("in town the screen's button is not Back to Town")
		if not _pick(select, "Second Hero"):
			return _finish("the second hero is not listed and selected")
	elif _frames == 55:
		if inventory.hero.get("name", "") != "Second Hero":
			_problems.append("swapping did not play the second hero")
		var first: Dictionary = ProtagonistSave.new().load_character(_first_id)
		if first.get("bag", []).is_empty() or first["bag"][0] != "backpack":
			_problems.append("swapping did not save the hero being left")
		inventory.bag[0] = "backpack"
		current_scene.queue_free()
	elif _frames == 60:
		var saved: Dictionary = ProtagonistSave.new().load_character(inventory.hero["id"])
		if saved.get("bag", []).is_empty() or saved["bag"][0] != "backpack":
			_problems.append("leaving the town did not save the bag")
		return _finish("")
	return false

## Creates a hero named `hero_name` on the screen and plays it.
func _pick(select: Node, hero_name: String) -> bool:
	select._name_edit.text = hero_name
	select._create()
	var picked_items: PackedInt32Array = select._list.get_selected_items()
	if picked_items.is_empty() or select._heroes[picked_items[0]]["name"] != hero_name:
		return false
	# In town, Back to Town plays the selected one.
	if select.in_town:
		select._back_to_town()
	else:
		select._play()
	return true

func _select_screen(panel: Node) -> Node:
	for child in panel.get_children():
		if child.has_signal("picked") and not child.is_queued_for_deletion():
			return child
	return null

func _finish(problem: String) -> bool:
	if problem != "":
		_problems.append(problem)
	_clear()
	print("PASS character_select" if _problems.is_empty() else "FAIL character_select: " + "; ".join(_problems))
	quit(0 if _problems.is_empty() else 1)
	return true

func _clear() -> void:
	DirAccess.remove_absolute(TEST_ROOT.path_join(CharacterSave.LAST_FILE))
	var folder := TEST_ROOT.path_join("protagonist")
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file_name))
