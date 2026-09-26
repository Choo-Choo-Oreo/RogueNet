class_name ProjectileVerb
extends RefCounted

## A shot at a spot: an "attacker" animation plays on the caster as it leaves (cosmetic), a
## projectile flies to the target at a fixed speed if the effect has one, and only on
## arrival does the "target" animation play. The projectile hits the first creature of the
## other team whose tile it passes through, not whoever it was aimed at: stepping out of its
## way makes it miss, stepping into it gets you hit. A shot with no projectile (a magic bolt)
## skips the flight and lands at once. Reaching the aimed tile with nobody there is a miss,
## but the impact animation still plays.
##
## Works for any caster; the team decides who is hit (TileHit). Who to aim at, and when, is
## the caster's driver's business.

const PROJECTILE_SCENE := preload("res://scenes/entities/ProjectileController.tscn")

## `attack` is a resolved action (amount, type, effect); `target_global` is the top-left
## pixel of the aimed tile.
static func perform(caster: Node2D, target_global: Vector2, attack: Dictionary) -> void:
	var tile_size: float = caster.grid_mover.tile_size
	var half := Vector2(tile_size, tile_size) / 2.0
	var effect: Dictionary = attack.get("effect", {})
	var amount: int = attack.get("amount", 0)
	var type: String = attack.get("type", "")
	var cause: String = attack.get("id", "")
	var attacker_data: Dictionary = effect.get("attacker", {})
	AttackEffect.play_attack(caster, target_global, attack, attacker_data)
	var texture: String = effect.get("projectile", "")
	if texture == "":
		_play_target(caster, effect, target_global)
		TileHit.apply(caster, Vector2i(((target_global + half) / tile_size).floor()), amount, type, cause)
		return
	var footprint: int = caster.get_meta("footprint", 1)
	var from: Vector2 = caster.global_position + Vector2(footprint, footprint) * tile_size / 2.0
	var projectile: ProjectileController = PROJECTILE_SCENE.instantiate()
	GameView.world_scene(caster.get_tree()).add_child(projectile)
	projectile.global_position = from
	var hit_on_the_way := func(pos: Vector2) -> bool:
		var tile := Vector2i((pos / tile_size).floor())
		if not TileHit.apply(caster, tile, amount, type, cause):
			return false
		_play_target(caster, effect, Vector2(tile) * tile_size)
		return true
	projectile.launch(texture, target_global + half, tile_size, func():
		_play_target(caster, effect, target_global), caster.grid_mover.is_position_blocked, hit_on_the_way)
	NetworkSync.share_projectile(texture, from, target_global + half)

## The "target" impact animation on a tile (cosmetic only).
static func _play_target(caster: Node2D, effect: Dictionary, tile_global: Vector2) -> void:
	var target_data: Dictionary = effect.get("target", {})
	if not target_data.is_empty():
		AttackEffect.play_between(caster.global_position, tile_global, target_data)
