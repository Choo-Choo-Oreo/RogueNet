class_name DestroyTilesVerb
extends RefCounted

## Breaks the walls inside the action's "shape" (see ActionShapes), aimed at the target and
## starting from the caster's own footprint. Host-authoritative through
## NetworkSync.destroy_tiles. Returns false when nothing broke, so it does not count as used.
## An optional "effect" plays like a hit's.
static func perform(caster: Node2D, target_global: Vector2, attack: Dictionary) -> bool:
	var tile_size: float = caster.grid_mover.tile_size
	var origin := Vector2i((caster.global_position / tile_size).floor())
	var target_tile := Vector2i((target_global / tile_size).floor())
	var cells := ActionShapes.cells(attack.get("shape", {}), origin, caster.get_meta("footprint", 1), target_tile)
	if NetworkSync.destroy_tiles(cells) == 0:
		return false
	caster.animator.animate_facing(target_global - caster.global_position)
	var effect: Dictionary = attack.get("effect", {})
	if not effect.is_empty():
		AttackEffect.play_between(caster.global_position, target_global, effect)
	return true
