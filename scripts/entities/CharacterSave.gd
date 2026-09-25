class_name CharacterSave
extends RefCounted

## Saved characters, Terraria style: one JSON file per character, kept on this machine
## only. What both teams share lives here: the files, their folder, listing, deleting,
## and the fields every character has. Each team's own fields come from its save:
## ProtagonistSave (a player's adventurer) and AntagonistSave (a player-driven antagonist).
##
## Every character has:
##   id       the file name (made once by create(), never shown)
##   name     what the player typed
##   version  the format, so an old file can be upgraded when the format changes
## Saving happens when the caller says (in town and on exit); nothing here runs on its own.

const VERSION := 1
const LAST_FILE := "last_played.json"

## The folder every team's folder sits in. Tests point it somewhere else.
static var root := "user://characters"

## This team's folder under root ("protagonist", "antagonist").
var team: String

func _init(team_name: String) -> void:
	team = team_name

## A new, unsaved character: the shared fields plus this team's (_team_fields).
func create(character_name: String) -> Dictionary:
	var character := {
		"version": VERSION,
		"id": "%d_%04d" % [Time.get_unix_time_from_system(), randi() % 10000],
		"name": character_name.strip_edges(),
	}
	character.merge(_team_fields())
	return character

## What a team's character holds beyond the shared fields, with its starting values.
func _team_fields() -> Dictionary:
	return {}

## Writes the character to its file: first to a .tmp file, then swapped in, so a crash
## halfway through never leaves a broken save behind.
func save(character: Dictionary) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(_dir())
	if error != OK:
		return error
	var path := _path(character["id"])
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(character, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

## The character with this id, or {} when there is no such file or it cannot be read.
func load_character(id: String) -> Dictionary:
	return _read(_path(id))

## Every saved character of this team, sorted by name. Files that cannot be read are left out.
func list() -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(_dir()):
		return characters
	for file_name in DirAccess.get_files_at(_dir()):
		if file_name.ends_with(".json"):
			var character := _read(_dir().path_join(file_name))
			if not character.is_empty():
				characters.append(character)
	characters.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return characters

func delete(id: String) -> Error:
	if last_id() == id:
		remember("")
	return DirAccess.remove_absolute(_path(id))

## The last character of this team the player picked, so the game remembers it after a
## restart: one small file for every team, root/last_played.json = {team: id}.
func remember(id: String) -> void:
	var last := _read_last()
	last[team] = id
	DirAccess.make_dir_recursive_absolute(root)
	var file := FileAccess.open(root.path_join(LAST_FILE), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(last, "\t"))

## The remembered id, or "" when there is none (or its file is gone).
func last_id() -> String:
	var id := str(_read_last().get(team, ""))
	return id if id != "" and FileAccess.file_exists(_path(id)) else ""

func _read_last() -> Dictionary:
	var path := root.path_join(LAST_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}

func _dir() -> String:
	return root.path_join(team)

func _path(id: String) -> String:
	return _dir().path_join(id + ".json")

## A file's character, with any field it is missing filled in from create()'s, or {} when
## the file is missing, is not JSON, or is from a newer version of the game.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse, not parse_string: a broken file is expected here, not an engine error.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data = json.data
	if not data is Dictionary or not data.has("id") or int(data.get("version", 0)) > VERSION:
		return {}
	var character := create("")
	character.merge(data, true)
	character["version"] = VERSION
	return character
