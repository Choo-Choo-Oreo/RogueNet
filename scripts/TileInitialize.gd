@tool
extends Node2D

@export var tile_types: Array[TileType] = []

func _ready():
	var floor_data_layer := _get_or_build_shared_data_layer("FloorData")
	var wall_data_layer := _get_or_build_shared_data_layer("WallData")
	for tile_type in tile_types:
		var data_layer := floor_data_layer if tile_type.category == TileType.Category.FLOOR else wall_data_layer
		_ensure_pair(tile_type, data_layer)

func _get_or_build_shared_data_layer(layer_name: String) -> TileMapLayer:
	if has_node(layer_name):
		return get_node(layer_name)
	var data_layer := TileMapLayer.new()
	data_layer.name = layer_name
	data_layer.tile_set = TileSet.new()
	add_child(data_layer)
	data_layer.owner = get_tree().edited_scene_root
	return data_layer
		
func _ensure_pair(tile_type: TileType, data_layer: TileMapLayer) -> void:
	if tile_type == null or tile_type.tile_name == "":
		return
	if has_node(tile_type.tile_name):
		var existing := get_node(tile_type.tile_name)
		existing.z_index = tile_type.sort_order
		_apply_marker_appearance(data_layer, existing.source_id, tile_type)
		return

	var pair := DualGridRender.new()
	pair.name = tile_type.tile_name
	pair.z_index = tile_type.sort_order
	pair.source_id = _register_marker_source(data_layer, tile_type)

	var display_layer := TileMapLayer.new()
	display_layer.name = "DisplayLayer"
	display_layer.tile_set = _build_display_tile_set(tile_type)

	pair.data_layer = data_layer
	pair.display_layer = display_layer
	pair.add_child(display_layer)

	add_child(pair)
	pair.owner = get_tree().edited_scene_root
	display_layer.owner = get_tree().edited_scene_root
	
func _register_marker_source(data_layer: TileMapLayer, tile_type: TileType) -> int:
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://resources/gfx/placeholders/flat-color.png")
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	var source_id := data_layer.tile_set.add_source(source)
	_apply_marker_appearance(data_layer, source_id, tile_type)
	return source_id

func _apply_marker_appearance(data_layer: TileMapLayer, source_id: int, tile_type: TileType) -> void:
	var source := data_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	source.get_tile_data(Vector2i(0, 0), 0).modulate = tile_type.marker_color
	source.resource_name = tile_type.atlas_texture.resource_path.get_file() if tile_type.atlas_texture else tile_type.tile_name
	
func _build_display_tile_set(tile_type: TileType) -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = tile_type.atlas_texture
	source.texture_region_size = Vector2i(16, 16)
	for row in range(4):
		for col in range(4):
			source.create_tile(Vector2i(col, row))
			
	var tile_set := TileSet.new()
	tile_set.add_source(source)
	return tile_set
