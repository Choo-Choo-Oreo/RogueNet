class_name DoorPlacer
extends RefCounted

## Decides which open joints between rooms get a door, after assembly. Purely
## geometry + a seeded roll: it never touches the assembler's own RNG, so
## turning doors on or off can't change the room layout, and every peer
## (same seed, same rooms) builds the identical door list -- door ids are just
## list positions, which is what the network sync sends.
##
## Per biome, defines.json may hold "doors": {"density": 0..1, "types": [...]}.
## No "doors" key = no doors. A joint only gets a type whose width range
## (game/doors/<type>.json min_width / max_width) fits it.

static func place(rooms: Dictionary, placements: Array, defines: Dictionary, dungeon_seed: int) -> Array[DoorRegistry.Door]:
	var result: Array[DoorRegistry.Door] = []
	var config: Dictionary = defines.get("doors", {})
	var density: float = config.get("density", 0.0)
	var types: Array = config.get("types", [])
	if density <= 0.0 or types.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([dungeon_seed, "doors"])
	for p in placements:
		if p.parent_index < 0 or p.suppressed_connectors.is_empty():
			continue
		var anchor: Vector2i = p.suppressed_connectors[0]
		var cells: Array = p.joint_cells.get(anchor, [])
		if cells.is_empty():
			continue
		# One roll per joint, drawn whether or not it is used, so a joint that
		# gets no door doesn't shift the rolls of the ones after it.
		var roll := rng.randf()
		var pick := rng.randi()
		if roll >= density:
			continue
		var fitting: Array = []
		for candidate in types:
			var def := DoorRegistry.get_def(candidate)
			if not def.is_empty() and cells.size() >= int(def.get("min_width", 1)) and cells.size() <= int(def.get("max_width", 1)):
				fitting.append(candidate)
		if fitting.is_empty():
			continue
		var room: Dictionary = rooms[p.room_id]
		var dir: int = DungeonAssembler._connector_dir(room, anchor)
		var step: Vector2i = DungeonAssembler._dir_step(dir)
		var world_cells: Array[Vector2i] = []
		for cell in cells:
			world_cells.append(p.offset + cell)
		var type: String = fitting[pick % fitting.size()]
		result.append(_build(type, world_cells, step))
	return result

## `own_cells` are this room's joint cells (ascending along the run), `step`
## points out of this room toward the parent, so own + step is the parent's cell.
static func _build(type: String, own_cells: Array[Vector2i], step: Vector2i) -> DoorRegistry.Door:
	var def := DoorRegistry.get_def(type)
	var door := DoorRegistry.Door.new()
	door.type = type
	door.transparent = def.get("transparent", false)
	door.open_seconds = def.get("open_seconds", 0.3)
	var count := own_cells.size()
	if step.y != 0:
		# Gap in a north/south wall. The art puts each column on the SOUTH cell of
		# the pair; the north cell stays plain floor.
		door.horizontal = true
		for i in count:
			var south: Vector2i = own_cells[i] if step.y < 0 else own_cells[i] + step
			door.cells.append(south)
			door.pieces.append({"cell": south, "piece": _horizontal_piece(i, count)})
	else:
		# Gap in an east/west wall: a left half on the WEST cell, a right half on the EAST cell.
		door.horizontal = false
		for i in count:
			var west: Vector2i = own_cells[i] if step.x > 0 else own_cells[i] + step
			var east: Vector2i = west + Vector2i(1, 0)
			var base := _vertical_piece(i, count)
			door.cells.append(west)
			door.cells.append(east)
			door.pieces.append({"cell": west, "piece": base + "_left"})
			door.pieces.append({"cell": east, "piece": base + "_right"})
	return door

static func _horizontal_piece(i: int, count: int) -> String:
	if count == 1:
		return "h_single"
	if i == 0:
		return "h_end_left"
	if i == count - 1:
		return "h_end_right"
	return "h_middle_left" if i < count / 2.0 else "h_middle_right"

static func _vertical_piece(i: int, count: int) -> String:
	if count == 1:
		return "v_single"
	if i == 0:
		return "v_end_top"
	if i == count - 1:
		return "v_end_bottom"
	return "v_middle_top" if i < count / 2.0 else "v_middle_bottom"
