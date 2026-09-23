extends Node

@export var tile_initialize: TileInitialize

const OPEN_CONNECTOR_TILE := "wall_door_open"
const VOID_PADDING := 2

## defines.json "doors": false (flesh, forest, cave...) leaves every joined 1-wide
## opening as a plain gap instead of a door tile.
var _doors_enabled := true

func _ready() -> void:
	var floor_data: TileMapLayer = tile_initialize.get_node("FloorData")
	var wall_data: TileMapLayer = tile_initialize.get_node("WallData")
	var registry: TileTypeRegistry = tile_initialize.tile_registry

	var biome := NetworkSync.dungeon_biome
	var defines := DungeonAssembler.load_defines(biome)
	_doors_enabled = defines.get("doors", true)
	var rooms := DungeonAssembler.load_rooms(biome)
	var placements := DungeonAssembler.generate_with_retry(rooms, NetworkSync.dungeon_seed, defines)
	RoomGraph.build(rooms, placements)
	FlowField.clear()
	SurroundSectors.clear()
	_paint(rooms, placements, floor_data, wall_data, registry)
	MusicManager.play_for_biome(defines)
	# LightMap is a later sibling in Dungeon.tscn -- its own _ready() (which
	# builds _local) hasn't run yet at this point in the frame, so defer
	# until every node's _ready() this frame is done.
	_spawn_enemies.call_deferred(rooms, placements, defines)

## Nothing is lit yet this early, so every spawn cell in the dungeon counts
## as unseen and gets rolled -- exactly the "fill everything at generation
## time" behavior EnemySpawning is meant to have at t=0.
func _spawn_enemies(rooms: Dictionary, placements: Array, defines: Dictionary) -> void:
	var light_map: LightMap = get_tree().current_scene.find_child("LightMap", true, false)
	var enemies_root := get_tree().current_scene.get_node_or_null("Enemies")
	if light_map == null or enemies_root == null:
		return
	var bad_cells := _warn_bad_spawn_cells(rooms, placements)
	var spawn_cells: Array[Vector2i] = []
	for cell in DungeonAssembler.collect_spawn_cells(rooms, placements):
		if not bad_cells.has(cell):
			spawn_cells.append(cell)
	EnemySpawning.spawn_in_unseen_cells(spawn_cells, defines.get("monsters", {}), light_map, enemies_root)

## Dev aid: checks each spawn cell against what was actually PAINTED (the same
## wall / void test GridMover uses), and names the room, its local cell, what
## the room data says is there, and any other room overlapping that world
## cell -- so a bad spawn can be traced to the room JSON or to the assembly.
## Returns the bad world cells so the caller can skip spawning on them.
func _warn_bad_spawn_cells(rooms: Dictionary, placements: Array) -> Dictionary:
	var bad_cells := {}
	var floor_data: TileMapLayer = tile_initialize.get_node("FloorData")
	var wall_data: TileMapLayer = tile_initialize.get_node("WallData")
	var registry: TileTypeRegistry = tile_initialize.tile_registry
	var open_door_id := registry.get_id(OPEN_CONNECTOR_TILE)
	var void_id := registry.get_id("floor_void")
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		for cell in room.get("spawn_cells", []):
			var local := Vector2i(int(cell["position"]["x"]), int(cell["position"]["y"]))
			var world: Vector2i = p.offset + local
			var problem := ""
			var wall_id := wall_data.get_cell_source_id(world)
			if wall_id != -1 and wall_id != open_door_id:
				problem = "painted wall"
			elif floor_data.get_cell_source_id(world) == void_id:
				problem = "painted void"
			if problem == "":
				continue
			bad_cells[world] = true
			var in_bounds: bool = local.x >= 0 and local.y >= 0 and local.x < room["width"] and local.y < room["height"]
			var data_wall: Variant = room["walls"][local.y][local.x] if in_bounds else "<out of bounds>"
			var data_floor: Variant = room["floor"][local.y][local.x] if in_bounds else "<out of bounds>"
			var overlaps: Array[String] = []
			for q in placements:
				if q == p:
					continue
				var qr: Dictionary = rooms[q.room_id]
				if Rect2i(q.offset, Vector2i(qr["width"], qr["height"])).has_point(world):
					overlaps.append(str(q.room_id))
			push_warning("Bad spawn cell: room '%s' local %s world %s -- %s. Room data: wall=%s floor=%s, sealed door=%s, overlapped by rooms %s" % [
				p.room_id, local, world, problem, data_wall, data_floor, p.locked_connectors.has(local), overlaps])
	return bad_cells

