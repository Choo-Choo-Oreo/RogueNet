@tool
extends Node2D

class_name StaticTileRender

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO

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
			if data_layer.get_cell_source_id(Vector2i(x, y)) == source_id:
				display_layer.set_cell(Vector2i(x, y), 0, atlas_coords)
