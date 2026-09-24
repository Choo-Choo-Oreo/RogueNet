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

static func spawn_in_unseen_cells(spawn_cells: Array[Vector2i], monster_weights: Dictionary, light_map: LightMap, enemies_root: Node) -> void:
	if monster_weights.is_empty():
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
		var enemy_id := _roll_enemy(monster_weights, rng)
		if enemy_id == "":
			continue
		var id := _next_id
		_next_id += 1
		spawn_one(id, enemy_id, tile, enemies_root)
		spawned.append({"id": id, "type": enemy_id, "tile": tile})
	NetworkSync.broadcast_enemy_spawns(spawned)

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
