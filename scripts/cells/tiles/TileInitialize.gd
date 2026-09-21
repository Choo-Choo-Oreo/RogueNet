@tool
extends Node2D
class_name TileInitialize

const SHADING_MATERIAL := preload("res://resources/shaders/normal_lit_material.tres")
const TILE_TYPES_DIR := "res://resources/tiles/"
const FRAME_TIME := 0.1
const OVERLAY_SHADER := preload("res://resources/shaders/overlay_anim.gdshader")

@export var tile_types: Array[TileType] = []
@export var tile_registry: TileTypeRegistry

var glow_sources := {}

func _ready():
	var types := tile_types if not tile_types.is_empty() else _discover_tile_types()
	var floor_data_layer := _get_or_build_shared_data_layer("FloorData")
	var wall_data_layer := _get_or_build_shared_data_layer("WallData")
	for tile_type in types:
		var data_layer := floor_data_layer if tile_type.category == TileType.Category.FLOOR else wall_data_layer
		_ensure_pair(tile_type, data_layer)
		if tile_type.glow_radius > 0.0:
			glow_sources[tile_registry.get_id(tile_type.tile_name)] = tile_type
	_link_wall_group(wall_data_layer)
	refresh_all()

func _discover_tile_types() -> Array[TileType]:
	var discovered: Array[TileType] = []
	var dir := DirAccess.open(TILE_TYPES_DIR)
	if dir == null:
		return discovered
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource := load(TILE_TYPES_DIR + file_name)
			if resource is TileType:
				discovered.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return discovered

func _link_wall_group(wall_data_layer: TileMapLayer) -> void:
	var group := {}
	for child in get_children():
		if child is DualGridRender and child.data_layer == wall_data_layer:
			group[child.source_id] = true
	var void_source := -1
	var void_node := get_node_or_null("floor_void")
	if void_node:
		void_source = void_node.source_id
	for child in get_children():
		if child is DualGridRender and child.data_layer == wall_data_layer:
			child.group_sources = group
			child.void_floor_source = void_source

func refresh_all() -> void:
	for child in get_children():
		if child.has_method("refresh"):
			child.refresh()

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
		if existing.display_layer:
			existing.display_layer.material = SHADING_MATERIAL
			existing.display_layer.tile_set = _build_display_tile_set(tile_type)
		if existing is StaticTileRender:
			existing.atlas_coords = tile_type.atlas_coords
			existing.orientable = tile_type.orientable
		_apply_marker_appearance(data_layer, existing.source_id, tile_type)
		_ensure_overlay(existing, tile_type)
		return

	var pair: Node2D
	if tile_type.shape == TileType.Shape.DUAL_GRID:
		pair = DualGridRender.new()
	else:
		pair = StaticTileRender.new()
	pair.name = tile_type.tile_name
	pair.z_index = tile_type.sort_order
	pair.source_id = _register_marker_source(data_layer, tile_type)
	if pair is StaticTileRender:
		pair.atlas_coords = tile_type.atlas_coords
		pair.orientable = tile_type.orientable

	var display_layer := TileMapLayer.new()
	display_layer.name = "DisplayLayer"
	display_layer.tile_set = _build_display_tile_set(tile_type)
	display_layer.material = SHADING_MATERIAL

	pair.data_layer = data_layer
	pair.display_layer = display_layer
	pair.add_child(display_layer)

	add_child(pair)
	pair.owner = get_tree().edited_scene_root
	display_layer.owner = get_tree().edited_scene_root
	_ensure_overlay(pair, tile_type)

# Overlay quads (lava embers) are animated by the shader from their world position, so the layer
# only marks which quads may show one. It has no owner, so it is rebuilt each run, never saved.
func _ensure_overlay(pair: Node, tile_type: TileType) -> void:
	var render := pair as DualGridRender
	if tile_type.overlay_texture == null or render == null:
		return
	var layer := pair.get_node_or_null("OverlayLayer") as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = "OverlayLayer"
		pair.add_child(layer)
	var source := TileSetAtlasSource.new()
	source.texture = tile_type.overlay_texture
	source.texture_region_size = Vector2i(8, 8)
	source.create_tile(Vector2i.ZERO)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(8, 8)
	tile_set.add_source(source)
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = OVERLAY_SHADER
	overlay_material.set_shader_parameter("overlay_tex", tile_type.overlay_texture)
	overlay_material.set_shader_parameter("frame_time", FRAME_TIME)
	overlay_material.set_shader_parameter("density", tile_type.overlay_density)
	layer.material = overlay_material
	render.set_overlay(layer)

func _register_marker_source(data_layer: TileMapLayer, tile_type: TileType) -> int:
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://resources/gfx/placeholders/flat-color.png")
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	var target_id := tile_registry.register(tile_type.tile_name) if tile_registry else -1
	var source_id := data_layer.tile_set.add_source(source, target_id)
	_apply_marker_appearance(data_layer, source_id, tile_type)
	return source_id

func _apply_marker_appearance(data_layer: TileMapLayer, source_id: int, tile_type: TileType) -> void:
	var source := data_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	source.get_tile_data(Vector2i(0, 0), 0).modulate = tile_type.marker_color
	source.resource_name = tile_type.atlas_texture.resource_path.get_file() if tile_type.atlas_texture else tile_type.tile_name

func _build_display_tile_set(tile_type: TileType) -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = tile_type.atlas_texture
	var quarters := tile_type.shape == TileType.Shape.DUAL_GRID
	source.texture_region_size = Vector2i(8, 8) if quarters else Vector2i(16, 16)
	if quarters:
		var frames := maxi(1, int(tile_type.atlas_texture.get_width() / 64.0))
		var rows := int(tile_type.atlas_texture.get_height() / 8.0)
		for row in range(rows):
			for col in range(8):
				var coords := Vector2i(col, row)
				source.create_tile(coords)
				if frames > 1:
					source.set_tile_animation_separation(coords, Vector2i(7, 0))
					source.set_tile_animation_frames_count(coords, frames)
					for f in range(frames):
						source.set_tile_animation_frame_duration(coords, f, FRAME_TIME)
	else:
		source.create_tile(tile_type.atlas_coords)

	var tile_set := TileSet.new()
	tile_set.add_source(source)
	tile_set.tile_size = Vector2i(8, 8) if quarters else Vector2i(16, 16)
	return tile_set
