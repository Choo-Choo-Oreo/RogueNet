extends Node2D

const TILE_SIZE := 16
const OBJECT_HIT_RADIUS := 8.0
const PALETTE_PATH := "res://game/tile_palette.json"
const WORLD_OFFSET := Vector2(16, 550)
const ROOM_FILL_COLOR := Color(0.26, 0.32, 0.26, 1.0)
const ROOM_OUTSIDE_COLOR := Color(0.14, 0.14, 0.16, 1.0)
const OUTSIDE_PADDING := 2500.0
const GRID_LINE_COLOR := Color(1, 1, 1, 0.08)
const ROOM_BORDER_COLOR := Color(0.9, 0.85, 0.3, 1.0)
const RECT_PREVIEW_FILL := Color(1, 1, 1, 0.25)
const RECT_PREVIEW_BORDER := Color(1, 1, 1, 0.9)
const OBJECT_MARKER_TEXTURES := {
	"torch": "res://resources/gfx/objects/Tortch.png",
	"chest": "res://resources/gfx/objects/Chest_Wood.png",
}
const CONNECTOR_TEXTURE_PATH := "res://resources/gfx/objects/Door.png"
const PLAYER_SPAWNER_TEXTURE_PATH := "res://resources/gfx/players/knight/Walking South.png"
const PLAYER_CONTROLLER_SCENE_PATH := "res://scenes/player/PlayerController.tscn"
const PLACEHOLDER_ENEMY_SCENE_PATH := "res://scenes/dungeon/PlaceholderMouse.tscn"
const ENEMY_TYPE_NAMES := ["mouse"]
const CAMERA_ZOOM_MIN := 0.25
const CAMERA_ZOOM_MAX := 3.0
const CAMERA_ZOOM_STEP := 0.9
const PAN_MARGIN_TILES := 10
const PAN_SPEED := 0.5
const PAN_SPEED_FLOOR := 0.15
const ROTATE_STEP_DEGREES := 45.0
const NUDGE_STEP := 4.0
const BRUSH_SIZE_MIN := 1
const BRUSH_SIZE_MAX := 5

const PAINT_MODE_COLOR := Color(0.3, 0.7, 0.95)
const OBJECT_MODE_COLOR := Color(0.95, 0.65, 0.2)
const CONNECTOR_MODE_COLOR := Color(0.35, 0.9, 0.55)
const ERASER_MODE_COLOR := Color(0.95, 0.35, 0.35)
const OBJECT_SELECT_COLOR := Color(1, 1, 0.3, 0.95)
const SPAWNER_MODE_COLOR := Color(0.85, 0.35, 0.85)

@onready var camera: Camera2D = $Camera2D
@onready var room_file_dialog: FileDialog = $RoomFileDialog

@onready var room_info_header: Button = $UI/LeftPanel/RoomInfoHeader
@onready var room_info: VBoxContainer = $UI/LeftPanel/RoomInfo
@onready var palette_header: Button = $UI/LeftPanel/PaletteHeader
@onready var palette_section: VBoxContainer = $UI/LeftPanel/PaletteSection
@onready var object_header: Button = $UI/RightPanel/ObjectHeader
@onready var object_section: VBoxContainer = $UI/RightPanel/ObjectSection
@onready var connector_header: Button = $UI/RightPanel/ConnectorHeader
@onready var connector_section: VBoxContainer = $UI/RightPanel/ConnectorSection
@onready var export_header: Button = $UI/RightPanel/ExportHeader
@onready var export_section: VBoxContainer = $UI/RightPanel/ExportSection

@onready var width_spin_box: SpinBox = $UI/LeftPanel/RoomInfo/WidthRow/WidthSpinBox
@onready var height_spin_box: SpinBox = $UI/LeftPanel/RoomInfo/HeightRow/HeightSpinBox
@onready var id_line_edit: LineEdit = $UI/LeftPanel/RoomInfo/IdRow/IdLineEdit
@onready var template_option: OptionButton = $UI/LeftPanel/RoomInfo/TemplateRow/TemplateOption
@onready var tag_line_edit: LineEdit = $UI/LeftPanel/RoomInfo/TagsSection/TagInputRow/TagLineEdit
@onready var tags_list: ItemList = $UI/LeftPanel/RoomInfo/TagsSection/TagsList
@onready var known_tags_list: ItemList = $UI/LeftPanel/RoomInfo/TagsSection/KnownTagsList
@onready var validation_label: Label = $UI/LeftPanel/RoomInfo/ValidationLabel
@onready var recent_rooms_list: ItemList = $UI/LeftPanel/RoomInfo/RecentRoomsList
@onready var floor_palette_list: ItemList = $UI/LeftPanel/PaletteSection/FloorPaletteList
@onready var wall_palette_list: ItemList = $UI/LeftPanel/PaletteSection/WallPaletteList
@onready var eraser_button: Button = $UI/LeftPanel/PaletteSection/EraserButton
@onready var floor_data_layer: TileMapLayer = $TileRenderer/FloorData
@onready var wall_data_layer: TileMapLayer = $TileRenderer/WallData
@onready var tile_renderer: Node2D = $TileRenderer
@onready var objects_layer: Node2D = $ObjectsLayer
@onready var object_palette_list: ItemList = $UI/RightPanel/ObjectSection/ObjectPaletteList
@onready var objects_list: ItemList = $UI/RightPanel/ObjectSection/ObjectsList
@onready var snap_toggle_button: Button = $UI/RightPanel/ObjectSection/SnapToggleButton
@onready var connectors_layer: Node2D = $ConnectorsLayer
@onready var connectors_list: ItemList = $UI/RightPanel/ConnectorSection/ConnectorsList
@onready var connector_mode_button: Button = $UI/RightPanel/ConnectorSection/ConnectorModeButton
@onready var export_status_label: Label = $UI/RightPanel/ExportSection/ExportStatusLabel
@onready var overwrite_confirm_dialog: ConfirmationDialog = $OverwriteConfirmDialog
@onready var overlay: Node2D = $Overlay
@onready var spawners_layer: Node2D = $SpawnersLayer
@onready var spawner_header: Button = $UI/RightPanel/SpawnerHeader
@onready var spawner_section: VBoxContainer = $UI/RightPanel/SpawnerSection
@onready var spawner_palette_list: ItemList = $UI/RightPanel/SpawnerSection/SpawnerPaletteList
@onready var spawners_list: ItemList = $UI/RightPanel/SpawnerSection/SpawnersList
@onready var test_button: Button = $UI/TestButton
@onready var spawner_settings_dialog: ConfirmationDialog = $SpawnerSettingsDialog
@onready var enemy_type_option: OptionButton = $SpawnerSettingsDialog/SettingsVBox/EnemyTypeRow/EnemyTypeOption
@onready var interval_spin_box: SpinBox = $SpawnerSettingsDialog/SettingsVBox/IntervalRow/IntervalSpinBox
@onready var count_spin_box: SpinBox = $SpawnerSettingsDialog/SettingsVBox/CountRow/CountSpinBox
@onready var test_hud: CanvasLayer = $TestHUD

var width: int = 5
var height: int = 5
var room_id: String = ""
var tags: Array[String] = []
var floor_names: Array = []
var walls_names: Array = []

var palette: Dictionary = {}
var floor_tile_names: Array = []
var wall_tile_names: Array = []
var object_type_names: Array = []
var selected_layer: String = ""
var selected_tile_name: String = ""
var eraser_active: bool = false
var brush_size: int = 1

var rect_paint_active: bool = false
var rect_paint_start_cell: Vector2i = Vector2i.ZERO
var rect_paint_current_cell: Vector2i = Vector2i.ZERO

enum PaintTool { FREEHAND, LINE, BOX, CIRCLE, SELECT }
var paint_tool: int = PaintTool.FREEHAND
var shape_drag_active: bool = false
var shape_start_cell: Vector2i = Vector2i.ZERO
var shape_current_cell: Vector2i = Vector2i.ZERO

var clipboard_floor: Array = []
var clipboard_walls: Array = []
var clipboard_size: Vector2i = Vector2i.ZERO
var has_clipboard: bool = false

var object_mode_active: bool = false
var objects: Array = []
var object_markers: Array[Node2D] = []
var selected_object_type: String = ""
var object_snap_active: bool = false
var pending_object_rotation: float = 0.0

var multi_selected_indices: Array[int] = []
var marquee_active: bool = false
var marquee_start_world: Vector2 = Vector2.ZERO
var marquee_current_world: Vector2 = Vector2.ZERO
var group_drag_active: bool = false
var group_drag_start_mouse: Vector2 = Vector2.ZERO
var group_drag_start_positions: Dictionary = {}

var connector_mode_active: bool = false
var connectors: Array = []
var connector_markers: Array[Node2D] = []

var spawner_mode_active: bool = false
var selected_spawner_type: String = ""

