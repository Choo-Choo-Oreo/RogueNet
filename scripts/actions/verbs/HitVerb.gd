class_name HitVerb
extends RefCounted

## A hit on a tile next to the caster: the effect (a swing, a bite) plays between the two,
## then whoever of the other team stands there is damaged (TileHit). Who to aim at, and when,
## is the caster's driver's business.

## `attack` is a resolved action (amount, type, effect); `target_global` is the top-left
## pixel of the aimed tile.
static func perform(caster: Node2D, target_global: Vector2, attack: Dictionary) -> void:
	var effect: Dictionary = attack.get("effect", {})
	AttackEffect.play_attack(caster, target_global, attack, effect)
	var tile_size: float = caster.grid_mover.tile_size
	var half := Vector2(tile_size, tile_size) / 2.0
	TileHit.apply(caster, Vector2i(((target_global + half) / tile_size).floor()), attack.get("amount", 0), attack.get("type", ""))
