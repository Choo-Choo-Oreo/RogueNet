class_name DebugDraw
extends Node2D

## World-space debug drawing, switched on and off by DebugState: room outlines
## and ids, connectors, doors, enemy state / target lines and cached routes.
## Sits above the light overlay so it can be read in the dark. Must be a child
## of the dungeon (world), NOT of a CanvasLayer -- a layer draws in screen space
## and would not follow the camera.

const TILE := 16
## Half a tile, as an int (TILE / 2 makes Godot warn about integer division).
const HALF := 8
## Opacity of the mesh-tile overlay: floors 35%, walls 50% (walls are harder to see).
const MESH_ALPHA_FLOOR := 0.35
const MESH_ALPHA_WALL := 0.5
## Text height in WORLD pixels (half of what it was). The glyphs themselves are
## rasterised at screen resolution, see _label.
const FONT_SIZE := 4

const ROLE_COLORS := {
	"entrance": Color(0.3, 1.0, 0.4),
	"boss": Color(1.0, 0.3, 0.3),
	"treasure": Color(1.0, 0.85, 0.2),
	"corridor": Color(0.3, 0.9, 1.0),
	"normal": Color(1.0, 1.0, 1.0),
}
const STATE_COLORS := [Color(0.6, 0.7, 0.9), Color(1.0, 0.9, 0.2), Color(1.0, 0.25, 0.25)]  # patrol, investigate, attack
const STATE_NAMES := ["patrol", "investigate", "attack"]

var _was_drawing := false
var _light_map: LightMap = null
var _renders: Array = []
var _renders_frame := -100000
var _mesh_texture: Texture2D = null
var _mesh_texture_light: Texture2D = null

func _ready() -> void:
	z_index = 4000
	z_as_relative = false

func _any_draw() -> bool:
	for option in ["show-room-outlines", "show-room-ids", "show-connectors", "show-doors", "show-enemy-state", "show-enemy-routes", "show-tile-grid", "show-mesh-grid", "show-mesh-tiles", "show-collision-rectangles", "show-active-enemies", "show-vision", "show-flow-field"]:
		if DebugState.on(option):
			return true
	return false

func _process(_delta: float) -> void:
	var drawing := _any_draw()
	if drawing or _was_drawing:
		queue_redraw()
	_was_drawing = drawing

func _draw() -> void:
	if DebugState.on("show-tile-grid"):
		_draw_grid()
	if DebugState.on("show-mesh-grid"):
		_draw_mesh_grid()
	if DebugState.on("show-mesh-tiles"):
		_draw_mesh_tiles()
	if DebugState.on("show-vision"):
		_draw_vision()
	if DebugState.on("show-flow-field"):
		_draw_flow_field()
	if DebugState.on("show-collision-rectangles"):
		_draw_collisions()
	if DebugState.on("show-active-enemies"):
		_draw_activity()
	if DebugState.on("show-room-outlines") or DebugState.on("show-room-ids"):
		_draw_rooms()
	if DebugState.on("show-connectors"):
		_draw_connectors()
	if DebugState.on("show-doors"):
		_draw_doors()
	if DebugState.on("show-enemy-state") or DebugState.on("show-enemy-routes"):
		_draw_enemies()

## The tiles currently on screen (plus one of margin).
func _visible_tiles() -> Rect2i:
	var viewport := get_viewport()
	var world: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	var from := Vector2i(floori(world.position.x / TILE) - 1, floori(world.position.y / TILE) - 1)
	var to := Vector2i(ceili(world.end.x / TILE) + 1, ceili(world.end.y / TILE) + 1)
	return Rect2i(from, to - from)

## Tile lines, with a brighter line every 8 tiles.
func _draw_grid() -> void:
	var tiles := _visible_tiles()
	var top := tiles.position.y * TILE
	var bottom := tiles.end.y * TILE
	var left := tiles.position.x * TILE
	var right := tiles.end.x * TILE
	for x in range(tiles.position.x, tiles.end.x + 1):
		draw_line(Vector2(x * TILE, top), Vector2(x * TILE, bottom), Color(1, 1, 1, 0.35 if x % 8 == 0 else 0.1), 1.0)
	for y in range(tiles.position.y, tiles.end.y + 1):
		draw_line(Vector2(left, y * TILE), Vector2(right, y * TILE), Color(1, 1, 1, 0.35 if y % 8 == 0 else 0.1), 1.0)