var has_player_spawner: bool = false
var player_spawner_cell: Vector2i = Vector2i.ZERO
var player_spawner_marker: Sprite2D = null

var enemy_spawners: Array = []
var enemy_spawner_markers: Array[Node2D] = []
var editing_spawner_index: int = -1

var test_mode_active: bool = false
var test_player: Node = null
var test_spawn_timers: Array[Timer] = []
var test_spawned_enemies: Array[Node] = []

var camera_dragging: bool = false
var camera_bounds_min: Vector2 = Vector2.ZERO
var camera_bounds_max: Vector2 = Vector2.ZERO

var hover_cell: Vector2i = Vector2i(-999, -999)
var hover_world_pos: Vector2 = Vector2.ZERO
var mouse_over_room: bool = false

var undo_stack: Array = []
var redo_stack: Array = []

var pending_export_data: Dictionary = {}
var pending_export_path: String = ""

func _ready() -> void:
	floor_names = _make_grid(width, height)
	walls_names = _make_grid(width, height)
	palette = _load_palette()
	_populate_palette_lists()
	_populate_object_palette()
	_populate_spawner_palette()
	_update_test_button()
	_setup_template_option()
	_setup_room_file_dialog()
	_setup_overwrite_confirm_dialog()
	_style_mode_button(connector_mode_button, CONNECTOR_MODE_COLOR)
	_style_mode_button(eraser_button, ERASER_MODE_COLOR)
	_update_camera_bounds()
	camera.position = WORLD_OFFSET + Vector2(width, height) * TILE_SIZE / 2.0
	camera.make_current()
	_update_validation_display()
	_refresh_recent_rooms()
	_refresh_known_tags()
	queue_redraw()

func _update_camera_bounds() -> void:
	var margin := Vector2(PAN_MARGIN_TILES, PAN_MARGIN_TILES) * TILE_SIZE
	camera_bounds_min = WORLD_OFFSET - margin
	camera_bounds_max = WORLD_OFFSET + Vector2(width, height) * TILE_SIZE + margin

func _clamp_camera_position() -> void:
	camera.position = camera.position.clamp(camera_bounds_min, camera_bounds_max)

func _draw() -> void:
	var outside_rect := Rect2(WORLD_OFFSET - Vector2(OUTSIDE_PADDING, OUTSIDE_PADDING), Vector2(width * TILE_SIZE, height * TILE_SIZE) + Vector2(OUTSIDE_PADDING, OUTSIDE_PADDING) * 2.0)
	draw_rect(outside_rect, ROOM_OUTSIDE_COLOR)
	var rect := Rect2(WORLD_OFFSET, Vector2(width * TILE_SIZE, height * TILE_SIZE))
	draw_rect(rect, ROOM_FILL_COLOR)
	_draw_grid_lines(rect)
	draw_rect(rect, ROOM_BORDER_COLOR, false, 2.0)

func _draw_grid_lines(rect: Rect2) -> void:
	for x in range(1, width):
		var px: float = rect.position.x + x * TILE_SIZE
		draw_line(Vector2(px, rect.position.y), Vector2(px, rect.position.y + rect.size.y), GRID_LINE_COLOR, 1.0)
	for y in range(1, height):
		var py: float = rect.position.y + y * TILE_SIZE
		draw_line(Vector2(rect.position.x, py), Vector2(rect.position.x + rect.size.x, py), GRID_LINE_COLOR, 1.0)

func _brush_cells(center: Vector2i) -> Array:
	var half := brush_size - 1
	var cells := []
	for y in range(center.y - half, center.y + half + 1):
		for x in range(center.x - half, center.x + half + 1):
			cells.append(Vector2i(x, y))
	return cells

func _brush_world_rect(center: Vector2i) -> Rect2:
	var half := brush_size - 1
	var top_left := Vector2i(center.x - half, center.y - half)
	var side := brush_size * 2 - 1
	return Rect2(WORLD_OFFSET + Vector2(top_left) * TILE_SIZE, Vector2(side, side) * TILE_SIZE)

func _shape_cells(tool: int, start: Vector2i, current: Vector2i) -> Array:
	match tool:
		PaintTool.LINE:
			return _line_cells(start, current)
		PaintTool.BOX:
			return _box_outline_cells(start, current)
		PaintTool.CIRCLE:
			return _circle_outline_cells(start, current)
		_:
			return []

func _line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var cells := []
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return cells

func _box_outline_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var min_x: int = min(from_cell.x, to_cell.x)
	var max_x: int = max(from_cell.x, to_cell.x)
	var min_y: int = min(from_cell.y, to_cell.y)
	var max_y: int = max(from_cell.y, to_cell.y)
	var cells := []
	for x in range(min_x, max_x + 1):
		cells.append(Vector2i(x, min_y))
		cells.append(Vector2i(x, max_y))
	for y in range(min_y + 1, max_y):
		cells.append(Vector2i(min_x, y))
		cells.append(Vector2i(max_x, y))
	return cells

func _circle_outline_cells(center_cell: Vector2i, edge_cell: Vector2i) -> Array:
	var radius: int = int(round(Vector2(edge_cell - center_cell).length()))
	if radius <= 0:
		return [center_cell]
	var cells := {}
	var x := radius
	var y := 0
	var err := 0
	while x >= y:
		_add_circle_octants(cells, center_cell, x, y)
		y += 1
		if err <= 0:
			err += 2 * y + 1
		if err > 0:
			x -= 1
			err -= 2 * x + 1
	return cells.keys()

func _add_circle_octants(cells: Dictionary, c: Vector2i, x: int, y: int) -> void:
	cells[c + Vector2i(x, y)] = true
	cells[c + Vector2i(y, x)] = true
	cells[c + Vector2i(-y, x)] = true
	cells[c + Vector2i(-x, y)] = true
	cells[c + Vector2i(-x, -y)] = true
	cells[c + Vector2i(-y, -x)] = true
	cells[c + Vector2i(y, -x)] = true
	cells[c + Vector2i(x, -y)] = true

func _style_mode_button(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.55)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover_pressed", style)

func _load_palette() -> Dictionary:
	var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open %s" % PALETTE_PATH)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}

func _populate_palette_lists() -> void:
	_style_selection_highlight(floor_palette_list, PAINT_MODE_COLOR)
	_style_selection_highlight(wall_palette_list, PAINT_MODE_COLOR)
	floor_palette_list.fixed_icon_size = Vector2i(16, 16)
	wall_palette_list.fixed_icon_size = Vector2i(16, 16)
	for tile_name in palette.keys():
		if tile_name.begins_with("floor_"):
			floor_tile_names.append(tile_name)
		elif tile_name.begins_with("wall_"):
			wall_tile_names.append(tile_name)
	_rebuild_floor_palette_list("")
	_rebuild_wall_palette_list("")

func _rebuild_floor_palette_list(filter_text: String) -> void:
	floor_palette_list.clear()
	for tile_name in floor_tile_names:
		if filter_text != "" and not tile_name.to_lower().contains(filter_text.to_lower()):
			continue
		floor_palette_list.add_item(tile_name, _make_tile_icon(floor_data_layer.tile_set, palette[tile_name]["source_id"]))

func _rebuild_wall_palette_list(filter_text: String) -> void:
	wall_palette_list.clear()
	for tile_name in wall_tile_names:
		if filter_text != "" and not tile_name.to_lower().contains(filter_text.to_lower()):
			continue
		wall_palette_list.add_item(tile_name, _make_tile_icon(wall_data_layer.tile_set, palette[tile_name]["source_id"]))

func _on_floor_search_changed(new_text: String) -> void:
	_rebuild_floor_palette_list(new_text.strip_edges())

func _on_wall_search_changed(new_text: String) -> void:
	_rebuild_wall_palette_list(new_text.strip_edges())

func _make_tile_icon(tile_set: TileSet, source_id: int) -> Texture2D:
	var color := Color.WHITE
	if tile_set != null:
		var source := tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
			if tile_data:
				color = tile_data.modulate
	return _make_color_swatch(color)

func _make_color_swatch(color: Color) -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _populate_object_palette() -> void:
	_style_selection_highlight(object_palette_list, OBJECT_MODE_COLOR)
	for object_type in OBJECT_MARKER_TEXTURES.keys():
		object_type_names.append(object_type)
	_rebuild_object_palette_list("")

func _rebuild_object_palette_list(filter_text: String) -> void:
	object_palette_list.clear()
	for object_type in object_type_names:
		if filter_text != "" and not object_type.to_lower().contains(filter_text.to_lower()):
			continue
		object_palette_list.add_item(object_type, _make_object_icon(object_type))

func _on_object_search_changed(new_text: String) -> void:
	_rebuild_object_palette_list(new_text.strip_edges())

func _style_selection_highlight(item_list: ItemList, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.25)
	style.border_color = color
	style.set_border_width_all(2)
	item_list.add_theme_stylebox_override("selected", style)
	item_list.add_theme_stylebox_override("selected_focus", style)

