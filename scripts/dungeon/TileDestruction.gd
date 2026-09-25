class_name TileDestruction
extends RefCounted

## Breaking walls at runtime (the "destroy_tiles" ability; an earth dragon, a bomb or
## a digging tool would use the same thing). Two halves so it works over the network:
##
##   plan()   HOST ONLY. Decides which walls fall, what floor shows under each and
##            which wall covers any void the hole exposes. Uses randomness, so only the
##            host does it, and it returns a plain list of changes.
##   apply()  EVERY PEER. Writes that list into the tile layers. No decisions here, so
##            all peers end up with the same map. NetworkSync.destroy_tiles ties the
##            two together.
##
## Only the two data layers (WallData / FloorData) are touched (apply() then tells the renderers
## to redraw); movement, sight and light read the layers live. What is
## cached (shared flow fields, the light's blocked-tile cache) is invalidated in apply().
##
## A change is {"cell": Vector2i, "wall": String, "floor": String}: tile NAMES, not ids.
## wall "" = remove the wall; floor "" = leave the floor alone.

## Walls whose tile name starts with this are never destroyed (barrier_bedrock ...).
const PROTECTED_PREFIX := "barrier_"
const NEIGHBOURS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

static var _registry: TileTypeRegistry
static var _names := {}       # tile id -> tile name
static var _plain_floor := {} # floor tile id -> true when it is ordinary ground
static var _atlas := {}       # tile id -> its texture path (rubble takes the wall's colours)
## When apply() last changed the map (msec), for the debug body sweep (BodySweep).
static var last_applied_msec := 0

static func _setup() -> void:
	if _registry != null:
		return
	_registry = TileTypeRegistry.new()
	for tile_name: String in _registry.ids:
		_names[_registry.ids[tile_name]] = tile_name
	var dir := DirAccess.open("res://game/tiles/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var data := JsonOnloading.load_dict("res://game/tiles/" + file_name)
		_atlas[_registry.get_id(str(data.get("tile_name", "")))] = str(data.get("atlas_texture", ""))
		if data.get("category", "") == "floor" and data.get("terrain", "normal") == "normal":
			_plain_floor[_registry.get_id(str(data.get("tile_name", "")))] = true

static func _name_of(source_id: int) -> String:
	return _names.get(source_id, "")

## Host only. `cells` are the tiles the ability hit. Returns the changes to apply
## (empty when there was nothing breakable there).
static func plan(cells: Array[Vector2i], scene: Node) -> Array:
	_setup()
	var wall_data := scene.find_child("WallData", true, false) as TileMapLayer
	var floor_data := scene.find_child("FloorData", true, false) as TileMapLayer
	if wall_data == null or floor_data == null:
		return []
	var broken := {}  # cell -> floor name to put there ("" = keep what is under it)
	for cell in cells:
		var wall_id := wall_data.get_cell_source_id(cell)
		if wall_id == -1 or _name_of(wall_id).begins_with(PROTECTED_PREFIX) or DoorRegistry.is_door_cell(cell):
			continue
		if TileSolid.has_floor(floor_data, cell):
			broken[cell] = ""  # the floor already under the wall (the room's own) shows through
			continue
		# No usable floor under it: borrow the ordinary floor of an open neighbour.
		var borrowed := _neighbour_floor(cell, wall_data, floor_data)
		if borrowed != "":
			broken[cell] = borrowed
	var changes: Array = []
	for cell in broken:
		changes.append({"cell": cell, "wall": "", "floor": broken[cell]})
	# Void the holes expose gets covered by a copy of a surrounding wall.
	var covered := {}
	for cell in broken:
		for offset in NEIGHBOURS_8:
			var next: Vector2i = cell + offset
			if broken.has(next) or covered.has(next) or wall_data.get_cell_source_id(next) != -1:
				continue
			if TileSolid.has_floor(floor_data, next):
				continue
			var wall := _cover_wall(next, broken, wall_data)
			if wall != "":
				covered[next] = true
				changes.append({"cell": next, "wall": wall, "floor": ""})
	return changes

## A random ordinary floor tile next to `cell` that is open (no wall on it).
static func _neighbour_floor(cell: Vector2i, wall_data: TileMapLayer, floor_data: TileMapLayer) -> String:
	var options: Array[String] = []
	for offset in NEIGHBOURS_8:
		var next: Vector2i = cell + offset
		if TileSolid.is_solid(wall_data, floor_data, next):
			continue
		var floor_id := floor_data.get_cell_source_id(next)
		if _plain_floor.has(floor_id):
			options.append(_name_of(floor_id))
	return options[randi() % options.size()] if not options.is_empty() else ""

## A random one of the walls around `cell` (not counting walls that just fell). Prefers
## breakable walls, so a hole is never plugged with indestructible rock unless that is
## all there is.
static func _cover_wall(cell: Vector2i, broken: Dictionary, wall_data: TileMapLayer) -> String:
	var breakable: Array[String] = []
	var protected_walls: Array[String] = []
	for offset in NEIGHBOURS_8:
		var next: Vector2i = cell + offset
		if broken.has(next):
			continue
		var wall_id := wall_data.get_cell_source_id(next)
		if wall_id == -1:
			continue
		var wall_name := _name_of(wall_id)
		if wall_name.begins_with(PROTECTED_PREFIX):
			protected_walls.append(wall_name)
		else:
			breakable.append(wall_name)
	var pool := breakable if not breakable.is_empty() else protected_walls
	return pool[randi() % pool.size()] if not pool.is_empty() else ""

## Every peer. Writes the changes into the layers and drops what was cached about the
## old layout.
static func apply(changes: Array, scene: Node) -> void:
	_setup()
	var wall_data := scene.find_child("WallData", true, false) as TileMapLayer
	var floor_data := scene.find_child("FloorData", true, false) as TileMapLayer
	if wall_data == null or floor_data == null:
		return
	for change: Dictionary in changes:
		var cell: Vector2i = change["cell"]
		if change["floor"] != "":
			floor_data.set_cell(cell, _registry.get_id(change["floor"]), Vector2i.ZERO)
		if change["wall"] == "":
			var old_wall := wall_data.get_cell_source_id(cell)
			if old_wall != -1:
				ParticleBurst.rubble(scene, wall_data.to_global(wall_data.map_to_local(cell)), _atlas.get(old_wall, ""))
			wall_data.erase_cell(cell)
		else:
			wall_data.set_cell(cell, _registry.get_id(change["wall"]), Vector2i.ZERO)
	# The layers' `changed` signal does not fire for set_cell / erase_cell while playing, so the
	# renderers would keep drawing the old walls (bodies walk through "solid" rock). Ask them.
	var tiles := scene.find_child("TileInitialize", true, false)
	if tiles != null:
		var cells: Array = []
		for change: Dictionary in changes:
			cells.append(change["cell"])
		tiles.refresh_cells(cells)
	last_applied_msec = Time.get_ticks_msec()
	# Shared flow fields were flooded around the old walls; the light re-floods when the
	# door version moves (LightMap polls it), the same way it does for a door opening.
	FlowField.clear()
	DoorRegistry.version += 1
