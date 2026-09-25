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
## The tile's variant_weights (see TileType), set by TileInitialize.
var variant_weights: Array[float] = []
var _variants := 1
var overlay_layer: TileMapLayer

func set_overlay(layer: TileMapLayer) -> void:
	overlay_layer = layer
	overlay_layer.position = display_layer.position

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
	if not is_instance_valid(display_layer) or display_layer.tile_set == null:
		return
	var source := display_layer.tile_set.get_source(0) as TileSetAtlasSource
	if source and source.texture:
		_variants = maxi(1, int(source.texture.get_height() / 64.0))
	display_layer.clear()
	if overlay_layer:
		overlay_layer.clear()
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

## Redraws only what `cells` (data-layer cells that changed) can affect: each display quad touches
## the four cells around its corner, so a changed cell alters four quads. The layer's `changed`
## signal does not fire for runtime set_cell, so whoever changes cells calls this (TileDestruction).
func refresh_cells(cells: Array) -> void:
	if not is_instance_valid(display_layer) or display_layer.tile_set == null:
		return
	var touched := {}
	for cell: Vector2i in cells:
		for offset in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			touched[cell + offset] = true
	for pos: Vector2i in touched:
		for k in 4:
			var quad := pos * 2 + Vector2i(k & 1, k >> 1)
			display_layer.erase_cell(quad)
			if overlay_layer:
				overlay_layer.erase_cell(quad)
		_refresh_cell(pos)

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
		var cell := pos * 2 + q
		var atlas := c * 2 + q
		atlas.y += 8 * _pick_variant(cell)
		if mask == 15 and overlay_layer:
			overlay_layer.set_cell(cell, 0, Vector2i.ZERO)
		display_layer.set_cell(cell, 0, atlas)

func _pick_variant(cell: Vector2i) -> int:
	if _variants <= 1:
		return 0
	if variant_weights.is_empty():
		return (((cell.x * 73856093) ^ (cell.y * 19349663)) & 0x7fffffff) % _variants
	# hash() mixes well, so the rare sets don't line up in rows or a checkerboard
	var total := 0.0
	for i in _variants:
		total += _weight(i)
	var roll := float(hash(cell) & 0xffff) / 65536.0 * total
	for i in _variants:
		roll -= _weight(i)
		if roll < 0.0:
			return i
	return 0

func _weight(variant: int) -> float:
	return variant_weights[variant] if variant < variant_weights.size() else 1.0
