@tool
extends Node2D

class_name DualGridRender

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer
@export var source_id: int = 0

const MASK_TO_CELL := {
	1: Vector2i(3, 3), 2: Vector2i(0, 2), 3: Vector2i(1, 2), 4: Vector2i(0, 0),
	5: Vector2i(3, 2), 6: Vector2i(2, 3), 7: Vector2i(3, 1), 8: Vector2i(1, 3),
	9: Vector2i(0, 1), 10: Vector2i(1, 0), 11: Vector2i(2, 2), 12: Vector2i(3, 0),
	13: Vector2i(2, 0), 14: Vector2i(1, 1), 15: Vector2i(2, 1),
}

const VOID := -2

func _cell_id(pos: Vector2i) -> int:
	var sid := data_layer.get_cell_source_id(pos)
	if sid != -1 or group_sources.is_empty():
		return sid
	var floor_layer := get_parent().get_node_or_null("FloorData") as TileMapLayer
	if floor_layer and floor_layer.get_cell_source_id(pos) == -1:
		return VOID
	return -1

var group_sources: Dictionary = {}

func _is_filled(sid: int) -> bool:
	if group_sources.is_empty():
		return sid == source_id
	return group_sources.has(sid) or sid == VOID

func _pieces(ids: Array[int]) -> Array[int]:
	var wall: Array[bool] = []
	for id in ids:
		wall.append(_is_filled(id))
	var groups: Array[int] = [1, 2, 4, 8]
	var joins := [
		[0, 2, true],                                         # left column: always join
		[1, 3, true],                                         # right column: always join
		[0, 1, ids[0] == ids[1] or (wall[2] and wall[3])],    # top row: conditional
		[2, 3, ids[2] == ids[3] or (wall[0] and wall[1])],    # bottom row: conditional
	]
	for j in joins:
		if j[2] and wall[j[0]] and wall[j[1]]:
			var merged: int = groups[j[0]] | groups[j[1]]
			for k in 4:
				if merged & (1 << k):
					groups[k] = merged
	var result: Array[int] = []
	for k in 4:
		if wall[k] and not result.has(groups[k]):
			result.append(groups[k])
	return result

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
	for y in range(used_rect.position.y - 1, used_rect.end.y):
		for x in range(used_rect.position.x - 1, used_rect.end.x):
			var ids: Array[int] = [
				_cell_id(Vector2i(x, y)),
				_cell_id(Vector2i(x + 1, y)),
				_cell_id(Vector2i(x, y + 1)),
				_cell_id(Vector2i(x + 1, y + 1)),
			]
			var mask := 0
			for piece in _pieces(ids):
				var best: int = -3
				for k in 4:
					if piece & (1 << k):
						best = max(best, ids[k])
				if best == source_id:
					mask |= piece
			if mask == 0:
				continue
			display_layer.set_cell(Vector2i(x, y), 0, MASK_TO_CELL[mask])
