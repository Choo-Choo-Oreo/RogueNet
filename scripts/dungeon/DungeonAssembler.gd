extends RefCounted
class_name DungeonAssembler

const ROOMS_DIR := "res://game/rooms/"

const MIN_ROOM_COUNT := 20
const MAX_ROOM_COUNT := 30

const IGNORED_FOLDERS := ["fallback"]
const FALLBACK_FOLDER := "fallback"

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

static func list_biomes() -> Array:
	var biomes: Array = []
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		return biomes
	for folder in dir.get_directories():
		if not IGNORED_FOLDERS.has(folder):
			biomes.append(folder)
	biomes.sort()
	return biomes

static func pick_biome(dungeon_seed: int) -> String:
	var biomes := list_biomes()
	if biomes.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = dungeon_seed ^ 0xB10E
	return biomes[rng.randi_range(0, biomes.size() - 1)]


static func _room_kind(room: Dictionary) -> String:
	var role: String = room.get("role", "normal")
	if role == "entrance" or role == "boss":
		return role
	if (room.get("tags", []) as Array).has("treasure"):
		return "treasure"
	return role

static func _fill_from_fallback(rooms: Dictionary) -> void:
	var present := {}
	for id in rooms:
		present[_room_kind(rooms[id])] = true
	var fallback := _read_folder(ROOMS_DIR + FALLBACK_FOLDER + "/")
	for kind in ["entrance", "boss", "treasure", "corridor", "normal"]:
		if present.has(kind):
			continue
		push_warning("DungeonAssembler: no \"%s\" room in this biome, using fallback" % kind)
		for id in fallback:
			if _room_kind(fallback[id]) == kind:
				rooms[id] = fallback[id]

static func _read_folder(folder: String) -> Dictionary:
	var rooms := {}
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("DungeonAssembler: couldn't open " + folder)
		return rooms
	var file_names: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and file_name != "defines.json":
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()
	for name in file_names:
		var data := JsonOnloading.load_dict(folder + name)
		if data.has("id"):
			Connector.upgrade_room(data)
			for problem in Connector.validate(data):
				push_warning("Room '%s': %s" % [data["id"], problem])
			rooms[data["id"]] = data
	return rooms

static func load_rooms(biome: String = "") -> Dictionary:
	var rooms := _read_folder(ROOMS_DIR + (biome + "/" if biome != "" else ""))
	_fill_from_fallback(rooms)
	return with_rotations(rooms)

## Any key a biome's own defines.json doesn't set (room_count, monsters,
## whatever) falls back to fallback/defines.json's value instead -- one
## reference file to fill in gaps, rather than every biome having to define
## everything itself.
static func load_defines(biome: String) -> Dictionary:
	if biome == "":
		return {}
	var defines := JsonOnloading.load_dict(ROOMS_DIR + biome + "/defines.json")
	var fallback := JsonOnloading.load_dict(ROOMS_DIR + FALLBACK_FOLDER + "/defines.json")
	for key in fallback:
		if not defines.has(key):
			defines[key] = fallback[key]
	return defines

static func dominant_wall_tile(room: Dictionary) -> String:
	return _dominant_tile(room["walls"], "")

static func dominant_floor_tile(room: Dictionary) -> String:
	return _dominant_tile(room["floor"], "")

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

## Spawn cells (and anything else that is a plain {"position"} point).
static func _rotate_points(points: Array, height: int) -> Array:
	var rotated: Array = []
	for c in points:
		var x: int = int(c["position"]["x"])
		var y: int = int(c["position"]["y"])
		var turned: Dictionary = (c as Dictionary).duplicate(true)  # keeps "enemy" and any other key
		turned["position"] = {"x": height - 1 - y, "y": x}
		rotated.append(turned)
	return rotated

