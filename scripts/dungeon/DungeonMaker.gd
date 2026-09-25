extends Node2D

const TILE_SIZE := 16
const OBJECT_HIT_RADIUS := 8.0
const ROOMS_DIR := "res://game/rooms/"
const ROOM_ROLES := ["normal", "corridor", "entrance", "boss"]
## Which 16px cell of a dual-grid sheet to show as the palette thumbnail.
## Floors: the fully filled cell. Walls: the cell that shows the front face.
const FLOOR_ICON_CELL := Vector2i(2, 1)
const WALL_ICON_CELL := Vector2i(1, 2)
const WORLD_OFFSET := Vector2(16, 550)
const ROOM_FILL_COLOR := Color(0.26, 0.32, 0.26, 1.0)
const ROOM_OUTSIDE_COLOR := Color(0.14, 0.14, 0.16, 1.0)
const OUTSIDE_PADDING := 2500.0
const GRID_LINE_COLOR := Color(1, 1, 1, 0.08)
const ROOM_BORDER_COLOR := Color(0.9, 0.85, 0.3, 1.0)
const RECT_PREVIEW_FILL := Color(1, 1, 1, 0.25)
const RECT_PREVIEW_BORDER := Color(1, 1, 1, 0.9)
const ROOM_THUMB_SIZE := 28
const ROOM_BROWSER_THUMB_SMALL := 40
const ROOM_BROWSER_THUMB_MEDIUM := 64
const ROOM_BROWSER_THUMB_LARGE := 96
const ROOM_BROWSER_COLUMN_PADDING := 32
const ROOM_BROWSER_ACCENT_COLOR := Color(0.4, 0.75, 0.95)
const ROOM_THUMB_VOID_COLOR := Color(0.1, 0.1, 0.12, 1.0)
const ROOM_THUMB_FLOOR_COLOR := Color(0.55, 0.55, 0.62, 1.0)
const ROOM_THUMB_WALL_COLOR := Color(0.22, 0.22, 0.25, 1.0)
## Keyword -> color for thumbnail tinting, checked against a tile's name
## (e.g. "floor_dirt" matches "dirt") so different materials read as
## different colors instead of every floor/wall looking flat grey. Matched
## in order, so put more specific keywords ("cobble", "brick") before broad
## ones if that ever matters.
const ROOM_THUMB_MATERIAL_COLORS := {
	"dirt": Color(0.5, 0.36, 0.22),
	"grass": Color(0.35, 0.62, 0.32),
	"lava": Color(0.85, 0.35, 0.15),
	"acid": Color(0.65, 0.85, 0.2),
	"water": Color(0.25, 0.55, 0.85),
	"flesh": Color(0.75, 0.32, 0.38),
	"wood": Color(0.55, 0.4, 0.24),
	"cobble": Color(0.55, 0.42, 0.4),
	"brick": Color(0.55, 0.42, 0.4),
	"cave": Color(0.42, 0.38, 0.34),
	"rough": Color(0.42, 0.38, 0.34),
	"forest": Color(0.22, 0.4, 0.24),
	"stone": Color(0.58, 0.58, 0.62),
	"void": ROOM_THUMB_VOID_COLOR,
}
const OBJECT_MARKER_TEXTURES := {
	"torch": "res://resources/gfx/objects/Torch.png",
	"chest": "res://resources/gfx/objects/Chest_Wood.png",
	"sign": "res://resources/gfx/objects/sign.png",
}
const CONNECTOR_TEXTURE_PATH := "res://resources/gfx/doors/Wood_W1.png"
const PLAYER_SPAWNER_TEXTURE_PATH := "res://resources/gfx/entities/entities.protagonist/knight/Knight-Down.png"
const PLAYER_CONTROLLER_SCENE_PATH := "res://scenes/entities/PlayerController.tscn"
## "" = any minion from the biome table; otherwise an id from game/entities/entities.antagonist/.
const MINION_ANY_LABEL := "Any (biome table)"
const MINION_SPAWNER_ICON_COLOR := Color(0.85, 0.25, 0.25)
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
const CONNECTOR_FREE_COLOR := Color(0.35, 0.8, 0.95)
const FREE_DOOR_COLOR := Color(1.0, 0.65, 0.2)
const ERASER_MODE_COLOR := Color(0.95, 0.35, 0.35)
const OBJECT_SELECT_COLOR := Color(1, 1, 0.3, 0.95)
const SPAWNER_MODE_COLOR := Color(0.85, 0.35, 0.85)

@onready var camera: Camera2D = $Camera2D
@onready var room_file_dialog: FileDialog = $RoomFileDialog
@onready var room_browser_popup: Window = $RoomBrowserPopup
@onready var room_browser_view_small_button: Button = $RoomBrowserPopup/BrowserVBox/BrowserFilterRow/BrowserViewSizeRow/ViewSmallButton
@onready var room_browser_view_medium_button: Button = $RoomBrowserPopup/BrowserVBox/BrowserFilterRow/BrowserViewSizeRow/ViewMediumButton
@onready var room_browser_view_large_button: Button = $RoomBrowserPopup/BrowserVBox/BrowserFilterRow/BrowserViewSizeRow/ViewLargeButton
@onready var room_browser_folder_list: ItemList = $RoomBrowserPopup/BrowserVBox/BrowserSplitRow/BrowserFolderPanel/BrowserFolderList
@onready var room_browser_item_list: ItemList = $RoomBrowserPopup/BrowserVBox/BrowserSplitRow/BrowserItemList
@onready var room_browser_sort_option: OptionButton = $RoomBrowserPopup/BrowserVBox/BrowserFilterRow/BrowserSortOption
@onready var room_browser_context_menu: PopupMenu = $RoomBrowserPopup/BrowserVBox/BrowserSplitRow/BrowserItemList/BrowserContextMenu
@onready var delete_room_confirm_dialog: ConfirmationDialog = $DeleteRoomConfirmDialog
@onready var room_browser_folder_context_menu: PopupMenu = $RoomBrowserPopup/BrowserVBox/BrowserSplitRow/BrowserFolderPanel/BrowserFolderList/BrowserFolderContextMenu
@onready var delete_folder_confirm_dialog: ConfirmationDialog = $DeleteFolderConfirmDialog
@onready var new_room_folder_dialog: ConfirmationDialog = $NewRoomFolderDialog
@onready var new_room_folder_line_edit: LineEdit = $NewRoomFolderDialog/NewFolderVBox/NewFolderLineEdit
@onready var save_location_dialog: Window = $SaveLocationDialog
@onready var save_location_label: Label = $SaveLocationDialog/SaveLocationVBox/SaveLocationLabel
@onready var save_location_folder_list: ItemList = $SaveLocationDialog/SaveLocationVBox/SaveLocationFolderList

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
@onready var role_option: OptionButton = $UI/LeftPanel/RoomInfo/RoleRow/RoleOption
@onready var biome_option: OptionButton = $UI/LeftPanel/RoomInfo/BiomeRow/BiomeOption
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
@onready var minion_type_option: OptionButton = $SpawnerSettingsDialog/SettingsVBox/MinionTypeRow/MinionTypeOption
@onready var interval_spin_box: SpinBox = $SpawnerSettingsDialog/SettingsVBox/IntervalRow/IntervalSpinBox
@onready var count_spin_box: SpinBox = $SpawnerSettingsDialog/SettingsVBox/CountRow/CountSpinBox
@onready var test_hud: CanvasLayer = $TestHUD

var width: int = 5
var height: int = 5
var room_id: String = ""
var room_role: String = "normal"
## The folder under game/rooms/ this room is saved into. "" is the top level.
var room_biome: String = ""
var tags: Array[String] = []
var room_search_filter: String = ""
var room_browser_filter: String = ""
## "" means "All Rooms"; otherwise a folder name under game/rooms/.
var room_browser_folder_filter: String = ""
var room_browser_thumb_size: int = ROOM_BROWSER_THUMB_MEDIUM
enum RoomSortMode { NAME, SIZE, ROLE }
var room_browser_sort_mode: int = RoomSortMode.NAME
var room_browser_context_target: String = ""
var pending_delete_room_file: String = ""
var room_browser_click_pending_file: String = ""
var room_browser_folder_context_target: String = ""
var pending_delete_folder: String = ""
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
## First click of the two-click connector tool (a boundary cell), or null.
var connector_run_start: Variant = null
## Room keys the Maker has no control for (base_floor, favored_minion): carried
## from load to save, or re-saving a room silently drops them.
var room_extras: Dictionary = {}
## Free-standing doors (the room's "doors" list): {"cell": Vector2i (first cell),
## "vertical": bool, "width": int, "type": String ("any" = the biome default)}.
var free_doors: Array = []
var connector_tool_option: OptionButton
var door_tool_box: VBoxContainer
var door_orient_option: OptionButton
var door_width_spin: SpinBox
var door_type_option: OptionButton
var free_doors_list: ItemList
const ROOM_EXTRA_KEYS := ["base_floor", "favored_minion", "favored_antagonist", "antagonist_spawns"]
## Controls for the selected connector, built in code under ConnectorSection.
var connector_free_check: CheckBox
var connector_door_option: OptionButton
var _syncing_connector_controls := false

var spawner_mode_active: bool = false
var selected_spawner_type: String = ""

var has_player_spawner: bool = false
var player_spawner_cell: Vector2i = Vector2i.ZERO
var player_spawner_marker: Sprite2D = null

var minion_spawners: Array = []
var minion_spawner_markers: Array[Node2D] = []
var editing_spawner_index: int = -1

