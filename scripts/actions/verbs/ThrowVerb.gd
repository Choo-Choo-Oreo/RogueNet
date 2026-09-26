class_name ThrowVerb
extends RefCounted

## Throws something to a spot that makes a noise where it lands (see Sound), and does no damage.
## It flies at most `range_tiles` toward the aimed tile and stops short of the first wall, so
## aiming at a wall lands it just in front. `db` is the landing's dB (Sound;
## a footstep is 30); without it the landing is silent. Players hear the action's sound
## (CombatSounds) at the landing, at that dB. The `effect.projectile` sprite is only the flight.
## Who hears it is the host's business (NetworkSync.report_noise).

static func perform(caster: Node2D, target_global: Vector2, attack: Dictionary) -> bool:
	var mover: GridMover = caster.grid_mover
	var tile_size: float = mover.tile_size
	var here := Vector2i((caster.global_position / tile_size).floor())
	var aimed := Vector2i((target_global / tile_size).floor())
	var offset := Vector2(aimed - here)
	var reach: float = attack.get("range_tiles", 6.0)
	if offset.length() > reach:
		offset = offset.normalized() * reach
	var landing := here
	var steps := ceili(offset.length())
	for i in range(1, steps + 1):
		var cell := here + Vector2i((offset * float(i) / float(steps)).round())
		if mover.is_tile_blocked(cell):
			break
		landing = cell
	if landing == here:
		return false
	var landing_global := (Vector2(landing) + Vector2(0.5, 0.5)) * tile_size
	var db: float = attack.get("db", 0.0)
	# Tagged now: the caster may be gone by the time it lands.
	var sound := CombatSounds.tag_effect(caster, attack, {})
	var land := func():
		NetworkSync.report_noise(landing_global, db)
		if sound["sound"] != "":
			NetworkSync.play_effect(landing_global, sound, Vector2.ZERO)
	var texture: String = attack.get("effect", {}).get("projectile", "")
	if texture == "":
		land.call()
		return true
	var from: Vector2 = caster.global_position + Vector2(tile_size, tile_size) / 2.0
	var flying: ProjectileController = ProjectileVerb.PROJECTILE_SCENE.instantiate()
	caster.get_tree().current_scene.add_child(flying)
	flying.global_position = from
	flying.launch(texture, landing_global, tile_size, land, mover.is_position_blocked)
	NetworkSync.share_projectile(texture, from, landing_global)
	return true
