class_name DebugDraw
extends Node2D

## World-space debug drawing, switched on and off by DebugState: room outlines
## and ids, connectors, doors, minion state / target lines and cached routes.
## Sits above the light overlay so it can be read in the dark. Must be a child
## of the dungeon (world), NOT of a CanvasLayer -- a layer draws in screen space
## and would not follow the camera.

const TILE := 16
## Half a tile, as an int (TILE / 2 makes Godot warn about integer division).
const HALF := 8
## Opacity of the mesh-tile overlay: floors 35%, walls 50% (walls are harder to see).
const MESH_ALPHA_FLOOR := 0.35
const MESH_ALPHA_WALL := 0.5
## Label text size in screen pixels of a 720-high window (times GameView.debug_scale), the same
## as the DebugMenu overlay. Not tied to the world zoom; see _label.
const LABEL_SIZE := 11

const ROLE_COLORS := {
	"entrance": Color(0.3, 1.0, 0.4),
	"boss": Color(1.0, 0.3, 0.3),
	"treasure": Color(1.0, 0.85, 0.2),
	"corridor": Color(0.3, 0.9, 1.0),
	"normal": Color(1.0, 1.0, 1.0),
}
const STATE_COLORS := [Color(0.6, 0.7, 0.9), Color(1.0, 0.9, 0.2), Color(1.0, 0.25, 0.25)]  # patrol, investigate, attack
const STATE_NAMES := ["patrol", "investigate", "attack"]
## Inspector text for a sense the creature does not have, or that is not built yet.
const NO_SENSE_COLOR := Color(0.6, 0.6, 0.6)

var _was_drawing := false
var _light_map: LightMap = null
var _vision: PlayerVision = null
var _renders: Array = []
var _renders_frame := -100000
var _mesh_texture: Texture2D = null
var _mesh_texture_light: Texture2D = null

func _ready() -> void:
	z_index = 4000
	z_as_relative = false

func _any_draw() -> bool:
	for option in ["show-room-outlines", "show-room-ids", "show-connectors", "show-doors", "show-minion-state", "show-minion-routes", "show-sight", "show-sound", "show-touch", "show-smell", "show-taste", "show-minion-inspector", "show-tile-grid", "show-mesh-grid", "show-mesh-tiles", "show-collision-rectangles", "show-active-minions", "show-vision", "show-torch-light", "show-adventurer-sight", "show-adventurer-touch", "show-flow-field"]:
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
	if DebugState.on("show-torch-light"):
		_draw_torch_light()
	if DebugState.on("show-adventurer-sight") or DebugState.on("show-adventurer-touch"):
		_draw_adventurer_senses()
	if DebugState.on("show-flow-field"):
		_draw_flow_field()
	if DebugState.on("show-collision-rectangles"):
		_draw_collisions()
	if DebugState.on("show-active-minions"):
		_draw_activity()
	if DebugState.on("show-room-outlines") or DebugState.on("show-room-ids"):
		_draw_rooms()
	if DebugState.on("show-connectors"):
		_draw_connectors()
	if DebugState.on("show-doors"):
		_draw_doors()
	if DebugState.on("show-minion-state") or DebugState.on("show-minion-routes"):
		_draw_minions()
	_draw_senses()
	if DebugState.on("show-sound"):
		_draw_sound()
	if DebugState.on("show-minion-inspector"):
		_draw_inspector()

## The tiles currently on screen (plus one of margin).
func _visible_tiles() -> Rect2i:
	var view := GameView.of(self)
	var shown := view.get_global_rect() if view else get_viewport().get_visible_rect()
	var world: Rect2 = get_canvas_transform().affine_inverse() * shown
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

func _player_vision() -> PlayerVision:
	if not is_instance_valid(_vision):
		_vision = get_parent().find_child("PlayerVision", true, false) as PlayerVision
	return _vision

## What the local player's team sees (PlayerVision.team_levels), in the 8px light cells:
## yellow = bright, blue = dim, nothing drawn = dark.
func _draw_vision() -> void:
	var vision := _player_vision()
	if vision == null:
		return
	_draw_levels(vision.team_levels(), Color(1.0, 0.9, 0.3, 0.25), Color(0.3, 0.5, 1.0, 0.25))

## Each torch on screen (LightMap.drawn_levels): orange = bright, brown = dim.
func _draw_torch_light() -> void:
	var light := _light()
	if light == null:
		return
	for levels in light.drawn_levels():
		_draw_levels(levels, Color(1.0, 0.55, 0.1, 0.2), Color(0.55, 0.3, 0.1, 0.2))

