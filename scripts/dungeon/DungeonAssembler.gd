extends RefCounted
class_name DungeonAssembler

const ROOMS_DIR := "res://game/rooms/"

const MIN_ROOM_COUNT := 20
const MAX_ROOM_COUNT := 30

enum Dir { NORTH, SOUTH, EAST, WEST }

static func _opposite(dir: int) -> int:
	match dir:
		Dir.NORTH: return Dir.SOUTH
		Dir.SOUTH: return Dir.NORTH
		Dir.EAST: return Dir.WEST
		Dir.WEST: return Dir.EAST
	return dir

static func _dir_step(dir: int) -> Vector2i:
	match dir:
		Dir.NORTH: return Vector2i(0, -1)
		Dir.SOUTH: return Vector2i(0, 1)
		Dir.EAST: return Vector2i(1, 0)
		Dir.WEST: return Vector2i(-1, 0)
	return Vector2i.ZERO

static func _connector_dir(room: Dictionary, pos: Vector2i) -> int:
	var h: int = room["height"]
	if pos.y == 0:
		return Dir.NORTH
	if pos.y == h - 1:
		return Dir.SOUTH
	if pos.x == 0:
		return Dir.WEST
	return Dir.EAST

static func load_rooms() -> Dictionary:
	var rooms := {}
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		push_error("DungeonAssembler: couldn't open " + ROOMS_DIR)
		return rooms
	var file_names: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()
	for name in file_names:
		var text := FileAccess.get_file_as_string(ROOMS_DIR + name)
		var data = JSON.parse_string(text)
		if data is Dictionary:
			rooms[data["id"]] = data
	return with_rotations(rooms)

static func dominant_wall_tile(room: Dictionary) -> String:
	return _dominant_tile(room["walls"], "wall_door")

static func dominant_floor_tile(room: Dictionary) -> String:
	return _dominant_tile(room["floor"], "")

static func door_orientation_alt(dir: int) -> int:
	match dir:
		Dir.SOUTH: return 0
		Dir.WEST: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		Dir.NORTH: return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		Dir.EAST: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
	return 0

static func _rotate_grid(grid: Array, width: int, height: int) -> Array:
	var rotated: Array = []
	for y in width:
		var row: Array = []
		row.resize(height)
		rotated.append(row)
	for y in height:
		for x in width:
			rotated[x][height - 1 - y] = grid[y][x]
	return rotated

static func _rotate_connectors(connectors: Array, height: int) -> Array:
	var rotated: Array = []
	for c in connectors:
		var x: int = int(c["position"]["x"])
		var y: int = int(c["position"]["y"])
		rotated.append({"position": {"x": height - 1 - y, "y": x}})
	return rotated

static func rotate_room(room: Dictionary, quarter_turns: int) -> Dictionary:
	var turns := posmod(quarter_turns, 4)
	var result: Dictionary = room.duplicate(true)
	for i in turns:
		var w: int = result["width"]
		var h: int = result["height"]
		result["floor"] = _rotate_grid(result["floor"], w, h)
		result["walls"] = _rotate_grid(result["walls"], w, h)
		result["connectors"] = _rotate_connectors(result["connectors"], h)
		result["width"] = h
		result["height"] = w
	if turns != 0:
		result["id"] = "%s#r%d" % [room["id"], turns]
	return result

static func with_rotations(rooms: Dictionary) -> Dictionary:
	var expanded := rooms.duplicate()
	for id in rooms.keys():
		var room: Dictionary = rooms[id]
		var role: String = room.get("role", "normal")
		if role == "entrance" or role == "boss":
			continue
		var seen := {_signature(room): true}
		for turns in [1, 2, 3]:
			var variant := rotate_room(room, turns)
			var sig := _signature(variant)
			if seen.has(sig):
				continue
			seen[sig] = true
			expanded[variant["id"]] = variant
	return expanded

static func _signature(room: Dictionary) -> String:
	return JSON.stringify([room["floor"], room["walls"], room["connectors"]])

static func _dominant_tile(grid: Array, exclude: String) -> String:
	var counts := {}
	for row in grid:
		for tile in row:
			if tile != null and tile != exclude:
				counts[tile] = counts.get(tile, 0) + 1
	var best := ""
	var best_count := -1
	var keys: Array = counts.keys()
	keys.sort()
	for tile in keys:
		if counts[tile] > best_count:
			best = tile
			best_count = counts[tile]
	return best

