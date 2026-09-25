class_name ActionIndex
extends RefCounted

## Finds every action definition in game/actions/ (see the README there) and turns a
## creature's "actions" list into the attack dictionaries the controllers use. An entry is
## an action id ("bite"), or {"action": "bite", "amount": 3} to change some of its numbers
## for this creature only. Each key of the override replaces the same key of the action.

const ROOTS: Array[String] = ["res://game/actions/"]

static var _paths := {}  # action id -> res:// path of its json
static var _data := {}   # action id -> parsed json, loaded on first use

static func _ensure() -> void:
	if not _paths.is_empty():
		return
	for root in ROOTS:
		JsonOnloading.find_by_id(root, _paths, "Action")

## The resolved attack dictionaries for a creature's "actions" list, in list order. An
## unknown action id is skipped with a warning.
static func resolve(entries: Array) -> Array:
	_ensure()
	var result: Array = []
	for entry in entries:
		var id: String = entry if entry is String else str((entry as Dictionary).get("action", ""))
		if not _paths.has(id):
			push_warning("Unknown action '%s', skipped" % id)
			continue
		if not _data.has(id):
			_data[id] = JsonOnloading.load_dict(_paths[id])
		if not ActionRunner.VERBS.has(str(_data[id].get("verb", ""))):
			push_warning("Action '%s' has no known verb (%s), skipped" % [id, ", ".join(ActionRunner.VERBS)])
			continue
		var attack: Dictionary = (_data[id] as Dictionary).duplicate(true)
		attack["id"] = id
		if entry is Dictionary:
			for key in entry:
				if key != "action":
					attack[key] = entry[key]
		result.append(attack)
	return result
