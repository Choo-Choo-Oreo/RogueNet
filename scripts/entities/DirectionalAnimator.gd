class_name DirectionalAnimator
extends Node

## Picks the Front/Back/Side animation (plus the diagonal FrontRight/BackRight
## ones, when a sprite has them) from a movement direction, snapped to the
## nearest of 8 directions. Shared by anything with directional sprite animations --
## players, antagonist, minions. Two ways to drive it: animate_moving()/
## animate_idle() when the caller already knows its own movement intent
## (the locally-controlled body), or animate_from_position() to infer
## facing from observed position changes (a remote peer's body).
##
## It also poses the body without new frames, by moving the whole sprite in whole
## pixels at 10 fps, so worn gear (GearLayers, which copies the offset) follows:
## - play_attack(): pull back 1px, lunge 2px toward the target, recover (0.4 s).
## - play_death(): topple sideways, lie flat in its own tile, fade (1.7 s). A body
##   that is freed on death (a minion) hands its sprite to leave_corpse() instead.
## - idle life, from the sprite JSON's "idle" block (set_idle_life): "breath" sinks
##   the body 1px for half of every 3 s, "blink" shows an eyelid sheet (one 16x16
##   cell per listed animation) for 0.2 s of every 3 s.
## Getting hurt is HitFeedback's (flash and jolt), not this.

@export var sprite_path: NodePath = ^"../AnimatedSprite2D"
@onready var sprite: AnimatedSprite2D = get_node(sprite_path)

var _last_anim_position := Vector2.ZERO
var _anim_idle_time := 0.0

const IDLE_TIMEOUT := 0.15
const IDLE_DISTANCE := 0.5

## Flying minions (bat, hamster_flying, hamster_demonic) hover rather than
## stand, so their wings shouldn't ever freeze on a mid-flap frame the way a
## grounded idle does -- set true by MinionController from the minion's JSON.
var continuous_animation: bool = false

signal pose_finished

## One step of a pose is this long (the house style's 10 fps).
const STEP := 0.1
## The attack's steps, in pixels toward the target.
const ATTACK_STEPS := [-1, 2, 2, 1]
const IDLE_LOOP := 3.0
const BREATH_FROM := 1.5
const BLINK_FROM := 2.2
const BLINK_TO := 2.4

var _pose: Array = []   # steps of [offset, degrees, alpha]
var _pose_time := 0.0
var _idle := false
var _idle_time := 0.0
var _breath := false
var _blink: Sprite2D = null
var _blink_columns: Array = []

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
	_idle = true