var test_mode_active: bool = false
var test_player: Node = null
var test_spawn_timers: Array[Timer] = []
var test_spawned_minions: Array[Node] = []

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
	_setup_role_and_biome_options()
	_setup_room_file_dialog()
	_setup_room_browser_popup()
	_setup_overwrite_confirm_dialog()
	_setup_delete_confirm_dialog()
	_setup_delete_folder_confirm_dialog()
	_style_selection_highlight(save_location_folder_list, ROOM_BROWSER_ACCENT_COLOR)
	_style_mode_button(connector_mode_button, CONNECTOR_MODE_COLOR)
	_setup_connector_controls()
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
	_draw_connector_runs()

## Every connector run as a tinted bar over its cells (green = exact, cyan = free,
## a brighter edge when it names a door), plus the pending first click.
func _draw_connector_runs() -> void:
	for connector in connectors:
		var start: Vector2i = connector["position"]
		var end: Vector2i = connector.get("b", start)
		var bar := Rect2(WORLD_OFFSET + Vector2(start) * TILE_SIZE, Vector2(end - start + Vector2i.ONE) * TILE_SIZE)
		var color := CONNECTOR_FREE_COLOR if connector.get("free", false) else CONNECTOR_MODE_COLOR
		draw_rect(bar, Color(color, 0.3))
		draw_rect(bar, Color(color, 0.9), false, 2.0 if connector.get("door", "") == "" else 3.0)
	for door in free_doors:
		for door_cell in _free_door_cells(door):
			draw_rect(Rect2(WORLD_OFFSET + Vector2(door_cell) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)), Color(FREE_DOOR_COLOR, 0.35))
		var origin: Vector2 = WORLD_OFFSET + Vector2(door["cell"]) * TILE_SIZE
		var span: float = door["width"] * TILE_SIZE
		# The barrier line the door closes: above a horizontal door, between the halves of a vertical one.
		if door["vertical"]:
			draw_line(origin + Vector2(TILE_SIZE, 0), origin + Vector2(TILE_SIZE, span), FREE_DOOR_COLOR, 3.0)
		else:
			draw_line(origin, origin + Vector2(span, 0), FREE_DOOR_COLOR, 3.0)
	if connector_run_start != null:
		var first: Vector2i = connector_run_start
		draw_rect(Rect2(WORLD_OFFSET + Vector2(first) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)), Color(1, 1, 1, 0.6), false, 3.0)

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

## Explicitly styles every button state (not just "pressed") so a toggle
## button's label always renders against a background we control, rather
## than whatever the inherited theme happens to use for "normal"/"hover".
func _style_mode_button(button: Button, color: Color) -> void:
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(color.r, color.g, color.b, 0.55)
	pressed_style.border_color = color
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover_pressed", pressed_style)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.18, 0.6)
	normal_style.border_color = Color(color.r, color.g, color.b, 0.4)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("focus", normal_style)

	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1))

## Built from the TileRenderer's children rather than tile_palette.json.
## TileInitialize makes one child per TileType .json in game/tiles/ (it
## runs before this script's _ready), so a new tile shows up here by itself.
func _load_palette() -> Dictionary:
	var result := {}
	for child in tile_renderer.get_children():
		if child is DualGridRender or child is StaticTileRender:
			var layer := "wall" if child.data_layer == wall_data_layer else "floor"
			result[String(child.name)] = {"source_id": child.source_id, "layer": layer}
	return result

func _populate_palette_lists() -> void:
	_style_selection_highlight(floor_palette_list, PAINT_MODE_COLOR)
	_style_selection_highlight(wall_palette_list, PAINT_MODE_COLOR)
	floor_palette_list.fixed_icon_size = Vector2i(16, 16)
	wall_palette_list.fixed_icon_size = Vector2i(16, 16)
	var tile_names := palette.keys()
	tile_names.sort()
	for tile_name in tile_names:
		if palette[tile_name]["layer"] == "floor":
			floor_tile_names.append(tile_name)
		else:
			wall_tile_names.append(tile_name)
	_rebuild_floor_palette_list("")
	_rebuild_wall_palette_list("")

func _rebuild_floor_palette_list(filter_text: String) -> void:
	floor_palette_list.clear()
	for tile_name in floor_tile_names:
		if filter_text != "" and not tile_name.to_lower().contains(filter_text.to_lower()):
			continue
		floor_palette_list.add_item(tile_name, _make_tile_icon(tile_name))

func _rebuild_wall_palette_list(filter_text: String) -> void:
	wall_palette_list.clear()
	for tile_name in wall_tile_names:
		if filter_text != "" and not tile_name.to_lower().contains(filter_text.to_lower()):
			continue
		wall_palette_list.add_item(tile_name, _make_tile_icon(tile_name))

func _on_floor_search_changed(new_text: String) -> void:
	_rebuild_floor_palette_list(new_text.strip_edges())

func _on_wall_search_changed(new_text: String) -> void:
	_rebuild_wall_palette_list(new_text.strip_edges())

## A 16x16 piece of the tile's real art, cut from the sheet its DisplayLayer
## draws with. Falls back to the marker color if there is no art to cut from.
func _make_tile_icon(tile_name: String) -> Texture2D:
	var pair = tile_renderer.get_node_or_null(tile_name)
	var texture: Texture2D = null
	if pair != null and pair.display_layer != null and pair.display_layer.tile_set != null:
		var display_set: TileSet = pair.display_layer.tile_set
		if display_set.get_source_count() > 0:
			var source := display_set.get_source(display_set.get_source_id(0)) as TileSetAtlasSource
			if source != null:
				texture = source.texture
	# The lit tiles are CanvasTextures (art + normal map); the icon wants the art.
	var canvas := texture as CanvasTexture
	if canvas != null:
		texture = canvas.diffuse_texture
	if texture == null:
		return _make_marker_swatch(tile_name)
	var cell := FLOOR_ICON_CELL
	if pair is StaticTileRender:
		cell = pair.atlas_coords
	elif palette[tile_name]["layer"] == "wall":
		cell = WALL_ICON_CELL
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(cell) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
	return atlas

func _make_marker_swatch(tile_name: String) -> Texture2D:
	var color := Color.WHITE
	var data_layer: TileMapLayer = wall_data_layer if palette[tile_name]["layer"] == "wall" else floor_data_layer
	var source := data_layer.tile_set.get_source(palette[tile_name]["source_id"]) as TileSetAtlasSource
	if source != null:
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

func _setup_role_and_biome_options() -> void:
	role_option.clear()
	for role in ROOM_ROLES:
		role_option.add_item(role)
	biome_option.clear()
	biome_option.add_item("(none)")
	for folder in _room_folders():
		if folder != "":
			biome_option.add_item(folder)
	_show_role_and_biome()

## Points the two dropdowns at room_role / room_biome.
func _show_role_and_biome() -> void:
	role_option.select(max(ROOM_ROLES.find(room_role), 0))
	biome_option.select(0)
	for i in range(biome_option.item_count):
		if biome_option.get_item_text(i) == room_biome:
			biome_option.select(i)

func _on_role_selected(index: int) -> void:
	room_role = role_option.get_item_text(index)

func _on_biome_selected(index: int) -> void:
	room_biome = "" if index == 0 else biome_option.get_item_text(index)

func _setup_room_file_dialog() -> void:
	room_file_dialog.access = FileDialog.ACCESS_RESOURCES
	room_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	room_file_dialog.add_filter("*.json", "Room JSON")
	room_file_dialog.current_dir = ROOMS_DIR
	room_file_dialog.file_selected.connect(_on_room_file_selected)

## A bigger, filterable, thumbnail-grid version of the Room Library list,
## opened by the Load Room button. FileDialog itself can't show custom
## thumbnails for arbitrary files, so this replaces it as the primary way
## to browse rooms; room_file_dialog stays around as a fallback for loading
## a JSON file from outside game/rooms/.
func _setup_room_browser_popup() -> void:
	room_browser_item_list.icon_mode = ItemList.ICON_MODE_TOP
	room_browser_item_list.same_column_width = true
	# max_columns defaults to 1 (single column); 0 tells the ItemList to fit
	# as many fixed_column_width columns as the current width allows, and to
	# re-wrap automatically if the popup is resized.
	room_browser_item_list.max_columns = 0
	_style_selection_highlight(room_browser_item_list, ROOM_BROWSER_ACCENT_COLOR)
	_style_selection_highlight(room_browser_folder_list, ROOM_BROWSER_ACCENT_COLOR)
	_style_mode_button(room_browser_view_small_button, ROOM_BROWSER_ACCENT_COLOR)
	_style_mode_button(room_browser_view_medium_button, ROOM_BROWSER_ACCENT_COLOR)
	_style_mode_button(room_browser_view_large_button, ROOM_BROWSER_ACCENT_COLOR)
	room_browser_sort_option.clear()
	room_browser_sort_option.add_item("Name", RoomSortMode.NAME)
	room_browser_sort_option.add_item("Size", RoomSortMode.SIZE)
	room_browser_sort_option.add_item("Role", RoomSortMode.ROLE)
	room_browser_context_menu.clear()
	room_browser_context_menu.add_item("Duplicate", 0)
	room_browser_context_menu.add_item("Delete", 1)
	room_browser_folder_context_menu.clear()
	room_browser_folder_context_menu.add_item("Delete Folder", 0)
	room_browser_folder_list.room_dropped.connect(_on_room_dropped_on_folder)
	room_browser_item_list.drag_started.connect(_on_room_browser_drag_started)
	# Control's own gui_input signal (not the _gui_input virtual) -- this only
	# observes input, it doesn't replace ItemList's built-in click/selection
	# handling, so selection and scrolling keep working exactly as before.
	room_browser_item_list.gui_input.connect(_on_room_browser_item_list_gui_input)
	_apply_room_browser_thumb_size(ROOM_BROWSER_THUMB_MEDIUM)
	_refresh_room_browser_folder_list()