func _draw_levels(levels: Dictionary, bright: Color, dim: Color) -> void:
	for cell in levels:
		var color := bright if levels[cell] == LightMap.Level.BRIGHT else dim
		draw_rect(Rect2(Vector2(cell) * LightMap.CELL, Vector2(LightMap.CELL, LightMap.CELL)), color, true)

## Each teammate's sight (green: in range and line of sight, lit or not) and touch (pink outline).
func _draw_adventurer_senses() -> void:
	var vision := _player_vision()
	if vision == null:
		return
	for view in vision.drawn_views():
		if DebugState.on("show-adventurer-sight"):
			for tile in view.seen:
				draw_rect(Rect2(Vector2(tile) * TILE, Vector2(TILE, TILE)), Color(0.3, 1.0, 0.4, 0.12), true)
		if DebugState.on("show-adventurer-touch"):
			for tile in view.touched:
				draw_rect(Rect2(Vector2(tile) * TILE + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(1.0, 0.4, 0.8, 0.8), false, 1.0)

## The shared walking-distance field minions follow toward the local player:
## the number is tiles to the player, the line points along the step they take.
## FlowField only builds each map once something asks for it, so either can be
## missing: the lines come from the walkers' (terrain-weighted) field when there
## is one, else the flyers' plain one.
func _draw_flow_field() -> void:
	var player := PlayerLookup.find_local(get_tree())
	if player == null:
		return
	var field: Dictionary = FlowField._fields.get([player.get_instance_id(), 1], {})
	var distances: Dictionary = field.get("distances", {})
	var directions: Dictionary = field.get("terrain_directions", field.get("directions", {}))
	if distances.is_empty() and directions.is_empty():
		_label(player.global_position + Vector2(-8, -6), "no flow field: nothing is chasing you", Color(1.0, 0.9, 0.3))
		return
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
## in a few ticks) or driven by the host.
func _draw_activity() -> void:
	for minion in get_tree().get_nodes_in_group("antagonist"):
		if not minion.has_method("is_thinking"):
			continue
		var thinking: bool = minion.is_thinking()
		var centre: Vector2 = minion.global_position + Vector2(TILE, TILE) / 2.0
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
			_label(rect.position + Vector2(2, _line_height()), "#%d %s" % [i, p.room_id], color)
			_label(rect.position + Vector2(2, _line_height() * 2), "%s  depth %d" % [room.get("role", "normal"), p.depth], color)

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

func _draw_minions() -> void:
	var near := _visible_tiles().grow(8)
	for minion in get_tree().get_nodes_in_group("antagonist"):
		if not "_last_state" in minion or not near.has_point(Vector2i((minion.global_position / TILE).floor())):
			continue
		var state := clampi(int(minion._last_state), 0, 2)
		var color: Color = STATE_COLORS[state]
		var centre: Vector2 = minion.global_position + Vector2(TILE, TILE) / 2.0
		if DebugState.on("show-minion-state"):
			draw_arc(centre, 7.0, 0.0, TAU, 16, color, 1.0)
			_label(centre + Vector2(-8, -9), STATE_NAMES[state], color)
			var target = minion._target
			if state != 0 and is_instance_valid(target):
				draw_line(centre, target.global_position + Vector2(TILE, TILE) / 2.0, Color(color, 0.7), 1.0)
		if DebugState.on("show-minion-routes"):
			# The tile the minion last tried to step onto (flow-field and direct
			# steps never fill _cached_path, so this is what shows them).
			if Time.get_ticks_msec() - minion._debug_step_msec < 400:
				var step_rect := Rect2(Vector2(minion._debug_step_tile) * TILE, Vector2(TILE, TILE))
				draw_rect(step_rect, Color(1.0, 0.9, 0.2, 0.3), true)
				draw_line(centre, step_rect.get_center(), Color(1.0, 0.9, 0.2, 0.8), 1.0)
			var path: Array = minion._cached_path
			var from: int = maxi(minion._cached_path_index - 1, 0)
			for i in range(from, path.size() - 1):
				draw_line(Vector2(path[i]) * TILE + Vector2(8, 8), Vector2(path[i + 1]) * TILE + Vector2(8, 8), Color(1.0, 1.0, 1.0, 0.6), 1.0)

## One toggle per sense, each drawing that sense's own range (SenseX.debug_draw) on every minion
## near the screen. A new sense gets a line here and a debug_draw of its own.
const SENSE_OPTIONS := {"show-sight": "sight", "show-sound": "hearing", "show-touch": "touch", "show-smell": "smell", "show-taste": "taste"}

func _draw_senses() -> void:
	var shown: Array[String] = []
	for option in SENSE_OPTIONS:
		if DebugState.on(option):
			shown.append(SENSE_OPTIONS[option])
	if shown.is_empty():
		return
	var near := _visible_tiles().grow(8)
	for minion in get_tree().get_nodes_in_group("antagonist"):
		if not "senses" in minion or not near.has_point(Vector2i((minion.global_position / TILE).floor())):
			continue
		var centre: Vector2 = minion.global_position + Vector2(TILE, TILE) / 2.0
		for sense_name in shown:
			minion.senses.get(sense_name).debug_draw(self, centre)
		_label_rings(minion, shown, centre)
		# Light is not a sense of the minion's (it is the player's light reaching it), but it is
		# what sends a minion to look when you walk near it in the dark, so sight shows it too.
		if "sight" in shown and minion.debug_lit:
			_label(centre + Vector2(-6, 6), "in your light", Color(1.0, 0.8, 0.5))
		if "sight" in shown:
			_draw_sight_line(minion, centre)
		if "hearing" in shown and minion.senses.state == MinionSenses.State.INVESTIGATE and is_instance_valid(minion.senses.investigate_marker):
			draw_line(centre, minion.senses.investigate_marker.global_position, Color(SenseHearing.DEBUG_COLOR, 0.8), 1.0)

## The number behind each ring, written on the ring at its point closest to the player (straight
## up when there is none): sight range in tiles. Hearing has no rings: its threshold is written
## over the minion, the dB a sound must still have there to be heard (compare the sound's tiles).
func _label_rings(minion: Node, shown: Array[String], centre: Vector2) -> void:
	var senses: MinionSenses = minion.senses
	var toward := Vector2.UP
	var player := _nearest_player(centre)
	if player != null and player.global_position + Vector2(TILE, TILE) / 2.0 != centre:
		toward = centre.direction_to(player.global_position + Vector2(TILE, TILE) / 2.0)
	if "sight" in shown and senses.sight.enabled:
		_label(centre + toward * senses.sight.range_tiles * TILE, "sight %.0f" % senses.sight.range_tiles, SenseSight.DEBUG_COLOR)
	if "hearing" in shown and senses.hearing.enabled:
		_label(centre + Vector2(-8, -TILE), "hears %.0f" % senses.hearing.threshold_db, SenseHearing.DEBUG_COLOR)

func _nearest_player(from: Vector2) -> Node2D:
	var best: Node2D = null
	for player: Node2D in get_tree().get_nodes_in_group("protagonist"):
		if best == null or player.global_position.distance_to(from) < best.global_position.distance_to(from):
			best = player
	return best

## What the minion's sight makes of its target right now: green = sees them, red = a wall is in
## the way (the blocking tile is outlined), grey = farther than its sight range.
func _draw_sight_line(minion: Node, centre: Vector2) -> void:
	var target = minion._target
	var sight: SenseSight = minion.senses.sight
	if not sight.enabled or not is_instance_valid(target):
		return
	var block := _sight_block(minion, target)
	var in_range: bool = minion.global_position.distance_to(target.global_position) <= sight.range_tiles * TILE
	var color := Color(0.6, 0.6, 0.6, 0.5)
	if in_range:
		color = Color(0.3, 1.0, 0.4, 0.9) if block == LineOfSight.CLEAR else Color(1.0, 0.3, 0.3, 0.9)
	draw_line(centre, target.global_position + Vector2(TILE, TILE) / 2.0, color, 1.0)
	if in_range and block != LineOfSight.CLEAR:
		draw_rect(Rect2(Vector2(block) * TILE, Vector2(TILE, TILE)), Color(1.0, 0.3, 0.3), false, 1.0)

func _sight_block(minion: Node, target: Node2D) -> Vector2i:
	var from := Vector2i((minion.global_position / TILE).floor())
	var to := Vector2i((target.global_position / TILE).floor())
	return LineOfSight.blocked_at(from, to, minion.grid_mover.blocks_sight)

## Each recent sound's spread (SoundSpread, per 8px quad), tinted by how loud it still is there:
## bright at the source, faint down at SoundSpread.FLOOR_DB; fades out over Sound.SHOW_SECONDS.
## Walls show up as the tint dropping sharply. Plus every noise spot (Sound markers, with seconds left).
func _draw_sound() -> void:
	var now := Time.get_ticks_msec()
	while not Sound.recent.is_empty() and now - int(Sound.recent[0]["msec"]) > Sound.SHOW_SECONDS * 1000.0:
		Sound.recent.pop_front()
	for sound in Sound.recent:
		var fade := 1.0 - (now - int(sound["msec"])) / (Sound.SHOW_SECONDS * 1000.0)
		var span := maxf(float(sound["db"]) - SoundSpread.FLOOR_DB, 1.0)
		var levels: Dictionary = sound["levels"]
		for quad in levels:
			var left := clampf((float(levels[quad]) - SoundSpread.FLOOR_DB) / span, 0.0, 1.0)
			draw_rect(Rect2(Vector2(quad) * SoundSpread.QUAD, Vector2(SoundSpread.QUAD, SoundSpread.QUAD)), Color(SenseHearing.DEBUG_COLOR, 0.5 * left * fade), true)
	if not Sound.recent.is_empty():
		_label_sound(Sound.recent.back())
	for marker: Node2D in get_tree().get_nodes_in_group(Sound.GROUP):
		var at := marker.global_position
		# Markers expire in game time (GameTick), like the minions that go to them.
		var seconds_left := (int(marker.get_meta("until_msec", 0)) - GameTick.msec()) / 1000.0
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(4, 0), at + Vector2(0, 4), at + Vector2(-4, 0)]), Color(SenseHearing.DEBUG_COLOR, 0.7))
		_label(at + Vector2(-8, -6), "noise %.0fs" % seconds_left, SenseHearing.DEBUG_COLOR)