func _make_object_icon(object_type: String) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(OBJECT_MARKER_TEXTURES[object_type])
	atlas.region = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
	return atlas

func _on_object_palette_selected(index: int) -> void:
	selected_object_type = object_palette_list.get_item_text(index)
	pending_object_rotation = 0.0
	_set_object_mode_active(true)
	queue_redraw()

func _setup_template_option() -> void:
	template_option.clear()
	template_option.add_item("Blank", 0)
	template_option.add_item("Hollow Box", 1)

func _setup_room_file_dialog() -> void:
	room_file_dialog.access = FileDialog.ACCESS_RESOURCES
	room_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	room_file_dialog.add_filter("*.json", "Room JSON")
	room_file_dialog.current_dir = "res://game/rooms"
	room_file_dialog.file_selected.connect(_on_room_file_selected)

func _setup_overwrite_confirm_dialog() -> void:
	overwrite_confirm_dialog.confirmed.connect(_on_overwrite_confirmed)

func _refresh_recent_rooms() -> void:
	recent_rooms_list.clear()
	var dir := DirAccess.open("res://game/rooms")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			recent_rooms_list.add_item(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_recent_room_selected(index: int) -> void:
	var file_name := recent_rooms_list.get_item_text(index)
	_on_room_file_selected("res://game/rooms/" + file_name)

func _refresh_known_tags() -> void:
	var seen := {}
	var dir := DirAccess.open("res://game/rooms")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file := FileAccess.open("res://game/rooms/" + file_name, FileAccess.READ)
				if file != null:
					var data = JSON.parse_string(file.get_as_text())
					if data is Dictionary:
						for tag in data.get("tags", []):
							seen[str(tag)] = true
			file_name = dir.get_next()
		dir.list_dir_end()
	known_tags_list.clear()
	var tag_names := seen.keys()
	tag_names.sort()
	for tag_name in tag_names:
		known_tags_list.add_item(tag_name)

func _on_known_tag_selected(index: int) -> void:
	var tag: String = known_tags_list.get_item_text(index)
	if tag == "" or tags.has(tag):
		return
	tags.append(tag)
	tags_list.add_item(tag)

func _make_grid(grid_width: int, grid_height: int) -> Array:
	var grid := []
	for y in range(grid_height):
		var row := []
		row.resize(grid_width)
		row.fill(null)
		grid.append(row)
	return grid

func _resize_room_data(new_width: int, new_height: int) -> void:
	var new_floor := _make_grid(new_width, new_height)
	var new_walls := _make_grid(new_width, new_height)
	for y in range(min(height, new_height)):
		for x in range(min(width, new_width)):
			new_floor[y][x] = floor_names[y][x]
			new_walls[y][x] = walls_names[y][x]
	width = new_width
	height = new_height
	floor_names = new_floor
	walls_names = new_walls
	_prune_invalid_connectors()
	_prune_invalid_spawners()
	_update_camera_bounds()
	_clamp_camera_position()
	_update_validation_display()
	queue_redraw()

func _on_width_changed(value: float) -> void:
	_resize_room_data(int(value), height)

func _on_height_changed(value: float) -> void:
	_resize_room_data(width, int(value))

func _on_id_changed(new_text: String) -> void:
	room_id = new_text
	_update_validation_display()

func _on_add_tag_pressed() -> void:
	var tag := tag_line_edit.text.strip_edges()
	if tag == "" or tags.has(tag):
		return
	tags.append(tag)
	tags_list.add_item(tag)
	tag_line_edit.clear()

func _on_remove_tag_pressed() -> void:
	var selected := tags_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	tags.remove_at(index)
	tags_list.remove_item(index)

func _on_apply_template_pressed() -> void:
	var old_floor = floor_names.duplicate(true)
	var old_walls = walls_names.duplicate(true)
	var new_floor := _make_grid(width, height)
	var new_walls := _make_grid(width, height)
	if template_option.get_selected_id() == 1:
		for y in range(height):
			for x in range(width):
				if x == 0 or x == width - 1 or y == 0 or y == height - 1:
					new_walls[y][x] = "wall_cobble_brick"
				else:
					new_floor[y][x] = "floor_dirt"
	_restore_grids(new_floor, new_walls)
	_push_undo(
		func(): _restore_grids(old_floor, old_walls),
		func(): _restore_grids(new_floor, new_walls)
	)
	queue_redraw()

func _on_flip_horizontal_pressed() -> void:
	_flip_room(true)

func _on_flip_vertical_pressed() -> void:
	_flip_room(false)

func _flip_room(horizontal: bool) -> void:
	var old_floor = floor_names.duplicate(true)
	var old_walls = walls_names.duplicate(true)
	var new_floor := _make_grid(width, height)
	var new_walls := _make_grid(width, height)
	for y in range(height):
		for x in range(width):
			var src_x: int = width - 1 - x if horizontal else x
			var src_y: int = y if horizontal else height - 1 - y
			new_floor[y][x] = floor_names[src_y][src_x]
			new_walls[y][x] = walls_names[src_y][src_x]
	_restore_grids(new_floor, new_walls)
	_push_undo(
		func(): _restore_grids(old_floor, old_walls),
		func(): _restore_grids(new_floor, new_walls)
	)
	_show_export_status("Flipped tiles %s (objects/connectors unchanged)" % ("horizontally" if horizontal else "vertically"))
	queue_redraw()

func _restore_grids(new_floor: Array, new_walls: Array) -> void:
	floor_names = new_floor.duplicate(true)
	walls_names = new_walls.duplicate(true)
	floor_data_layer.clear()
	wall_data_layer.clear()
	for y in range(height):
		for x in range(width):
			var f = floor_names[y][x]
			if f != null and palette.has(f):
				floor_data_layer.set_cell(Vector2i(x, y), palette[f]["source_id"], Vector2i.ZERO)
			var w = walls_names[y][x]
			if w != null and palette.has(w):
				var cell := Vector2i(x, y)
				var alt := _door_orientation_alt(cell) if DOOR_TILE_NAMES.has(w) else 0
				wall_data_layer.set_cell(cell, palette[w]["source_id"], Vector2i.ZERO, alt)
	tile_renderer.refresh_all()
	_update_validation_display()

func _on_room_info_header_toggled(pressed: bool) -> void:
	_set_section_expanded(room_info_header, room_info, pressed, "Room Info")

func _on_palette_header_toggled(pressed: bool) -> void:
	_set_section_expanded(palette_header, palette_section, pressed, "Tile Palette")

func _on_object_header_toggled(pressed: bool) -> void:
	_set_section_expanded(object_header, object_section, pressed, "Objects")

func _on_connector_header_toggled(pressed: bool) -> void:
	_set_section_expanded(connector_header, connector_section, pressed, "Connectors")

func _on_export_header_toggled(pressed: bool) -> void:
	_set_section_expanded(export_header, export_section, pressed, "Export")

func _set_section_expanded(header: Button, body: Control, pressed: bool, label: String) -> void:
	body.visible = pressed
	header.text = ("▾ " if pressed else "▸ ") + label

func _on_eraser_toggled(pressed: bool) -> void:
	eraser_active = pressed
	if pressed:
		_set_object_mode_active(false)
	queue_redraw()

func _on_floor_palette_selected(index: int) -> void:
	selected_layer = "floor"
	selected_tile_name = floor_palette_list.get_item_text(index)
	wall_palette_list.deselect_all()
	eraser_button.button_pressed = false
	eraser_active = false
	_set_object_mode_active(false)
	queue_redraw()

func _on_wall_palette_selected(index: int) -> void:
	selected_layer = "wall"
	selected_tile_name = wall_palette_list.get_item_text(index)
	floor_palette_list.deselect_all()
	eraser_button.button_pressed = false
	eraser_active = false
	_set_object_mode_active(false)
	queue_redraw()

func _on_tool_freehand_pressed() -> void:
	paint_tool = PaintTool.FREEHAND

func _on_tool_line_pressed() -> void:
	paint_tool = PaintTool.LINE

func _on_tool_box_pressed() -> void:
	paint_tool = PaintTool.BOX

func _on_tool_circle_pressed() -> void:
	paint_tool = PaintTool.CIRCLE

func _on_tool_select_pressed() -> void:
	paint_tool = PaintTool.SELECT

func _unhandled_input(event: InputEvent) -> void:
	if test_mode_active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_stop_test()
		return
	if event is InputEventMouseMotion:
		_update_hover()
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_shortcut(event):
			return
	_handle_camera_input(event)
	if connector_mode_active:
		_handle_connector_input(event)
	elif object_mode_active:
		_handle_object_input(event)
	elif spawner_mode_active:
		_handle_spawner_input(event)
	else:
		_handle_paint_input(event)

func _update_hover() -> void:
	hover_world_pos = get_global_mouse_position() - WORLD_OFFSET
	hover_cell = _mouse_to_cell()
	mouse_over_room = hover_cell.x >= 0 and hover_cell.x < width and hover_cell.y >= 0 and hover_cell.y < height
	queue_redraw()

func _handle_shortcut(event: InputEventKey) -> bool:
	if event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed:
		_undo()
		return true
	if event.ctrl_pressed and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)):
		_redo()
		return true
	if event.ctrl_pressed and event.keycode == KEY_V:
		_paste_clipboard()
		return true
	if event.ctrl_pressed and event.keycode == KEY_D:
		_duplicate_multi_selection()
		return true
	if event.keycode == KEY_DELETE:
		_delete_selected()
		return true
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT or event.keycode == KEY_UP or event.keycode == KEY_DOWN:
		return _nudge_selected_object(event)
	if event.keycode == KEY_1:
		_set_object_mode_active(false)
		_set_connector_mode(false)
		_set_spawner_mode_active(false)
		return true
	if event.keycode == KEY_2:
		_set_object_mode_active(true)
		return true
	if event.keycode == KEY_3:
		_set_connector_mode(true)
		return true
	return false

