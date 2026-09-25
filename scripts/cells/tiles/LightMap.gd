extends Node2D
class_name LightMap

## The world's light: every torch a Viewer holds (Viewer.light) and every glowing tile,
## and how lit each 8px cell is (Level). Minions ask whether a player's torch reaches them
## (is_tile_lit); PlayerVision asks how bright a cell is (level_at). It draws what light looks
## like: the glow colour tint and the normal-map shading. What each player can see, and the
## darkness over the rest, is PlayerVision's.

const CELL := 8
const TILE := 16
const STRAIGHT := LightFlood.STRAIGHT
const NO_CELL := Vector2i(-99999, -99999)
## Pixels walked per unit of flood cost (torches and glow alike; 1.0824 was tuned by eye).
const COST_TO_PIXELS := CELL / (STRAIGHT * 1.0824)
## Most lights drawn at once (light_smooth's light_map_1..4, normal_lit's lights[4]).
const MAX_DRAWN := 4
## Where the shaders' bright step ends (light_steps.gdshaderinc step_1). Each light's own
## bright_fraction is scaled to land here, so one set of steps draws every torch.
const BRIGHT_STEP := 0.5

@export var tile_initialize: TileInitialize

## Light levels, for seeing by: BRIGHT out to a light's bright_fraction of its radius, DIM from
## there to the edge, DARK where no light reaches.
enum Level { DARK, DIM, BRIGHT }

# One torch: its own window of cells around its holder and the flood results inside it.
class Light:
	var radius := 0.0
	var bright_fraction := 0.5
	var ghost := false
	var image: Image
	var texture: ImageTexture
	var top_left := Vector2i.ZERO
	var reached: Array[Vector2i] = []
	var cost := {}
	var last_origin := Vector2i(-99999, -99999)
	var last_light_pos := Vector2(INF, INF)
	var light_pos := Vector2.ZERO

var _wall_data: TileMapLayer
var _floor_data: TileMapLayer
var _lights := {}  # Viewer -> Light, only viewers holding a light
## The lights the local player's screen shows this frame, their own first (Viewer.shown_to_local).
var drawn: Array[Light] = []
var _blocked_cache := {}
var _door_version := 0
var _glow_cost := {}
var _glow_from := {}
var _glow_sources: Array = []
var _glow_reached: Array[Vector2i] = []
var _glow_image: Image
var glow_texture: ImageTexture
var _tint: Sprite2D
var _glow_top_left := Vector2i.ZERO

var _shading: ShaderMaterial = load("res://resources/shaders/normal_lit_material.tres")

func _ready() -> void:
	_wall_data = tile_initialize.get_node("WallData")
	_floor_data = tile_initialize.get_node("FloorData")
	_glow_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_glow_image.fill(Color(0, 0, 0, 1))
	glow_texture = ImageTexture.create_from_image(_glow_image)
	_tint = Sprite2D.new()
	_tint.texture = glow_texture
	_tint.centered = false
	_tint.scale = Vector2(CELL, CELL)
	_tint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tint := ShaderMaterial.new()
	tint.shader = load("res://resources/shaders/glow_tint.gdshader")
	tint.set_shader_parameter("cell_size", float(CELL))
	_tint.material = tint
	_tint.z_index = 2001
	add_child(_tint)
	bake_glow()

func bake_glow() -> void:
	_blocked_cache.clear()
	var tiles := _floor_data.get_used_rect().merge(_wall_data.get_used_rect())
	_scan_glow_sources(tiles)
	_glow_top_left = tiles.position * 2
	_glow_image = Image.create(tiles.size.x * 2, tiles.size.y * 2, false, Image.FORMAT_RGBA8)
	glow_texture = ImageTexture.create_from_image(_glow_image)
	_flood_glow()
	_paint_glow()
	_tint.texture = glow_texture
	_tint.position = Vector2(_glow_top_left * CELL)

## World pixel of the glow map's top-left corner, and its size in cells (for PlayerVision's shader).
func glow_origin() -> Vector2:
	return _tint.position

func glow_size() -> Vector2:
	return Vector2(_glow_image.get_size())

func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	_process_inner()
	DebugState.add_time("light", Time.get_ticks_usec() - started)

func _process_inner() -> void:
	if DoorRegistry.version != _door_version:
		# A door opened or closed (or a wall was smashed): every light re-floods next update.
		_door_version = DoorRegistry.version
		_blocked_cache.clear()
		for light: Light in _lights.values():
			light.last_origin = NO_CELL
	_update_lights()
	_pick_drawn()
	var positions := PackedVector2Array()
	positions.resize(MAX_DRAWN)
	for i in drawn.size():
		var light := drawn[i]
		if light.light_pos != light.last_light_pos:
			light.last_light_pos = light.light_pos
			_paint(light)
		positions[i] = light.light_pos
	_shading.set_shader_parameter("lights", positions)
	_shading.set_shader_parameter("light_count", drawn.size())

