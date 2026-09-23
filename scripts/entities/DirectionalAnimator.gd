class_name DirectionalAnimator
extends Node

## Picks the North/South/SideLeft/SideRight animation from a movement
## direction. Shared by anything with directional sprite animations --
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

func animate_idle() -> void:
	sprite.stop()

func animate_moving(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		_play_side(direction.x < 0)
	else:
		sprite.play("Back" if direction.y < 0 else "Front")

## Same direction picking as animate_moving(), but held on one frame instead
## of looping the walk cycle -- for facing a target while stationary (e.g. an
## enemy that's stopped adjacent to its target).
func animate_facing(direction: Vector2) -> void:
	animate_moving(direction)
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
