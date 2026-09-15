@tool
extends Node2D

@export var tile_types: Array[TileType] = []

func _ready():
	for tile_type in tile_types:
		_ensure_pair(tile_type)
		
func _ensure_pair(tile_type: TileType) -> void:
	if tile_type == null or tile_type.tile_name == "":
		return
	if has_node(tile_type.tile_name):
		return
		
	var pair := DualGridRender.new()
	pair.name = tile_type.tile_name
	
	var data_layer := TileMapLayer.new()
	data_layer.name = "DataLayer"
	data_layer.tile_set = _build_marker_tile_set()
	
	var display_layer := TileMapLayer.new()
	display_layer.name = "DisplayLayer"
	display_layer.tile_set = _build_display_tile_set(tile_type)
	
	pair.data_layer = data_layer
	pair.display_layer = display_layer
	pair.add_child(data_layer)
	pair.add_child(display_layer)
	
	add_child(pair)
	pair.owner = get_tree().edited_scene_root
	data_layer.owner = get_tree().edited_scene_root
	display_layer.owner = get_tree().edited_scene_root
	
func _build_marker_tile_set() -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://resources/gfx/placeholders/flat-color-yellow.png")
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	
	var tile_set := TileSet.new()
	tile_set.add_source(source)
	return tile_set
	
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
