class_name EnemySpawning
extends RefCounted

## Rolls and instantiates enemies into any spawn cell not currently lit for
## the local player -- called at dungeon start (everything is unseen at t=0,
## so this naturally fills the whole dungeon), and later on boss death and
## from a debug menu. No "already spawned here" memory: a spawn cell that's
## still unseen keeps re-rolling every call, which can double up enemies on
## an un-cleared cell -- intentional, not a bug.
##
## Host-only, same reasoning NetworkSync.gd's dungeon seed already uses: enemy
## identity/position has to be decided in exactly one place and told to
## everyone else, not independently re-rolled per peer (each peer has its own
## RNG state and its own local fog-of-war, so two peers rolling separately
## would see different monsters in different places).

const ENEMY_SCENE := preload("res://scenes/entities/EnemyController.tscn")
const TILE_SIZE := 16.0

## Network id for the next enemy this process spawns -- just needs to stay
## unique within one dungeon session so "Enemies/<id>" node paths line up
## across peers, not globally unique forever.
static var _next_id: int = 1

## `favors` maps a spawn cell to its room's favored-enemy list (see
## DungeonAssembler.collect_spawn_favors); cells without one roll the plain table.
static func spawn_in_unseen_cells(spawn_cells: Array[Vector2i], monster_weights: Dictionary, light_map: LightMap, enemies_root: Node, favors: Dictionary = {}, fixed_enemies: Dictionary = {}) -> void:
	if monster_weights.is_empty() and fixed_enemies.is_empty():
		return
	var mp := enemies_root.get_multiplayer()
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
		# A cell that names its enemy always gets it (as long as that enemy exists).
		var enemy_id: String = fixed_enemies.get(tile, "")
		if enemy_id != "" and not FileAccess.file_exists(EnemyController.ENEMY_TYPES_DIR + enemy_id + ".json"):
			push_warning("Spawn cell %s names unknown enemy '%s', rolling instead" % [tile, enemy_id])
			enemy_id = ""
		if enemy_id == "":
			enemy_id = _roll_enemy(_favored_weights(monster_weights, favors.get(tile, [])), rng)
		if enemy_id == "":
			continue
		var id := _next_id
		_next_id += 1
		spawn_one(id, enemy_id, tile, enemies_root)
		spawned.append({"id": id, "type": enemy_id, "tile": tile})
	NetworkSync.broadcast_enemy_spawns(spawned)

## The antagonist spawns of the boss rooms: each entry is {"tile", "enemy"}. Always
## placed (no roll, not gated by the fog), host only, and told to every peer the same
## way as the normal spawns.
static func spawn_antagonists(entries: Array, enemies_root: Node) -> void:
	var mp := enemies_root.get_multiplayer()
	if mp.multiplayer_peer != null and not mp.is_server():
		return
	var spawned: Array = []
	for entry in entries:
		var enemy_id: String = entry["enemy"]
		if enemy_id == "":
			enemy_id = _pick_boss(entry["favor"])
		if enemy_id == "" or not FileAccess.file_exists(EnemyController.ENEMY_TYPES_DIR + enemy_id + ".json"):
			push_warning("Antagonist spawn at %s found no boss (enemy '%s'), skipped" % [entry["tile"], enemy_id])
			continue
		var id := _next_id
		_next_id += 1
		spawn_one(id, enemy_id, entry["tile"], enemies_root)
		spawned.append({"id": id, "type": enemy_id, "tile": entry["tile"]})
	if not spawned.is_empty():
		NetworkSync.broadcast_enemy_spawns(spawned)

## A random boss: every enemy json with "boss": true starts at weight 1, then the
## room's favored_antagonist boosts the matching ones, the very same weighting a
## favored_enemy gives the biome table (_favored_weights). No favor = all equal.
static func _pick_boss(favor: Array) -> String:
	var weights := {}
	for file_name in DirAccess.get_files_at(EnemyController.ENEMY_TYPES_DIR):
		if not file_name.ends_with(".json"):
			continue
		var enemy_id := file_name.get_basename()
		var data := JsonOnloading.load_dict(EnemyController.ENEMY_TYPES_DIR + file_name)
		if not data.get("boss", false):
			continue
		weights[enemy_id] = 1.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return _roll_enemy(_favored_weights(weights, favor), rng)

## Debug menu: one enemy of a chosen type on a chosen tile, host only.
static func spawn_debug(enemy_id: String, tile: Vector2i, enemies_root: Node) -> void:
	if enemy_id.contains("/") or enemy_id.contains("\\") or enemy_id.contains(".."):
		return
	if not FileAccess.file_exists(EnemyController.ENEMY_TYPES_DIR + enemy_id + ".json"):
		return
	var id := _next_id
	_next_id += 1
	spawn_one(id, enemy_id, tile, enemies_root)
	NetworkSync.broadcast_enemy_spawns([{"id": id, "type": enemy_id, "tile": tile}])

## Shared by the host's own roll above and NetworkSync.receive_spawn_enemies
## (each client building its local copy of what the host already rolled).
static func spawn_one(id: int, enemy_id: String, tile: Vector2i, enemies_root: Node) -> EnemyController:
	var enemy: EnemyController = ENEMY_SCENE.instantiate()
	enemy.name = str(id)
	enemies_root.add_child(enemy)
	# Enemies are always host-owned -- host runs their AI and tells everyone
	# else where they end up, the same "host decides, peers are told" split
	# the dungeon seed already uses, not a per-player authority split like
	# PlayerController's own movement.
	enemy.set_multiplayer_authority(1)
	enemy.global_position = Vector2(tile) * TILE_SIZE
	enemy.set_enemy_type(enemy_id)
	return enemy

## The biome table with each matching enemy's weight multiplied by the room's
## favor. Only a boost: an enemy the biome table does not list is never added,
## and a favor that matches nothing leaves the table as it was. An enemy matches
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

static func _tags_of(enemy_id: String) -> Array:
	if not _tag_cache.has(enemy_id):
		var data := JsonOnloading.load_dict(EnemyController.ENEMY_TYPES_DIR + enemy_id + ".json")
		var tags: Array = (data.get("tags", []) as Array).duplicate()
		tags.append(enemy_id)
		_tag_cache[enemy_id] = tags
	return _tag_cache[enemy_id]

static func _roll_enemy(weights: Dictionary, rng: RandomNumberGenerator) -> String:
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