func _on_load_room_pressed() -> void:
	room_browser_click_pending_file = ""
	_refresh_room_browser_folder_list()
	_refresh_room_browser()
	room_browser_popup.popup_centered()

func _on_room_browser_view_small_pressed() -> void:
	_apply_room_browser_thumb_size(ROOM_BROWSER_THUMB_SMALL)

func _on_room_browser_view_medium_pressed() -> void:
	_apply_room_browser_thumb_size(ROOM_BROWSER_THUMB_MEDIUM)

func _on_room_browser_view_large_pressed() -> void:
	_apply_room_browser_thumb_size(ROOM_BROWSER_THUMB_LARGE)

func _apply_room_browser_thumb_size(thumb_size: int) -> void:
	room_browser_thumb_size = thumb_size
	room_browser_item_list.fixed_icon_size = Vector2i(thumb_size, thumb_size)
	room_browser_item_list.fixed_column_width = thumb_size + ROOM_BROWSER_COLUMN_PADDING
	_refresh_room_browser()

## Rebuilds the folder sidebar: "All Rooms" plus every folder under
## game/rooms/. These are real directories on disk -- the same ones a room's
## saved location already determines its biome from -- just presented here
## as free-form organisation folders a person can add to, instead of a fixed
## biome picker.
func _refresh_room_browser_folder_list() -> void:
	var previous := room_browser_folder_filter
	room_browser_folder_list.clear()
	room_browser_folder_list.add_item("All Rooms")
	for folder in _room_folders():
		if folder != "":
			room_browser_folder_list.add_item(folder)
	for i in range(room_browser_folder_list.item_count):
		var label := "" if i == 0 else room_browser_folder_list.get_item_text(i)
		if label == previous:
			room_browser_folder_list.select(i)
			return
	room_browser_folder_filter = ""
	room_browser_folder_list.select(0)

func _on_room_browser_folder_selected(index: int) -> void:
	room_browser_folder_filter = "" if index == 0 else room_browser_folder_list.get_item_text(index)
	_refresh_room_browser()

func _on_new_folder_button_pressed() -> void:
	new_room_folder_line_edit.text = ""
	new_room_folder_dialog.popup_centered()
	new_room_folder_line_edit.grab_focus()

func _on_new_room_folder_confirmed() -> void:
	var folder_name := new_room_folder_line_edit.text.strip_edges()
	if folder_name == "" or folder_name.contains("/") or folder_name.contains("\\") or folder_name.contains(".."):
		_show_export_status("Folder names can't contain / \\ or ..")
		return
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		return
	dir.make_dir(folder_name)
	room_browser_folder_filter = folder_name
	# Folders double as the Room Info biome dropdown's options, so keep it in
	# sync too -- a folder created here is immediately usable to save into.
	_setup_role_and_biome_options()
	_refresh_room_browser_folder_list()
	_refresh_room_browser()
	# "+ New Folder" can also be opened from the save-location picker; if
	# that's what's currently up, refresh it too and select the new folder.
	if save_location_dialog.visible:
		_refresh_save_location_folder_list(folder_name)

## Rebuilds the room browser grid from the current search text and folder
## filter. Item metadata holds the room's path (relative to ROOMS_DIR) so
## the display label can show just the room's id.
func _refresh_room_browser() -> void:
	room_browser_click_pending_file = ""
	room_browser_item_list.clear()
	var needle := room_browser_filter.strip_edges().to_lower()
	var entries := []
	for room_file in _list_room_files():
		if room_browser_folder_filter != "" and not room_file.begins_with(room_browser_folder_filter + "/"):
			continue
		var data := _read_room_file(room_file)
		if data.is_empty():
			continue
		if needle != "" and not _room_matches_filter(room_file, data, needle):
			continue
		var label: String = str(data.get("id", "")) if data.get("id", "") != "" else room_file.get_file().get_basename()
		entries.append({"room_file": room_file, "data": data, "label": label})
	entries.sort_custom(_room_browser_entry_less_than)
	for entry in entries:
		room_browser_item_list.add_item(entry["label"], _build_room_thumbnail(entry["data"], room_browser_thumb_size))
		var item_index := room_browser_item_list.item_count - 1
		room_browser_item_list.set_item_tooltip(item_index, entry["room_file"])
		room_browser_item_list.set_item_metadata(item_index, entry["room_file"])

## Comparator used to order the room browser grid according to
## room_browser_sort_mode. Falls back to alphabetical on ties (and for the
## default Name mode itself).
func _room_browser_entry_less_than(a: Dictionary, b: Dictionary) -> bool:
	match room_browser_sort_mode:
		RoomSortMode.SIZE:
			var area_a: int = int(a["data"].get("width", 0)) * int(a["data"].get("height", 0))
			var area_b: int = int(b["data"].get("width", 0)) * int(b["data"].get("height", 0))
			if area_a != area_b:
				return area_a < area_b
		RoomSortMode.ROLE:
			var role_a: String = str(a["data"].get("role", ""))
			var role_b: String = str(b["data"].get("role", ""))
			if role_a != role_b:
				return role_a < role_b
	return a["label"].to_lower() < b["label"].to_lower()

func _on_room_browser_sort_selected(index: int) -> void:
	room_browser_sort_mode = index
	_refresh_room_browser()

func _on_room_browser_search_changed(new_text: String) -> void:
	room_browser_filter = new_text
	_refresh_room_browser()

## item_selected fires on mouse-DOWN, before Godot knows whether this press
## will turn into a drag -- loading and closing the popup immediately would
## make click-and-hold-to-drag impossible. So this only remembers which room
## was pressed; the actual load happens on mouse-UP (_on_room_browser_item_list_gui_input),
## and only if no drag started in between (_on_room_browser_drag_started).
## That way holding as long as you like before moving still lets a drag
## start, while a plain press-and-release still opens the room immediately.
func _on_room_browser_item_selected(index: int) -> void:
	room_browser_click_pending_file = room_browser_item_list.get_item_metadata(index)

func _on_room_browser_drag_started() -> void:
	room_browser_click_pending_file = ""

func _on_room_browser_item_list_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return
	if room_browser_click_pending_file == "":
		return
	var room_file := room_browser_click_pending_file
	room_browser_click_pending_file = ""
	_on_room_file_selected(ROOMS_DIR + room_file)
	room_browser_popup.hide()

func _on_room_browser_browse_files_pressed() -> void:
	room_browser_popup.hide()
	room_file_dialog.popup_centered_ratio(0.5)

## Right-click support for the room grid: item_selected (left click) still
## loads the room, this only opens the Duplicate/Delete menu on other buttons.
func _on_room_browser_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	room_browser_click_pending_file = ""
	var room_file = room_browser_item_list.get_item_metadata(index)
	if not (room_file is String):
		return
	room_browser_context_target = room_file
	var screen_pos: Vector2 = room_browser_item_list.get_screen_transform() * at_position
	room_browser_context_menu.popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))

func _on_room_browser_context_menu_id_pressed(id: int) -> void:
	if room_browser_context_target == "":
		return
	match id:
		0:
			_duplicate_room_file(room_browser_context_target)
		1:
			_confirm_delete_room_file(room_browser_context_target)

## Copies a room file within the same folder, appending " (copy)" to its id
## (and, if that name's already taken, " (copy 2)", " (copy 3)", ...).
func _duplicate_room_file(room_file: String) -> void:
	var data := _read_room_file(room_file)
	if data.is_empty():
		return
	var base_id: String = str(data.get("id", room_file.get_file().get_basename()))
	var folder := room_file.get_base_dir()
	var folder_prefix := "" if folder == "" else folder + "/"
	var new_id := base_id + " (copy)"
	var suffix := 2
	while FileAccess.file_exists("%s%s%s.json" % [ROOMS_DIR, folder_prefix, new_id]):
		new_id = "%s (copy %d)" % [base_id, suffix]
		suffix += 1
	data["id"] = new_id
	_write_room_file("%s%s%s.json" % [ROOMS_DIR, folder_prefix, new_id], data)
	_refresh_room_browser()

func _confirm_delete_room_file(room_file: String) -> void:
	pending_delete_room_file = room_file
	delete_room_confirm_dialog.dialog_text = "Delete \"%s\"? This can't be undone." % room_file
	delete_room_confirm_dialog.popup_centered()

func _setup_delete_confirm_dialog() -> void:
	# DungeonMaker.tscn already connects this; only connect here if it did not.
	if not delete_room_confirm_dialog.confirmed.is_connected(_on_delete_room_confirmed):
		delete_room_confirm_dialog.confirmed.connect(_on_delete_room_confirmed)

func _on_delete_room_confirmed() -> void:
	if pending_delete_room_file == "":
		return
	var dir := DirAccess.open(ROOMS_DIR)
	if dir != null:
		dir.remove(pending_delete_room_file)
	_show_export_status("Deleted " + pending_delete_room_file)
	pending_delete_room_file = ""
	_refresh_room_browser()
	_refresh_recent_rooms()
	_refresh_known_tags()

## Right-click support for the folder sidebar. Index 0 is "All Rooms", which
## isn't a real folder, so it's excluded.
func _on_room_browser_folder_list_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT or index == 0:
		return
	room_browser_folder_context_target = room_browser_folder_list.get_item_text(index)
	var screen_pos: Vector2 = room_browser_folder_list.get_screen_transform() * at_position
	room_browser_folder_context_menu.popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))

func _on_room_browser_folder_context_menu_id_pressed(id: int) -> void:
	if room_browser_folder_context_target == "":
		return
	match id:
		0:
			_confirm_delete_folder(room_browser_folder_context_target)

