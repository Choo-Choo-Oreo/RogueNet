class_name EnemySpawning
extends RefCounted

## Rolls and instantiates enemies into any spawn cell not currently lit for
## the local player -- called at dungeon start (everything is unseen at t=0,
## so this naturally fills the whole dungeon), and later on boss death and
## from a debug menu. No "already spawned here" memory: a spawn cell that's
## still unseen keeps re-rolling every call, which can double up enemies on
## an un-cleared cell -- intentional, not a bug.

const ENEMY_SCENE := preload("res://scenes/entities/EnemyController.tscn")
const TILE_SIZE := 16.0

static func spawn_in_unseen_cells(spawn_cells: Array[Vector2i], monster_weights: Dictionary, light_map: LightMap, parent: Node) -> void:
	if monster_weights.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for tile in spawn_cells:
		if light_map.is_tile_lit(tile):
			continue
		var enemy_id := _roll_enemy(monster_weights, rng)
		if enemy_id == "":
			continue
		var enemy: EnemyController = ENEMY_SCENE.instantiate()
		parent.add_child(enemy)
		enemy.global_position = Vector2(tile) * TILE_SIZE
		enemy.set_enemy_type(enemy_id)

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