class Placement:
	var room_id: String
	var offset: Vector2i
	var depth: int = 0  # hop count from the entrance, used to find the "farthest" dead end for the boss room
	var locked_connectors: Array[Vector2i] = []
	var suppressed_connectors: Array[Vector2i] = []

## dungeon_seed: RNG seed, same value on host and every client -> identical layout.
static func generate(rooms: Dictionary, dungeon_seed: int) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = dungeon_seed
	var target_count := rng.randi_range(MIN_ROOM_COUNT, MAX_ROOM_COUNT)

	var entrance_id := ""
	var boss_id := ""
	var treasure_ids: Array = []
	var pool_ids: Array = []  # normal/corridor rooms eligible for random growth
	var corridor_ids: Array = []  # role=="corridor" only, for the boss fallback below
	var room_ids: Array = rooms.keys()
	room_ids.sort()
	for id in room_ids:
		var r: Dictionary = rooms[id]
		var role: String = r.get("role", "normal")
		if role == "entrance":
			entrance_id = id
		elif role == "boss":
			boss_id = id
		elif (r.get("tags", []) as Array).has("treasure"):
			treasure_ids.append(id)
		else:
			pool_ids.append(id)
			if role == "corridor":
				corridor_ids.append(id)

	if entrance_id == "":
		push_error("DungeonAssembler: no room with role \"entrance\" found")
		return []

	var placements: Array[Placement] = []
	var occupied: Array[Rect2i] = []
	# Each entry: {placement_index, local_pos, dir}
	var open_connectors: Array = []

	var entrance_room: Dictionary = rooms[entrance_id]
	var center := Vector2i(int(entrance_room["width"] / 2), int(entrance_room["height"] / 2))
	var entrance_placement := Placement.new()
	entrance_placement.room_id = entrance_id
	entrance_placement.offset = Vector2i.ZERO - center
	placements.append(entrance_placement)
	occupied.append(Rect2i(entrance_placement.offset, Vector2i(entrance_room["width"], entrance_room["height"])))
	_queue_connectors(entrance_room, 0, open_connectors)
	_seal_random_entrance_doors(entrance_placement, open_connectors, rng)

	var normal_budget: int = max(target_count - 2, 1)

	const DEAD_END_AVOIDANCE_MARGIN := 3
	while open_connectors.size() > 0 and placements.size() < normal_budget:
		var entry: Dictionary = open_connectors.pop_front()
		var avoid_dead_ends: bool = placements.size() < normal_budget - DEAD_END_AVOIDANCE_MARGIN
		if not _try_place(rooms, pool_ids, entry, placements, occupied, open_connectors, rng, avoid_dead_ends):
			_lock(placements[entry["placement_index"]], entry["local_pos"])

	for entry in open_connectors:
		_lock(placements[entry["placement_index"]], entry["local_pos"])
	open_connectors.clear()

	if boss_id != "":
		_place_farthest(rooms, boss_id, corridor_ids, placements, occupied)
	else:
		push_warning("DungeonAssembler: no room with role \"boss\" found, skipping")

	if not treasure_ids.is_empty():
		_place_any_locked(rooms, treasure_ids, placements, occupied)
	else:
		push_warning("DungeonAssembler: no room tagged \"treasure\" found, skipping")

	return placements

static func generate_with_retry(rooms: Dictionary, dungeon_seed: int, max_attempts: int = 20) -> Array[Placement]:
	var need_boss := false
	var need_treasure := false
	for id in rooms:
		var r: Dictionary = rooms[id]
		if r.get("role", "normal") == "boss":
			need_boss = true
		if (r.get("tags", []) as Array).has("treasure"):
			need_treasure = true

	for attempt in max_attempts:
		var placements := generate(rooms, dungeon_seed + attempt)
		if not placements.is_empty() and _satisfies_requirements(rooms, placements, need_boss, need_treasure):
			if attempt > 0:
				push_warning("DungeonAssembler: seed %d needed %d retr%s (used seed %d)" % [dungeon_seed, attempt, "y" if attempt == 1 else "ies", dungeon_seed + attempt])
			return placements

	push_warning("DungeonAssembler: no complete layout found in %d attempts from seed %d — using attempt 0 anyway" % [max_attempts, dungeon_seed])
	return generate(rooms, dungeon_seed)

