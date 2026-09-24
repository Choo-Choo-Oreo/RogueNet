class_name DoorRegistry
extends RefCounted

## Runtime door state for the current dungeon: every door DoorPlacer made, and
## which cells each one occupies. Doors are not painted tiles -- GridMover,
## LightMap and the enemy sight checks ask this (cell -> door) instead, so a
## door can open and close without repainting anything.
##
## Door types (wood, iron, ...) are defined in game/doors/*.json; a Door keeps
## the few fields the rest of the game needs (transparent, open_seconds).

const DEFS_DIR := "res://game/doors/"

class Door:
	extends RefCounted
	var id: int = 0
	var type: String = ""
	## See-through (bars, grates): a closed one still blocks walking and shots,
	## but not sight or light.
	var transparent := false
	var open_seconds := 0.3
	## Seconds after it starts opening until it can be walked through (a fraction
	## of open_seconds, per door type: wood swings clear early, bars must fully lift).
	var passable_seconds := 0.3
	var horizontal := true
	## Tiles wide the opening is; picks which art file a per-width type uses.
	var width := 1
	## The cells a closed door blocks.
	var cells: Array[Vector2i] = []
	## What to draw: [{"cell": Vector2i, "piece": String}] (piece names come
	## from the door art's own json).
	var pieces: Array = []
	## Boss doors only (layered art): which leaves set to draw (wood .. gold) and
	## the wall tile the frame stands in (picks the frame set).
	var tier := "wood"
	var wall_tile := ""
	var is_open := false
	## True from the moment it starts opening until passable_seconds have passed:
	## it counts as closed (blocks walking and shots, not sight) for that time, then
	## becomes passable. Timed locally on each peer from when it hears of the change.
	var swinging := false
	var opened_msec := 0

static var doors: Array = []  # Door, indexed by id
static var _swinging: Array = []  # doors still mid-swing
static var _by_cell := {}     # Vector2i -> Door
static var _defs := {}
## Bumped on every state change; LightMap polls it to re-flood vision.
static var version := 0

static func clear() -> void:
	doors.clear()
	_by_cell.clear()
	_swinging.clear()
	version += 1

## Something about a door changed: light re-floods, and the shared enemy flow
## fields (which treat a closed door as a wall for anything that cannot open
## it) are rebuilt so a door that just became passable is not remembered as a wall.
static func _changed() -> void:
	version += 1
	FlowField.clear()

## Ends the swing of every door whose animation time is up. DoorManager calls
## this each frame.
static func tick() -> void:
	if _swinging.is_empty():
		return
	var now := Time.get_ticks_msec()
	var done: Array = []
	for door: Door in _swinging:
		if now - door.opened_msec >= int(door.passable_seconds * 1000.0):
			door.swinging = false
			done.append(door)
	if done.is_empty():
		return
	for door in done:
		_swinging.erase(door)
	_changed()

static func register(door: Door) -> void:
	door.id = doors.size()
	doors.append(door)
	for cell in door.cells:
		_by_cell[cell] = door

static func is_door_cell(cell: Vector2i) -> bool:
	return _by_cell.has(cell)

## The door blocking `cell` right now, or null (no door there, or it is open).
static func closed_door_at(cell: Vector2i) -> Door:
	var door: Door = _by_cell.get(cell)
	if door == null or (door.is_open and not door.swinging):
		return null
	return door

## Does this door stop walking and shots right now (closed, or still swinging)?
static func is_blocking(door: Door) -> bool:
	return not door.is_open or door.swinging

## The door whose thin barrier a step `from` -> `to` would cross, or null. The
## barrier is a line, not a tile: a horizontal door's line runs between its
## cell and the cell north of it; a vertical door's between its west and east
## cells. Standing on a door cell, or stepping onto it from the front, crosses
## nothing. (The door cells themselves stay "blocked" for pathfinding and sight.)
static func crossing_door(from: Vector2i, to: Vector2i) -> Door:
	var door: Door = _by_cell.get(from)
	if door != null:
		if door.horizontal:
			if to == from + Vector2i.UP:
				return door
		elif to.y == from.y and _by_cell.get(to) == door:
			return door
	door = _by_cell.get(to)
	if door != null and door.horizontal and from == to + Vector2i.UP:
		return door
	return null

static func blocks_sight(cell: Vector2i) -> bool:
	var door: Door = _by_cell.get(cell)
	# Sight and light pass as soon as it starts opening; only walking and shots wait
	# for the swing (closed_door_at).
	return door != null and not door.is_open and not door.transparent

## Returns false if nothing changed (unknown id, or already in that state).
static func set_open(id: int, open: bool) -> bool:
	if id < 0 or id >= doors.size():
		return false
	var door: Door = doors[id]
	if door.is_open == open:
		return false
	door.is_open = open
	door.swinging = open and door.passable_seconds > 0.0
	if door.swinging:
		door.opened_msec = Time.get_ticks_msec()
		if not _swinging.has(door):
			_swinging.append(door)
	else:
		_swinging.erase(door)
	_changed()
	return true

## Type name -> its game/doors json, loaded once.
static func get_def(type: String) -> Dictionary:
	if _defs.is_empty():
		_load_defs()
	return _defs.get(type, {})

## Every door type name.
static func all_types() -> Array:
	if _defs.is_empty():
		_load_defs()
	return _defs.keys()

static func _load_defs() -> void:
	var dir := DirAccess.open(DEFS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open(DEFS_DIR + file_name, FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			_defs[data.get("name", file_name.get_basename())] = data
