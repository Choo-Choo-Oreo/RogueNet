class_name ActionRunner
extends RefCounted

## Carries out a resolved action (see ActionIndex) for a caster: the one place that maps an
## action's "verb" to the script that does it. The caster's driver decides when to call this
## and where to aim; the verb does the rest. `target_global` is the top-left pixel of the
## aimed tile. Returns false when the action had no effect (a wall smash with nothing to
## break), so the driver can leave its cooldown unspent; true otherwise.

const VERBS := ["hit", "projectile", "destroy_tiles", "taunt"]

static func perform(caster: Node2D, target_global: Vector2, attack: Dictionary) -> bool:
	match str(attack.get("verb", "")):
		"hit":
			HitVerb.perform(caster, target_global, attack)
		"projectile":
			ProjectileVerb.perform(caster, target_global, attack)
		"destroy_tiles":
			return DestroyTilesVerb.perform(caster, target_global, attack)
		"taunt":
			TauntVerb.perform(caster, attack)
		_:
			return false
	return true