## Free-standing doors after one clockwise quarter turn of a room `height` tall.
## A horizontal door (barrier between its cells and the ones north) turns into a
## vertical one (barrier between its cell and the one east) and the other way round;
## `cell` stays the first cell along the run, top-left of what the door covers.
static func _rotate_doors(doors: Array, height: int) -> Array:
	var rotated: Array = []
	for d in doors:
		var turned: Dictionary = (d as Dictionary).duplicate(true)
		var x: int = int(d["cell"]["x"])
		var y: int = int(d["cell"]["y"])
		var width: int = int(d.get("width", 1))
		if d.get("orient", "h") == "h":
			turned["orient"] = "v"
			turned["cell"] = {"x": height - 1 - y, "y": x}
		else:
			turned["orient"] = "h"
			turned["cell"] = {"x": height - 1 - (y + width - 1), "y": x + 1}
		rotated.append(turned)
	return rotated

static func _rotate_connectors(connectors: Array, height: int) -> Array:
	var rotated: Array = []
	for c in connectors:
		rotated.append(Connector.rotate(c, height))
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
		result["spawn_cells"] = _rotate_points(result.get("spawn_cells", []), h)
		if result.has("antagonist_spawns"):
			result["antagonist_spawns"] = _rotate_points(result["antagonist_spawns"], h)
		if result.has("doors"):
			result["doors"] = _rotate_doors(result["doors"], h)
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
		# The entrance stays as drawn (the dive starts there). Bosses rotate like any
		# other room: with one fixed facing a boss only fit dead ends facing one way.
		if role == "entrance":
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
	return JSON.stringify([room["floor"], room["walls"], room["connectors"], room.get("doors", []), room.get("spawn_cells", []), room.get("antagonist_spawns", [])])

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
	## Which other placement this room was attached to, and the world cell of
	## the door connecting them (this room's own connector cell, always open
	## floor once painted) -- -1/unset for the entrance, which has no parent.
	## Placement is otherwise pure geometry; these two fields exist only so
	## RoomGraph.gd can rebuild room-to-room adjacency after generation
	## finishes, for hierarchical/coarse enemy pathfinding across rooms.
	## Bookkeeping only, no RNG use, so it can't affect the deterministic
	## layout itself.
	var parent_index: int = -1
	var door_cell: Vector2i = Vector2i.ZERO
	## Every world cell of the joint on this room's side (door_cell is the middle
	## one), so RoomGraph can aim at the nearest opening of a wide joint.
	var joint_world: Array[Vector2i] = []
	## Connector anchor (local first cell) -> the LOCAL cells of that connector
	## that actually join another room. A connector with no entry is treated as
	## joined along its whole length; cells of a wider connector outside its
	## joint are sealed by the painter.
	var joint_cells: Dictionary = {}

## dungeon_seed: RNG seed, same value on host and every client -> identical layout.
static func generate(rooms: Dictionary, dungeon_seed: int, defines: Dictionary = {}) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = dungeon_seed
	var room_count: Dictionary = defines.get("room_count", {})
	var min_count: int = room_count.get("min", MIN_ROOM_COUNT)
	var max_count: int = room_count.get("max", MAX_ROOM_COUNT)
	var target_count := rng.randi_range(min_count, max_count)
	var tag_weights: Dictionary = defines.get("tag_weights", {})

	var entrance_ids: Array = []
	var boss_ids: Array = []
	var treasure_ids: Array = []
	var pool_ids: Array = []  # normal/corridor rooms eligible for random growth
	var corridor_ids: Array = []  # role=="corridor" only, for the boss fallback below
	var room_ids: Array = rooms.keys()
	room_ids.sort()
	for id in room_ids:
		var r: Dictionary = rooms[id]
		var role: String = r.get("role", "normal")
		if role == "entrance":
			entrance_ids.append(id)
		elif role == "boss":
			boss_ids.append(id)
		elif (r.get("tags", []) as Array).has("treasure"):
			treasure_ids.append(id)
		else:
			pool_ids.append(id)
			if role == "corridor":
				corridor_ids.append(id)

	# Several entrance / boss rooms may exist; one is picked per dungeon. The RNG
	# is only touched when there is a real choice, so a biome with a single one
	# builds the same layout for a given seed as before.
	var entrance_id := "" if entrance_ids.is_empty() else _pick(entrance_ids, rng)
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
		if not _try_place(rooms, pool_ids, entry, placements, occupied, open_connectors, rng, avoid_dead_ends, tag_weights):
			_lock(placements[entry["placement_index"]], entry["local_pos"])

	for entry in open_connectors:
		_lock(placements[entry["placement_index"]], entry["local_pos"])
	open_connectors.clear()

	if not boss_ids.is_empty():
		# The picked boss first; if it fits nowhere, the others get a turn.
		var first := _pick(boss_ids, rng)
		var order: Array = [first]
		for id in boss_ids:
			if id != first:
				order.append(id)
		for boss_id in order:
			if _place_farthest(rooms, boss_id, corridor_ids, placements, occupied):
				break
	else:
		push_warning("DungeonAssembler: no room with role \"boss\" found, skipping")

	if not treasure_ids.is_empty():
		_place_any_locked(rooms, treasure_ids, placements, occupied)
	else:
		push_warning("DungeonAssembler: no room tagged \"treasure\" found, skipping")

	return placements

