class_name MinionSpawning
extends RefCounted

## Rolls and instantiates minions into any spawn cell not currently lit for
## the local player -- called at dungeon start (everything is unseen at t=0,
## so this naturally fills the whole dungeon), and later on boss death and
## from a debug menu. No "already spawned here" memory: a spawn cell that's
## still unseen keeps re-rolling every call, which can double up minions on
## an un-cleared cell -- intentional, not a bug.
##
## Host-only, same reasoning NetworkSync.gd's dungeon seed already uses: minion
## identity/position has to be decided in exactly one place and told to
## everyone else, not independently re-rolled per peer (each peer has its own
## RNG state and its own local fog-of-war, so two peers rolling separately
## would see different monsters in different places).

const MINION_SCENE := preload("res://scenes/entities/MinionController.tscn")
const TILE_SIZE := 16.0

## Network id for the next minion this process spawns -- just needs to stay
## unique within one dungeon session so "Minions/<id>" node paths line up
## across peers, not globally unique forever.
static var _next_id: int = 1

## `favors` maps a spawn cell to its room's favored-minion list (see
## DungeonAssembler.collect_spawn_favors); cells without one roll the plain table.
static func spawn_in_unseen_cells(spawn_cells: Array[Vector2i], monster_weights: Dictionary, light_map: LightMap, minions_root: Node, favors: Dictionary = {}, fixed_minions: Dictionary = {}) -> void:
	if monster_weights.is_empty() and fixed_minions.is_empty():
		return
	var mp := minions_root.get_multiplayer()
	# Fails open (acts as host) when no peer is assigned at all -- eg. running
	# Dungeon.tscn directly in the editor, bypassing the menu's peer setup.
	if mp.multiplayer_peer != null and not mp.is_server():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawned: Array = []
	for tile in spawn_cells:
		if light_map.is_tile_lit(tile):
			continue
		# A cell that names its minion always gets it (as long as that minion exists).
		var minion_id: String = fixed_minions.get(tile, "")
		if minion_id != "" and not MinionIndex.has(minion_id):
			push_warning("Spawn cell %s names unknown minion '%s', rolling instead" % [tile, minion_id])
			minion_id = ""
		var placed := NO_FIT
		if minion_id != "":
			placed = fit_tile(minion_id, tile, minions_root)
		else:
			var rolled := _roll_and_fit(_favored_weights(monster_weights, favors.get(tile, [])), tile, minions_root, rng)
			if not rolled.is_empty():
				minion_id = rolled[0]
				placed = rolled[1]
		if placed == NO_FIT:
			continue
		var id := _next_id
		_next_id += 1
		spawn_one(id, minion_id, placed, minions_root)
		spawned.append({"id": id, "type": minion_id, "tile": placed})
	NetworkSync.broadcast_minion_spawns(spawned)

## The antagonist spawns of the boss rooms: each entry is {"tile", "minion"}. Always
## placed (no roll, not gated by the fog), host only, and told to every peer the same
## way as the normal spawns.
static func spawn_antagonists(entries: Array, minions_root: Node) -> void:
	var mp := minions_root.get_multiplayer()
	if mp.multiplayer_peer != null and not mp.is_server():
		return
	var spawned: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for entry in entries:
		var minion_id: String = entry["minion"]
		var placed := NO_FIT
		if minion_id != "" and MinionIndex.has(minion_id):
			placed = fit_tile(minion_id, entry["tile"], minions_root)
		elif minion_id == "":
			# Only a boss that fits the room: a 7x7 dragon picked for a small boss room
			# used to be skipped, leaving the room with no boss at all.
			var rolled := _roll_and_fit(_favored_weights(_boss_weights(), entry["favor"]), entry["tile"], minions_root, rng)
			if not rolled.is_empty():
				minion_id = rolled[0]
				placed = rolled[1]
		if placed == NO_FIT:
			push_warning("Antagonist spawn at %s found no boss that fits (minion '%s'), skipped" % [entry["tile"], minion_id])
			continue
		var id := _next_id
		_next_id += 1
		spawn_one(id, minion_id, placed, minions_root)
		spawned.append({"id": id, "type": minion_id, "tile": placed})
	if not spawned.is_empty():
		NetworkSync.broadcast_minion_spawns(spawned)

## Every boss (see MinionIndex.is_boss) at weight 1. A room's favored_antagonist then
## boosts the matching ones, the very same weighting a favored_minion gives the biome
## table (_favored_weights). No favor = all equal.
static func _boss_weights() -> Dictionary:
	var weights := {}
	for minion_id: String in MinionIndex.ids():
		if MinionIndex.is_boss(minion_id):
			weights[minion_id] = 1.0
	return weights

## Rolls a minion from `weights` whose whole body fits at (or near) `tile`; one that does
## not fit is struck off and the roll repeats. Returns [minion id, tile], or [] if none fits.
static func _roll_and_fit(weights: Dictionary, tile: Vector2i, minions_root: Node, rng: RandomNumberGenerator) -> Array:
	var left := weights.duplicate()
	while not left.is_empty():
		var minion_id := _roll_minion(left, rng)
		if minion_id == "":
			return []
		var placed := fit_tile(minion_id, tile, minions_root, false)
		if placed != NO_FIT:
			return [minion_id, placed]
		left.erase(minion_id)
	return []