## The dual grid: the mesh tiles are drawn offset by half a tile, so its lines
## sit between the tile-grid lines (cyan).
func _draw_mesh_grid() -> void:
	var tiles := _visible_tiles()
	var top := tiles.position.y * TILE + HALF
	var bottom := tiles.end.y * TILE + HALF
	var left := tiles.position.x * TILE + HALF
	var right := tiles.end.x * TILE + HALF
	for x in range(tiles.position.x, tiles.end.x + 1):
		draw_line(Vector2(x * TILE + HALF, top), Vector2(x * TILE + HALF, bottom), Color(0.3, 0.9, 1.0, 0.3), 1.0)
	for y in range(tiles.position.y, tiles.end.y + 1):
		draw_line(Vector2(left, y * TILE + HALF), Vector2(right, y * TILE + HALF), Color(0.3, 0.9, 1.0, 0.3), 1.0)

func _dual_renders() -> Array:
	if Engine.get_process_frames() - _renders_frame > 120:
		_renders_frame = Engine.get_process_frames()
		_renders = get_parent().find_children("*", "DualGridRender", true, false)
	return _renders

## Overlays the any_debug atlas (MESH_ALPHA_FLOOR / MESH_ALPHA_WALL) on every mesh cell, picked by the same
## 4-corner mask the real tile uses: dark for walls, light for floors. Walls are
## drawn from one renderer (they all share one group mask), floors from the
## floor data itself, one overlay per floor type present in the cell.
func _draw_mesh_tiles() -> void:
	if _mesh_texture == null:
		_mesh_texture = load("res://resources/gfx/tileset/any_debug_dark.png")
	if _mesh_texture_light == null:
		_mesh_texture_light = load("res://resources/gfx/tileset/any_debug_light.png")
	if _mesh_texture == null or _mesh_texture_light == null:
		return
	var floor_render: DualGridRender = null
	var wall_render: DualGridRender = null
	for render: DualGridRender in _dual_renders():
		if not is_instance_valid(render.data_layer):
			continue
		if render.group_sources.is_empty():
			floor_render = floor_render if floor_render != null else render
		elif wall_render == null:
			wall_render = render
	var tiles := _visible_tiles()
	for y in range(tiles.position.y, tiles.end.y):
		for x in range(tiles.position.x, tiles.end.x):
			var pos := Vector2i(x, y)
			if floor_render != null:
				var masks := {}
				for k in 4:
					var source: int = floor_render._cell_id(pos + Vector2i(k & 1, k >> 1))
					if source >= 0:
						masks[source] = masks.get(source, 0) | (1 << k)
				for mask in masks.values():
					_draw_mesh_cell(pos, mask, _mesh_texture_light, MESH_ALPHA_FLOOR)
			if wall_render != null:
				var wall_mask := 0
				for k in 4:
					if wall_render._is_filled(wall_render._cell_id(pos + Vector2i(k & 1, k >> 1))):
						wall_mask |= 1 << k
				_draw_mesh_cell(pos, wall_mask, _mesh_texture, MESH_ALPHA_WALL)

func _draw_mesh_cell(pos: Vector2i, mask: int, texture: Texture2D, alpha: float) -> void:
	if mask == 0:
		return
	var atlas_cell: Vector2i = DualGridRender.MASK_TO_CELL[mask]
	draw_texture_rect_region(texture,
		Rect2(Vector2(pos) * TILE + Vector2(HALF, HALF), Vector2(TILE, TILE)),
		Rect2(Vector2(atlas_cell) * TILE, Vector2(TILE, TILE)), Color(1, 1, 1, alpha))

func _light() -> LightMap:
	if not is_instance_valid(_light_map):
		_light_map = get_parent().find_child("LightMap", true, false) as LightMap
	return _light_map