func _confirm_delete_folder(folder_name: String) -> void:
	pending_delete_folder = folder_name
	var map_count := 0
	var dir := DirAccess.open(ROOMS_DIR + folder_name)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".json"):
				map_count += 1
	var plural := "" if map_count == 1 else "s"
	delete_folder_confirm_dialog.dialog_text = "Delete \"%s\" and the %d map%s in it? This can't be undone." % [folder_name, map_count, plural]
	delete_folder_confirm_dialog.popup_centered()

func _setup_delete_folder_confirm_dialog() -> void:
	# DungeonMaker.tscn already connects this; only connect here if it did not.
	if not delete_folder_confirm_dialog.confirmed.is_connected(_on_delete_folder_confirmed):
		delete_folder_confirm_dialog.confirmed.connect(_on_delete_folder_confirmed)

func _on_delete_folder_confirmed() -> void:
	if pending_delete_folder == "":
		return
	var folder_name := pending_delete_folder
	pending_delete_folder = ""
	var dir := DirAccess.open(ROOMS_DIR + folder_name)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	var parent_dir := DirAccess.open(ROOMS_DIR)
	if parent_dir == null or parent_dir.remove(folder_name) != OK:
		_show_export_status("Failed to delete folder " + folder_name)
	else:
		_show_export_status("Deleted folder " + folder_name)
	if room_browser_folder_filter == folder_name:
		room_browser_folder_filter = ""
	_setup_role_and_biome_options()
	_refresh_room_browser_folder_list()
	_refresh_room_browser()
	_refresh_recent_rooms()
	_refresh_known_tags()

## Called when a room thumbnail is dragged onto a folder in the sidebar
## (see RoomBrowserSourceList.gd / RoomBrowserFolderList.gd). Moves the file
## on disk; the folder is the room's biome, so nothing in the file changes.
func _on_room_dropped_on_folder(room_file: String, target_folder: String) -> void:
	var current_folder := room_file.get_base_dir()
	if current_folder == target_folder:
		return
	var file_name := room_file.get_file()
	var new_rel := file_name if target_folder == "" else target_folder + "/" + file_name
	if FileAccess.file_exists(ROOMS_DIR + new_rel):
		_show_export_status("A room named %s already exists in that folder" % file_name)
		return
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null or dir.rename(room_file, new_rel) != OK:
		_show_export_status("Failed to move " + room_file)
		return
	_show_export_status("Moved to " + new_rel)
	_refresh_room_browser_folder_list()
	_refresh_room_browser()

func _setup_overwrite_confirm_dialog() -> void:
	overwrite_confirm_dialog.confirmed.connect(_on_overwrite_confirmed)

## The top level of game/rooms/ (as "") plus every folder in it. Biomes are
## folders, so a new biome folder is picked up without touching this script.
func _room_folders() -> Array:
	var folders := [""]
	var dir := DirAccess.open(ROOMS_DIR)
	if dir != null:
		var sub_folders := dir.get_directories()
		sub_folders.sort()
		for folder in sub_folders:
			folders.append(folder)
	return folders

## Every room file, as a path relative to game/rooms/ ("cave/Cave_Bend_5x5.json").
func _list_room_files() -> Array:
	var files := []
	for folder in _room_folders():
		var dir := DirAccess.open(ROOMS_DIR + folder)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if file_name.ends_with(".json"):
				files.append(file_name if folder == "" else folder + "/" + file_name)
	files.sort()
	return files

func _refresh_recent_rooms() -> void:
	recent_rooms_list.clear()
	recent_rooms_list.icon_mode = ItemList.ICON_MODE_LEFT
	recent_rooms_list.fixed_icon_size = Vector2i(ROOM_THUMB_SIZE, ROOM_THUMB_SIZE)
	var needle := room_search_filter.strip_edges().to_lower()
	for room_file in _list_room_files():
		var data := _read_room_file(room_file)
		if data.is_empty():
			continue
		if needle != "" and not _room_matches_filter(room_file, data, needle):
			continue
		recent_rooms_list.add_item(room_file, _build_room_thumbnail(data))

func _on_room_search_changed(new_text: String) -> void:
	room_search_filter = new_text
	_refresh_recent_rooms()

## True if the room's file name, room ID, or any tag contains needle.
## needle is expected to already be lowercased.
func _room_matches_filter(room_file: String, data: Dictionary, needle: String) -> bool:
	if room_file.to_lower().contains(needle):
		return true
	if str(data.get("id", "")).to_lower().contains(needle):
		return true
	for tag in data.get("tags", []):
		if str(tag).to_lower().contains(needle):
			return true
	return false

func _on_recent_room_selected(index: int) -> void:
	_on_room_file_selected(ROOMS_DIR + recent_rooms_list.get_item_text(index))

## Reads and parses a room JSON file, relative to ROOMS_DIR. Empty
## Dictionary on any failure (missing file, invalid JSON).
func _read_room_file(room_file: String) -> Dictionary:
	return JsonOnloading.load_dict(ROOMS_DIR + room_file)