func _set_connector_mode(active: bool) -> void:
	connector_mode_button.set_pressed_no_signal(active)
	_on_connector_mode_toggled(active)

func _deselect_all() -> void:
	selected_tile_name = ""
	selected_layer = ""
	floor_palette_list.deselect_all()
	wall_palette_list.deselect_all()
	object_palette_list.deselect_all()
	selected_object_type = ""
	eraser_button.button_pressed = false
	eraser_active = false
	_set_object_mode_active(false)
	_set_connector_mode(false)
	_set_spawner_mode_active(false)
	_clear_multi_selection()
	marquee_active = false
	queue_redraw()

func _delete_selected() -> void:
	if not multi_selected_indices.is_empty():
		_delete_multi_selection()
	elif not objects_list.get_selected_items().is_empty():
		_on_delete_object_pressed()
	elif not connectors_list.get_selected_items().is_empty():
		var index: int = connectors_list.get_selected_items()[0]
		_remove_connector_with_undo(index)
	elif not spawners_list.get_selected_items().is_empty():
		_on_delete_spawner_pressed()

func _nudge_selected_object(event: InputEventKey) -> bool:
	var selected := objects_list.get_selected_items()
	if selected.is_empty():
		return false
	var index: int = selected[0]
	var step: float = TILE_SIZE if event.shift_pressed else NUDGE_STEP
	var delta := Vector2.ZERO
	if event.keycode == KEY_LEFT:
		delta = Vector2(-step, 0)
	elif event.keycode == KEY_RIGHT:
		delta = Vector2(step, 0)
	elif event.keycode == KEY_UP:
		delta = Vector2(0, -step)
	else:
		delta = Vector2(0, step)
	var old_pos: Vector2 = objects[index]["position"]
	var new_pos := old_pos + delta
	_move_object_and_refresh(index, new_pos)
	_push_undo(
		func(): _move_object_and_refresh(index, old_pos),
		func(): _move_object_and_refresh(index, new_pos)
	)
	return true

func _push_undo(undo_fn: Callable, redo_fn: Callable) -> void:
	undo_stack.append({"undo": undo_fn, "redo": redo_fn})
	redo_stack.clear()

func _undo() -> void:
	if undo_stack.is_empty():
		return
	var action = undo_stack.pop_back()
	action["undo"].call()
	redo_stack.append(action)
	_update_validation_display()
	queue_redraw()

func _redo() -> void:
	if redo_stack.is_empty():
		return
	var action = redo_stack.pop_back()
	action["redo"].call()
	undo_stack.append(action)
	_update_validation_display()
	queue_redraw()

