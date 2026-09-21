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
	var floor_layer := _floor_layer
	if floor_layer:
		var floor_sid := floor_layer.get_cell_source_id(pos)
		if floor_sid == -1 or floor_sid == void_floor_source:
			return VOID
	return -1

var group_sources: Dictionary = {}
var void_floor_source: int = -1

func _is_filled(sid: int) -> bool:
	if group_sources.is_empty():
		return sid == source_id
	return group_sources.has(sid) or sid == VOID

var _floor_layer: TileMapLayer

func _ready():
	display_layer.position = Vector2(data_layer.tile_set.tile_size) / 2.0
	data_layer.changed.connect(_on_data_layer_changed)
	_floor_layer = get_parent().get_node_or_null("FloorData") as TileMapLayer
	refresh()

var _refresh_queued := false

func _on_data_layer_changed() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_run_queued_refresh.call_deferred()

func _run_queued_refresh() -> void:
	_refresh_queued = false
	refresh()
	
func refresh():
	if not is_instance_valid(display_layer):
		return
	display_layer.clear()
	if group_sources.is_empty():
		var touched := {}
		for cell in data_layer.get_used_cells_by_id(source_id):
			for offset in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				touched[cell + offset] = true
		for pos in touched:
			_refresh_cell(pos)
	else:
		var used_rect := data_layer.get_used_rect()
		for y in range(used_rect.position.y - 1, used_rect.end.y):
			for x in range(used_rect.position.x - 1, used_rect.end.x):
				_refresh_cell(Vector2i(x, y))

func _refresh_cell(pos: Vector2i) -> void:
	var ids: Array[int] = [
		_cell_id(pos),
		_cell_id(pos + Vector2i(1, 0)),
		_cell_id(pos + Vector2i(0, 1)),
		_cell_id(pos + Vector2i(1, 1)),
	]
	var mask := 0
	for k in 4:
		if _is_filled(ids[k]):
			mask |= 1 << k
	if mask == 0:
		return
	var c: Vector2i = MASK_TO_CELL[mask]
	for k in 4:
		if not group_sources.is_empty() and ids[k] != source_id:
			continue
		var q := Vector2i(k & 1, k >> 1)
		display_layer.set_cell(pos * 2 + q, 0, c * 2 + q)
