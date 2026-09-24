class_name DoorPlacer
extends RefCounted

## Decides which open joints between rooms get a door, after assembly. Purely
## geometry and data, no randomness: every peer (same seed, same rooms) builds the
## identical door list -- door ids are just list positions, which is what the
## network sync sends.
##
## Each joint joins two connectors, and each connector may say what it wants
## (Connector "door"): a door type, "none", or "any" (the default).
##   - a specific type always gets its door; if both sides ask for a type, the
##     room being entered (the deeper one) wins
##   - otherwise "none" on either side means no door
##   - "any" + "any" uses the biome's defines.json "default_door" (a type name,
##     or "none"; missing = "none")
## A type only fills a joint whose width fits its min_width / max_width
## (game/doors/<type>.json); one that does not fit is replaced by the first
## type that does, with a warning, or no door if none does.

static func place(rooms: Dictionary, placements: Array, defines: Dictionary) -> Array[DoorRegistry.Door]:
	var result: Array[DoorRegistry.Door] = []
	var fallback: String = defines.get("default_door", "none")
	for p in placements:
		if p.parent_index < 0 or p.suppressed_connectors.is_empty():
			continue
		var anchor: Vector2i = p.suppressed_connectors[0]
		var cells: Array = p.joint_cells.get(anchor, [])
		if cells.is_empty():
			continue
		var room: Dictionary = rooms[p.room_id]
		var dir: int = DungeonAssembler._connector_dir(room, anchor)
		var step: Vector2i = DungeonAssembler._dir_step(dir)
		var own_want := _want(room, anchor)
		var parent_want := _parent_want(rooms, placements, p, p.offset + Vector2i(cells[0]) + step)
		var type := _resolve(own_want, parent_want, fallback)
		if type == "none":
			continue
		type = _fit(type, cells.size())
		if type == "":
			continue
		var world_cells: Array[Vector2i] = []
		for cell in cells:
			world_cells.append(p.offset + cell)
		result.append(_build(type, world_cells, step))
	return result

## The "door" setting of the connector of `room` whose first cell is `anchor`.
static func _want(room: Dictionary, anchor: Vector2i) -> String:
	for c in room.get("connectors", []):
		if Connector.a(c) == anchor:
			return Connector.door(c)
	return "any"

## The parent room's setting for the connector that contains `parent_cell`.
static func _parent_want(rooms: Dictionary, placements: Array, p, parent_cell: Vector2i) -> String:
	var parent = placements[p.parent_index]
	var parent_room: Dictionary = rooms.get(parent.room_id, {})
	for c in parent_room.get("connectors", []):
		for cell in Connector.cells(c):
			if parent.offset + cell == parent_cell:
				return Connector.door(c)
	return "any"

static func _resolve(own: String, parent: String, fallback: String) -> String:
	var own_specific := own != "any" and own != "none"
	var parent_specific := parent != "any" and parent != "none"
	if own_specific:
		return own
	if parent_specific:
		return parent
	if own == "none" or parent == "none":
		return "none"
	return fallback

## `type` if it fits `width`, else the first type (by name) that does, else "".
static func _fit(type: String, width: int) -> String:
	if _fits(type, width):
		return type
	var names: Array = DoorRegistry.all_types()
	names.sort()
	for candidate in names:
		if _fits(candidate, width):
			push_warning("DoorPlacer: door type '%s' does not fit a %d-wide opening, using '%s'" % [type, width, candidate])
			return candidate
	push_warning("DoorPlacer: no door type fits a %d-wide opening (wanted '%s')" % [width, type])
	return ""

static func _fits(type: String, width: int) -> bool:
	var def := DoorRegistry.get_def(type)
	return not def.is_empty() and width >= int(def.get("min_width", 1)) and width <= int(def.get("max_width", 1))

## `own_cells` are this room's joint cells (ascending along the run), `step`
## points out of this room toward the parent, so own + step is the parent's cell.
static func _build(type: String, own_cells: Array[Vector2i], step: Vector2i) -> DoorRegistry.Door:
	var def := DoorRegistry.get_def(type)
	var door := DoorRegistry.Door.new()
	door.type = type
	door.transparent = def.get("transparent", false)
	door.open_seconds = def.get("open_seconds", 0.3)
	door.passable_seconds = door.open_seconds * clampf(def.get("passable_at", 1.0), 0.0, 1.0)
	var count := own_cells.size()
	door.width = count
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
