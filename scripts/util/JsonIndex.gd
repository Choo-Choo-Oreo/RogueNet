class_name JsonIndex
extends RefCounted

## One kind of content found by id: every .json under `roots` (any subfolder), id = file
## name (JsonOnloading.find_by_id). Scanned on first use, each file parsed on first use.
## MinionIndex and ActionIndex each keep one.

var _roots: Array[String]
var _kind: String  # for find_by_id's duplicate warning ("Minion", "Action")
var _paths := {}  # id -> res:// path of its json
var _data := {}   # id -> parsed json

func _init(roots: Array[String], kind: String) -> void:
	_roots = roots
	_kind = kind

func _ensure() -> void:
	if not _paths.is_empty():
		return
	for root in _roots:
		JsonOnloading.find_by_id(root, _paths, _kind)

## Scan again (after content was added while the game runs, e.g. by a tool).
func refresh() -> void:
	_paths.clear()
	_data.clear()

func has(id: String) -> bool:
	_ensure()
	return _paths.has(id)

## Every id, sorted.
func ids() -> Array:
	_ensure()
	var result: Array = _paths.keys()
	result.sort()
	return result

## The json's res:// path, or "" for an unknown id.
func path_of(id: String) -> String:
	_ensure()
	return _paths.get(id, "")

## The parsed json (a copy, safe to change), or {} for an unknown id.
func load_data(id: String) -> Dictionary:
	_ensure()
	if not _paths.has(id):
		return {}
	if not _data.has(id):
		_data[id] = JsonOnloading.load_dict(_paths[id])
	return (_data[id] as Dictionary).duplicate(true)
