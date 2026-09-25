class_name ActionIndex
extends RefCounted

## Finds every action definition in game/actions/ (see the README there) and turns a
## creature's "actions" list into the attack dictionaries the controllers use. An entry is
## an action id ("bite"), or {"action": "bite", "amount": 3} to change some of its numbers
## for this creature only. Each key of the override replaces the same key of the action.

const ROOTS: Array[String] = ["res://game/actions/"]

static var _index := JsonIndex.new(ROOTS, "Action")

## The resolved attack dictionaries for a creature's "actions" list, in list order, each
## with its action "id" added (the hotbar shows it). An unknown action id is skipped with a warning.
static func resolve(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		var id: String = entry if entry is String else str((entry as Dictionary).get("action", ""))
		if not _index.has(id):
			push_warning("Unknown action '%s', skipped" % id)
			continue
		var attack := _index.load_data(id)
		if not ActionRunner.VERBS.has(str(attack.get("verb", ""))):
			push_warning("Action '%s' has no known verb (%s), skipped" % [id, ", ".join(ActionRunner.VERBS)])
			continue
		attack["id"] = id
		if entry is Dictionary:
			for key in entry:
				if key != "action":
					attack[key] = entry[key]
		result.append(attack)
	return result