## The local player's flooded vision, in the 8px light cells: green = near,
## red = far edge of the light.
func _draw_vision() -> void:
	var light := _light()
	if light == null or light._local == null:
		return
	var cells: Array = light._local.reached
	var cost: Dictionary = light._local.cost
	var far := 1
	for cell in cells:
		far = maxi(far, int(cost.get(cell, 0)))
	for cell in cells:
		var t := float(cost.get(cell, 0)) / far
		var color := Color(0.3, 1.0, 0.4).lerp(Color(1.0, 0.3, 0.3), t)
		draw_rect(Rect2(Vector2(cell) * LightMap.CELL, Vector2(LightMap.CELL, LightMap.CELL)), Color(color, 0.2), true)

## The shared walking-distance field enemies follow toward the local player:
## the number is tiles to the player, the line points along the step they take.
## FlowField only builds each map once something asks for it, so either can be
## missing: the lines come from the walkers' (terrain-weighted) field when there
## is one, else the flyers' plain one.
func _draw_flow_field() -> void:
	var player := PlayerLookup.find_local(get_tree())
	if player == null:
		return
	var field: Dictionary = FlowField._fields.get(player.get_instance_id(), {})
	var distances: Dictionary = field.get("distances", {})
	var directions: Dictionary = field.get("terrain_directions", field.get("directions", {}))
	var tiles := _visible_tiles()
	for tile in (distances if not distances.is_empty() else directions):
		if not tiles.has_point(tile):
			continue
		var centre := Vector2(tile) * TILE + Vector2(TILE, TILE) / 2.0
		var step: Vector2i = directions.get(tile, Vector2i.ZERO)
		if step != Vector2i.ZERO:
			draw_line(centre, centre + Vector2(step) * 5.0, Color(1.0, 0.9, 0.3, 0.8), 1.0)
		if distances.has(tile):
			_label(Vector2(tile) * TILE + Vector2(1, 7), str(distances[tile]), Color(1, 1, 1, 0.7))

## What stops the local player: red = blocked for them (walls, void, doors they
## can't open), orange = a closed door that stops shots but they can open.
func _draw_collisions() -> void:
	var player := PlayerLookup.find_local(get_tree())
	if player == null:
		return
	var mover: GridMover = player.grid_mover
	var tiles := _visible_tiles()
	for y in range(tiles.position.y, tiles.end.y):
		for x in range(tiles.position.x, tiles.end.x):
			var tile := Vector2i(x, y)
			var color := Color.TRANSPARENT
			if mover.is_tile_blocked(tile):
				color = Color(1.0, 0.2, 0.2)
			elif mover.blocks_shot(tile):
				color = Color(1.0, 0.6, 0.1)
			if color.a > 0.0:
				var rect := Rect2(Vector2(tile) * TILE, Vector2(TILE, TILE))
				draw_rect(rect, Color(color, 0.3), true)
				draw_rect(rect, color, false, 1.0)

## Green dot = doing a full AI tick, grey dot = waiting (boxed in / re-thinking
## in a few frames) or driven by the host.
func _draw_activity() -> void:
	var frame := Engine.get_process_frames()
	for enemy in get_tree().get_nodes_in_group("antagonist"):
		if not "_idle_until_frame" in enemy:
			continue
		var thinking: bool = enemy.is_multiplayer_authority() and not enemy._stuck and enemy._idle_until_frame <= frame
		var centre: Vector2 = enemy.global_position + Vector2(TILE, TILE) / 2.0
		draw_circle(centre, 2.5, Color(0.3, 1.0, 0.4) if thinking else Color(0.6, 0.6, 0.6))

func _draw_rooms() -> void:
	for i in DebugState.placements.size():
		var p = DebugState.placements[i]
		var room: Dictionary = DebugState.rooms.get(p.room_id, {})
		if room.is_empty():
			continue
		var color: Color = ROLE_COLORS.get(room.get("role", "normal"), Color.WHITE)
		var rect := Rect2(Vector2(p.offset) * TILE, Vector2(room["width"], room["height"]) * TILE)
		if DebugState.on("show-room-outlines"):
			draw_rect(rect, color, false, 1.0)
		if DebugState.on("show-room-ids"):
			_label(rect.position + Vector2(2, FONT_SIZE + 1), "#%d %s" % [i, p.room_id], color)
			_label(rect.position + Vector2(2, FONT_SIZE * 2 + 2), "%s  depth %d" % [room.get("role", "normal"), p.depth], color)