## Every viewer's torch, living or not, on every machine: the host needs them all for the
## minions (is_tile_lit), the others to draw their teammates' light.
func _update_lights() -> void:
	for viewer in _lights.keys():
		if not Viewer.all.has(viewer):
			_lights.erase(viewer)
	for viewer in Viewer.all:
		var data := viewer.light
		if data.is_empty():
			_lights.erase(viewer)
			continue
		var radius := float(data["glow_radius"])
		var bright := float(data.get("bright_fraction", BRIGHT_STEP))
		var light: Light = _lights.get(viewer)
		if light == null or light.radius != radius or light.bright_fraction != bright:
			light = _make_light(radius, bright)
			_lights[viewer] = light
		light.ghost = viewer.ghost
		light.light_pos = (viewer.position + Vector2(TILE / 2.0, TILE / 2.0)).round()
		var origin := Vector2i((light.light_pos / CELL).floor())
		if origin != light.last_origin:
			light.last_origin = origin
			_flood(light, origin)
			light.last_light_pos = Vector2(INF, INF)

func _pick_drawn() -> void:
	drawn.clear()
	for viewer in Viewer.local_first():
		if drawn.size() >= MAX_DRAWN:
			break
		if _lights.has(viewer) and Viewer.shown_to_local(viewer):
			drawn.append(_lights[viewer])

## True if a living viewer's torch lights any of this tile's four cells: a minion notices a
## light that reaches it. Glowing tiles don't count; glow alone never alerts a minion.
func is_tile_lit(tile: Vector2i) -> bool:
	for light: Light in _lights.values():
		if light.ghost:
			continue
		var gap := _gap(light)
		for cell in half_cells(tile):
			if light.cost.has(cell) and _level(_fraction(light, cell, gap)) != Level.DARK:
				return true
	return false

## How lit one cell is, from the brightest of every torch and glowing tile (a Level).
## ghosts: also count dead viewers' torches (what a ghost sees).
func level_at(cell: Vector2i, ghosts := false) -> int:
	var best: int = _level(_glow_fraction(cell)) if _glow_cost.has(cell) else Level.DARK
	for light: Light in _lights.values():
		if light.cost.has(cell) and (ghosts or not light.ghost):
			best = maxi(best, _level(_fraction(light, cell, _gap(light))))
	return best

## Each drawn light's cells with their Level (the debug view of torch light).
func drawn_levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for light in drawn:
		var levels := {}
		var gap := _gap(light)
		for cell in light.reached:
			var level := _level(_fraction(light, cell, gap))
			if level != Level.DARK:
				levels[cell] = level
		result.append(levels)
	return result

func _make_light(radius: float, bright: float) -> Light:
	var light := Light.new()
	light.radius = radius
	light.bright_fraction = clampf(bright, 0.01, 0.99)
	# Room for the whole flood: it runs PATH_SLACK past the radius, plus rounding.
	var half := ceili(radius / CELL * LightFlood.PATH_SLACK) + 2
	light.image = Image.create(half * 2 + 1, half * 2 + 1, false, Image.FORMAT_RGBA8)
	light.image.fill(Color(1, 0, 0, 1))
	light.texture = ImageTexture.create_from_image(light.image)
	return light

func _scan_glow_sources(tiles: Rect2i) -> void:
	_glow_sources.clear()
	var glowing := tile_initialize.glow_sources
	if glowing.is_empty():
		return
	for ty in range(tiles.position.y, tiles.end.y):
		for tx in range(tiles.position.x, tiles.end.x):
			var tile := Vector2i(tx, ty)
			var id := _floor_data.get_cell_source_id(tile)
			if not glowing.has(id):
				id = _wall_data.get_cell_source_id(tile)
			if glowing.has(id):
				var type: TileType = glowing[id]
				_glow_sources.append({"tile": tile, "radius": type.glow_radius, "color": type.glow_color})

func _paint(light: Light) -> void:
	var image := light.image
	image.fill(Color(1, 0, 0, 1))
	var gap := _gap(light)
	for cell in light.reached:
		var pixel := cell - light.top_left
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
			continue
		image.set_pixelv(pixel, Color(_fraction(light, cell, gap), 0, 0, 1))
	light.texture.update(image)

## How far out a lit cell is: 0 at the light, 1 at the edge of its radius (farther of the
## straight line and the way round walls), scaled so its bright edge sits at BRIGHT_STEP.
## What the darkness is shaded by, and what levels use.
func _fraction(light: Light, cell: Vector2i, gap: float) -> float:
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var straight := (centre - light.light_pos).length()
	var walked: float = light.cost[cell] * COST_TO_PIXELS - gap
	var raw := minf(maxf(straight, walked) / light.radius, 1.0)
	if raw <= light.bright_fraction:
		return raw * BRIGHT_STEP / light.bright_fraction
	return BRIGHT_STEP + (raw - light.bright_fraction) * (1.0 - BRIGHT_STEP) / (1.0 - light.bright_fraction)

func _gap(light: Light) -> float:
	return ((Vector2(light.last_origin) + Vector2(0.5, 0.5)) * CELL - light.light_pos).length()

