extends SceneTree

## Vision is the sum of the adventurer's senses, and light only comes from a held torch:
##   1. no torch: the tiles next to you are felt (touch), a tile 3 away is dark, and no minion
##      can be lit by you (LightMap.is_tile_lit);
##   2. with the poacher torch: that tile 3 away is seen and lit.
## Stands the player in light_blind_ignores (open floor, no glowing tiles) in the dev biome.
##
##   godot --headless --fixed-fps 60 -s res://test/sim/vision_torch.gd

const CELL_NAME := "light_blind_ignores"

var _frame := 0
var _player: Node2D
var _tile := Vector2i.ZERO
var _problems: Array[String] = []

func _initialize() -> void:
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 120:
		_player = get_nodes_in_group("protagonist")[0]
		_player.set("debug_god", true)
		_player.set_equipment({})
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://test/sim/dev_cells.json"))
		var centre := Vector2i(int(meta["width"] / 2), int(meta["height"] / 2))
		for cell in meta["cells"]:
			if cell["name"] == CELL_NAME:
				_tile = Vector2i(int(cell["player_at"]["x"]), int(cell["player_at"]["y"])) - centre
		_player.grid_mover.teleport(Vector2(_tile * 16))
	if _frame == 140:
		_check("no torch: the tile next to you is felt", _vision().is_tile_seen(_tile + Vector2i(1, 0)), true)
		_check("no torch: a tile 3 away is dark", _vision().is_tile_seen(_tile + Vector2i(3, 0)), false)
		_check("no torch: you light nothing for a minion", _light().is_tile_lit(_tile + Vector2i(1, 0)), false)
		_player.set_equipment({"off_hand": "poacher_torch"})
	if _frame == 160:
		_check("torch: a tile 3 away is seen", _vision().is_tile_seen(_tile + Vector2i(3, 0)), true)
		_check("torch: a tile 3 away is lit for a minion", _light().is_tile_lit(_tile + Vector2i(3, 0)), true)
		if _problems.is_empty():
			print("PASS vision_torch")
		else:
			print("FAIL vision_torch: ", "; ".join(_problems))
		quit(0 if _problems.is_empty() else 1)
	return false

func _vision():
	return current_scene.find_child("PlayerVision", true, false)

func _light():
	return current_scene.find_child("LightMap", true, false)

func _check(what: String, got: bool, want: bool) -> void:
	print("  %s: %s" % [what, "ok" if got == want else "WRONG (got %s)" % got])
	if got != want:
		_problems.append(what)
