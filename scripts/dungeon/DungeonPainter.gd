extends Node

@export var tile_initialize: TileInitialize

const OPEN_CONNECTOR_TILE := "wall_door_open"
const VOID_PADDING := 2

func _ready() -> void:
	var floor_data: TileMapLayer = tile_initialize.get_node("FloorData")
	var wall_data: TileMapLayer = tile_initialize.get_node("WallData")
	var registry: TileTypeRegistry = tile_initialize.tile_registry

	var biome := NetworkSync.dungeon_biome
	var defines := DungeonAssembler.load_defines(biome)
	var rooms := DungeonAssembler.load_rooms(biome)
	var placements := DungeonAssembler.generate_with_retry(rooms, NetworkSync.dungeon_seed, defines)
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
	if light_map == null:
		return
	var spawn_cells := DungeonAssembler.collect_spawn_cells(rooms, placements)
	EnemySpawning.spawn_in_unseen_cells(spawn_cells, defines.get("monsters", {}), light_map, get_tree().current_scene)

func _paint(rooms: Dictionary, placements: Array, floor_data: TileMapLayer, wall_data: TileMapLayer, registry: TileTypeRegistry) -> void:
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		var locked := {}
		for local_pos in p.locked_connectors:
			locked[local_pos] = true
		var suppressed := {}
		for local_pos in p.suppressed_connectors:
			suppressed[local_pos] = true
		var sealed_tile := DungeonAssembler.dominant_wall_tile(room) if not locked.is_empty() else ""
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
				if wall_name == "wall_door":
					if suppressed.has(local):
						wall_name = null
					elif locked.has(local):
						wall_name = sealed_tile
					else:
						wall_name = OPEN_CONNECTOR_TILE
						alt = DungeonAssembler.door_orientation_alt(DungeonAssembler._connector_dir(room, local))
				if wall_name != null:
					wall_data.set_cell(world, registry.get_id(wall_name), Vector2i.ZERO, alt)

		for c in room["connectors"]:
			var local := Vector2i(int(c["position"]["x"]), int(c["position"]["y"]))
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