## Green = joined to another room, red = sealed dead end, magenta = left open
## with no partner (should not happen).
func _draw_connectors() -> void:
	for p in DebugState.placements:
		var room: Dictionary = DebugState.rooms.get(p.room_id, {})
		for c in room.get("connectors", []):
			var anchor := Connector.a(c)
			var color := Color(1.0, 0.2, 1.0)
			if p.locked_connectors.has(anchor):
				color = Color(1.0, 0.25, 0.25)
			elif p.joint_cells.has(anchor):
				color = Color(0.3, 1.0, 0.4)
			for cell in Connector.cells(c):
				var rect := Rect2(Vector2(p.offset + cell) * TILE, Vector2(TILE, TILE))
				draw_rect(rect, Color(color, 0.25), true)
				draw_rect(rect, color, false, 1.0)

func _draw_doors() -> void:
	for door: DoorRegistry.Door in DoorRegistry.doors:
		var color := Color(0.3, 1.0, 0.4) if door.is_open else Color(1.0, 0.6, 0.1)
		for cell in door.cells:
			var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
			draw_rect(rect, Color(color, 0.3), true)
			draw_rect(rect, color, false, 1.0)
		var first: Vector2i = door.cells[0]
		var text := "door %d %s%s %s" % [door.id, door.type, " (bars)" if door.transparent else "", "open" if door.is_open else "closed"]
		_label(Vector2(first) * TILE + Vector2(0, -2), text, color)

func _draw_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("antagonist"):
		if not "_last_state" in enemy:
			continue
		var state := clampi(int(enemy._last_state), 0, 2)
		var color: Color = STATE_COLORS[state]
		var centre: Vector2 = enemy.global_position + Vector2(TILE, TILE) / 2.0
		if DebugState.on("show-enemy-state"):
			draw_arc(centre, 7.0, 0.0, TAU, 16, color, 1.0)
			_label(centre + Vector2(-8, -9), STATE_NAMES[state], color)
			var target = enemy._target
			if state != 0 and is_instance_valid(target):
				draw_line(centre, target.global_position + Vector2(TILE, TILE) / 2.0, Color(color, 0.7), 1.0)
		if DebugState.on("show-enemy-routes"):
			# The tile the enemy last tried to step onto (flow-field and direct
			# steps never fill _cached_path, so this is what shows them).
			if Time.get_ticks_msec() - enemy._debug_step_msec < 400:
				var step_rect := Rect2(Vector2(enemy._debug_step_tile) * TILE, Vector2(TILE, TILE))
				draw_rect(step_rect, Color(1.0, 0.9, 0.2, 0.3), true)
				draw_line(centre, step_rect.get_center(), Color(1.0, 0.9, 0.2, 0.8), 1.0)
			var path: Array = enemy._cached_path
			var from: int = maxi(enemy._cached_path_index - 1, 0)
			for i in range(from, path.size() - 1):
				draw_line(Vector2(path[i]) * TILE + Vector2(8, 8), Vector2(path[i + 1]) * TILE + Vector2(8, 8), Color(1.0, 1.0, 1.0, 0.6), 1.0)

## Text is drawn at screen resolution and snapped to a whole screen pixel, so it
## stays sharp at any camera zoom instead of being a scaled-up world-size glyph.
## Only its anchor point lives in the world, so it still follows the map.
func _label(pos: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var zoom := to_screen.get_scale().x
	var screen := (to_screen * pos).round()
	draw_set_transform(to_screen.affine_inverse() * screen, 0.0, Vector2(1.0 / zoom, 1.0 / zoom))
	var size := maxi(int(round(FONT_SIZE * zoom)), 6)
	draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
