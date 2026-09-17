@tool
extends Node2D

class_name StaticTileRender

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var orientable: bool = false

func _ready():
	display_layer.position = Vector2(data_layer.tile_set.tile_size) / 2.0
	data_layer.changed.connect(_on_data_layer_changed)
	refresh()

func _on_data_layer_changed() -> void:
	refresh.call_deferred()

func refresh():
	if not is_instance_valid(display_layer):
		return
	display_layer.clear()
	var used_rect := data_layer.get_used_rect()
	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var cell := Vector2i(x, y)
			if data_layer.get_cell_source_id(cell) == source_id:
				var alt := 0
				if orientable and _is_vertical_run(cell):
					alt = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
				display_layer.set_cell(cell, 0, atlas_coords, alt)

func _is_vertical_run(cell: Vector2i) -> bool:
	var vertical_score := 0
	var horizontal_score := 0
	if data_layer.get_cell_source_id(cell + Vector2i(0, -1)) != -1:
		vertical_score += 1
	if data_layer.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
		vertical_score += 1
	if data_layer.get_cell_source_id(cell + Vector2i(-1, 0)) != -1:
		horizontal_score += 1
	if data_layer.get_cell_source_id(cell + Vector2i(1, 0)) != -1:
		horizontal_score += 1
	return vertical_score > horizontal_score
