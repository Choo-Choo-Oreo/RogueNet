@tool
extends EditorScript

const TILES_DIR := "res://game/tiles/"
const OUTPUT_PATH := "res://game/tile_palette.json"

func _run() -> void:
	var registry := TileTypeRegistry.new()
	var palette := {}

	var dir := DirAccess.open(TILES_DIR)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var tile_type := TileType.new()
			tile_type.load_from_file(TILES_DIR + file_name)
			var id := registry.register(tile_type.tile_name)
			var entry := { "source_id": id }
			if tile_type.shape == TileType.Shape.STATIC:
				entry["atlas_coords"] = [tile_type.atlas_coords.x, tile_type.atlas_coords.y]
			palette[tile_type.tile_name] = entry
		file_name = dir.get_next()
	dir.list_dir_end()

	registry.save()

	JsonOnloading.write_dict(OUTPUT_PATH, palette)

	print("Compiled tile palette: ", palette.size(), " entries -> ", OUTPUT_PATH)
