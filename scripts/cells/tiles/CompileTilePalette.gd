@tool
extends EditorScript

const TILES_DIR := "res://resources/tiles/"
const REGISTRY_PATH := "res://resources/tiles/tile_type_registry.tres"
const OUTPUT_PATH := "res://game/tile_palette.json"

func _run() -> void:
	var registry: TileTypeRegistry = load(REGISTRY_PATH)
	var palette := {}

	var dir := DirAccess.open(TILES_DIR)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource := load(TILES_DIR + file_name)
			if resource is TileType:
				var tile_type: TileType = resource
				var id := registry.register(tile_type.tile_name)
				var entry := { "source_id": id }
				if tile_type.shape == TileType.Shape.STATIC:
					entry["atlas_coords"] = [tile_type.atlas_coords.x, tile_type.atlas_coords.y]
				palette[tile_type.tile_name] = entry
		file_name = dir.get_next()
	dir.list_dir_end()

	ResourceSaver.save(registry, REGISTRY_PATH)

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(palette, "\t"))
	file.close()

	print("Compiled tile palette: ", palette.size(), " entries -> ", OUTPUT_PATH)
