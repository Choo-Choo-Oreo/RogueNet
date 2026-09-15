@tool
extends Node2D

class_name DualGridRender

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer

const MASK_TO_CELL := {
	1: Vector2i(3, 3), 2: Vector2i(0, 2), 3: Vector2i(1, 2), 4: Vector2i(0, 0),
	5: Vector2i(3, 2), 6: Vector2i(2, 3), 7: Vector2i(3, 1), 8: Vector2i(1, 3),
	9: Vector2i(0, 1), 10: Vector2i(1, 0), 11: Vector2i(2, 2), 12: Vector2i(3, 0),
	13: Vector2i(2, 0), 14: Vector2i(1, 1), 15: Vector2i(2, 1),
}

func _ready():
	display_layer.position = Vector2(data_layer.tile_set.tile_size) / 2.0
	data_layer.changed.connect(refresh)
	refresh()
	
func refresh():
	if not is_instance_valid(display_layer):
		return
	display_layer.clear()
	var used_rect := data_layer.get_used_rect()
	for y in range(used_rect.position.y - 1, used_rect.end.y):
		var data_row := ""
		var mask_row := ""
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

			data_row += "#" if top_left else "."
			mask_row += ("%2d" % mask) if mask > 0 else " ."

			if mask == 0:
				continue
			display_layer.set_cell(Vector2i(x, y), 0, MASK_TO_CELL[mask])
		print(data_row)
		print(mask_row)
