class_name TauntVerb
extends RefCounted

## Forces the minions within `radius_tiles` of the caster (the nearest `max_targets`) onto the
## caster for `duration` seconds. The host applies it (NetworkSync.report_taunt); the effect,
## if there is one, plays on the caster. The caster's driver owns the cooldown.
static func perform(caster: Node2D, attack: Dictionary) -> void:
	NetworkSync.report_taunt(
		int(str(caster.name)),
		attack.get("radius_tiles", 6.0),
		attack.get("duration", 4.0),
		attack.get("max_targets", 24))
	var effect: Dictionary = attack.get("effect", {})
	if not effect.is_empty():
		AttackEffect.play_between(caster.global_position, caster.global_position, effect)
