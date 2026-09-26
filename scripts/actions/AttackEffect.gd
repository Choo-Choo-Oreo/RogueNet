class_name AttackEffect
extends Node2D

## One-shot animated effect (sword swing, rat bite, etc.) -- spawned at a
## position, plays its animation once, then frees itself. data matches the
## "effect" key inside an entity's "attack" JSON block: {"texture",
## "frame_count", "speed"}, reusing SpriteFramesLoader's animation format.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## "midpoint" (default) centers the effect between attacker and target -- a
## melee swing or bite happens between the two. "attacker" anchors it on the
## attacker's own tile instead: a ranged shot fires FROM the attacker, it
## isn't drawn hovering out at the target. "target" is the reverse, for a
## magic hit that only plays on the target: offset half a tile off the
## target's origin, toward the caster, so it lands on whichever edge (or
## corner, if the caster is diagonal) of the target faces them.
static func effect_position(attacker_global: Vector2, target_global: Vector2, data: Dictionary) -> Vector2:
	match data.get("anchor", "midpoint"):
		"attacker":
			return attacker_global
		"target":
			var to_attacker := attacker_global - target_global
			if to_attacker.length() > 0.0:
				to_attacker = to_attacker.normalized() * 8.0
			return target_global + to_attacker
		_:
			return (attacker_global + target_global) / 2.0

## Plays `data` for a caster, anchored between it and a spot (see effect_position) and shared
## with every peer. `at_global` is the top-left pixel of the target tile.
static func play_between(caster_global: Vector2, at_global: Vector2, data: Dictionary) -> void:
	NetworkSync.play_effect(effect_position(caster_global, at_global, data), data, at_global - caster_global)

## An attack's opening: its `effect` picture (may be empty) plus its sound
## (CombatSounds.tag_effect), shared with every peer. An attack with neither sends nothing; one
## with a sound but no picture sends just the sound (NetworkSync._spawn_effect skips the picture).
## Its `db` is also a noise minions hear (Sound.make), from where the effect plays.
static func play_attack(caster: Node2D, at_global: Vector2, attack: Dictionary, effect: Dictionary) -> void:
	var tagged := CombatSounds.tag_effect(caster, attack, effect)
	if tagged["db"] > 0.0:
		NetworkSync.report_noise(effect_position(caster.global_position, at_global, tagged), tagged["db"])
	if effect.is_empty() and tagged["sound"] == "":
		return
	play_between(caster.global_position, at_global, tagged)

## direction points from attacker to target. The art is drawn attacking
## left-to-right (attacker on the left, swinging right), so that's the
## rotation/flip baseline: right needs neither, left is the same swing
## mirrored, and up/down are that same rightward swing rotated 90 degrees
## instead of separate art. Bucketed to the nearest of the 4 cardinal cases,
## same as DirectionalAnimator's own facing logic.
func play(data: Dictionary, direction: Vector2 = Vector2.RIGHT) -> void:
	var one_shot: Dictionary = data.duplicate()
	one_shot["loop"] = false
	sprite.sprite_frames = SpriteFramesLoader.build({
		"frame_size": [16, 16],
		"animations": {"Play": one_shot},
	})
	sprite.animation_finished.connect(queue_free)
	if abs(direction.x) >= abs(direction.y):
		sprite.flip_h = direction.x < 0
		sprite.rotation = 0.0
	else:
		sprite.flip_h = false
		sprite.rotation = -PI / 2.0 if direction.y < 0 else PI / 2.0
	sprite.play("Play")

## Same instancing/positioning use as play(), but for a strip where each
## frame is a distinct static icon rather than a sequence (e.g. an alertness
## indicator: one frame per AI state) -- holds frame_index still for
## hold_seconds of wall-clock time instead of animating through frame_count
## at data's speed, then frees itself the same as a normal effect finishing.
func play_frame(data: Dictionary, frame_index: int, hold_seconds: float) -> void:
	sprite.sprite_frames = SpriteFramesLoader.build({
		"frame_size": [16, 16],
		"animations": {"Play": data},
	})
	sprite.stop()
	sprite.animation = "Play"
	sprite.frame = frame_index
	get_tree().create_timer(hold_seconds).timeout.connect(queue_free)