func _build_room_thumbnail(data: Dictionary, thumb_size: int = ROOM_THUMB_SIZE) -> ImageTexture:
	var thumb_width: int = int(data.get("width", 0))
	var thumb_height: int = int(data.get("height", 0))
	if thumb_width <= 0 or thumb_height <= 0:
		return null
	var floor_grid: Array = data.get("floor", [])
	var walls_grid: Array = data.get("walls", [])
	var img := Image.create(thumb_width, thumb_height, false, Image.FORMAT_RGBA8)
	for y in range(thumb_height):
		var floor_row: Array = floor_grid[y] if y < floor_grid.size() else []
		var walls_row: Array = walls_grid[y] if y < walls_grid.size() else []
		for x in range(thumb_width):
			var wall_value = walls_row[x] if x < walls_row.size() else null
			var floor_value = floor_row[x] if x < floor_row.size() else null
			var color := ROOM_THUMB_VOID_COLOR
			if wall_value != null and str(wall_value) != "":
				var wall_name := str(wall_value)
				color = _thumbnail_material_color(wall_name, ROOM_THUMB_WALL_COLOR, true)
			elif floor_value != null and str(floor_value) != "":
				color = _thumbnail_material_color(str(floor_value), ROOM_THUMB_FLOOR_COLOR, false)
			img.set_pixel(x, y, color)
	img.resize(thumb_size, thumb_size, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

## Colors a tile by material keyword (see ROOM_THUMB_MATERIAL_COLORS) so
## different floor/wall types are visually distinct in room thumbnails, e.g.
## lava reads as orange and grass as green instead of everything being the
## same flat grey. Walls get a darkened version of their material's color --
## some materials (e.g. "flesh") name both a floor and a wall tile, and
## without this a wall would render as the exact same color as the floor
## next to it and disappear. A tile name matching no known keyword still
## gets a consistent color (hashed from its name, at the fallback's
## brightness so floors stay lighter than walls) rather than flat grey.
func _thumbnail_material_color(tile_name: String, fallback: Color, is_wall: bool) -> Color:
	var lower := tile_name.to_lower()
	for keyword in ROOM_THUMB_MATERIAL_COLORS.keys():
		if lower.contains(keyword):
			var base: Color = ROOM_THUMB_MATERIAL_COLORS[keyword]
			return base.darkened(0.4) if is_wall else base
	var hue := float(tile_name.hash() % 360) / 360.0
	return Color.from_hsv(hue, 0.4, fallback.v)

func _refresh_known_tags() -> void:
	var seen := {}
	for room_file in _list_room_files():
		var data := _read_room_file(room_file)
		for tag in data.get("tags", []):
			seen[str(tag)] = true
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
	var old_connectors := connectors.duplicate(true)
	var new_connectors := _flipped_connectors(horizontal)
	var old_doors := free_doors.duplicate(true)
	var new_doors := _flipped_free_doors(horizontal)
	_restore_grids(new_floor, new_walls)
	_set_connectors(new_connectors)
	_set_free_doors(new_doors)
	_push_undo(
		func():
			_restore_grids(old_floor, old_walls)
			_set_connectors(old_connectors)
			_set_free_doors(old_doors),
		func():
			_restore_grids(new_floor, new_walls)
			_set_connectors(new_connectors)
			_set_free_doors(new_doors)
	)
	_show_export_status("Flipped tiles and connectors %s (objects unchanged)" % ("horizontally" if horizontal else "vertically"))
	queue_redraw()

## The connectors mirrored across the room, ends re-sorted so "position" stays
## the first (top-left) cell of the run; free / door ride along unchanged.
func _flipped_connectors(horizontal: bool) -> Array:
	var result: Array = []
	for connector in connectors:
		var start: Vector2i = connector["position"]
		var end: Vector2i = connector.get("b", start)
		var flipped_start := Vector2i(width - 1 - start.x, start.y) if horizontal else Vector2i(start.x, height - 1 - start.y)
		var flipped_end := Vector2i(width - 1 - end.x, end.y) if horizontal else Vector2i(end.x, height - 1 - end.y)
		var copy: Dictionary = connector.duplicate()
		copy["position"] = Vector2i(mini(flipped_start.x, flipped_end.x), mini(flipped_start.y, flipped_end.y))
		var far := Vector2i(maxi(flipped_start.x, flipped_end.x), maxi(flipped_start.y, flipped_end.y))
		if far != copy["position"]:
			copy["b"] = far
		else:
			copy.erase("b")
		result.append(copy)
	return result

## Replaces every connector (data, list rows and markers) with `new_list`.
func _set_connectors(new_list: Array) -> void:
	_clear_connectors()
	for connector in new_list:
		_insert_connector_data(connector.duplicate(), connectors.size())

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
				wall_data_layer.set_cell(Vector2i(x, y), palette[w]["source_id"], Vector2i.ZERO)
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
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_stop_test()
			elif event.keycode == KEY_R:
				_restart_test()
			elif event.keycode == KEY_K:
				_kill_all_test_minions()
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
		# Ctrl+V duplicates the current object/group selection when there is
		# one; otherwise it falls back to pasting a copied tile region.
		if not multi_selected_indices.is_empty():
			_duplicate_multi_selection()
		else:
			_paste_clipboard()
		return true
	if event.ctrl_pressed and event.keycode == KEY_D:
		_duplicate_multi_selection()
		return true
	if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
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
	# Cancel any in-progress box paint / line-shape drag too, otherwise its
	# preview outline is left stuck on screen since nothing clears it.
	rect_paint_active = false
	shape_drag_active = false
	queue_redraw()

func _delete_selected() -> void:
	if not multi_selected_indices.is_empty():
		_delete_multi_selection()
	elif not objects_list.get_selected_items().is_empty():
		_on_delete_object_pressed()
	elif not connectors_list.get_selected_items().is_empty():
		var index: int = connectors_list.get_selected_items()[0]
		_remove_connector_with_undo(index)
	elif free_doors_list != null and not free_doors_list.get_selected_items().is_empty():
		_remove_free_door_with_undo(free_doors_list.get_selected_items()[0])
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
		elif event.pressed and event.shift_pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and (object_mode_active or not multi_selected_indices.is_empty()):
			_adjust_rotation_input(ROTATE_STEP_DEGREES)
		elif event.pressed and event.shift_pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and (object_mode_active or not multi_selected_indices.is_empty()):
			_adjust_rotation_input(-ROTATE_STEP_DEGREES)
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
	var minion_index := _find_minion_spawner_at(cell)
	if minion_index != -1:
		_remove_minion_spawner_with_undo(minion_index)
		return
	if has_player_spawner and player_spawner_cell == cell:
		_clear_player_spawner_with_undo()

## Shift+wheel means two different things depending on context: adjusting the
## rotation an about-to-be-placed object will spawn with, or rotating the
## object(s) currently selected in the room.
func _adjust_rotation_input(delta_degrees: float) -> void:
	if object_mode_active:
		_adjust_pending_rotation(delta_degrees)
	else:
		_rotate_multi_selection(delta_degrees)

func _adjust_pending_rotation(delta_degrees: float) -> void:
	pending_object_rotation = fmod(pending_object_rotation + delta_degrees + 360.0, 360.0)
	queue_redraw()

func _rotate_multi_selection(delta_degrees: float) -> void:
	if multi_selected_indices.is_empty():
		return
	var old_rotations := {}
	var new_rotations := {}
	for index in multi_selected_indices:
		old_rotations[index] = objects[index]["rotation"]
		new_rotations[index] = fmod(old_rotations[index] + delta_degrees + 360.0, 360.0)
		_set_object_rotation(index, new_rotations[index])
	_push_undo(
		func():
			for index in old_rotations.keys():
				_set_object_rotation(index, old_rotations[index]),
		func():
			for index in new_rotations.keys():
				_set_object_rotation(index, new_rotations[index])
	)

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
			wall_data_layer.set_cell(cell, palette[value]["source_id"], Vector2i.ZERO)
		walls_names[cell.y][cell.x] = value
	_queue_tile_refresh()

var _tile_refresh_queued := false

## _apply_tile runs once per cell, and a fill or paste can be thousands of
## cells. This folds them into one refresh_all() at the end of the frame.
## The explicit refresh is still needed: walls draw differently next to void
## floor, but they only listen to the wall layer, so a floor edit alone
## wouldn't redraw them.
func _queue_tile_refresh() -> void:
	if _tile_refresh_queued:
		return
	_tile_refresh_queued = true
	_run_tile_refresh.call_deferred()

func _run_tile_refresh() -> void:
	_tile_refresh_queued = false
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

func _set_object_rotation(index: int, rotation_degrees: float) -> void:
	objects[index]["rotation"] = rotation_degrees
	object_markers[index].rotation_degrees = rotation_degrees
	_refresh_object_list_item(index)

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
	if not pressed:
		connector_run_start = null
	if pressed:
		_set_object_mode_active(false)
		_set_spawner_mode_active(false)
	queue_redraw()

func _handle_connector_input(event: InputEvent) -> void:
	if connector_tool_option != null and connector_tool_option.selected == 1:
		_handle_free_door_input(event)
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and connector_run_start != null:
		_cancel_connector_run()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := _mouse_to_cell()
	if not _is_boundary_cell(cell):
		return
	var index := _find_connector_at(cell)
	if connector_run_start == null:
		# Clicking an existing run removes it; otherwise this click starts a new one.
		if index != -1:
			_remove_connector_with_undo(index)
		else:
			connector_run_start = cell
			queue_redraw()
		return
	var first: Vector2i = connector_run_start
	var last := _snap_run_end(first, cell)
	if last == Vector2i(-1, -1):
		_show_export_status("A connector can't run along a corner")
		return
	var run := {"position": Vector2i(mini(first.x, last.x), mini(first.y, last.y))}
	var far := Vector2i(maxi(first.x, last.x), maxi(first.y, last.y))
	if far != run["position"]:
		run["b"] = far
	for other in connectors:
		if _runs_overlap(run, other):
			_show_export_status("That run overlaps another connector")
			_cancel_connector_run()
			return
	_cancel_connector_run()
	_add_connector_with_undo(run)
	_clear_walls_under_run(run)

## A connector is an opening, so the wall tiles on its cells are erased (one undo
## step of its own: Ctrl+Z brings the walls back, a second one removes the run).
func _clear_walls_under_run(run: Dictionary) -> void:
	var start: Vector2i = run["position"]
	var end: Vector2i = run.get("b", start)
	var cells: Array[Vector2i] = []
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			cells.append(Vector2i(x, y))
	_clear_walls_under_cells(cells)

func _clear_walls_under_cells(cells: Array[Vector2i]) -> void:
	var old_floor = floor_names.duplicate(true)
	var old_walls = walls_names.duplicate(true)
	var new_walls = walls_names.duplicate(true)
	var changed := false
	for cell in cells:
		if _cell_in_bounds(cell) and new_walls[cell.y][cell.x] != null:
			new_walls[cell.y][cell.x] = null
			changed = true
	if not changed:
		return
	_restore_grids(old_floor, new_walls)
	_push_undo(
		func(): _restore_grids(old_floor, old_walls),
		func(): _restore_grids(old_floor, new_walls)
	)

func _cancel_connector_run() -> void:
	connector_run_start = null
	queue_redraw()

## The second click, moved onto the same edge as the first: a first click on the
## top / bottom edge runs along x, on the left / right edge along y. Corners have
## no side, so a run starting on one (or ending past the ends) is clamped or refused.
func _snap_run_end(first: Vector2i, clicked: Vector2i) -> Vector2i:
	var on_horizontal_edge := first.y == 0 or first.y == height - 1
	var on_vertical_edge := first.x == 0 or first.x == width - 1
	if on_horizontal_edge and on_vertical_edge:
		return Vector2i(-1, -1)
	if on_horizontal_edge:
		return Vector2i(clampi(clicked.x, 1, width - 2), first.y)
	return Vector2i(first.x, clampi(clicked.y, 1, height - 2))

func _runs_overlap(x: Dictionary, y: Dictionary) -> bool:
	var xb: Vector2i = x.get("b", x["position"])
	var yb: Vector2i = y.get("b", y["position"])
	return x["position"].x <= yb.x and y["position"].x <= xb.x and x["position"].y <= yb.y and y["position"].y <= xb.y

func _add_connector_with_undo(connector: Dictionary) -> void:
	var index := connectors.size()
	var saved := connector.duplicate()
	_insert_connector_data(saved.duplicate(), index)
	_push_undo(
		func(): _remove_connector(index),
		func(): _insert_connector_data(saved.duplicate(), index)
	)

## Undo keeps the WHOLE connector (both ends, free, door), not just its first cell.
func _remove_connector_with_undo(index: int) -> void:
	var saved: Dictionary = connectors[index].duplicate()
	_remove_connector(index)
	_push_undo(
		func(): _insert_connector_data(saved.duplicate(), index),
		func(): _remove_connector(index)
	)

## Free + door controls for the connector selected in the list. Built here, not
## in the scene, so DungeonMaker.tscn stays untouched.
func _setup_connector_controls() -> void:
	connector_free_check = CheckBox.new()
	connector_free_check.text = "Free (joins a run of any width)"
	connector_free_check.toggled.connect(_on_connector_free_toggled)
	connector_section.add_child(connector_free_check)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Door"
	row.add_child(label)
	connector_door_option = OptionButton.new()
	connector_door_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connector_door_option.item_selected.connect(_on_connector_door_selected)
	row.add_child(connector_door_option)
	connector_section.add_child(row)
	connectors_list.item_selected.connect(_on_connector_selected)
	_sync_connector_controls()
	_setup_free_door_controls()

## The tool picker (connector run / free-standing door) and the free door settings.
func _setup_free_door_controls() -> void:
	connector_tool_option = OptionButton.new()
	connector_tool_option.add_item("Tool: connector run")
	connector_tool_option.add_item("Tool: free-standing door")
	connector_tool_option.item_selected.connect(_on_connector_tool_selected)
	connector_section.add_child(connector_tool_option)
	connector_section.move_child(connector_tool_option, connector_mode_button.get_index() + 1)

	door_tool_box = VBoxContainer.new()
	door_tool_box.visible = false
	var hint := Label.new()
	hint.text = "Click a cell: the door starts there and runs right (horizontal) or down (vertical). Click a door to remove it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	door_tool_box.add_child(hint)
	door_orient_option = OptionButton.new()
	door_orient_option.add_item("Horizontal (blocks north-south)")
	door_orient_option.add_item("Vertical (blocks east-west)")
	door_tool_box.add_child(door_orient_option)
	var width_row := HBoxContainer.new()
	var width_label := Label.new()
	width_label.text = "Width"
	width_row.add_child(width_label)
	door_width_spin = SpinBox.new()
	door_width_spin.min_value = 1
	door_width_spin.max_value = 5
	door_width_spin.value = 1
	door_width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door_width_spin.value_changed.connect(func(_v): _fill_free_door_types())
	width_row.add_child(door_width_spin)
	door_tool_box.add_child(width_row)
	door_type_option = OptionButton.new()
	door_tool_box.add_child(door_type_option)
	_fill_free_door_types()
	free_doors_list = ItemList.new()
	free_doors_list.custom_minimum_size = Vector2(0, 80)
	door_tool_box.add_child(free_doors_list)
	connector_section.add_child(door_tool_box)

func _on_connector_tool_selected(_item: int) -> void:
	connector_run_start = null
	door_tool_box.visible = connector_tool_option.selected == 1
	queue_redraw()

## any (the biome default), then each door type; ones that do not fit the chosen width are marked.
func _fill_free_door_types() -> void:
	var keep := door_type_option.get_item_text(door_type_option.selected).get_slice(" ", 0) if door_type_option.selected >= 0 and door_type_option.item_count > 0 else "any"
	door_type_option.clear()
	door_type_option.add_item("any")
	var width := int(door_width_spin.value)
	var types := DoorRegistry.all_types()
	types.sort()
	for type_name in types:
		var def := DoorRegistry.get_def(type_name)
		var fits := width >= int(def.get("min_width", 1)) and width <= int(def.get("max_width", 1))
		door_type_option.add_item("%s (%d-%d wide)%s" % [type_name, int(def.get("min_width", 1)), int(def.get("max_width", 1)), "" if fits else "  - does not fit w%d" % width])
	for i in door_type_option.item_count:
		if door_type_option.get_item_text(i).get_slice(" ", 0) == keep:
			door_type_option.select(i)

func _free_door_cells(door: Dictionary) -> Array[Vector2i]:
	return DoorPlacer.free_door_cells(door["cell"], door["vertical"], door["width"])

func _free_door_label(door: Dictionary) -> String:
	var cell: Vector2i = door["cell"]
	return "%s w%d @ (%d, %d)  %s" % ["vertical" if door["vertical"] else "horizontal", door["width"], cell.x, cell.y, door["type"]]

func _find_free_door_at(cell: Vector2i) -> int:
	for i in free_doors.size():
		if _free_door_cells(free_doors[i]).has(cell):
			return i
	return -1

func _handle_free_door_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cell := _mouse_to_cell()
	if not _cell_in_bounds(cell):
		return
	var existing := _find_free_door_at(cell)
	if existing != -1:
		_remove_free_door_with_undo(existing)
		return
	var door := {
		"cell": cell,
		"vertical": door_orient_option.selected == 1,
		"width": int(door_width_spin.value),
		"type": door_type_option.get_item_text(door_type_option.selected).get_slice(" ", 0),
	}
	for door_cell in _free_door_cells(door):
		if not _cell_in_bounds(door_cell):
			_show_export_status("That door does not fit inside the room here")
			return
		if _find_free_door_at(door_cell) != -1:
			_show_export_status("That door overlaps another door")
			return
	var index := free_doors.size()
	var saved := door.duplicate()
	_insert_free_door(saved.duplicate(), index)
	_push_undo(
		func(): _remove_free_door(index),
		func(): _insert_free_door(saved.duplicate(), index)
	)
	_clear_walls_under_cells(_free_door_cells(door))

func _insert_free_door(door: Dictionary, index: int) -> void:
	free_doors.insert(index, door)
	_refresh_free_doors_list()
	_update_validation_display()
	queue_redraw()

func _remove_free_door(index: int) -> void:
	free_doors.remove_at(index)
	_refresh_free_doors_list()
	_update_validation_display()
	queue_redraw()

func _remove_free_door_with_undo(index: int) -> void:
	var saved: Dictionary = free_doors[index].duplicate()
	_remove_free_door(index)
	_push_undo(
		func(): _insert_free_door(saved.duplicate(), index),
		func(): _remove_free_door(index)
	)

func _set_free_doors(new_list: Array) -> void:
	free_doors = new_list.duplicate(true)
	_refresh_free_doors_list()
	_update_validation_display()
	queue_redraw()

func _clear_free_doors() -> void:
	free_doors.clear()
	if free_doors_list != null:
		_refresh_free_doors_list()

func _refresh_free_doors_list() -> void:
	if free_doors_list == null:
		return
	free_doors_list.clear()
	for door in free_doors:
		free_doors_list.add_item(_free_door_label(door))

## The doors mirrored across the room: a horizontal door's cells are the SOUTH cell of
## each column (barrier above them), a vertical door's the WEST cell of each row (barrier
## to their east), so a mirror that swaps a door's sides also moves its first cell.
func _flipped_free_doors(horizontal: bool) -> Array:
	var result: Array = []
	for door in free_doors:
		var copy: Dictionary = door.duplicate()
		var cell: Vector2i = door["cell"]
		var w: int = door["width"]
		if horizontal:
			if door["vertical"]:
				copy["cell"] = Vector2i(width - 2 - cell.x, cell.y)
			else:
				copy["cell"] = Vector2i(width - cell.x - w, cell.y)
		else:
			if door["vertical"]:
				copy["cell"] = Vector2i(cell.x, height - cell.y - w)
			else:
				copy["cell"] = Vector2i(cell.x, height - cell.y)
		result.append(copy)
	return result

func _serialize_free_doors() -> Array:
	var result: Array = []
	for door in free_doors:
		var cell: Vector2i = door["cell"]
		result.append({
			"cell": {"x": cell.x, "y": cell.y},
			"orient": "v" if door["vertical"] else "h",
			"width": door["width"],
			"type": door["type"],
		})
	return result

func _selected_connector_index() -> int:
	var selected := connectors_list.get_selected_items()
	return -1 if selected.is_empty() else selected[0]

## Shows the selected connector's settings; disabled when nothing is selected.
func _sync_connector_controls() -> void:
	_syncing_connector_controls = true
	var index := _selected_connector_index()
	connector_free_check.disabled = index == -1
	connector_door_option.disabled = index == -1
	connector_free_check.set_pressed_no_signal(index != -1 and connectors[index].get("free", false))
	var door_value: String = "any" if index == -1 else connectors[index].get("door", "")
	if door_value == "":
		door_value = "any"
	_fill_door_options(index)
	connector_door_option.select(0)
	for i in connector_door_option.item_count:
		if connector_door_option.get_item_text(i).get_slice(" ", 0) == door_value:
			connector_door_option.select(i)
	_syncing_connector_controls = false

## any / none, then every door type, marking the ones that do not fit the run's
## width (game/doors/<type>.json min_width / max_width). A joint is only as wide as the
## overlap with the room next to it, so a misfit is a warning, not forbidden.
func _fill_door_options(index: int) -> void:
	connector_door_option.clear()
	connector_door_option.add_item("any")
	connector_door_option.add_item("none")
	var run_width := 1
	if index != -1:
		var start: Vector2i = connectors[index]["position"]
		var end: Vector2i = connectors[index].get("b", start)
		run_width = maxi(end.x - start.x, end.y - start.y) + 1
	var types := DoorRegistry.all_types()
	types.sort()
	for type_name in types:
		var def := DoorRegistry.get_def(type_name)
		var fits := run_width >= int(def.get("min_width", 1)) and run_width <= int(def.get("max_width", 1))
		var label := "%s (%d-%d wide)" % [type_name, int(def.get("min_width", 1)), int(def.get("max_width", 1))]
		connector_door_option.add_item(label if fits else label + "  - does not fit w%d" % run_width)

func _on_connector_selected(_index: int) -> void:
	_sync_connector_controls()

func _on_connector_free_toggled(pressed: bool) -> void:
	if _syncing_connector_controls:
		return
	_edit_selected_connector("free", pressed if pressed else null)

func _on_connector_door_selected(item: int) -> void:
	if _syncing_connector_controls:
		return
	var text := connector_door_option.get_item_text(item).get_slice(" ", 0)
	_edit_selected_connector("door", null if text == "any" else text)

## Sets (or, for null, removes) one field of the selected connector, undoable as a
## whole-connector swap.
func _edit_selected_connector(key: String, value: Variant) -> void:
	var index := _selected_connector_index()
	if index == -1:
		return
	var before: Dictionary = connectors[index].duplicate()
	var after: Dictionary = before.duplicate()
	if value == null:
		after.erase(key)
	else:
		after[key] = value
	_replace_connector(index, after)
	_push_undo(
		func(): _replace_connector(index, before),
		func(): _replace_connector(index, after)
	)

func _replace_connector(index: int, connector: Dictionary) -> void:
	connectors[index] = connector.duplicate()
	connectors_list.set_item_text(index, _connector_label(connector))
	_sync_connector_controls()
	_update_validation_display()
	queue_redraw()

func _is_boundary_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	return cell.x == 0 or cell.x == width - 1 or cell.y == 0 or cell.y == height - 1

## The connector whose run covers `cell`, or -1.
func _find_connector_at(cell: Vector2i) -> int:
	for i in range(connectors.size()):
		var start: Vector2i = connectors[i]["position"]
		var end: Vector2i = connectors[i].get("b", start)
		if cell.x >= start.x and cell.x <= end.x and cell.y >= start.y and cell.y <= end.y:
			return i
	return -1

func _insert_connector(cell: Vector2i, index: int) -> void:
	_insert_connector_data({"position": cell}, index)

## `connector` is {"position", "b"?, "free"?, "door"?}, the same shape as the list.
func _insert_connector_data(connector: Dictionary, index: int) -> void:
	var cell: Vector2i = connector["position"]
	connectors.insert(index, connector)
	var marker := _make_connector_marker(cell)
	connectors_layer.add_child(marker)
	connector_markers.insert(index, marker)
	connectors_list.add_item(_connector_label(connector))
	if index != connectors_list.item_count - 1:
		connectors_list.move_item(connectors_list.item_count - 1, index)
	_update_validation_display()
	queue_redraw()

## "(2, 0)-(4, 0)  w3  free  door: iron" -- only what is set beyond the defaults.
func _connector_label(connector: Dictionary) -> String:
	var start: Vector2i = connector["position"]
	var end: Vector2i = connector.get("b", start)
	var text := "(%d, %d)" % [start.x, start.y]
	if end != start:
		text += "-(%d, %d)  w%d" % [end.x, end.y, maxi(end.x - start.x, end.y - start.y) + 1]
	if connector.get("free", false):
		text += "  free"
	if connector.get("door", "") != "":
		text += "  door: " + connector["door"]
	return text

func _remove_connector(index: int) -> void:
	connectors.remove_at(index)
	connector_markers[index].queue_free()
	connector_markers.remove_at(index)
	connectors_list.remove_item(index)
	if connector_free_check != null:
		_sync_connector_controls()
	_update_validation_display()
	queue_redraw()

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
	connector_run_start = null
	if connector_free_check != null:
		_sync_connector_controls()
	queue_redraw()

func _make_connector_marker(cell: Vector2i) -> Sprite2D:
	var marker := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(CONNECTOR_TEXTURE_PATH)
	atlas.region = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
	marker.texture = atlas
	marker.position = Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)
	return marker

