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
	var horizontal := true
	## The cells a closed door blocks.
	var cells: Array[Vector2i] = []
	## What to draw: [{"cell": Vector2i, "piece": String}] (piece names come
	## from the door art's own json).
	var pieces: Array = []
	var is_open := false

static var doors: Array = []  # Door, indexed by id
static var _by_cell := {}     # Vector2i -> Door
static var _defs := {}
## Bumped on every state change; LightMap polls it to re-flood vision.
static var version := 0

static func clear() -> void:
	doors.clear()
	_by_cell.clear()
	version += 1

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
	if door == null or door.is_open:
		return null
	return door

static func blocks_sight(cell: Vector2i) -> bool:
	var door: Door = _by_cell.get(cell)
	return door != null and not door.is_open and not door.transparent

## Returns false if nothing changed (unknown id, or already in that state).
static func set_open(id: int, open: bool) -> bool:
	if id < 0 or id >= doors.size():
		return false
	var door: Door = doors[id]
	if door.is_open == open:
		return false
	door.is_open = open
	version += 1
	return true

## Type name -> its game/doors json, loaded once.
static func get_def(type: String) -> Dictionary:
	if _defs.is_empty():
		_load_defs()
	return _defs.get(type, {})

static func all_defs() -> Dictionary:
	if _defs.is_empty():
		_load_defs()
	return _defs

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
