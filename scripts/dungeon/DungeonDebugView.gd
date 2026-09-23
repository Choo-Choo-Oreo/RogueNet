extends Node

## Drop this into any dev scene. Press F5 (see "debug_dungeon_layout" in
## the input map) to generate a fresh dungeon layout with a random seed
## and dump it as an ASCII grid to the output console — a stand-in for
## real rendering until DungeonAssembler's output actually gets painted
## into a TileMapLayer.

const ROLE_CHAR := {
	"entrance": "E",
	"corridor": "c",
	"boss": "B",
	"normal": ".",
}

func _unhandled_input(event: InputEvent) -> void:
	# The action lives in project.godot; a copy without it would error on every key press.
	if InputMap.has_action("debug_dungeon_layout") and event.is_action_pressed("debug_dungeon_layout"):
		_dump_layout(NetworkSync.dungeon_seed)

func _dump_layout(dungeon_seed: int) -> void:
	var biome := DungeonAssembler.pick_biome(dungeon_seed)
	var defines := DungeonAssembler.load_defines(biome)
	var rooms := DungeonAssembler.load_rooms(biome)
	if rooms.is_empty():
		print("DungeonDebugView: no rooms loaded")
		return
	var placements := DungeonAssembler.generate_with_retry(rooms, dungeon_seed, defines)
	if placements.is_empty():
		print("DungeonDebugView: generation failed")
		return

	var min_pos := Vector2i(1 << 30, 1 << 30)
	var max_pos := Vector2i(-(1 << 30), -(1 << 30))
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		var room_max: Vector2i = p.offset + Vector2i(room["width"], room["height"])
		min_pos.x = min(min_pos.x, p.offset.x)
		min_pos.y = min(min_pos.y, p.offset.y)
		max_pos.x = max(max_pos.x, room_max.x)
		max_pos.y = max(max_pos.y, room_max.y)

	var w: int = max_pos.x - min_pos.x
	var h: int = max_pos.y - min_pos.y
	var grid := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill(" ")
		grid.append(row)

	for i in placements.size():
		var p = placements[i]
		var room: Dictionary = rooms[p.room_id]
		var role: String = room.get("role", "normal")
		var is_treasure: bool = (room.get("tags", []) as Array).has("treasure")
		var ch: String = "$" if is_treasure else ROLE_CHAR.get(role, "?")
		for y in room["height"]:
			for x in room["width"]:
				var gx: int = p.offset.x + x - min_pos.x
				var gy: int = p.offset.y + y - min_pos.y
				if room["walls"][y][x] != null:
					grid[gy][gx] = "#"
				elif room["floor"][y][x] != null:
					grid[gy][gx] = ch
		for c in room["connectors"]:
			var anchor := Connector.a(c)
			for cell in Connector.cells(c):
				var gx: int = p.offset.x + cell.x - min_pos.x
				var gy: int = p.offset.y + cell.y - min_pos.y
				grid[gy][gx] = "x" if anchor in p.locked_connectors else "o"

	print("=== Dungeon layout, seed=%d, rooms=%d ===" % [dungeon_seed, placements.size()])
	for row in grid:
		print("".join(row))
	print("Legend: E entrance, c corridor, B boss, $ treasure, . normal, # wall, o open door, x locked door")