func animate_moving(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_idle = false
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
## minion that's stopped adjacent to its target). continuous_animation skips
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

## The sprite JSON's "idle" block ({} turns idle life off).
func set_idle_life(idle: Dictionary) -> void:
	_breath = idle.get("breath", false)
	var blink: Dictionary = idle.get("blink", {})
	_blink_columns = blink.get("animations", [])
	if blink.has("texture"):
		if _blink == null:
			_blink = Sprite2D.new()
			_blink.name = "Blink"
			_blink.visible = false
			sprite.add_child(_blink)
		_blink.texture = load(blink["texture"])
		_blink.hframes = _blink_columns.size()
	elif _blink != null:
		_blink.queue_free()
		_blink = null

## direction: toward the target. The lunge snaps to the nearest of the 8 directions.
func play_attack(direction: Vector2) -> void:
	var forward := Vector2(signf(roundf(direction.normalized().x)), signf(roundf(direction.normalized().y)))
	_pose = ATTACK_STEPS.map(func(px): return [forward * px, 0.0, 1.0])
	_pose_time = 0.0

## Topples the way the body faces (right unless flipped). Waits out HitFeedback's jolt
## first. Ends faded out; pose_finished fires, then reset_pose() puts the body back.
func play_death() -> void:
	var side := -1.0 if sprite.flip_h else 1.0
	_pose = [[Vector2.ZERO, 0.0, 1.0], [Vector2.ZERO, 0.0, 1.0], [Vector2.ZERO, 45.0 * side, 1.0]]
	for i in 10:
		_pose.append([Vector2.ZERO, 90.0 * side, 1.0])
	for alpha in [0.75, 0.5, 0.25, 0.0]:
		_pose.append([Vector2.ZERO, 90.0 * side, alpha])
	_pose_time = 0.0

## Plays the death topple on a body that is about to be freed: the sprite moves to a
## short-lived "Corpse" node beside the body (same place, same z) which plays it and
## then frees itself. The body goes at once as before, so nothing can hit, target or
## count a dead one. Cosmetic only; every peer frees its own copy of the body.
static func leave_corpse(body: Node2D, body_sprite: AnimatedSprite2D) -> void:
	var parent := body.get_parent()
	if parent == null or not body.is_inside_tree():
		return
	# the body is only freed at the end of the frame; until then it must not touch the sprite
	body.process_mode = Node.PROCESS_MODE_DISABLED
	var corpse := Node2D.new()
	corpse.name = "Corpse"
	corpse.z_index = body.z_index
	corpse.z_as_relative = body.z_as_relative
	parent.add_child(corpse)
	corpse.global_position = body.global_position
	body_sprite.reparent(corpse)
	body_sprite.stop()
	body_sprite.speed_scale = 1.0
	var animator := DirectionalAnimator.new()
	animator.sprite_path = NodePath("../" + String(body_sprite.name))
	corpse.add_child(animator)
	animator.play_death()
	animator.pose_finished.connect(corpse.queue_free)
	# HitFeedback went with the body mid-flash: finish the flash here.
	corpse.get_tree().create_timer(HitFeedback.WHITE_SECONDS + HitFeedback.RED_SECONDS).timeout.connect(func():
		if is_instance_valid(body_sprite):
			body_sprite.modulate = Color(1, 1, 1, body_sprite.modulate.a))

func reset_pose() -> void:
	_pose = []
	_apply(Vector2.ZERO, 0.0, 1.0)

func _process(delta: float) -> void:
	if not _pose.is_empty():
		_pose_time += delta
		var i := int(_pose_time / STEP)
		if i < _pose.size():
			_apply(_pose[i][0], _pose[i][1], _pose[i][2])
			_show_blink(false)
			return
		var last: Array = _pose.back()
		_pose = []
		# a death stays down until reset_pose(); an attack springs back
		if last[1] == 0.0:
			_apply(Vector2.ZERO, 0.0, 1.0)
		pose_finished.emit()
		return
	if sprite.rotation != 0.0 or (not _breath and _blink == null):
		return
	_idle_time = fmod(_idle_time + delta, IDLE_LOOP) if _idle else 0.0
	sprite.offset = Vector2(0, 1) if _breath and _idle and _idle_time >= BREATH_FROM else Vector2.ZERO
	_show_blink(_idle and _idle_time >= BLINK_FROM and _idle_time < BLINK_TO)

# Starts turning about the feet (the bottom middle of the frame), and the pivot slides up
# to the middle as it goes, so a body lying flat stays inside its own tile.
func _apply(offset: Vector2, degrees: float, alpha: float) -> void:
	var feet := Vector2(0, _frame_height() / 2.0) * (1.0 - absf(degrees) / 90.0)
	sprite.rotation = deg_to_rad(degrees)
	sprite.offset = offset.rotated(-sprite.rotation) + feet.rotated(-sprite.rotation) - feet
	sprite.modulate.a = alpha

func _show_blink(on: bool) -> void:
	if _blink == null:
		return
	var column := _blink_columns.find(String(sprite.animation))
	_blink.visible = on and column >= 0
	if _blink.visible:
		_blink.frame = column
		_blink.flip_h = sprite.flip_h
		_blink.offset = sprite.offset

func _frame_height() -> float:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation):
		return 16.0
	var texture := frames.get_frame_texture(sprite.animation, sprite.frame)
	return texture.get_size().y if texture else 16.0
