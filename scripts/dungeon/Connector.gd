class_name Connector
extends RefCounted

## Room connector helpers (room JSON format 2). A connector is the OPENING
## between rooms, nothing else -- a run of cells along one room edge:
##   { "a": {"x": 0, "y": 5}, "b": {"x": 0, "y": 7}, "free": false }
## a and b are both INCLUDED in the run, a is always the smaller coordinate
## (top / left end), and a == b is the old single-cell connector. `free` (optional,
## default false) is reserved for "may join a connector of any width".
## `door` (optional) says what this opening wants: a door type from game/doors/
## ("wood", "iron", ...), "none" (never a door), or "any" (the default, whatever
## the other side wants, else the biome's default_door). See DoorPlacer.
##
## Format 1 stored {"position": {"x","y"}}; upgrade_room() converts that in
## memory on load, so old files keep working until they are re-saved.

const FORMAT := 2

## Same values as DungeonAssembler.Dir (NORTH, SOUTH, EAST, WEST) -- repeated
## here instead of referenced so the two scripts don't depend on each other.
const NORTH := 0
const SOUTH := 1
const EAST := 2
const WEST := 3

static func make(from_cell: Vector2i, to_cell: Vector2i, free: bool = false, door_type: String = "") -> Dictionary:
	var lo := Vector2i(mini(from_cell.x, to_cell.x), mini(from_cell.y, to_cell.y))
	var hi := Vector2i(maxi(from_cell.x, to_cell.x), maxi(from_cell.y, to_cell.y))
	var result := {"a": {"x": lo.x, "y": lo.y}, "b": {"x": hi.x, "y": hi.y}}
	if free:
		result["free"] = true
	if door_type != "" and door_type != "any":
		result["door"] = door_type
	return result

## Format 1 {"position"} -> format 2 {"a","b"}; a format 2 connector is just
## re-normalised (a <= b). Returns a new dictionary.
static func upgrade(c: Dictionary) -> Dictionary:
	if c.has("a") and c.has("b"):
		return make(_vec(c["a"]), _vec(c["b"]), c.get("free", false), c.get("door", ""))
	var p := _vec(c.get("position", {}))
	return make(p, p)

## Converts room["connectors"] to format 2 in place and stamps the format.
static func upgrade_room(room: Dictionary) -> void:
	var upgraded: Array = []
	for c in room.get("connectors", []):
		upgraded.append(upgrade(c))
	room["connectors"] = upgraded
	room["format"] = FORMAT

static func a(c: Dictionary) -> Vector2i:
	return _vec(c["a"])

static func b(c: Dictionary) -> Vector2i:
	return _vec(c["b"])

## "any" when the connector does not say.
static func door(c: Dictionary) -> String:
	var value: String = c.get("door", "")
	return "any" if value == "" else value

static func is_free(c: Dictionary) -> bool:
	return c.get("free", false)

static func width(c: Dictionary) -> int:
	var d := b(c) - a(c)
	return maxi(d.x, d.y) + 1

## Every cell of the run, from a to b.
static func cells(c: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := a(c)
	var end := b(c)
	var step := Vector2i(signi(end.x - start.x), signi(end.y - start.y))
	var cell := start
	result.append(cell)
	while cell != end:
		cell += step
		result.append(cell)
	return result

## Which way the opening faces (out of the room), for a room of this size.
## A horizontal run faces N or S, a vertical run W or E; a single cell keeps
## the old rule (top edge, bottom edge, left edge, else right).
static func dir(c: Dictionary, _room_width: int, room_height: int) -> int:
	var start := a(c)
	var end := b(c)
	if start.x != end.x:
		return NORTH if start.y == 0 else SOUTH
	if start.y != end.y:
		return WEST if start.x == 0 else EAST
	if start.y == 0:
		return NORTH
	if start.y == room_height - 1:
		return SOUTH
	if start.x == 0:
		return WEST
	return EAST

## One clockwise quarter turn of a room that is currently `room_height` tall
## (same mapping as the tile grids: (x, y) -> (height - 1 - y, x)); a and b are
## both turned and then re-sorted so a stays the smaller end.
static func rotate(c: Dictionary, room_height: int) -> Dictionary:
	var p := a(c)
	var q := b(c)
	return make(
		Vector2i(room_height - 1 - p.y, p.x),
		Vector2i(room_height - 1 - q.y, q.x),
		is_free(c))

## Human-readable problems with a room's (format 2) connectors; empty = fine.
static func validate(room: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var w: int = room["width"]
	var h: int = room["height"]
	var claimed := {}
	var index := 0
	for c in room.get("connectors", []):
		var label := "connector[%d]" % index
		index += 1
		var start := a(c)
		var end := b(c)
		if start.x != end.x and start.y != end.y:
			errors.append("%s %s-%s is not a straight run" % [label, start, end])
			continue
		var in_bounds := true
		for cell in cells(c):
			if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
				in_bounds = false
		if not in_bounds:
			errors.append("%s %s-%s is out of bounds (room is %dx%d)" % [label, start, end, w, h])
			continue
		var on_edge := false
		if start.x != end.x:
			on_edge = start.y == 0 or start.y == h - 1
		elif start.y != end.y:
			on_edge = start.x == 0 or start.x == w - 1
		else:
			on_edge = start.x == 0 or start.x == w - 1 or start.y == 0 or start.y == h - 1
		if not on_edge:
			errors.append("%s %s-%s is not on a single room edge" % [label, start, end])
			continue
		for cell in cells(c):
			var on_x_edge: bool = cell.x == 0 or cell.x == w - 1
			var on_y_edge: bool = cell.y == 0 or cell.y == h - 1
			if on_x_edge and on_y_edge:
				errors.append("%s includes corner cell %s" % [label, cell])
			if claimed.has(cell):
				errors.append("%s overlaps another connector at %s" % [label, cell])
			claimed[cell] = true
	return errors

static func _vec(d: Dictionary) -> Vector2i:
	return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
