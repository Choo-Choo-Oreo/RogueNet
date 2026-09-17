extends Node2D

@onready var main = get_parent()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main.rect_paint_active:
		var min_cell := Vector2i(min(main.rect_paint_start_cell.x, main.rect_paint_current_cell.x), min(main.rect_paint_start_cell.y, main.rect_paint_current_cell.y))
		var max_cell := Vector2i(max(main.rect_paint_start_cell.x, main.rect_paint_current_cell.x), max(main.rect_paint_start_cell.y, main.rect_paint_current_cell.y))
		var preview_rect := Rect2(main.WORLD_OFFSET + Vector2(min_cell) * main.TILE_SIZE, Vector2(max_cell - min_cell + Vector2i(1, 1)) * main.TILE_SIZE)
		draw_rect(preview_rect, main.RECT_PREVIEW_FILL)
		draw_rect(preview_rect, main.RECT_PREVIEW_BORDER, false, 2.0)
	elif main.shape_drag_active:
		_draw_shape_preview()
	elif main.mouse_over_room:
		_draw_hover_ghost()
	if not main.multi_selected_indices.is_empty():
		_draw_multi_selection_highlight()
	if main.marquee_active:
		_draw_marquee()

func _draw_multi_selection_highlight() -> void:
	for index in main.multi_selected_indices:
		if index < 0 or index >= main.objects.size():
			continue
		var pos: Vector2 = main.objects[index]["position"]
		var center: Vector2 = main.WORLD_OFFSET + pos
		draw_arc(center, main.OBJECT_HIT_RADIUS + 3.0, 0.0, TAU, 24, main.OBJECT_SELECT_COLOR, 2.0)

func _draw_marquee() -> void:
	var min_pos := Vector2(min(main.marquee_start_world.x, main.marquee_current_world.x), min(main.marquee_start_world.y, main.marquee_current_world.y))
	var max_pos := Vector2(max(main.marquee_start_world.x, main.marquee_current_world.x), max(main.marquee_start_world.y, main.marquee_current_world.y))
	var marquee_rect := Rect2(main.WORLD_OFFSET + min_pos, max_pos - min_pos)
	draw_rect(marquee_rect, main.RECT_PREVIEW_FILL)
	draw_rect(marquee_rect, main.RECT_PREVIEW_BORDER, false, 1.5)

func _draw_hover_ghost() -> void:
	if main.connector_mode_active:
		if main._is_boundary_cell(main.hover_cell):
			var cell_rect := Rect2(main.WORLD_OFFSET + Vector2(main.hover_cell) * main.TILE_SIZE, Vector2(main.TILE_SIZE, main.TILE_SIZE))
			draw_rect(cell_rect, Color(main.CONNECTOR_MODE_COLOR.r, main.CONNECTOR_MODE_COLOR.g, main.CONNECTOR_MODE_COLOR.b, 0.35))
			draw_rect(cell_rect, main.CONNECTOR_MODE_COLOR, false, 2.0)
	elif main.object_mode_active:
		if main.selected_object_type != "" and main.OBJECT_MARKER_TEXTURES.has(main.selected_object_type):
			var icon: Texture2D = main._make_object_icon(main.selected_object_type)
			var center: Vector2 = main.WORLD_OFFSET + main.hover_world_pos
			draw_set_transform(center, deg_to_rad(main.pending_object_rotation), Vector2.ONE)
			draw_texture_rect(icon, Rect2(-Vector2(main.TILE_SIZE, main.TILE_SIZE) / 2.0, Vector2(main.TILE_SIZE, main.TILE_SIZE)), false, Color(1, 1, 1, 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif main.selected_object_type != "":
			draw_circle(main.WORLD_OFFSET + main.hover_world_pos, main.OBJECT_HIT_RADIUS, Color(main.OBJECT_MODE_COLOR.r, main.OBJECT_MODE_COLOR.g, main.OBJECT_MODE_COLOR.b, 0.5))
	elif main.eraser_active:
		var brush_rect: Rect2 = main._brush_world_rect(main.hover_cell)
		draw_rect(brush_rect, Color(main.ERASER_MODE_COLOR.r, main.ERASER_MODE_COLOR.g, main.ERASER_MODE_COLOR.b, 0.35))
		draw_rect(brush_rect, main.ERASER_MODE_COLOR, false, 2.0)
	elif main.selected_tile_name != "":
		var brush_rect: Rect2 = main._brush_world_rect(main.hover_cell)
		draw_rect(brush_rect, Color(main.PAINT_MODE_COLOR.r, main.PAINT_MODE_COLOR.g, main.PAINT_MODE_COLOR.b, 0.35))
		draw_rect(brush_rect, main.PAINT_MODE_COLOR, false, 2.0)

func _draw_shape_preview() -> void:
	if main.paint_tool == main.PaintTool.SELECT:
		var min_cell := Vector2i(min(main.shape_start_cell.x, main.shape_current_cell.x), min(main.shape_start_cell.y, main.shape_current_cell.y))
		var max_cell := Vector2i(max(main.shape_start_cell.x, main.shape_current_cell.x), max(main.shape_start_cell.y, main.shape_current_cell.y))
		var select_rect := Rect2(main.WORLD_OFFSET + Vector2(min_cell) * main.TILE_SIZE, Vector2(max_cell - min_cell + Vector2i(1, 1)) * main.TILE_SIZE)
		draw_rect(select_rect, main.RECT_PREVIEW_FILL)
		draw_rect(select_rect, main.RECT_PREVIEW_BORDER, false, 2.0)
		return
	var cells: Array = main._shape_cells(main.paint_tool, main.shape_start_cell, main.shape_current_cell)
	var color: Color = main.ERASER_MODE_COLOR if main.eraser_active else main.PAINT_MODE_COLOR
	for cell in cells:
		var cell_rect := Rect2(main.WORLD_OFFSET + Vector2(cell) * main.TILE_SIZE, Vector2(main.TILE_SIZE, main.TILE_SIZE))
		draw_rect(cell_rect, Color(color.r, color.g, color.b, 0.35))
		draw_rect(cell_rect, color, false, 1.0)