## The flood runs a little past the radius (PATH_SLACK, and one cell of rounding); those cells
## are painted fully dark (fraction 1), so they are DARK here too.
static func _level(fraction: float) -> Level:
	if fraction >= 1.0:
		return Level.DARK
	return Level.BRIGHT if fraction <= BRIGHT_STEP else Level.DIM

## A glowing tile's fraction at a cell it reached, the same distance rule as a torch's but
## measured from the edge of the tile.
func _glow_fraction(cell: Vector2i) -> float:
	var source: Dictionary = _glow_sources[_glow_from[cell]]
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var source_centre: Vector2 = (Vector2(source["tile"]) + Vector2(0.5, 0.5)) * TILE
	var beyond := (centre - source_centre).abs() - Vector2(TILE / 2.0, TILE / 2.0)
	var straight := Vector2(maxf(beyond.x, 0.0), maxf(beyond.y, 0.0)).length()
	var walked: float = (_glow_cost[cell] - source["head"]) * COST_TO_PIXELS - CELL * 0.75
	return minf(maxf(straight, walked) / source["radius"], 1.0)

func _paint_glow() -> void:
	_glow_image.fill(Color(0, 0, 0, 1))
	for cell in _glow_reached:
		var pixel := cell - _glow_top_left
		var color: Color = _glow_sources[_glow_from[cell]]["color"]
		_glow_image.set_pixelv(pixel, Color(color.r, color.g, color.b, _glow_fraction(cell)))
	glow_texture.update(_glow_image)

func _flood(light: Light, origin: Vector2i) -> void:
	var half := int(light.image.get_width() / 2.0)
	light.top_left = origin - Vector2i(half, half)
	var flood := LightFlood.flood(origin, light.radius / CELL, _is_blocked)
	reveal_doors(flood, half_cells)
	light.cost = flood["cost"]
	light.reached = flood["reached"]

# The flood stops at the first cell of a closed solid door, so the rest of it (the far half of a
# vertical door, the overhang above a horizontal one) would stay dark. Once any part of a door is
# reached, reach all of it at the same cost, so it draws whole from whichever side it is seen.
# cells_of(tile) is the flood's cells in one tile: half_cells for light, [tile] for sight.
static func reveal_doors(flood: Dictionary, cells_of: Callable) -> void:
	var cost: Dictionary = flood["cost"]
	var reached: Array = flood["reached"]
	for door: DoorRegistry.Door in DoorRegistry.doors:
		if door.is_open or door.transparent:
			continue
		var best := -1
		for tile in door.cells:
			for c in cells_of.call(tile):
				if cost.has(c) and (best < 0 or cost[c] < best):
					best = cost[c]
		if best < 0:
			continue
		var shown: Array[Vector2i] = door.cells.duplicate()
		for entry in door.pieces:
			shown.append(entry["cell"] + Vector2i(0, -1))
		for tile in shown:
			for c in cells_of.call(tile):
				if not cost.has(c):
					cost[c] = best
					reached.append(c)

## The four half-tile (CELL) cells that make up one tile.
static func half_cells(tile: Vector2i) -> Array[Vector2i]:
	var base := tile * 2
	return [base, base + Vector2i(1, 0), base + Vector2i(0, 1), base + Vector2i(1, 1)]

func _flood_glow() -> void:
	_glow_cost.clear()
	_glow_from.clear()
	_glow_reached.clear()
	if _glow_sources.is_empty():
		return
	var biggest := 0.0
	for source in _glow_sources:
		biggest = maxf(biggest, source["radius"])
	var highest := LightFlood.max_cost(biggest / CELL)
	var seeds := {}
	for i in _glow_sources.size():
		var source: Dictionary = _glow_sources[i]
		source["head"] = highest - LightFlood.max_cost(source["radius"] / CELL)
		for cell in half_cells(source["tile"]):
			seeds[cell] = [source["head"], i]
	var bounds := _glow_image.get_size()
	var inside := func(cell: Vector2i) -> bool:
		var pixel := cell - _glow_top_left
		return pixel.x >= 0 and pixel.y >= 0 and pixel.x < bounds.x and pixel.y < bounds.y
	var flood := LightFlood.flood_sources(seeds, highest, _is_blocked, inside)
	_glow_cost = flood["cost"]
	_glow_from = flood["from"]
	_glow_reached.assign(flood["reached"])

func _is_blocked(cell: Vector2i) -> bool:
	return blocks_light(Vector2i(floori(cell.x * CELL / float(TILE)), floori(cell.y * CELL / float(TILE))))

## Whether light (and so sight) stops at this tile: a wall, no floor, or a closed solid door.
## Cached until a door changes or a wall is smashed (both bump DoorRegistry.version).
func blocks_light(tile: Vector2i) -> bool:
	if _blocked_cache.has(tile):
		return _blocked_cache[tile]
	var blocked := TileSolid.is_solid(_wall_data, _floor_data, tile) or DoorRegistry.blocks_sight(tile)
	_blocked_cache[tile] = blocked
	return blocked