func _handle_camera_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			camera_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()
		elif event.pressed and event.shift_pressed and object_mode_active and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_pending_rotation(ROTATE_STEP_DEGREES)
		elif event.pressed and event.shift_pressed and object_mode_active and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_pending_rotation(-ROTATE_STEP_DEGREES)
		elif event.pressed and event.ctrl_pressed and (eraser_active or selected_tile_name != "") and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_brush_size(1)
		elif event.pressed and event.ctrl_pressed and (eraser_active or selected_tile_name != "") and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_brush_size(-1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.0 / CAMERA_ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(CAMERA_ZOOM_STEP)
	elif event is InputEventMouseMotion and camera_dragging:
		camera.position -= event.relative * (PAN_SPEED / camera.zoom.x + PAN_SPEED_FLOOR)
		_clamp_camera_position()

func _has_active_selection() -> bool:
	return selected_tile_name != "" or eraser_active or object_mode_active or connector_mode_active or spawner_mode_active or not multi_selected_indices.is_empty()

func _handle_right_click() -> void:
	if _has_active_selection():
		_deselect_all()
	else:
		_delete_at_mouse()

func _delete_at_mouse() -> void:
	var pos := get_global_mouse_position() - WORLD_OFFSET
	var hit := _find_object_at(pos)
	if hit != -1:
		_set_multi_selection([hit])
		_delete_multi_selection()
		return
	var cell := _mouse_to_cell()
	var connector_index := _find_connector_at(cell)
	if connector_index != -1:
		_remove_connector_with_undo(connector_index)
		return
	var enemy_index := _find_enemy_spawner_at(cell)
	if enemy_index != -1:
		_remove_enemy_spawner_with_undo(enemy_index)
		return
	if has_player_spawner and player_spawner_cell == cell:
		_clear_player_spawner_with_undo()

func _adjust_pending_rotation(delta_degrees: float) -> void:
	pending_object_rotation = fmod(pending_object_rotation + delta_degrees + 360.0, 360.0)
	queue_redraw()

func _adjust_brush_size(delta: int) -> void:
	brush_size = clampi(brush_size + delta, BRUSH_SIZE_MIN, BRUSH_SIZE_MAX)
	var side := brush_size * 2 - 1
	_show_export_status("Brush size: %dx%d" % [side, side])

func _zoom_camera(factor: float) -> void:
	var clamped := clampf(camera.zoom.x * factor, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	var new_zoom := Vector2(clamped, clamped)
	if new_zoom == camera.zoom:
		return
	var world_before := get_global_mouse_position()
	camera.zoom = new_zoom
	var world_after := get_global_mouse_position()
	camera.position += world_before - world_after
	_clamp_camera_position()

func _on_frame_room_pressed() -> void:
	var room_size := Vector2(width, height) * TILE_SIZE
	var viewport_size := get_viewport_rect().size
	var padding := 1.2
	var target_zoom := CAMERA_ZOOM_MAX
	if room_size.x > 0 and room_size.y > 0:
		target_zoom = clampf(min(viewport_size.x / (room_size.x * padding), viewport_size.y / (room_size.y * padding)), CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	camera.zoom = Vector2(target_zoom, target_zoom)
	camera.position = WORLD_OFFSET + room_size / 2.0
	_update_camera_bounds()
	_clamp_camera_position()

func _handle_paint_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed:
		_eyedrop_at_mouse()
		return
	if not eraser_active and selected_tile_name == "":
		_handle_select_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.shift_pressed:
			rect_paint_active = true
			rect_paint_start_cell = _mouse_to_cell()
			rect_paint_current_cell = rect_paint_start_cell
			queue_redraw()
			return
		if not event.pressed and rect_paint_active:
			rect_paint_active = false
			_fill_rect(rect_paint_start_cell, rect_paint_current_cell)
			queue_redraw()
			return
	if rect_paint_active:
		if event is InputEventMouseMotion:
			rect_paint_current_cell = _mouse_to_cell()
			queue_redraw()
		return
	if paint_tool != PaintTool.FREEHAND:
		_handle_shape_tool_input(event)
		return
	var painting: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var dragging: bool = event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if painting or dragging:
		_paint_at_mouse()

func _handle_shape_tool_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			shape_drag_active = true
			shape_start_cell = _mouse_to_cell()
			shape_current_cell = shape_start_cell
			queue_redraw()
		elif shape_drag_active:
			shape_drag_active = false
			if paint_tool == PaintTool.SELECT:
				_copy_region(shape_start_cell, shape_current_cell)
			else:
				_apply_cells_with_undo(_shape_cells(paint_tool, shape_start_cell, shape_current_cell))
			queue_redraw()
	elif event is InputEventMouseMotion and shape_drag_active:
		shape_current_cell = _mouse_to_cell()
		queue_redraw()

func _handle_select_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos := get_global_mouse_position() - WORLD_OFFSET
			var hit := _find_object_at(pos)
			if hit != -1:
				if not multi_selected_indices.has(hit):
					_set_multi_selection([hit])
				_begin_group_drag()
			elif _toggle_door_at(_mouse_to_cell()):
				pass
			elif _try_open_spawner_settings(_mouse_to_cell()):
				pass
			else:
				_clear_multi_selection()
				marquee_active = true
				marquee_start_world = pos
				marquee_current_world = pos
				queue_redraw()
		else:
			if marquee_active:
				marquee_active = false
				_finish_marquee_selection()
				queue_redraw()
			elif group_drag_active:
				_finish_group_drag()
	elif event is InputEventMouseMotion:
		if marquee_active:
			marquee_current_world = get_global_mouse_position() - WORLD_OFFSET
			queue_redraw()
		elif group_drag_active:
			_update_group_drag()

func _toggle_door_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	var current = walls_names[cell.y][cell.x]
	if current != "wall_door" and current != "wall_door_open":
		return false
	var new_value: String = "wall_door_open" if current == "wall_door" else "wall_door"
	_apply_tile("wall", cell, new_value)
	_push_undo(
		func(): _apply_tile("wall", cell, current),
		func(): _apply_tile("wall", cell, new_value)
	)
	return true

func _set_multi_selection(indices: Array) -> void:
	multi_selected_indices.clear()
	for index in indices:
		multi_selected_indices.append(index)
	queue_redraw()

func _clear_multi_selection() -> void:
	multi_selected_indices.clear()
	queue_redraw()

func _finish_marquee_selection() -> void:
	var min_pos := Vector2(min(marquee_start_world.x, marquee_current_world.x), min(marquee_start_world.y, marquee_current_world.y))
	var max_pos := Vector2(max(marquee_start_world.x, marquee_current_world.x), max(marquee_start_world.y, marquee_current_world.y))
	var select_rect := Rect2(min_pos, max_pos - min_pos)
	var indices := []
	for i in range(objects.size()):
		if select_rect.has_point(objects[i]["position"]):
			indices.append(i)
	_set_multi_selection(indices)

func _begin_group_drag() -> void:
	group_drag_active = true
	group_drag_start_mouse = get_global_mouse_position() - WORLD_OFFSET
	group_drag_start_positions.clear()
	for index in multi_selected_indices:
		group_drag_start_positions[index] = objects[index]["position"]

func _update_group_drag() -> void:
	var mouse_pos := get_global_mouse_position() - WORLD_OFFSET
	var delta := mouse_pos - group_drag_start_mouse
	if object_snap_active:
		delta = Vector2(round(delta.x / TILE_SIZE), round(delta.y / TILE_SIZE)) * TILE_SIZE
	for index in multi_selected_indices:
		var start_pos: Vector2 = group_drag_start_positions[index]
		_move_object(index, start_pos + delta)
	queue_redraw()

func _finish_group_drag() -> void:
	group_drag_active = false
	var old_positions: Dictionary = group_drag_start_positions.duplicate()
	var new_positions := {}
	var changed := false
	for index in multi_selected_indices:
		new_positions[index] = objects[index]["position"]
		_refresh_object_list_item(index)
		if old_positions[index] != new_positions[index]:
			changed = true
	if not changed:
		return
	_push_undo(
		func():
			for index in old_positions.keys():
				_move_object_and_refresh(index, old_positions[index]),
		func():
			for index in new_positions.keys():
				_move_object_and_refresh(index, new_positions[index])
	)

func _delete_multi_selection() -> void:
	if multi_selected_indices.is_empty():
		return
	var indices_desc := multi_selected_indices.duplicate()
	indices_desc.sort()
	indices_desc.reverse()
	var deleted_desc := []
	for index in indices_desc:
		deleted_desc.append({"index": index, "obj": objects[index].duplicate()})
		_delete_object_at(index)
	var deleted_asc := deleted_desc.duplicate()
	deleted_asc.reverse()
	_clear_multi_selection()
	_push_undo(
		func():
			for entry in deleted_asc:
				_insert_object(entry["obj"].duplicate(), entry["index"]),
		func():
			for entry in deleted_desc:
				_delete_object_at(entry["index"])
	)

func _duplicate_multi_selection() -> void:
	if multi_selected_indices.is_empty():
		return
	var new_indices := []
	var inserted := []
	for source_index in multi_selected_indices:
		var source = objects[source_index]
		var obj := {"type": source["type"], "position": source["position"] + Vector2(8, 8), "rotation": source["rotation"]}
		var index := objects.size()
		_insert_object(obj, index)
		inserted.append({"index": index, "obj": obj.duplicate()})
		new_indices.append(index)
	_set_multi_selection(new_indices)
	_push_undo(
		func():
			for i in range(inserted.size() - 1, -1, -1):
				_delete_object_at(inserted[i]["index"]),
		func():
			for entry in inserted:
				_insert_object(entry["obj"].duplicate(), entry["index"])
	)

func _copy_region(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var min_x: int = min(from_cell.x, to_cell.x)
	var max_x: int = max(from_cell.x, to_cell.x)
	var min_y: int = min(from_cell.y, to_cell.y)
	var max_y: int = max(from_cell.y, to_cell.y)
	clipboard_size = Vector2i(max_x - min_x + 1, max_y - min_y + 1)
	clipboard_floor = []
	clipboard_walls = []
	for y in range(min_y, max_y + 1):
		var floor_row := []
		var wall_row := []
		for x in range(min_x, max_x + 1):
			if x >= 0 and x < width and y >= 0 and y < height:
				floor_row.append(floor_names[y][x])
				wall_row.append(walls_names[y][x])
			else:
				floor_row.append(null)
				wall_row.append(null)
		clipboard_floor.append(floor_row)
		clipboard_walls.append(wall_row)
	has_clipboard = true
	_show_export_status("Copied %d x %d tiles (Ctrl+V to paste)" % [clipboard_size.x, clipboard_size.y])

func _paste_clipboard() -> void:
	if not has_clipboard or not mouse_over_room:
		return
	var changes := []
	for dy in range(clipboard_size.y):
		for dx in range(clipboard_size.x):
			var cell := hover_cell + Vector2i(dx, dy)
			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
				continue
			var new_floor = clipboard_floor[dy][dx]
			var new_wall = clipboard_walls[dy][dx]
			var old_floor = floor_names[cell.y][cell.x]
			var old_wall = walls_names[cell.y][cell.x]
			if new_floor == old_floor and new_wall == old_wall:
				continue
			_apply_tile("floor", cell, new_floor)
			_apply_tile("wall", cell, new_wall)
			changes.append({"cell": cell, "old_floor": old_floor, "old_wall": old_wall, "new_floor": new_floor, "new_wall": new_wall})
	if changes.is_empty():
		return
	_push_undo(
		func():
			for c in changes:
				_apply_tile("floor", c["cell"], c["old_floor"])
				_apply_tile("wall", c["cell"], c["old_wall"]),
		func():
			for c in changes:
				_apply_tile("floor", c["cell"], c["new_floor"])
				_apply_tile("wall", c["cell"], c["new_wall"])
	)
	queue_redraw()

func _eyedrop_at_mouse() -> void:
	var cell := _mouse_to_cell()
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return
	var wall_name = walls_names[cell.y][cell.x]
	var floor_name = floor_names[cell.y][cell.x]
	if wall_name != null:
		_select_palette_tile("wall", wall_name)
	elif floor_name != null:
		_select_palette_tile("floor", floor_name)

func _select_palette_tile(layer: String, tile_name: String) -> void:
	selected_layer = layer
	selected_tile_name = tile_name
	eraser_button.button_pressed = false
	eraser_active = false
	_set_object_mode_active(false)
	var list: ItemList = wall_palette_list if layer == "wall" else floor_palette_list
	var other_list: ItemList = floor_palette_list if layer == "wall" else wall_palette_list
	other_list.deselect_all()
	for i in range(list.item_count):
		if list.get_item_text(i) == tile_name:
			list.select(i)
			break
	queue_redraw()

func _paint_at_mouse() -> void:
	var cell := _mouse_to_cell()
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return
	_apply_cells_with_undo(_brush_cells(cell))

func _mouse_to_cell() -> Vector2i:
	var pos := get_global_mouse_position() - WORLD_OFFSET
	return Vector2i(floori(pos.x / TILE_SIZE), floori(pos.y / TILE_SIZE))

const DOOR_TILE_NAMES := ["wall_door", "wall_door_open"]

## Matches DungeonAssembler._connector_dir's boundary-facing rule, so a door
## painted here looks identical to how DungeonPainter renders it at runtime.
func _door_orientation_alt(cell: Vector2i) -> int:
	var dir: int
	if cell.y == 0:
		dir = DungeonAssembler.Dir.NORTH
	elif cell.y == height - 1:
		dir = DungeonAssembler.Dir.SOUTH
	elif cell.x == 0:
		dir = DungeonAssembler.Dir.WEST
	else:
		dir = DungeonAssembler.Dir.EAST
	return DungeonAssembler.door_orientation_alt(dir)

func _apply_tile(layer: String, cell: Vector2i, value) -> void:
	if layer == "floor":
		if value == null:
			floor_data_layer.erase_cell(cell)
		else:
			floor_data_layer.set_cell(cell, palette[value]["source_id"], Vector2i.ZERO)
		floor_names[cell.y][cell.x] = value
	else:
		if value == null:
			wall_data_layer.erase_cell(cell)
		else:
			var alt := _door_orientation_alt(cell) if DOOR_TILE_NAMES.has(value) else 0
			wall_data_layer.set_cell(cell, palette[value]["source_id"], Vector2i.ZERO, alt)
		walls_names[cell.y][cell.x] = value
	tile_renderer.refresh_all()

func _fill_rect(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var min_x: int = min(from_cell.x, to_cell.x)
	var max_x: int = max(from_cell.x, to_cell.x)
	var min_y: int = min(from_cell.y, to_cell.y)
	var max_y: int = max(from_cell.y, to_cell.y)
	var cells := []
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			cells.append(Vector2i(x, y))
	_apply_cells_with_undo(cells)

func _apply_cells_with_undo(cells: Array) -> void:
	if not eraser_active and (selected_tile_name == "" or selected_layer == ""):
		return
	var changes := []
	for cell in cells:
		if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
			continue
		var old_floor = floor_names[cell.y][cell.x]
		var old_wall = walls_names[cell.y][cell.x]
		var new_floor = old_floor
		var new_wall = old_wall
		if eraser_active:
			new_floor = null
			new_wall = null
		elif selected_layer == "floor":
			new_floor = selected_tile_name
		else:
			new_wall = selected_tile_name
		if new_floor == old_floor and new_wall == old_wall:
			continue
		_apply_tile("floor", cell, new_floor)
		_apply_tile("wall", cell, new_wall)
		changes.append({"cell": cell, "old_floor": old_floor, "old_wall": old_wall, "new_floor": new_floor, "new_wall": new_wall})
	if changes.is_empty():
		return
	_push_undo(
		func():
			for c in changes:
				_apply_tile("floor", c["cell"], c["old_floor"])
				_apply_tile("wall", c["cell"], c["old_wall"]),
		func():
			for c in changes:
				_apply_tile("floor", c["cell"], c["new_floor"])
				_apply_tile("wall", c["cell"], c["new_wall"])
	)

func _set_object_mode_active(active: bool) -> void:
	object_mode_active = active
	if active:
		connector_mode_active = false
		connector_mode_button.set_pressed_no_signal(false)
		_set_spawner_mode_active(false)
	queue_redraw()

func _on_object_snap_toggled(pressed: bool) -> void:
	object_snap_active = pressed

func _snap_position(pos: Vector2) -> Vector2:
	if not object_snap_active:
		return pos
	return (Vector2(floor(pos.x / TILE_SIZE), floor(pos.y / TILE_SIZE)) + Vector2(0.5, 0.5)) * TILE_SIZE

func _handle_object_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position() - WORLD_OFFSET
		_place_object(_snap_position(pos))

func _find_object_at(pos: Vector2) -> int:
	for i in range(objects.size()):
		if objects[i]["position"].distance_to(pos) <= OBJECT_HIT_RADIUS:
			return i
	return -1

func _place_object(pos: Vector2) -> void:
	if selected_object_type == "":
		return
	var obj := {"type": selected_object_type, "position": pos, "rotation": pending_object_rotation}
	var index := objects.size()
	_insert_object(obj, index)
	_push_undo(
		func(): _delete_object_at(index),
		func(): _insert_object(obj.duplicate(), index)
	)

func _insert_object(obj: Dictionary, index: int) -> void:
	objects.insert(index, obj)
	var marker := _make_object_marker(obj["position"], obj["type"], obj["rotation"])
	objects_layer.add_child(marker)
	object_markers.insert(index, marker)
	objects_list.add_item(_object_label(obj["type"], obj["position"], obj["rotation"]))
	if index != objects_list.item_count - 1:
		objects_list.move_item(objects_list.item_count - 1, index)

func _delete_object_at(index: int) -> void:
	objects.remove_at(index)
	objects_list.remove_item(index)
	object_markers[index].queue_free()
	object_markers.remove_at(index)

func _move_object(index: int, pos: Vector2) -> void:
	objects[index]["position"] = pos
	object_markers[index].position = pos

func _move_object_and_refresh(index: int, pos: Vector2) -> void:
	_move_object(index, pos)
	_refresh_object_list_item(index)

func _refresh_object_list_item(index: int) -> void:
	var obj = objects[index]
	objects_list.set_item_text(index, _object_label(obj["type"], obj["position"], obj["rotation"]))

func _object_label(object_type: String, pos: Vector2, rotation_degrees: float) -> String:
	return "%s @ (%.1f, %.1f) %d°" % [object_type, pos.x, pos.y, int(rotation_degrees)]

func _make_object_marker(pos: Vector2, object_type: String, rotation_degrees: float) -> Sprite2D:
	var marker := Sprite2D.new()
	if OBJECT_MARKER_TEXTURES.has(object_type):
		marker.texture = _make_object_icon(object_type)
	else:
		marker.texture = preload("res://resources/gfx/placeholders/flat-color.png")
		marker.modulate = Color(1, 0.85, 0.2)
		marker.scale = Vector2(0.5, 0.5)
	marker.position = pos
	marker.rotation_degrees = rotation_degrees
	return marker

func _on_rotate_left_pressed() -> void:
	_rotate_selected_object(-ROTATE_STEP_DEGREES)

func _on_rotate_right_pressed() -> void:
	_rotate_selected_object(ROTATE_STEP_DEGREES)

func _rotate_selected_object(delta_degrees: float) -> void:
	var selected := objects_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	var old_rotation = objects[index]["rotation"]
	var new_rotation := fmod(old_rotation + delta_degrees + 360.0, 360.0)
	_set_object_rotation(index, new_rotation)
	_push_undo(
		func(): _set_object_rotation(index, old_rotation),
		func(): _set_object_rotation(index, new_rotation)
	)

func _set_object_rotation(index: int, rotation_degrees: float) -> void:
	objects[index]["rotation"] = rotation_degrees
	object_markers[index].rotation_degrees = rotation_degrees
	_refresh_object_list_item(index)

func _on_duplicate_object_pressed() -> void:
	var selected := objects_list.get_selected_items()
	if selected.is_empty():
		return
	var source = objects[selected[0]]
	var obj := {"type": source["type"], "position": source["position"] + Vector2(8, 8), "rotation": source["rotation"]}
	var index := objects.size()
	_insert_object(obj, index)
	objects_list.select(index)
	_push_undo(
		func(): _delete_object_at(index),
		func(): _insert_object(obj.duplicate(), index)
	)

func _on_delete_object_pressed() -> void:
	var selected := objects_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	var obj = objects[index].duplicate()
	_delete_object_at(index)
	_push_undo(
		func(): _insert_object(obj.duplicate(), index),
		func(): _delete_object_at(index)
	)

func _clear_objects() -> void:
	for marker in object_markers:
		marker.queue_free()
	objects.clear()
	object_markers.clear()
	objects_list.clear()

func _on_connector_mode_toggled(pressed: bool) -> void:
	connector_mode_active = pressed
	if pressed:
		_set_object_mode_active(false)
		_set_spawner_mode_active(false)
	queue_redraw()

func _handle_connector_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _mouse_to_cell()
		if not _is_boundary_cell(cell):
			return
		var index := _find_connector_at(cell)
		if index != -1:
			_remove_connector_with_undo(index)
		else:
			_add_connector_with_undo(cell)

func _add_connector_with_undo(cell: Vector2i) -> void:
	var index := connectors.size()
	_insert_connector(cell, index)
	_push_undo(
		func(): _remove_connector(index),
		func(): _insert_connector(cell, index)
	)

func _remove_connector_with_undo(index: int) -> void:
	var cell = connectors[index]["position"]
	_remove_connector(index)
	_push_undo(
		func(): _insert_connector(cell, index),
		func(): _remove_connector(index)
	)

func _is_boundary_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	return cell.x == 0 or cell.x == width - 1 or cell.y == 0 or cell.y == height - 1

func _find_connector_at(cell: Vector2i) -> int:
	for i in range(connectors.size()):
		if connectors[i]["position"] == cell:
			return i
	return -1

func _insert_connector(cell: Vector2i, index: int) -> void:
	connectors.insert(index, {"position": cell})
	var marker := _make_connector_marker(cell)
	connectors_layer.add_child(marker)
	connector_markers.insert(index, marker)
	connectors_list.add_item("(%d, %d)" % [cell.x, cell.y])
	if index != connectors_list.item_count - 1:
		connectors_list.move_item(connectors_list.item_count - 1, index)
	_update_validation_display()

func _remove_connector(index: int) -> void:
	connectors.remove_at(index)
	connector_markers[index].queue_free()
	connector_markers.remove_at(index)
	connectors_list.remove_item(index)
	_update_validation_display()

func _prune_invalid_connectors() -> void:
	var i := connectors.size() - 1
	while i >= 0:
		if not _is_boundary_cell(connectors[i]["position"]):
			_remove_connector(i)
		i -= 1

func _clear_connectors() -> void:
	for marker in connector_markers:
		marker.queue_free()
	connectors.clear()
	connector_markers.clear()
	connectors_list.clear()

func _make_connector_marker(cell: Vector2i) -> Sprite2D:
	var marker := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(CONNECTOR_TEXTURE_PATH)
	atlas.region = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
	marker.texture = atlas
	marker.position = Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)
	return marker

## --- Spawners (player start / enemy spawners) ---
## Session-only: not part of _build_export_data, matching the current
## room JSON format. A real runtime spawner system will be designed later.

func _populate_spawner_palette() -> void:
	_style_selection_highlight(spawner_palette_list, SPAWNER_MODE_COLOR)
	spawner_palette_list.add_item("player_spawner", _make_player_spawner_icon())
	spawner_palette_list.add_item("enemy_spawner", PlaceholderMouse.make_icon())

func _make_player_spawner_icon() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(PLAYER_SPAWNER_TEXTURE_PATH)
	atlas.region = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
	return atlas

func _cell_center_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func _on_spawner_palette_selected(index: int) -> void:
	selected_spawner_type = spawner_palette_list.get_item_text(index)
	_set_spawner_mode_active(true)
	queue_redraw()

func _set_spawner_mode_active(active: bool) -> void:
	spawner_mode_active = active
	if active:
		_set_object_mode_active(false)
		_set_connector_mode(false)
	else:
		spawner_palette_list.deselect_all()
		selected_spawner_type = ""
	queue_redraw()

func _handle_spawner_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cell := _mouse_to_cell()
	if not _cell_in_bounds(cell):
		return
	if selected_spawner_type == "player_spawner":
		_place_player_spawner_with_undo(cell)
	elif selected_spawner_type == "enemy_spawner":
		var index := _find_enemy_spawner_at(cell)
		if index != -1:
			_remove_enemy_spawner_with_undo(index)
		else:
			_add_enemy_spawner_with_undo(cell)

func _find_enemy_spawner_at(cell: Vector2i) -> int:
	for i in range(enemy_spawners.size()):
		if enemy_spawners[i]["cell"] == cell:
			return i
	return -1

func _try_open_spawner_settings(cell: Vector2i) -> bool:
	var index := _find_enemy_spawner_at(cell)
	if index == -1:
		return false
	_open_spawner_settings(index)
	return true

func _place_player_spawner_with_undo(cell: Vector2i) -> void:
	var had_spawner := has_player_spawner
	var old_cell := player_spawner_cell
	if had_spawner and old_cell == cell:
		return
	_set_player_spawner(cell)
	_push_undo(
		func():
			if had_spawner:
				_set_player_spawner(old_cell)
			else:
				_clear_player_spawner(),
		func(): _set_player_spawner(cell)
	)

func _clear_player_spawner_with_undo() -> void:
	var old_cell := player_spawner_cell
	_clear_player_spawner()
	_push_undo(
		func(): _set_player_spawner(old_cell),
		func(): _clear_player_spawner()
	)

func _set_player_spawner(cell: Vector2i) -> void:
	player_spawner_cell = cell
	has_player_spawner = true
	if player_spawner_marker == null:
		player_spawner_marker = Sprite2D.new()
		player_spawner_marker.texture = _make_player_spawner_icon()
		spawners_layer.add_child(player_spawner_marker)
	player_spawner_marker.position = _cell_center_world(cell)
	_refresh_spawners_list()
	_update_test_button()

func _clear_player_spawner() -> void:
	has_player_spawner = false
	if player_spawner_marker != null:
		player_spawner_marker.queue_free()
		player_spawner_marker = null
	_refresh_spawners_list()
	_update_test_button()

func _add_enemy_spawner_with_undo(cell: Vector2i) -> void:
	var index := enemy_spawners.size()
	var data := {"cell": cell, "enemy_type": "mouse", "spawn_interval": 2.0, "spawn_count": 3}
	_insert_enemy_spawner(data, index)
	_push_undo(
		func(): _remove_enemy_spawner(index),
		func(): _insert_enemy_spawner(data.duplicate(), index)
	)

func _remove_enemy_spawner_with_undo(index: int) -> void:
	var data: Dictionary = enemy_spawners[index].duplicate()
	_remove_enemy_spawner(index)
	_push_undo(
		func(): _insert_enemy_spawner(data.duplicate(), index),
		func(): _remove_enemy_spawner(index)
	)

func _insert_enemy_spawner(data: Dictionary, index: int) -> void:
	enemy_spawners.insert(index, data)
	var marker := Sprite2D.new()
	marker.texture = PlaceholderMouse.make_icon()
	marker.position = _cell_center_world(data["cell"])
	spawners_layer.add_child(marker)
	enemy_spawner_markers.insert(index, marker)
	_refresh_spawners_list()
	_update_test_button()

func _remove_enemy_spawner(index: int) -> void:
	enemy_spawners.remove_at(index)
	enemy_spawner_markers[index].queue_free()
	enemy_spawner_markers.remove_at(index)
	_refresh_spawners_list()
	_update_test_button()

func _clear_spawners() -> void:
	_clear_player_spawner()
	for marker in enemy_spawner_markers:
		marker.queue_free()
	enemy_spawners.clear()
	enemy_spawner_markers.clear()
	_refresh_spawners_list()
	_update_test_button()

func _prune_invalid_spawners() -> void:
	if has_player_spawner and not _cell_in_bounds(player_spawner_cell):
		_clear_player_spawner()
	var i := enemy_spawners.size() - 1
	while i >= 0:
		if not _cell_in_bounds(enemy_spawners[i]["cell"]):
			_remove_enemy_spawner(i)
		i -= 1

func _refresh_spawners_list() -> void:
	spawners_list.clear()
	if has_player_spawner:
		spawners_list.add_item("Player Spawner @ (%d, %d)" % [player_spawner_cell.x, player_spawner_cell.y])
	for spawner in enemy_spawners:
		var cell: Vector2i = spawner["cell"]
		spawners_list.add_item("Enemy Spawner (%s) @ (%d, %d) — every %.1fs x%d" % [spawner["enemy_type"], cell.x, cell.y, spawner["spawn_interval"], spawner["spawn_count"]])

func _spawners_list_index_to_enemy_index(list_index: int) -> int:
	var offset := 1 if has_player_spawner else 0
	if list_index < offset:
		return -1
	return list_index - offset

func _on_edit_spawner_pressed() -> void:
	var selected := spawners_list.get_selected_items()
	if selected.is_empty():
		return
	var enemy_index := _spawners_list_index_to_enemy_index(selected[0])
	if enemy_index != -1:
		_open_spawner_settings(enemy_index)

func _on_delete_spawner_pressed() -> void:
	var selected := spawners_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if has_player_spawner and index == 0:
		_clear_player_spawner_with_undo()
		return
	var enemy_index := _spawners_list_index_to_enemy_index(index)
	if enemy_index != -1:
		_remove_enemy_spawner_with_undo(enemy_index)

func _open_spawner_settings(enemy_index: int) -> void:
	editing_spawner_index = enemy_index
	var data: Dictionary = enemy_spawners[enemy_index]
	enemy_type_option.clear()
	for i in range(ENEMY_TYPE_NAMES.size()):
		enemy_type_option.add_item(ENEMY_TYPE_NAMES[i].capitalize(), i)
	enemy_type_option.select(max(ENEMY_TYPE_NAMES.find(data["enemy_type"]), 0))
	interval_spin_box.value = data["spawn_interval"]
	count_spin_box.value = data["spawn_count"]
	spawner_settings_dialog.popup_centered()

func _on_spawner_settings_confirmed() -> void:
	if editing_spawner_index == -1 or editing_spawner_index >= enemy_spawners.size():
		return
	var index := editing_spawner_index
	var old_data: Dictionary = enemy_spawners[index].duplicate()
	var new_data := old_data.duplicate()
	new_data["enemy_type"] = ENEMY_TYPE_NAMES[enemy_type_option.get_selected_id()]
	new_data["spawn_interval"] = interval_spin_box.value
	new_data["spawn_count"] = int(count_spin_box.value)
	_apply_spawner_settings(index, new_data)
	_push_undo(
		func(): _apply_spawner_settings(index, old_data),
		func(): _apply_spawner_settings(index, new_data)
	)

func _apply_spawner_settings(index: int, data: Dictionary) -> void:
	enemy_spawners[index] = data.duplicate()
	_refresh_spawners_list()

func _on_spawner_header_toggled(pressed: bool) -> void:
	_set_section_expanded(spawner_header, spawner_section, pressed, "Spawners")

func _update_test_button() -> void:
	test_button.disabled = not has_player_spawner

## --- Test mode ---
## Drops the designer into a live, walkable instance of the room currently
## being edited, using the real PlayerController + NetworkSync RPC path so
## behavior matches live play, but on an OfflineMultiplayerPeer so it's
## fully local — no port, no other peers, nothing to configure.

func _on_test_pressed() -> void:
	if not has_player_spawner or test_mode_active:
		return
	_start_test()

func _start_test() -> void:
	test_mode_active = true
	_deselect_all()
	overlay.visible = false
	$UI.visible = false
	test_hud.visible = true
	camera.enabled = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	test_player = load(PLAYER_CONTROLLER_SCENE_PATH).instantiate()
	test_player.name = "1"
	test_player.global_position = WORLD_OFFSET + _cell_top_left(player_spawner_cell)
	add_child(test_player)
	test_player.get_node("Camera2D").make_current()

	for spawner in enemy_spawners:
		_start_enemy_spawner_timer(spawner)

func _cell_top_left(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)

func _start_enemy_spawner_timer(spawner: Dictionary) -> void:
	var world_pos: Vector2 = WORLD_OFFSET + _cell_top_left(spawner["cell"])
	var max_count: int = spawner["spawn_count"]
	var spawned := [0]
	var timer := Timer.new()
	timer.wait_time = spawner["spawn_interval"]
	add_child(timer)
	test_spawn_timers.append(timer)
	timer.timeout.connect(func():
		spawned[0] += 1
		_spawn_test_enemy(world_pos)
		if spawned[0] >= max_count:
			timer.stop()
	)
	timer.start()

func _spawn_test_enemy(world_pos: Vector2) -> void:
	var enemy: Node2D = load(PLACEHOLDER_ENEMY_SCENE_PATH).instantiate()
	enemy.global_position = world_pos
	add_child(enemy)
	test_spawned_enemies.append(enemy)

func _on_quit_test_pressed() -> void:
	_stop_test()

func _stop_test() -> void:
	test_mode_active = false
	# set_process(false) first: PlayerController's queued-for-deletion node
	# still gets one more _process() this frame otherwise, and it reads
	# multiplayer.get_unique_id(), which errors once the peer below is gone.
	if is_instance_valid(test_player):
		test_player.set_process(false)
		test_player.set_physics_process(false)
		test_player.queue_free()
	test_player = null
	multiplayer.multiplayer_peer = null
	for timer in test_spawn_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	test_spawn_timers.clear()
	for enemy in test_spawned_enemies:
		if is_instance_valid(enemy):
			enemy.set_process(false)
			enemy.queue_free()
	test_spawned_enemies.clear()
	camera.enabled = true
	camera.make_current()
	$UI.visible = true
	overlay.visible = true
	test_hud.visible = false
	queue_redraw()

func _on_load_room_pressed() -> void:
	room_file_dialog.popup_centered_ratio(0.5)

func _on_room_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_export_status("Failed to open " + path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		_show_export_status("Invalid room file: " + path)
		return
	_load_room_data(data)
	_refresh_recent_rooms()
	_show_export_status("Loaded " + path)

func _load_room_data(data: Dictionary) -> void:
	undo_stack.clear()
	redo_stack.clear()
	_clear_objects()
	_clear_connectors()
	_clear_spawners()

	room_id = str(data.get("id", ""))
	id_line_edit.text = room_id

	tags.clear()
	tags_list.clear()
	for tag in data.get("tags", []):
		tags.append(str(tag))
		tags_list.add_item(str(tag))

	width = int(data.get("width", width))
	height = int(data.get("height", height))
	width_spin_box.set_value_no_signal(width)
	height_spin_box.set_value_no_signal(height)

	var loaded_floor = data.get("floor", _make_grid(width, height))
	var loaded_walls = data.get("walls", _make_grid(width, height))
	_restore_grids(loaded_floor, loaded_walls)

	for obj_data in data.get("objects", []):
		var pos_data = obj_data.get("position", {})
		var obj := {
			"type": str(obj_data.get("type", "")),
			"position": Vector2(float(pos_data.get("x", 0)), float(pos_data.get("y", 0))),
			"rotation": float(obj_data.get("rotation", 0.0)),
		}
		_insert_object(obj, objects.size())

	for conn_data in data.get("connectors", []):
		var pos_data = conn_data.get("position", {})
		var cell := Vector2i(int(pos_data.get("x", 0)), int(pos_data.get("y", 0)))
		_insert_connector(cell, connectors.size())

	_update_camera_bounds()
	camera.position = WORLD_OFFSET + Vector2(width, height) * TILE_SIZE / 2.0
	_clamp_camera_position()
	_update_validation_display()
	queue_redraw()

func _on_export_pressed() -> void:
	var errors := _validate_room()
	if not errors.is_empty():
		_show_export_status("Cannot export: " + ", ".join(errors))
		return

	var data := _build_export_data()
	var path := "res://game/rooms/%s.json" % room_id
	if FileAccess.file_exists(path):
		pending_export_data = data
		pending_export_path = path
		overwrite_confirm_dialog.dialog_text = "A room named '%s' already exists. Overwrite it?" % room_id
		overwrite_confirm_dialog.popup_centered()
		return
	_write_room_file(path, data)

func _on_overwrite_confirmed() -> void:
	_write_room_file(pending_export_path, pending_export_data)

func _build_export_data() -> Dictionary:
	return {
		"format": 1,
		"id": room_id,
		"tags": tags,
		"width": width,
		"height": height,
		"floor": floor_names,
		"walls": walls_names,
		"objects": _serialize_objects(),
		"connectors": _serialize_connectors(),
	}

func _write_room_file(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show_export_status("Failed to open %s for writing" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_show_export_status("Exported to " + path)
	_refresh_recent_rooms()
	_refresh_known_tags()

func _on_validate_all_pressed() -> void:
	var dir := DirAccess.open("res://game/rooms")
	if dir == null:
		_show_export_status("Could not open game/rooms")
		return
	var total := 0
	var failed := []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			total += 1
			var errors := _validate_room_file("res://game/rooms/" + file_name)
			if not errors.is_empty():
				failed.append("%s: %s" % [file_name, ", ".join(errors)])
		file_name = dir.get_next()
	dir.list_dir_end()
	if failed.is_empty():
		_show_export_status("Validated %d room(s) — all OK" % total)
	else:
		_show_export_status("Validated %d room(s) — %d issue(s): %s" % [total, failed.size(), " | ".join(failed)])

func _validate_room_file(path: String) -> Array[String]:
	var errors: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("could not open")
		return errors
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		errors.append("not valid JSON object")
		return errors
	if str(data.get("id", "")).strip_edges() == "":
		errors.append("missing id")
	var w: int = int(data.get("width", 0))
	var h: int = int(data.get("height", 0))
	var floor_grid = data.get("floor", [])
	var wall_grid = data.get("walls", [])
	if not (floor_grid is Array) or floor_grid.size() != h or (h > 0 and floor_grid[0].size() != w):
		errors.append("floor grid size mismatch")
	if not (wall_grid is Array) or wall_grid.size() != h or (h > 0 and wall_grid[0].size() != w):
		errors.append("walls grid size mismatch")
	for connector in data.get("connectors", []):
		var pos = connector.get("position", {})
		var cx: int = int(pos.get("x", -1))
		var cy: int = int(pos.get("y", -1))
		var in_bounds: bool = cx >= 0 and cx < w and cy >= 0 and cy < h
		var on_boundary: bool = in_bounds and (cx == 0 or cx == w - 1 or cy == 0 or cy == h - 1)
		if not on_boundary:
			errors.append("connector out of bounds")
	return errors

func _validate_room() -> Array[String]:
	var errors: Array[String] = []
	if room_id.strip_edges() == "":
		errors.append("Room ID is empty")
	if floor_names.size() != height or (height > 0 and floor_names[0].size() != width):
		errors.append("Floor grid size doesn't match width/height")
	if walls_names.size() != height or (height > 0 and walls_names[0].size() != width):
		errors.append("Walls grid size doesn't match width/height")
	for connector in connectors:
		if not _is_boundary_cell(connector["position"]):
			errors.append("Connector %s is not on a boundary cell" % str(connector["position"]))
	return errors

func _update_validation_display() -> void:
	if validation_label == null:
		return
	var errors := _validate_room()
	if errors.is_empty():
		validation_label.text = "✓ Room looks valid"
		validation_label.modulate = Color(0.5, 1.0, 0.5)
	else:
		validation_label.text = "⚠ " + ", ".join(errors)
		validation_label.modulate = Color(1.0, 0.6, 0.3)

func _serialize_objects() -> Array:
	var result := []
	for obj in objects:
		var pos: Vector2 = obj["position"]
		result.append({"type": obj["type"], "position": {"x": pos.x, "y": pos.y}, "rotation": obj["rotation"]})
	return result

func _serialize_connectors() -> Array:
	var result := []
	for connector in connectors:
		var pos: Vector2i = connector["position"]
		result.append({"position": {"x": pos.x, "y": pos.y}})
	return result

func _show_export_status(message: String) -> void:
	export_status_label.text = message

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