## Debug menu: one minion of a chosen type on a chosen tile, host only.
static func spawn_debug(minion_id: String, tile: Vector2i, minions_root: Node) -> void:
	if minion_id.contains("/") or minion_id.contains("\\") or minion_id.contains(".."):
		return
	if not MinionIndex.has(minion_id):
		return
	var placed := fit_tile(minion_id, tile, minions_root)
	if placed == NO_FIT:
		return
	var id := _next_id
	_next_id += 1
	spawn_one(id, minion_id, placed, minions_root)
	NetworkSync.broadcast_minion_spawns([{"id": id, "type": minion_id, "tile": placed}])

## The tile to spawn `minion_id` on so its WHOLE body fits: a big minion (size_tiles 2+)
## stands on a square of tiles starting at its top-left one, and a spawn cell only
## promises that one tile is open (a debug spawn not even that). Returns `tile` itself when the body fits there, else
## the nearest tile (searching up to FIT_SEARCH_RADIUS out) where every tile of the
## square is open floor, else NO_FIT with a warning. Host only, before broadcasting.
const FIT_SEARCH_RADIUS := 6
## What fit_tile returns when the body fits nowhere: the spawn is skipped, never placed in a wall.
const NO_FIT := Vector2i(-2147483648, -2147483648)

static func fit_tile(minion_id: String, tile: Vector2i, minions_root: Node, warn := true) -> Vector2i:
	var size := int(MinionIndex.load_data(minion_id).get("size_tiles", 1))
	var scene := minions_root.get_tree().current_scene
	var wall_data := scene.find_child("WallData", true, false) as TileMapLayer
	var floor_data := scene.find_child("FloorData", true, false) as TileMapLayer
	if wall_data == null or floor_data == null:
		return tile
	var void_id := GridMover._tile_ids().get_id("floor_void")
	# The usual case, and the only check a 1x1 body needs (the debug menu can aim it at a wall).
	if _body_fits(tile, size, wall_data, floor_data, void_id):
		return tile
	var best := tile
	var best_distance := INF
	for dy in range(-FIT_SEARCH_RADIUS, FIT_SEARCH_RADIUS + 1):
		for dx in range(-FIT_SEARCH_RADIUS, FIT_SEARCH_RADIUS + 1):
			var candidate := tile + Vector2i(dx, dy)
			var distance := float(dx * dx + dy * dy)
			if distance >= best_distance or not _body_fits(candidate, size, wall_data, floor_data, void_id):
				continue
			best = candidate
			best_distance = distance
	if best_distance == INF:
		if warn:
			push_warning("No room for a %dx%d '%s' within %d tiles of %s, not spawning it" % [size, size, minion_id, FIT_SEARCH_RADIUS, tile])
		return NO_FIT
	return best

static func _body_fits(top_left: Vector2i, size: int, wall_data: TileMapLayer, floor_data: TileMapLayer, void_id: int) -> bool:
	for y in size:
		for x in size:
			var cell := top_left + Vector2i(x, y)
			var floor_id := floor_data.get_cell_source_id(cell)
			if wall_data.get_cell_source_id(cell) != -1 or floor_id == -1 or floor_id == void_id:
				return false
	return true

## Shared by the host's own roll above and NetworkSync.receive_spawn_minions
## (each client building its local copy of what the host already rolled).
static func spawn_one(id: int, minion_id: String, tile: Vector2i, minions_root: Node) -> MinionController:
	var minion: MinionController = MINION_SCENE.instantiate()
	minion.name = str(id)
	minions_root.add_child(minion)
	# Minions are always host-owned -- host runs their AI and tells everyone
	# else where they end up, the same "host decides, peers are told" split
	# the dungeon seed already uses, not a per-player authority split like
	# PlayerController's own movement.
	minion.set_multiplayer_authority(1)
	minion.global_position = Vector2(tile) * TILE_SIZE
	minion.set_minion_type(minion_id)
	return minion

## The biome table with each matching minion's weight multiplied by the room's
## favor. Only a boost: a minion the biome table does not list is never added,
## and a favor that matches nothing leaves the table as it was. A minion matches
## a favor by its own id or by its "tags", main or main.secondary (see game/TAGS.md).
static func _favored_weights(weights: Dictionary, favor: Array) -> Dictionary:
	if favor.is_empty():
		return weights
	var result := {}
	for id in weights:
		var multiplier := 1.0
		var tags := _tags_of(id)
		for entry in favor:
			if _matches(tags, entry["tag"]):
				multiplier *= float(entry["weight"])
		result[id] = float(weights[id]) * multiplier
	return result

## A tag is "main" or "main.secondary" (undead.skeleton). Asking for the main
## one matches every secondary under it; asking for the full one matches only it.
static func _matches(tags: Array, wanted: String) -> bool:
	for tag: String in tags:
		if tag == wanted or tag.begins_with(wanted + "."):
			return true
	return false

static var _tag_cache := {}

static func _tags_of(minion_id: String) -> Array:
	if not _tag_cache.has(minion_id):
		var data := MinionIndex.load_data(minion_id)
		var tags: Array = (data.get("tags", []) as Array).duplicate()
		tags.append(minion_id)
		_tag_cache[minion_id] = tags
	return _tag_cache[minion_id]

static func _roll_minion(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for w in weights.values():
		total += float(w)
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for id in weights:
		roll -= float(weights[id])
		if roll <= 0.0:
			return id
	return weights.keys()[-1]
