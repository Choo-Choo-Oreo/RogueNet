class_name EnemyIndex
extends RefCounted

## Finds every enemy definition: scans the enemy folder and everything under it, so an
## enemy is just a .json dropped in any subfolder (a species folder, bosses/, a
## mod's folder) and nothing in the code has to be told about it. The enemy's id is its
## file name without ".json", and must be unique across the whole tree; on a duplicate
## the first one found wins and a warning is printed. Non-json files (the README) are
## ignored.
##
## ROOTS is a list so content from somewhere else (a workshop folder) can be added later
## without rewriting the scan.

const ROOTS: Array[String] = ["res://game/entities/entities.antagonist/"]

## A file under a folder with this name is a boss: the folder decides, there is no json flag.
const BOSS_FOLDER := "/bosses/"

static var _paths := {}  # enemy id -> res:// path of its json
static var _data := {}   # enemy id -> parsed json, loaded on first use

static func _ensure() -> void:
	if not _paths.is_empty():
		return
	for root in ROOTS:
		_scan(root)

static func _scan(dir_path: String) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".json"):
			continue
		var id := file_name.get_basename()
		if _paths.has(id):
			push_warning("Enemy id '%s' exists twice (%s and %s), using the first" % [id, _paths[id], dir_path + file_name])
			continue
		_paths[id] = dir_path + file_name
	for sub_dir in DirAccess.get_directories_at(dir_path):
		_scan(dir_path + sub_dir + "/")

## Scan again (after content was added while the game runs, e.g. by a tool).
static func refresh() -> void:
	_paths.clear()
	_data.clear()

static func has(enemy_id: String) -> bool:
	_ensure()
	return _paths.has(enemy_id)

## Every enemy id, sorted.
static func ids() -> Array:
	_ensure()
	var result: Array = _paths.keys()
	result.sort()
	return result

## The json's res:// path, or "" for an unknown id.
static func path_of(enemy_id: String) -> String:
	_ensure()
	return _paths.get(enemy_id, "")

## The parsed json (a copy, safe to change), or {} for an unknown id.
static func load_data(enemy_id: String) -> Dictionary:
	_ensure()
	if not _paths.has(enemy_id):
		return {}
	if not _data.has(enemy_id):
		_data[enemy_id] = JsonOnloading.load_dict(_paths[enemy_id])
	return (_data[enemy_id] as Dictionary).duplicate(true)

static func is_boss(enemy_id: String) -> bool:
	_ensure()
	if not _paths.has(enemy_id):
		return false
	return String(_paths[enemy_id]).contains(BOSS_FOLDER)
