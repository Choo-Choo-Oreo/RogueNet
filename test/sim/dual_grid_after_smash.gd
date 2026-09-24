extends SceneTree

## Regression check for "walls look solid but are gone" (found in the Test Lab): after
## TileDestruction.apply breaks the walls inside bug3_smash_plain, every renderer must show exactly
## what a full refresh would. The layers' `changed` signal does not fire for runtime set_cell, so
## apply() has to tell the renderers itself (TileInitialize.refresh_cells).
##
##   godot --headless -s res://test/sim/dual_grid_after_smash.gd

var t := 0
var sc
var changes := []
func _initialize() -> void:
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")
func snap(layer) -> Dictionary:
	var d := {}
	for c in layer.get_used_cells():
		d[c] = [layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c)]
	return d
func _process(_d: float) -> bool:
	t += 1
	sc = current_scene
	if t == 120:
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://test/sim/dev_cells.json"))
		var cen := Vector2i(int(meta["width"] / 2), int(meta["height"] / 2))
		var cell = null
		for c in meta["cells"]:
			if c["name"] == "bug3_smash_plain": cell = c
		var r = cell["rect"]
		var wd = sc.find_child("WallData", true, false)
		var cells: Array[Vector2i] = []
		for y in range(int(r["y"]) + 1, int(r["y"]) + int(r["h"]) - 1):
			for x in range(int(r["x"]) + 1, int(r["x"]) + int(r["w"]) - 1):
				var w := Vector2i(x, y) - cen
				if wd.get_cell_source_id(w) != -1: cells.append(w)
		print("interior wall cells: ", cells.size())
		var TD = load("res://scripts/dungeon/TileDestruction.gd")
		changes = TD.plan(cells, sc)
		print("changes: ", changes.size())
		var t0 := Time.get_ticks_usec()
		TD.apply(changes, sc)
		print("apply took %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	if t == 200:
		var bad := 0
		for n in ["wall_smooth_stone", "floor_smooth_stone", "floor_void"]:
			var render = sc.get_node("TileInitialize/" + n)
			var layer = render.display_layer
			var before := snap(layer)
			render.refresh()
			var after := snap(layer)
			var diff := 0
			for k in after: if not before.has(k) or before[k] != after[k]: diff += 1
			for k in before: if not after.has(k): diff += 1
			print(n, ": cells stale vs a fresh refresh: ", diff)
			bad += diff
		print("PASS dual_grid_after_smash" if bad == 0 else "FAIL dual_grid_after_smash: the drawn walls do not match the map after a wall was destroyed")
		quit(1 if bad > 0 else 0)
	return false