static func generate_with_retry(rooms: Dictionary, dungeon_seed: int, defines: Dictionary = {}, max_attempts: int = 20) -> Array[Placement]:
	var need_boss := false
	var need_treasure := false
	for id in rooms:
		var r: Dictionary = rooms[id]
		if r.get("role", "normal") == "boss":
			need_boss = true
		if (r.get("tags", []) as Array).has("treasure"):
			need_treasure = true

	for attempt in max_attempts:
		var placements := generate(rooms, dungeon_seed + attempt, defines)
		if not placements.is_empty() and _satisfies_requirements(rooms, placements, need_boss, need_treasure):
			if attempt > 0:
				push_warning("DungeonAssembler: seed %d needed %d retr%s (used seed %d)" % [dungeon_seed, attempt, "y" if attempt == 1 else "ies", dungeon_seed + attempt])
			return placements

	push_warning("DungeonAssembler: no complete layout found in %d attempts from seed %d — using attempt 0 anyway" % [max_attempts, dungeon_seed])
	return generate(rooms, dungeon_seed, defines)

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

## World-space spawn cell positions across every placed room. Which monsters
## actually roll there is a biome-wide decision (defines.json's "monsters"
## table), not a per-cell one -- see EnemySpawning. Kept here since this is
## placement geometry (same local-to-world conversion as connectors/floor
## tiles), not spawn behavior.
static func collect_spawn_cells(rooms: Dictionary, placements: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		for cell in room.get("spawn_cells", []):
			var local := Vector2i(int(cell["position"]["x"]), int(cell["position"]["y"]))
			cells.append(p.offset + local)
	return cells

## Antagonist spawns (boss rooms): world tile plus what to place there, one entry per
## "antagonist_spawns" item. Which boss comes is the room's "favored_antagonist",
## written and matched exactly like "favored_enemy" (see EnemySpawning). An item can
## instead force one with "enemy". Unlike spawn_cells these always spawn (no fog
## check) and never go through the biome table.
static func collect_antagonist_spawns(rooms: Dictionary, placements: Array) -> Array:
	var result: Array = []
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		var favor := favored_enemies(room, "favored_antagonist")
		for entry in room.get("antagonist_spawns", []):
			var local := Vector2i(int(entry["position"]["x"]), int(entry["position"]["y"]))
			result.append({"tile": p.offset + local, "enemy": str(entry.get("enemy", "")), "favor": favor})
	return result

## World spawn cell -> the exact enemy id a room's spawn cell asks for ("enemy"
## on the cell), only for cells that name one. Other cells roll the biome table.
static func collect_spawn_enemies(rooms: Dictionary, placements: Array) -> Dictionary:
	var fixed := {}
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		for cell in room.get("spawn_cells", []):
			var enemy := str(cell.get("enemy", ""))
			if enemy == "":
				continue
			var local := Vector2i(int(cell["position"]["x"]), int(cell["position"]["y"]))
			fixed[p.offset + local] = enemy
	return fixed

## World spawn cell -> that room's "favored_enemy" list ([{"tag", "weight"}]),
## only for rooms that have one. A room's favor is a nudge to the biome's
## monster table, see EnemySpawning.
static func collect_spawn_favors(rooms: Dictionary, placements: Array) -> Dictionary:
	var favors := {}
	for p in placements:
		var room: Dictionary = rooms[p.room_id]
		var favor := favored_enemies(room)
		if favor.is_empty():
			continue
		for cell in room.get("spawn_cells", []):
			var local := Vector2i(int(cell["position"]["x"]), int(cell["position"]["y"]))
			favors[p.offset + local] = favor
	return favors

## A room's "favored_enemy" (or, with `key`, "favored_antagonist") as a list, whether
## it was written as one {"tag", "weight"} entry or an array of them. Weight defaults to 3.
static func favored_enemies(room: Dictionary, key: String = "favored_enemy") -> Array:
	var raw = room.get(key, [])
	var list: Array = raw if raw is Array else [raw]
	var result: Array = []
	for entry in list:
		if entry is Dictionary and entry.get("tag", "") != "":
			result.append({"tag": str(entry["tag"]), "weight": float(entry.get("weight", 3.0))})
	return result

static func _try_place(rooms: Dictionary, candidate_ids: Array, entry: Dictionary, placements: Array[Placement], occupied: Array[Rect2i], open_connectors: Array, rng: RandomNumberGenerator, avoid_dead_ends: bool, tag_weights: Dictionary) -> bool:
	var from_placement: Placement = placements[entry["placement_index"]]
	var from_world: Vector2i = from_placement.offset + entry["local_pos"]
	var need_dir: int = _opposite(entry["dir"])
	var step: Vector2i = _dir_step(entry["dir"])
	var axis: Vector2i = _run_axis(entry["dir"])
	var target_cell: Vector2i = from_world + step
	var from_run: Dictionary = _connector_at(rooms[from_placement.room_id], entry["local_pos"])

	var shuffled_ids: Array = _weighted_shuffle(candidate_ids, rooms, tag_weights, rng)
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
			var local_pos := Connector.a(c)
			if _connector_dir(cand, local_pos) != need_dir:
				continue
			for shift in _join_shifts(from_run, c):
				var offset: Vector2i = target_cell + axis * shift - local_pos
				var rect := Rect2i(offset, Vector2i(cand["width"], cand["height"]))
				if _overlaps_any(rect, occupied):
					continue
				var joint := _joint_cells(from_run, c, shift, axis)
				var placement := Placement.new()
				placement.room_id = cand_id
				placement.offset = offset
				placement.depth = from_placement.depth + 1
				placement.suppressed_connectors.append(local_pos)
				placement.parent_index = entry["placement_index"]
				placement.joint_cells[local_pos] = joint["cand"]
				from_placement.joint_cells[entry["local_pos"]] = joint["from"]
				placement.door_cell = from_placement.offset + _middle_cell(joint["from"]) + step
				placement.joint_world = _world_joint(from_placement.offset, joint["from"], step)
				placements.append(placement)
				occupied.append(rect)
				_queue_connectors(cand, placements.size() - 1, open_connectors, local_pos)
				return true
	return false

static func _fit_room_at(rooms: Dictionary, room_id: String, from_placement: Placement, local_pos: Vector2i, placements: Array[Placement], occupied: Array[Rect2i], parent_index: int) -> bool:
	var from_room: Dictionary = rooms[from_placement.room_id]
	var from_dir: int = _connector_dir(from_room, local_pos)
	var need_dir: int = _opposite(from_dir)
	var step: Vector2i = _dir_step(from_dir)
	var axis: Vector2i = _run_axis(from_dir)
	var target_cell: Vector2i = from_placement.offset + local_pos + step
	var from_run: Dictionary = _connector_at(from_room, local_pos)

	var room: Dictionary = rooms[room_id]
	var connectors: Array = room["connectors"].duplicate()
	connectors.sort_custom(func(p, q):
		var pa := Connector.a(p)
		var qa := Connector.a(q)
		if pa.y != qa.y:
			return pa.y < qa.y
		return pa.x < qa.x
	)
	for c in connectors:
		var cand_local := Connector.a(c)
		if _connector_dir(room, cand_local) != need_dir:
			continue
		for shift in _join_shifts(from_run, c):
			var offset: Vector2i = target_cell + axis * shift - cand_local
			var rect := Rect2i(offset, Vector2i(room["width"], room["height"]))
			if _overlaps_any(rect, occupied):
				continue
			var joint := _joint_cells(from_run, c, shift, axis)
			var placement := Placement.new()
			placement.room_id = room_id
			placement.offset = offset
			placement.depth = from_placement.depth + 1
			placement.suppressed_connectors.append(cand_local)
			placement.parent_index = parent_index
			placement.joint_cells[cand_local] = joint["cand"]
			from_placement.joint_cells[local_pos] = joint["from"]
			placement.door_cell = from_placement.offset + _middle_cell(joint["from"]) + step
			placement.joint_world = _world_joint(from_placement.offset, joint["from"], step)
			placements.append(placement)
			occupied.append(rect)
			var extra: Array = []
			_queue_connectors(room, placements.size() - 1, extra, cand_local)
			for e in extra:
				_lock(placements[e["placement_index"]], e["local_pos"])
			return true
	return false

## The connector of `room` whose first cell is `anchor` (connectors are keyed
## by that cell everywhere else). Falls back to a single cell if not found.
static func _connector_at(room: Dictionary, anchor: Vector2i) -> Dictionary:
	for c in room["connectors"]:
		if Connector.a(c) == anchor:
			return c
	return Connector.make(anchor, anchor)

## Which way a run of cells extends for an opening facing `dir`.
static func _run_axis(dir: int) -> Vector2i:
	return Vector2i(1, 0) if dir == Dir.NORTH or dir == Dir.SOUTH else Vector2i(0, 1)

## The offsets (in cells along the run, candidate's first cell relative to the
## from-run's first cell) at which `cand_run` may join `from_run`, best first.
## Exact mode (neither run is `free`): equal widths only, lined up end to end.
## Free mode (either run is `free`): any widths, at least one cell overlapping --
## centred first (a 1-wide passage opens onto the middle of a wide one), then
## start-aligned, then end-aligned. No RNG here, so seeds stay deterministic.
static func _join_shifts(from_run: Dictionary, cand_run: Dictionary) -> Array[int]:
	var from_width := Connector.width(from_run)
	var cand_width := Connector.width(cand_run)
	var shifts: Array[int] = []
	if not (Connector.is_free(from_run) or Connector.is_free(cand_run)):
		if from_width == cand_width:
			shifts.append(0)
		return shifts
	for s in [floori((from_width - cand_width) / 2.0), 0, from_width - cand_width]:
		if not shifts.has(s):
			shifts.append(s)
	return shifts

## The cells actually shared by the two runs at `shift`, as LOCAL cells of each
## room ({"from": [...], "cand": [...]}, same order). Any cell of either run
## outside this overlap has no partner and gets walled off by the painter.
static func _joint_cells(from_run: Dictionary, cand_run: Dictionary, shift: int, axis: Vector2i) -> Dictionary:
	var from_cells: Array[Vector2i] = []
	var cand_cells: Array[Vector2i] = []
	var from_width := Connector.width(from_run)
	var cand_width := Connector.width(cand_run)
	for i in range(maxi(0, shift), mini(from_width - 1, shift + cand_width - 1) + 1):
		from_cells.append(Connector.a(from_run) + axis * i)
		cand_cells.append(Connector.a(cand_run) + axis * (i - shift))
	return {"from": from_cells, "cand": cand_cells}

static func _world_joint(offset: Vector2i, from_cells: Array, step: Vector2i) -> Array[Vector2i]:
	var world: Array[Vector2i] = []
	for c in from_cells:
		world.append(offset + c + step)
	return world

static func _middle_cell(cells: Array) -> Vector2i:
	return cells[floori(cells.size() / 2.0)]

const MAX_BOSS_CORRIDOR_EXTENSION := 8

static func _place_farthest(rooms: Dictionary, room_id: String, corridor_ids: Array, placements: Array[Placement], occupied: Array[Rect2i]) -> bool:
	var candidates: Array = []
	for i in placements.size():
		for local_pos in placements[i].locked_connectors:
			candidates.append({"placement_index": i, "local_pos": local_pos, "depth": placements[i].depth})
	candidates.sort_custom(func(a, b): return a["depth"] > b["depth"])

	for c in candidates:
		var from_placement: Placement = placements[c["placement_index"]]
		if _fit_room_at(rooms, room_id, from_placement, c["local_pos"], placements, occupied, c["placement_index"]):
			from_placement.locked_connectors.erase(c["local_pos"])
			return true

	if not corridor_ids.is_empty():
		for c in candidates:
			var cur_placement: Placement = placements[c["placement_index"]]
			var cur_index: int = c["placement_index"]
			var cur_local: Vector2i = c["local_pos"]
			for extension in MAX_BOSS_CORRIDOR_EXTENSION:
				if _fit_room_at(rooms, room_id, cur_placement, cur_local, placements, occupied, cur_index):
					cur_placement.locked_connectors.erase(cur_local)
					return true
				var extended := false
				for corridor_id in corridor_ids:
					if _fit_room_at(rooms, corridor_id, cur_placement, cur_local, placements, occupied, cur_index):
						cur_placement.locked_connectors.erase(cur_local)
						var new_placement: Placement = placements[placements.size() - 1]
						if new_placement.locked_connectors.is_empty():
							break  # this corridor dead-ended, can't extend further this way
						cur_placement = new_placement
						cur_index = placements.size() - 1
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
			if _fit_room_at(rooms, room_id, from_placement, c["local_pos"], placements, occupied, c["placement_index"]):
				from_placement.locked_connectors.erase(c["local_pos"])
				return true
	push_warning("DungeonAssembler: no treasure room fit any dead end")
	return false

static func _queue_connectors(room: Dictionary, placement_index: int, open_connectors: Array, skip_local: Vector2i = Vector2i(-1, -1)) -> void:
	var connectors: Array = room["connectors"].duplicate()
	connectors.sort_custom(func(p, q):
		var pa := Connector.a(p)
		var qa := Connector.a(q)
		if pa.y != qa.y:
			return pa.y < qa.y
		return pa.x < qa.x
	)
	for c in connectors:
		var local_pos := Connector.a(c)
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

## One entry of `ids`; the RNG is only used when there is more than one.
static func _pick(ids: Array, rng: RandomNumberGenerator) -> String:
	if ids.size() == 1:
		return ids[0]
	return ids[rng.randi_range(0, ids.size() - 1)]

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _room_weight(room: Dictionary, tag_weights: Dictionary) -> float:
	var weight: float = tag_weights.get(room.get("role", "normal"), 1.0)
	for tag in (room.get("tags", []) as Array):
		weight *= tag_weights.get(tag, 1.0)
	return max(weight, 0.0001)

# Same effect as _shuffle when every weight is 1.0; a lower-weight room just tends
# to sort later, so it's picked less often without ever being impossible to pick.
static func _weighted_shuffle(ids: Array, rooms: Dictionary, tag_weights: Dictionary, rng: RandomNumberGenerator) -> Array:
	var keyed: Array = []
	for id in ids:
		keyed.append([pow(rng.randf(), 1.0 / _room_weight(rooms[id], tag_weights)), id])
	keyed.sort_custom(func(a, b): return a[0] > b[0])
	var result: Array = []
	for pair in keyed:
		result.append(pair[1])
	return result
