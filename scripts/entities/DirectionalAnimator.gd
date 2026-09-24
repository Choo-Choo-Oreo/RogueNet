class_name DirectionalAnimator
extends Node

## Picks the Front/Back/Side animation (plus the diagonal FrontRight/BackRight
## ones, when a sprite has them) from a movement direction, snapped to the
## nearest of 8 directions. Shared by anything with directional sprite animations --
## players, antagonist, enemies. Two ways to drive it: animate_moving()/
## animate_idle() when the caller already knows its own movement intent
## (the locally-controlled body), or animate_from_position() to infer
## facing from observed position changes (a remote peer's body).

@export var sprite_path: NodePath = ^"../AnimatedSprite2D"
@onready var sprite: AnimatedSprite2D = get_node(sprite_path)

var _last_anim_position := Vector2.ZERO
var _anim_idle_time := 0.0

const IDLE_TIMEOUT := 0.15
const IDLE_DISTANCE := 0.5

## Flying enemies (bat, hamster_flying, hamster_demonic) hover rather than
## stand, so their wings shouldn't ever freeze on a mid-flap frame the way a
## grounded idle does -- set true by EnemyController from the enemy's JSON.
var continuous_animation: bool = false

# Some characters (eg. the dwarf) have real, separately-drawn left/right art; others (eg. the
# knight) have one side image that gets mirrored. Play whichever the current sprite_frames provides.
func _play_side(is_left: bool) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames.has_animation("SideLeft") and frames.has_animation("SideRight"):
		sprite.flip_h = false
		sprite.play("SideLeft" if is_left else "SideRight")
	else:
		sprite.flip_h = is_left
		sprite.play("Side")

func _play_straight(anim: String) -> void:
	# Front/Back art is drawn facing one way; don't let a flip left over from
	# walking left mirror it (it would swap which hand holds what).
	sprite.flip_h = false
	sprite.play(anim)

# Diagonals: `vertical` is "Front" (moving down) or "Back" (moving up). Uses
# FrontLeft/FrontRight (or BackLeft/BackRight) when drawn, mirrors the other
# one when only one side is drawn (the human only has the right-facing art),
# and falls back to the plain side animation for sprites with no diagonal art
# at all (most creatures).
func _play_diagonal(vertical: String, is_left: bool) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	var own := vertical + ("Left" if is_left else "Right")
	var mirrored := vertical + ("Right" if is_left else "Left")
	if frames.has_animation(own):
		sprite.flip_h = false
		sprite.play(own)
	elif frames.has_animation(mirrored):
		sprite.flip_h = true
		sprite.play(mirrored)
	else:
		_play_side(is_left)

func animate_idle() -> void:
	if continuous_animation:
		return
	sprite.stop()

func animate_moving(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	# Nearest of 8 directions, counting clockwise from right: 0 right, 1 down-right,
	# 2 down, 3 down-left, 4 left, 5 up-left, 6 up, 7 up-right (y points down).
	var octant := int(round(fposmod(direction.angle(), TAU) / (PI / 4.0))) % 8
	match octant:
		0: _play_side(false)
		1: _play_diagonal("Front", false)
		2: _play_straight("Front")
		3: _play_diagonal("Front", true)
		4: _play_side(true)
		5: _play_diagonal("Back", true)
		6: _play_straight("Back")
		7: _play_diagonal("Back", false)

## Same direction picking as animate_moving(), but held on one frame instead
## of looping the walk cycle -- for facing a target while stationary (e.g. an
## enemy that's stopped adjacent to its target). continuous_animation skips
## the hold, same reasoning as animate_idle().
func animate_facing(direction: Vector2) -> void:
	animate_moving(direction)
	if not continuous_animation:
		sprite.stop()

func animate_from_position(delta: float, current_position: Vector2) -> void:
	var delta_pos := current_position - _last_anim_position
	_last_anim_position = current_position
	if delta_pos.length() < IDLE_DISTANCE:
		_anim_idle_time += delta
		if _anim_idle_time > IDLE_TIMEOUT:
			animate_idle()
		return
	_anim_idle_time = 0.0
	animate_moving(delta_pos)