## --- Spawners (player start / minion spawners) ---
## Session-only: not part of _build_export_data, matching the current
## room JSON format. A real runtime spawner system will be designed later.

func _populate_spawner_palette() -> void:
	_style_selection_highlight(spawner_palette_list, SPAWNER_MODE_COLOR)
	spawner_palette_list.add_item("player_spawner", _make_player_spawner_icon())
	spawner_palette_list.add_item("minion_spawner", _make_minion_spawner_icon())
	spawner_palette_list.set_item_icon_modulate(1, MINION_SPAWNER_ICON_COLOR)

func _make_player_spawner_icon() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(PLAYER_SPAWNER_TEXTURE_PATH)
	atlas.region = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
	return atlas

## Generic placeholder marker/icon for minion spawners. There's no concrete
## minion scene wired up yet (PlaceholderMouse was removed upstream in favor
## of a shared MinionController the team hasn't hooked up here), so this is
## just a tinted square until that's decided.
func _make_minion_spawner_icon() -> Texture2D:
	return preload("res://resources/gfx/placeholders/flat-color.png")

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
	elif selected_spawner_type == "minion_spawner":
		var index := _find_minion_spawner_at(cell)
		if index != -1:
			_remove_minion_spawner_with_undo(index)
		else:
			_add_minion_spawner_with_undo(cell)

