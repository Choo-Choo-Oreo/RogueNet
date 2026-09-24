class_name MinionIndex
extends RefCounted

## Finds every minion definition: scans the minion folder and everything under it, so an
## minion is just a .json dropped in any subfolder (a species folder, bosses/, a
## mod's folder) and nothing in the code has to be told about it. The minion's id is its
## file name without ".json", and must be unique across the whole tree; on a duplicate
## the first one found wins and a warning is printed. Non-json files (the README) are
## ignored.
##
## ROOTS is a list so content from somewhere else (a workshop folder) can be added later
## without rewriting the scan.

const ROOTS: Array[String] = ["res://game/entities/entities.antagonist/"]

## A file under a folder with this name is a boss: the folder decides, there is no json flag.
const BOSS_FOLDER := "/bosses/"

static var _paths := {}  # minion id -> res:// path of its json
static var _data := {}   # minion id -> parsed json, loaded on first use

static func _ensure() -> void:
	if not _paths.is_empty():
		return
	for root in ROOTS:
		JsonOnloading.find_by_id(root, _paths, "Minion")

## Scan again (after content was added while the game runs, e.g. by a tool).
static func refresh() -> void:
	_paths.clear()
	_data.clear()

static func has(minion_id: String) -> bool:
	_ensure()
	return _paths.has(minion_id)

## Every minion id, sorted.
static func ids() -> Array:
	_ensure()
	var result: Array = _paths.keys()
	result.sort()
	return result

## The json's res:// path, or "" for an unknown id.
static func path_of(minion_id: String) -> String:
	_ensure()
	return _paths.get(minion_id, "")

## The parsed json (a copy, safe to change), or {} for an unknown id.
static func load_data(minion_id: String) -> Dictionary:
	_ensure()
	if not _paths.has(minion_id):
		return {}
	if not _data.has(minion_id):
		_data[minion_id] = JsonOnloading.load_dict(_paths[minion_id])
	return (_data[minion_id] as Dictionary).duplicate(true)

static func is_boss(minion_id: String) -> bool:
	_ensure()
	if not _paths.has(minion_id):
		return false
	return String(_paths[minion_id]).contains(BOSS_FOLDER)