static func _satisfies_requirements(rooms: Dictionary, placements: Array[Placement], need_boss: bool, need_treasure: bool) -> bool:
	var has_boss := false
	var has_treasure := false
	for p in placements:
		var r: Dictionary = rooms[p.room_id]
		if r.get("role", "normal") == "boss":
			has_boss = true
		if (r.get("tags", []) as Array).has("treasure"):
			has_treasure = true
	return (not need_boss or has_boss) and (not need_treasure or has_treasure)

static func _try_place(rooms: Dictionary, candidate_ids: Array, entry: Dictionary, placements: Array[Placement], occupied: Array[Rect2i], open_connectors: Array, rng: RandomNumberGenerator, avoid_dead_ends: bool) -> bool:
	var from_placement: Placement = placements[entry["placement_index"]]
	var from_world: Vector2i = from_placement.offset + entry["local_pos"]
	var need_dir: int = _opposite(entry["dir"])
	var target_cell: Vector2i = from_world + _dir_step(entry["dir"])

	var shuffled_ids: Array = candidate_ids.duplicate()
	_shuffle(shuffled_ids, rng)
	if avoid_dead_ends:
		var multi: Array = []
		var single: Array = []
		for id in shuffled_ids:
			if (rooms[id]["connectors"] as Array).size() > 1:
				multi.append(id)
			else:
				single.append(id)
		shuffled_ids = multi + single
	for cand_id in shuffled_ids:
		var cand: Dictionary = rooms[cand_id]
		var cand_connectors: Array = cand["connectors"].duplicate()
		_shuffle(cand_connectors, rng)
		for c in cand_connectors:
			var local_pos := Vector2i(int(c["position"]["x"]), int(c["position"]["y"]))
			if _connector_dir(cand, local_pos) != need_dir:
				continue
			var offset: Vector2i = target_cell - local_pos
			var rect := Rect2i(offset, Vector2i(cand["width"], cand["height"]))
			if _overlaps_any(rect, occupied):
				continue
			var placement := Placement.new()
			placement.room_id = cand_id
			placement.offset = offset
			placement.depth = from_placement.depth + 1
			placement.suppressed_connectors.append(local_pos)
			placements.append(placement)
			occupied.append(rect)
			_queue_connectors(cand, placements.size() - 1, open_connectors, local_pos)
			return true
	return false

static func _fit_room_at(rooms: Dictionary, room_id: String, from_placement: Placement, local_pos: Vector2i, placements: Array[Placement], occupied: Array[Rect2i]) -> bool:
	var from_room: Dictionary = rooms[from_placement.room_id]
	var from_dir: int = _connector_dir(from_room, local_pos)
	var need_dir: int = _opposite(from_dir)
	var target_cell: Vector2i = from_placement.offset + local_pos + _dir_step(from_dir)

	var room: Dictionary = rooms[room_id]
	var connectors: Array = room["connectors"].duplicate()
	connectors.sort_custom(func(a, b):
		if a["position"]["y"] != b["position"]["y"]:
			return a["position"]["y"] < b["position"]["y"]
		return a["position"]["x"] < b["position"]["x"]
	)
	for c in connectors:
		var cand_local := Vector2i(int(c["position"]["x"]), int(c["position"]["y"]))
		if _connector_dir(room, cand_local) != need_dir:
			continue
		var offset: Vector2i = target_cell - cand_local
		var rect := Rect2i(offset, Vector2i(room["width"], room["height"]))
		if _overlaps_any(rect, occupied):
			continue
		var placement := Placement.new()
		placement.room_id = room_id
		placement.offset = offset
		placement.depth = from_placement.depth + 1
		placement.suppressed_connectors.append(cand_local)
		placements.append(placement)
		occupied.append(rect)
		var extra: Array = []
		_queue_connectors(room, placements.size() - 1, extra, cand_local)
		for e in extra:
			_lock(placements[e["placement_index"]], e["local_pos"])
		return true
	return false