func _find_minion_spawner_at(cell: Vector2i) -> int:
	for i in range(minion_spawners.size()):
		if minion_spawners[i]["cell"] == cell:
			return i
	return -1

func _try_open_spawner_settings(cell: Vector2i) -> bool:
	var index := _find_minion_spawner_at(cell)
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

func _add_minion_spawner_with_undo(cell: Vector2i) -> void:
	var index := minion_spawners.size()
	var data := {"cell": cell, "minion_type": "", "spawn_interval": 2.0, "spawn_count": 3}
	_insert_minion_spawner(data, index)
	_push_undo(
		func(): _remove_minion_spawner(index),
		func(): _insert_minion_spawner(data.duplicate(), index)
	)

func _remove_minion_spawner_with_undo(index: int) -> void:
	var data: Dictionary = minion_spawners[index].duplicate()
	_remove_minion_spawner(index)
	_push_undo(
		func(): _insert_minion_spawner(data.duplicate(), index),
		func(): _remove_minion_spawner(index)
	)

func _insert_minion_spawner(data: Dictionary, index: int) -> void:
	minion_spawners.insert(index, data)
	var marker := Sprite2D.new()
	marker.texture = _make_minion_spawner_icon()
	marker.modulate = MINION_SPAWNER_ICON_COLOR
	marker.scale = Vector2(0.5, 0.5)
	marker.position = _cell_center_world(data["cell"])
	spawners_layer.add_child(marker)
	minion_spawner_markers.insert(index, marker)
	_refresh_spawners_list()
	_update_test_button()

func _remove_minion_spawner(index: int) -> void:
	minion_spawners.remove_at(index)
	minion_spawner_markers[index].queue_free()
	minion_spawner_markers.remove_at(index)
	_refresh_spawners_list()
	_update_test_button()

func _clear_spawners() -> void:
	_clear_player_spawner()
	for marker in minion_spawner_markers:
		marker.queue_free()
	minion_spawners.clear()
	minion_spawner_markers.clear()
	_refresh_spawners_list()
	_update_test_button()

func _prune_invalid_spawners() -> void:
	if has_player_spawner and not _cell_in_bounds(player_spawner_cell):
		_clear_player_spawner()
	var i := minion_spawners.size() - 1
	while i >= 0:
		if not _cell_in_bounds(minion_spawners[i]["cell"]):
			_remove_minion_spawner(i)
		i -= 1

func _refresh_spawners_list() -> void:
	spawners_list.clear()
	if has_player_spawner:
		spawners_list.add_item("Player Spawner @ (%d, %d)" % [player_spawner_cell.x, player_spawner_cell.y])
	for spawner in minion_spawners:
		var cell: Vector2i = spawner["cell"]
		var kind: String = spawner["minion_type"] if spawner["minion_type"] != "" else "any"
		spawners_list.add_item("Minion Spawner (%s) @ (%d, %d) — test: every %.1fs x%d" % [kind, cell.x, cell.y, spawner["spawn_interval"], spawner["spawn_count"]])

func _spawners_list_index_to_minion_index(list_index: int) -> int:
	var offset := 1 if has_player_spawner else 0
	if list_index < offset:
		return -1
	return list_index - offset

func _on_edit_spawner_pressed() -> void:
	var selected := spawners_list.get_selected_items()
	if selected.is_empty():
		return
	var minion_index := _spawners_list_index_to_minion_index(selected[0])
	if minion_index != -1:
		_open_spawner_settings(minion_index)

func _on_delete_spawner_pressed() -> void:
	var selected := spawners_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if has_player_spawner and index == 0:
		_clear_player_spawner_with_undo()
		return
	var minion_index := _spawners_list_index_to_minion_index(index)
	if minion_index != -1:
		_remove_minion_spawner_with_undo(minion_index)

## Every minion id (its json filename) in the game's minion folder and its subfolders, sorted.
func _minion_type_ids() -> Array:
	return MinionIndex.ids()

func _open_spawner_settings(minion_index: int) -> void:
	editing_spawner_index = minion_index
	var data: Dictionary = minion_spawners[minion_index]
	minion_type_option.clear()
	minion_type_option.add_item(MINION_ANY_LABEL, 0)
	var ids := _minion_type_ids()
	for i in ids.size():
		minion_type_option.add_item(ids[i], i + 1)
	minion_type_option.select(ids.find(data["minion_type"]) + 1)
	interval_spin_box.value = data["spawn_interval"]
	count_spin_box.value = data["spawn_count"]
	spawner_settings_dialog.popup_centered()

func _on_spawner_settings_confirmed() -> void:
	if editing_spawner_index == -1 or editing_spawner_index >= minion_spawners.size():
		return
	var index := editing_spawner_index
	var old_data: Dictionary = minion_spawners[index].duplicate()
	var new_data := old_data.duplicate()
	var picked := minion_type_option.get_selected_id()
	new_data["minion_type"] = "" if picked == 0 else _minion_type_ids()[picked - 1]
	new_data["spawn_interval"] = interval_spin_box.value
	new_data["spawn_count"] = int(count_spin_box.value)
	_apply_spawner_settings(index, new_data)
	_push_undo(
		func(): _apply_spawner_settings(index, old_data),
		func(): _apply_spawner_settings(index, new_data)
	)

func _apply_spawner_settings(index: int, data: Dictionary) -> void:
	minion_spawners[index] = data.duplicate()
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
	_spawn_test_entities()

## Puts a fresh player + minion spawner timers into the room. Used both to
## enter Test mode and to restart it without leaving/re-entering.
func _spawn_test_entities() -> void:
	test_player = load(PLAYER_CONTROLLER_SCENE_PATH).instantiate()
	test_player.name = "1"
	test_player.global_position = WORLD_OFFSET + _cell_top_left(player_spawner_cell)
	add_child(test_player)
	test_player.get_node("Camera2D").make_current()

	for spawner in minion_spawners:
		_start_minion_spawner_timer(spawner)

## Frees the test player, spawner timers, and any spawned minions, but leaves
## the offline multiplayer peer and editor UI state untouched so a restart
## can immediately call _spawn_test_entities() again.
func _teardown_test_entities() -> void:
	# set_process(false) first: PlayerController's queued-for-deletion node
	# still gets one more _process() this frame otherwise, and it reads
	# multiplayer.get_unique_id(), which errors once the peer is gone.
	# remove_child() before queue_free() so the name "1" is free again right
	# away — restart adds a new player named "1" in the same call, and
	# queue_free() alone leaves the old one occupying that name until its
	# deferred removal, which makes Godot rename the new node and breaks its
	# multiplayer-authority check (and with it, the player camera).
	if is_instance_valid(test_player):
		test_player.set_process(false)
		test_player.set_physics_process(false)
		remove_child(test_player)
		test_player.queue_free()
	test_player = null
	for timer in test_spawn_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	test_spawn_timers.clear()
	_kill_all_test_minions()

