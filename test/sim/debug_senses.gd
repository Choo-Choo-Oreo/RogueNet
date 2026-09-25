extends SceneTree

# Loaded once the game runs (see _process): a -s script cannot compile code that names an
# autoload before the autoloads exist (Sound uses GameTick).
var _sound

## Smoke check for the sense debug overlays: loads the Test Lab with every minion and
## adventurer sense overlay on (OPTIONS), makes a sound, lets the
## overlay draw for a few seconds and builds the inspector panel for every creature. Any script
## error in the drawing code shows up in the output; it prints PASS when it got through.
##
##   godot --headless -s res://test/sim/debug_senses.gd

const OPTIONS := ["show-sight", "show-sound", "show-touch", "show-smell", "show-taste", "show-minion-inspector", "show-vision", "show-torch-light", "show-adventurer-sight", "show-adventurer-touch", "show-flow-field"]
const RUN_FRAMES := 300

var _frames := 0
var _sounded := false

func _initialize() -> void:
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

func _process(_delta: float) -> bool:
	if _sound == null:
		_sound = load("res://scripts/entities/entities.senses/Sound.gd")
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
		# A torch, so show-torch-light has a light to draw.
		players[0].set_equipment({"off_hand": "poacher_torch"})
		_sound.make(self, players[0].global_position, 3.0)
		if _sound.recent.is_empty():
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
	print("inspected %d creatures, %d sound floods kept" % [inspected, _sound.recent.size()])
	print("PASS debug_senses" if draw != null and inspected > 0 else "FAIL debug_senses: no DebugDraw or no creatures")
	quit(0 if draw != null and inspected > 0 else 1)
	return true