## The numbers of the newest sound only (older ones would write over each other): on each tile
## the dB left in its top-left quad, at the source its level, and on every minion that was close
## enough to check "level >= threshold, heard" or "level < threshold, missed".
func _label_sound(sound: Dictionary) -> void:
	var levels: Dictionary = sound["levels"]
	var tiles := _visible_tiles()
	for quad: Vector2i in levels:
		var tile := Vector2i(floori(quad.x / 2.0), floori(quad.y / 2.0))
		if quad == tile * 2 and tiles.has_point(tile):
			_label(Vector2(tile) * TILE + Vector2(2, 6), "%.0f" % levels[quad], Color(1, 1, 1, 0.8))
	var source: Vector2i = sound["source"]
	_label(Vector2(source) * SoundSpread.QUAD + Vector2(-4, -2), "%.0f dB" % sound["db"], SenseHearing.DEBUG_COLOR)
	for sum in sound["sums"]:
		var at: Vector2 = sum[0] + Vector2(-4, TILE + 4)
		var level: float = sum[1]
		var total: float = sum[2]
		var threshold: float = sum[3]
		# With other recent noises added (SenseHearing.add_noise), when that made a difference.
		var added := " (+ others %.1f)" % total if total > level + 0.05 else ""
		if total >= threshold:
			_label(at, "%.1f%s >= %.0f heard" % [level, added, threshold], Color(0.3, 1.0, 0.4))
		elif level == -INF:
			_label(at, "past the flood < %.0f missed" % threshold, Color(1.0, 0.3, 0.3))
		else:
			_label(at, "%.1f%s < %.0f missed" % [level, added, threshold], Color(1.0, 0.3, 0.3))