func _kill_all_test_minions() -> void:
	for minion in test_spawned_minions:
		if is_instance_valid(minion):
			minion.set_process(false)
			minion.queue_free()
	test_spawned_minions.clear()

func _on_kill_minions_pressed() -> void:
	_kill_all_test_minions()

func _on_restart_test_pressed() -> void:
	_restart_test()

func _restart_test() -> void:
	if not test_mode_active:
		return
	_teardown_test_entities()
	_spawn_test_entities()

func _cell_top_left(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)

func _start_minion_spawner_timer(spawner: Dictionary) -> void:
	var world_pos: Vector2 = WORLD_OFFSET + _cell_top_left(spawner["cell"])
	var max_count: int = spawner["spawn_count"]
	var spawned := [0]
	var timer := Timer.new()
	timer.wait_time = spawner["spawn_interval"]
	add_child(timer)
	test_spawn_timers.append(timer)
	timer.timeout.connect(func():
		spawned[0] += 1
		_spawn_test_minion(world_pos)
		if spawned[0] >= max_count:
			timer.stop()
	)
	timer.start()

## No concrete minion scene is wired up yet (see _make_minion_spawner_icon) —
## spawns a plain marker so spawn timing/count is still visible in Test mode.
func _spawn_test_minion(world_pos: Vector2) -> void:
	var minion := Sprite2D.new()
	minion.texture = _make_minion_spawner_icon()
	minion.modulate = MINION_SPAWNER_ICON_COLOR
	minion.scale = Vector2(0.5, 0.5)
	minion.global_position = world_pos
	add_child(minion)
	test_spawned_minions.append(minion)

func _on_quit_test_pressed() -> void:
	_stop_test()

func _stop_test() -> void:
	test_mode_active = false
	_teardown_test_entities()
	multiplayer.multiplayer_peer = null
	camera.enabled = true
	camera.make_current()
	$UI.visible = true
	overlay.visible = true
	test_hud.visible = false
	queue_redraw()

func _on_room_file_selected(path: String) -> void:
	if not FileAccess.file_exists(path):
		_show_export_status("Failed to open " + path)
		return
	var data := JsonOnloading.load_dict(path)
	if data.is_empty():
		_show_export_status("Invalid room file: " + path)
		return
	_load_room_data(data)
	# The folder is the biome (the file does not store it).
	room_biome = ""
	if path.begins_with(ROOMS_DIR):
		var folder := path.get_base_dir().trim_prefix(ROOMS_DIR.trim_suffix("/")).trim_prefix("/")
		if not folder.contains("/"):
			room_biome = folder
	_show_role_and_biome()
	_refresh_recent_rooms()
	_show_export_status("Loaded " + path)

func _load_room_data(data: Dictionary) -> void:
	undo_stack.clear()
	redo_stack.clear()
	_clear_objects()
	_clear_connectors()
	_clear_free_doors()
	_clear_spawners()

	room_id = str(data.get("id", ""))
	id_line_edit.text = room_id
	room_role = str(data.get("role", "normal"))
	room_extras.clear()
	for key in ROOM_EXTRA_KEYS:
		if data.has(key):
			room_extras[key] = data[key]
	_show_role_and_biome()

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

	for door_data in data.get("doors", []):
		var door_cell: Dictionary = door_data.get("cell", {})
		free_doors.append({
			"cell": Vector2i(int(door_cell.get("x", 0)), int(door_cell.get("y", 0))),
			"vertical": door_data.get("orient", "h") == "v",
			"width": maxi(1, int(door_data.get("width", 1))),
			"type": str(door_data.get("type", "any")),
		})
	_refresh_free_doors_list()

	for spawn_data in data.get("spawn_cells", []):
		var position_data: Dictionary = spawn_data.get("position", {})
		_insert_minion_spawner({
			"cell": Vector2i(int(position_data.get("x", 0)), int(position_data.get("y", 0))),
			"minion_type": str(spawn_data.get("minion", "")),
			"spawn_interval": 2.0,
			"spawn_count": 3,
		}, minion_spawners.size())

	for conn_data in data.get("connectors", []):
		# Accepts format 1 ({"position"}) and format 2 ({"a", "b"}). "b", "free" and
		# "door" are carried along, or re-saving a room would drop them.
		var conn := Connector.upgrade(conn_data)
		var loaded := {"position": Connector.a(conn)}
		if Connector.b(conn) != Connector.a(conn):
			loaded["b"] = Connector.b(conn)
		if Connector.is_free(conn):
			loaded["free"] = true
		if Connector.door(conn) != "" and Connector.door(conn) != "any":
			loaded["door"] = Connector.door(conn)
		_insert_connector_data(loaded, connectors.size())

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
	var folder := "" if room_biome == "" else room_biome + "/"
	var path := "%s%s%s.json" % [ROOMS_DIR, folder, room_id]
	pending_export_data = data
	if FileAccess.file_exists(path):
		pending_export_path = path
		overwrite_confirm_dialog.dialog_text = "%s already exists. Overwrite it?" % path
		overwrite_confirm_dialog.popup_centered()
		return
	# A brand-new room -- confirm where it's actually going instead of
	# silently trusting whatever the Room Info biome dropdown was left on.
	_show_save_location_dialog()

func _on_overwrite_confirmed() -> void:
	_write_room_file(pending_export_path, pending_export_data)

func _show_save_location_dialog() -> void:
	save_location_label.text = "Save \"%s\" into:" % room_id
	_refresh_save_location_folder_list(room_biome)
	save_location_dialog.popup_centered()

func _refresh_save_location_folder_list(preferred_folder: String) -> void:
	save_location_folder_list.clear()
	save_location_folder_list.add_item("(none - top level)")
	var select_index := 0
	for folder in _room_folders():
		if folder == "":
			continue
		save_location_folder_list.add_item(folder)
		if folder == preferred_folder:
			select_index = save_location_folder_list.item_count - 1
	save_location_folder_list.select(select_index)

func _on_save_location_confirmed() -> void:
	var selected := save_location_folder_list.get_selected_items()
	var folder_name := "" if selected.is_empty() or selected[0] == 0 else save_location_folder_list.get_item_text(selected[0])
	room_biome = folder_name
	_show_role_and_biome()
	save_location_dialog.hide()
	var folder := "" if folder_name == "" else folder_name + "/"
	var path := "%s%s%s.json" % [ROOMS_DIR, folder, room_id]
	if FileAccess.file_exists(path):
		pending_export_path = path
		overwrite_confirm_dialog.dialog_text = "%s already exists. Overwrite it?" % path
		overwrite_confirm_dialog.popup_centered()
		return
	_write_room_file(path, pending_export_data)

func _build_export_data() -> Dictionary:
	var data := {
		"format": Connector.FORMAT,
		"id": room_id,
		"role": room_role,
		"tags": tags,
		"width": width,
		"height": height,
		"floor": floor_names,
		"walls": walls_names,
		"objects": _serialize_objects(),
		"connectors": _serialize_connectors(),
	}
	for key in room_extras:
		data[key] = room_extras[key]
	var spawn_cells := _serialize_spawn_cells()
	if not spawn_cells.is_empty():
		data["spawn_cells"] = spawn_cells
	if not free_doors.is_empty():
		data["doors"] = _serialize_free_doors()
	return data

## The minion spawners are the room's spawn_cells: each is a cell the dungeon
## rolls a minion for, or (when "minion" is set) always spawns that exact minion.
## The test-mode interval / count are editor-only and not saved.
func _serialize_spawn_cells() -> Array:
	var result: Array = []
	for spawner in minion_spawners:
		var cell: Vector2i = spawner["cell"]
		var entry := {"position": {"x": cell.x, "y": cell.y}}
		if spawner.get("minion_type", "") != "":
			entry["minion"] = spawner["minion_type"]
		result.append(entry)
	return result

func _write_room_file(path: String, data: Dictionary) -> void:
	if not JsonOnloading.write_dict(path, data):
		_show_export_status("Failed to open %s for writing" % path)
		return
	_show_export_status("Exported to " + path)
	_refresh_recent_rooms()
	_refresh_known_tags()

func _on_validate_all_pressed() -> void:
	var total := 0
	var failed := []
	for room_file in _list_room_files():
		total += 1
		var errors := _validate_room_file(ROOMS_DIR + room_file)
		if not errors.is_empty():
			failed.append("%s: %s" % [room_file, ", ".join(errors)])
	if failed.is_empty():
		_show_export_status("Validated %d room(s) — all OK" % total)
	else:
		_show_export_status("Validated %d room(s) — %d issue(s): %s" % [total, failed.size(), " | ".join(failed)])

func _validate_room_file(path: String) -> Array[String]:
	var errors: Array[String] = []
	if not FileAccess.file_exists(path):
		errors.append("could not open")
		return errors
	var data := JsonOnloading.load_dict(path)
	if data.is_empty():
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
	var probe := {"width": w, "height": h, "connectors": []}
	for connector in data.get("connectors", []):
		probe["connectors"].append(Connector.upgrade(connector))
	errors.append_array(Connector.validate(probe))
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
	for door in free_doors:
		for door_cell in _free_door_cells(door):
			if not _cell_in_bounds(door_cell):
				errors.append("Free door at %s leaves the room" % str(door["cell"]))
				break
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
		result.append(Connector.make(pos, connector.get("b", pos), connector.get("free", false), connector.get("door", "")))
	return result

func _show_export_status(message: String) -> void:
	export_status_label.text = message

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
