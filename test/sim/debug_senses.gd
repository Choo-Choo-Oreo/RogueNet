extends SceneTree

## Smoke check for the sense debug overlays: loads the Test Lab with show-sight, show-sound,
## show-touch, show-smell, show-taste and show-minion-inspector on, makes a sound, lets the
## overlay draw for a few seconds and builds the inspector panel for every creature. Any script
## error in the drawing code shows up in the output; it prints PASS when it got through.
##
##   godot --headless -s res://test/sim/debug_senses.gd

const OPTIONS := ["show-sight", "show-sound", "show-touch", "show-smell", "show-taste", "show-minion-inspector", "show-vision", "show-flow-field"]
const RUN_FRAMES := 300

var _frames := 0
var _sounded := false

func _initialize() -> void:
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 120 or current_scene == null:
		return false
	var players := get_nodes_in_group("protagonist")
	if players.is_empty():
		return false
	if not _sounded:
		_sounded = true
		# Set here, not at start: the debug menu loads the saved settings when the dungeon opens.
		for option in OPTIONS:
			DebugState.flags["always:" + option] = true
		Sound.make(self, players[0].global_position, 3.0)
		if Sound.recent.is_empty():
			print("FAIL debug_senses: a sound made with show-sound on left no flood to draw")
			quit(1)
			return true
	if _frames < 120 + RUN_FRAMES:
		return false
	var draw: Node = null
	for child in current_scene.get_children():
		if child.has_method("_inspect_lines"):
			draw = child
	var inspected := 0
	for minion in get_nodes_in_group("antagonist"):
		if draw != null and "senses" in minion:
			draw._inspect_lines(minion)
			inspected += 1
	print("inspected %d creatures, %d sound floods kept" % [inspected, Sound.recent.size()])
	print("PASS debug_senses" if draw != null and inspected > 0 else "FAIL debug_senses: no DebugDraw or no creatures")
	quit(0 if draw != null and inspected > 0 else 1)
	return true
