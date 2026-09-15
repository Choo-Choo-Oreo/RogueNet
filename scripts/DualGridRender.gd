@tool
extends Node2D

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer

func _ready():
	display_layer.position = Vector2(data_layer.tile_set.tile_size) / 2.0
	data_layer.changed.connect(refresh)
	refresh()
	
func refresh():
	display_layer.clear()
	var used_rect := data_layer.get_used_rect()
	for y in range(used_rect.position.y - 1, used_rect.end.y):
		for x in range(used_rect.position.x - 1, used_rect.end.x):
			var top_left := data_layer.get_cell_source_id(Vector2i(x, y)) != -1
			var top_right := data_layer.get_cell_source_id(Vector2i(x + 1, y)) != -1
			var bottom_left := data_layer.get_cell_source_id(Vector2i(x, y + 1)) != -1
			var bottom_right := data_layer.get_cell_source_id(Vector2i(x + 1, y + 1)) != -1

			var mask := 0
			if top_left: mask += 1
			if top_right: mask += 2
			if bottom_left: mask += 4
			if bottom_right: mask += 8
			if mask == 0:
				continue
			
			display_layer.set_cell(Vector2i(x, y), 0, Vector2i(mask % 4, mask / 4))