const MAX_BOSS_CORRIDOR_EXTENSION := 8

static func _place_farthest(rooms: Dictionary, room_id: String, corridor_ids: Array, placements: Array[Placement], occupied: Array[Rect2i]) -> bool:
	var candidates: Array = []
	for i in placements.size():
		for local_pos in placements[i].locked_connectors:
			candidates.append({"placement_index": i, "local_pos": local_pos, "depth": placements[i].depth})
	candidates.sort_custom(func(a, b): return a["depth"] > b["depth"])

	for c in candidates:
		var from_placement: Placement = placements[c["placement_index"]]
		if _fit_room_at(rooms, room_id, from_placement, c["local_pos"], placements, occupied):
			from_placement.locked_connectors.erase(c["local_pos"])
			return true

	if not corridor_ids.is_empty():
		for c in candidates:
			var cur_placement: Placement = placements[c["placement_index"]]
			var cur_local: Vector2i = c["local_pos"]
			for extension in MAX_BOSS_CORRIDOR_EXTENSION:
				if _fit_room_at(rooms, room_id, cur_placement, cur_local, placements, occupied):
					cur_placement.locked_connectors.erase(cur_local)
					return true
				var extended := false
				for corridor_id in corridor_ids:
					if _fit_room_at(rooms, corridor_id, cur_placement, cur_local, placements, occupied):
						cur_placement.locked_connectors.erase(cur_local)
						var new_placement: Placement = placements[placements.size() - 1]
						if new_placement.locked_connectors.is_empty():
							break  # this corridor dead-ended, can't extend further this way
						cur_placement = new_placement
						cur_local = new_placement.locked_connectors[0]
						extended = true
						break
				if not extended:
					break

	push_warning("DungeonAssembler: boss room \"%s\" didn't fit anywhere, even after extending corridors" % room_id)
	return false

static func _place_any_locked(rooms: Dictionary, room_ids: Array, placements: Array[Placement], occupied: Array[Rect2i]) -> bool:
	var candidates: Array = []
	for i in placements.size():
		for local_pos in placements[i].locked_connectors:
			candidates.append({"placement_index": i, "local_pos": local_pos})
	for c in candidates:
		var from_placement: Placement = placements[c["placement_index"]]
		for room_id in room_ids:
			if _fit_room_at(rooms, room_id, from_placement, c["local_pos"], placements, occupied):
				from_placement.locked_connectors.erase(c["local_pos"])
				return true
	push_warning("DungeonAssembler: no treasure room fit any dead end")
	return false

static func _queue_connectors(room: Dictionary, placement_index: int, open_connectors: Array, skip_local: Vector2i = Vector2i(-1, -1)) -> void:
	var connectors: Array = room["connectors"].duplicate()
	connectors.sort_custom(func(a, b):
		if a["position"]["y"] != b["position"]["y"]:
			return a["position"]["y"] < b["position"]["y"]
		return a["position"]["x"] < b["position"]["x"]
	)
	for c in connectors:
		var local_pos := Vector2i(int(c["position"]["x"]), int(c["position"]["y"]))
		if local_pos == skip_local:
			continue
		open_connectors.append({
			"placement_index": placement_index,
			"local_pos": local_pos,
			"dir": _connector_dir(room, local_pos),
		})

static func _overlaps_any(rect: Rect2i, occupied: Array[Rect2i]) -> bool:
	for r in occupied:
		if rect.intersects(r):
			return true
	return false

static func _lock(placement: Placement, local_pos: Vector2i) -> void:
	placement.locked_connectors.append(local_pos)

static func _seal_random_entrance_doors(entrance_placement: Placement, entrance_connectors: Array, rng: RandomNumberGenerator) -> void:
	var total: int = entrance_connectors.size()
	var shuffled: Array = entrance_connectors.duplicate()
	_shuffle(shuffled, rng)
	entrance_connectors.clear()
	var remaining := total
	var removed := 0
	for entry in shuffled:
		if remaining <= 1:
			entrance_connectors.append(entry)
			continue
		var chance: float = float(removed + 1) / total
		if rng.randf() < chance:
			_lock(entrance_placement, entry["local_pos"])
			removed += 1
			remaining -= 1
		else:
			entrance_connectors.append(entry)

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