## The minion under the mouse (within 2 tiles): a panel with each thing it is tracking on its
## own line, instead of everything stacked over every minion.
func _draw_inspector() -> void:
	var mouse := get_global_mouse_position()
	var picked: Node = null
	var best := 2.0 * TILE
	for minion in get_tree().get_nodes_in_group("antagonist"):
		if not "senses" in minion:
			continue
		var d: float = (minion.global_position + Vector2(TILE, TILE) / 2.0).distance_to(mouse)
		if d < best:
			best = d
			picked = minion
	if picked == null:
		return
	var lines := _inspect_lines(picked)
	var at: Vector2 = picked.global_position + Vector2(TILE + 4, -4)
	var line := _line_height()
	var width := 0.0
	for entry in lines:
		width = maxf(width, _label_width(entry[0]))
	draw_rect(Rect2(at - Vector2(2, line), Vector2(width + 4, lines.size() * line + 3)), Color(0, 0, 0, 0.6), true)
	for i in lines.size():
		_label(at + Vector2(0, i * line), lines[i][0], lines[i][1])

func _inspect_lines(minion: Node) -> Array:
	var senses: MinionSenses = minion.senses
	var state := clampi(int(senses.state), 0, 2)
	var lines: Array = []
	var head := "%s  %s" % [minion.minion_id, STATE_NAMES[state]]
	if state != 0:
		head += "  %.1fs left  <- %s" % [senses._active_timer, senses.last_trigger]
	lines.append([head, STATE_COLORS[state]])
	# One block per sense, shown only while that sense's show- toggle is on. "none" = this
	# creature does not have the sense (its JSON turns it off).
	var target = minion._target
	var sight := senses.sight
	if DebugState.on("show-sight"):
		if not sight.enabled:
			lines.append(["sight: none (blind, ignores light)", NO_SENSE_COLOR])
		else:
			if is_instance_valid(target):
				var d: float = minion.global_position.distance_to(target.global_position) / TILE
				var block := _sight_block(minion, target)
				var why := "too far" if d > sight.range_tiles else ("clear, sees you" if block == LineOfSight.CLEAR else "blocked at (%d,%d)" % [block.x, block.y])
				lines.append(["sight: range %.0f, you %.1f tiles, %s" % [sight.range_tiles, d, why], SenseSight.DEBUG_COLOR])
			lines.append(["light: %s" % ("lit by your light" if minion.debug_lit else "dark"), Color(1.0, 0.8, 0.5)])
	if DebugState.on("show-touch"):
		lines.append(["touch: %s" % ("has it" if senses.touch.enabled else "none"), SenseTouch.DEBUG_COLOR if senses.touch.enabled else NO_SENSE_COLOR])
	var hearing := senses.hearing
	if DebugState.on("show-sound"):
		var heard := "  last sound %.1f dB" % senses.last_heard_db if senses.last_heard_db > -INF else ""
		lines.append(["hearing: %s%s" % ["from %.0f dB (a step %.0f tiles)" % [hearing.threshold_db, hearing.reach_tiles(CombatSounds.footstep_db())] if hearing.enabled else "none", heard], SenseHearing.DEBUG_COLOR if hearing.enabled else NO_SENSE_COLOR])
	if DebugState.on("show-smell"):
		lines.append(["smell: %s (not built)" % ("has it" if senses.smell.enabled else "none"), NO_SENSE_COLOR])
	if DebugState.on("show-taste"):
		lines.append(["taste: %s (not built)" % ("has it" if senses.taste.enabled else "none"), NO_SENSE_COLOR])
	if state == 1 and is_instance_valid(senses.investigate_marker):
		var spot := Vector2i((senses.investigate_marker.global_position / TILE).floor())
		lines.append(["going to (%d,%d)" % [spot.x, spot.y], STATE_COLORS[1]])
	if minion.pack_id != "":
		var leader = minion._pack_leader()
		lines.append(["pack %s, %s" % [minion.pack_id, "leads" if leader == null else "follows %d" % leader.get_instance_id()], Color(0.8, 0.6, 1.0)])
	if state == 0:
		var patrol := "patrol: " + ("awake" if minion._patrol_active else "asleep (no player near)")
		if minion._patrol_has_goal:
			patrol += ", to (%d,%d)" % [minion._patrol_goal.x, minion._patrol_goal.y]
		lines.append([patrol, STATE_COLORS[0]])
	return lines

## Text is drawn in real screen pixels and snapped to a whole one, so it stays sharp at any
## camera zoom and window size; its size is LABEL_SIZE times GameView.debug_scale, like the
## DebugMenu. Only its anchor point lives in the world, so it still follows the map.
func _label(pos: Vector2, text: String, color: Color) -> void:
	var to_window := _to_window()
	var screen := (to_window * pos).round()
	draw_set_transform_matrix(to_window.affine_inverse() * Transform2D(0.0, screen))
	var size := _label_size()
	draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## World position to real window pixels (this layer's canvas, then the window's stretch).
func _to_window() -> Transform2D:
	return get_viewport().get_final_transform() * get_canvas_transform()

func _label_size() -> int:
	return maxi(roundi(LABEL_SIZE * GameView.debug_scale(get_tree())), 6)

## One label line, in world pixels.
func _line_height() -> float:
	return (_label_size() + 2) / _to_window().get_scale().x

## A label's width, in world pixels.
func _label_width(text: String) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size()).x / _to_window().get_scale().x
