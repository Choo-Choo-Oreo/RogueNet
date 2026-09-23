class_name TileTypeRegistry
extends RefCounted

const REGISTRY_PATH := "res://game/tile_registry.json"

var ids: Dictionary = {}
var next_id: int = 0

func _init() -> void:
	if not FileAccess.file_exists(REGISTRY_PATH):
		return
	var data := JsonOnloading.load_dict(REGISTRY_PATH)
	ids = data.get("ids", {})
	next_id = data.get("next_id", 0)

func get_id(tile_name: String) -> int:
	return ids.get(tile_name, -1)

func register(tile_name: String) -> int:
	if ids.has(tile_name):
		return ids[tile_name]
	var id := next_id
	ids[tile_name] = id
	next_id += 1
	return id

func save() -> void:
	JsonOnloading.write_dict(REGISTRY_PATH, {"ids": ids, "next_id": next_id})