func _paint(rooms: Dictionary, placements: Array, floor_data: TileMapLayer, wall_data: TileMapLayer, registry: TileTypeRegistry) -> void:
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		var locked := {}
		for local_pos in p.locked_connectors:
			locked[local_pos] = true
		var suppressed := {}
		for local_pos in p.suppressed_connectors:
			suppressed[local_pos] = true
		var sealed_tile := DungeonAssembler.dominant_wall_tile(room)
		# Every cell of every connector run -> its connector, so a run wider than
		# one cell is opened / sealed cell by cell instead of by its first cell.
		var connector_of := {}
		for c in room["connectors"]:
			for cell in Connector.cells(c):
				connector_of[cell] = c
		var floor_tile: String = room.get("base_floor", DungeonAssembler.dominant_floor_tile(room))

		for y in room["height"]:
			for x in room["width"]:
				var local := Vector2i(x, y)
				var world: Vector2i = p.offset + local

				var floor_name: Variant = room["floor"][y][x]
				if floor_name != null:
					floor_data.set_cell(world, registry.get_id(floor_name), Vector2i.ZERO)
				elif room["walls"][y][x] != null:
					floor_data.set_cell(world, registry.get_id(floor_tile), Vector2i.ZERO)

				var wall_name: Variant = room["walls"][y][x]
				var alt := 0
				if connector_of.has(local):
					var run: Dictionary = connector_of[local]
					var anchor := Connector.a(run)
					var joint: Variant = p.joint_cells.get(anchor)
					if joint != null and not (joint as Array).has(local):
						# Part of a wider connector with no partner cell: wall it off.
						if sealed_tile != "":
							wall_name = sealed_tile
						else:
							wall_name = null
					elif suppressed.has(anchor):
						wall_name = null
					elif locked.has(anchor):
						wall_name = sealed_tile
					elif Connector.width(run) > 1:
						# A wide opening is a plain open gap, not a single door tile.
						wall_name = null
					elif _doors_enabled:
						wall_name = OPEN_CONNECTOR_TILE
						alt = DungeonAssembler.door_orientation_alt(DungeonAssembler._connector_dir(room, anchor))
					else:
						wall_name = null
				elif wall_name == "wall_door":
					if suppressed.has(local):
						wall_name = null
					elif locked.has(local):
						wall_name = sealed_tile
					elif _doors_enabled:
						wall_name = OPEN_CONNECTOR_TILE
						alt = DungeonAssembler.door_orientation_alt(DungeonAssembler._connector_dir(room, local))
					else:
						wall_name = null
				if wall_name != null:
					wall_data.set_cell(world, registry.get_id(wall_name), Vector2i.ZERO, alt)

		for c in room["connectors"]:
			for local in Connector.cells(c):
				var world: Vector2i = p.offset + local
				floor_data.set_cell(world, registry.get_id(floor_tile), Vector2i.ZERO)

	_fill_void(floor_data, wall_data, registry)

func _fill_void(floor_data: TileMapLayer, wall_data: TileMapLayer, registry: TileTypeRegistry) -> void:
	var void_id := registry.get_id("floor_void")
	var rect := floor_data.get_used_rect().merge(wall_data.get_used_rect()).grow(VOID_PADDING)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if floor_data.get_cell_source_id(cell) == -1:
				floor_data.set_cell(cell, void_id, Vector2i.ZERO)
