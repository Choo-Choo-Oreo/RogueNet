@tool
extends Node2D

class_name StaticTileRender

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var orientable: bool = false

func _ready():
	data_layer.changed.connect(_on_data_layer_changed)
	refresh()

func _on_data_layer_changed() -> void:
	refresh.call_deferred()

## Redraws just `cells`; see DualGridRender.refresh_cells.
func refresh_cells(cells: Array) -> void:
	if not is_instance_valid(display_layer):
		return
	for cell: Vector2i in cells:
		display_layer.erase_cell(cell)
		if data_layer.get_cell_source_id(cell) == source_id:
			var alt := data_layer.get_cell_alternative_tile(cell) if orientable else 0
			display_layer.set_cell(cell, 0, atlas_coords, alt)

func refresh():
	if not is_instance_valid(display_layer):
		return
	display_layer.clear()
	var used_rect := data_layer.get_used_rect()
	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var cell := Vector2i(x, y)
			if data_layer.get_cell_source_id(cell) == source_id:
				# The orientation isn't guessable from neighboring wall shape
				# alone (that can't tell north from south or east from west) —
				# whoever painted this cell already knows which way it should
				# face and encodes it as the data layer's alternative tile.
				var alt := data_layer.get_cell_alternative_tile(cell) if orientable else 0
				display_layer.set_cell(cell, 0, atlas_coords, alt)
