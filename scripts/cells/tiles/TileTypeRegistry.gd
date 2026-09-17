@tool
extends Resource
class_name TileTypeRegistry

@export var ids: Dictionary = {}
@export var next_id: int = 0

func get_id(tile_name: String) -> int:
	return ids.get(tile_name, -1)

func register(tile_name: String) -> int:
	if ids.has(tile_name):
		return ids[tile_name]
	var id := next_id
	ids[tile_name] = id
	next_id += 1
	return id
