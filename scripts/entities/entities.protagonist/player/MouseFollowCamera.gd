class_name MouseFollowCamera
extends Camera2D

## Nudges the camera toward the mouse, capped to a max offset. Shared by any
## locally-controlled body with an on-screen camera -- players, and antagonist
## when a human opts to play that role (bot-controlled antagonist has no camera).
## Relies on multiplayer authority being set (with the default recursive=true)
## on an ancestor, so this node inherits it.

@export var mouse_weight := 0.3
@export var max_offset := 96.0
## Free cam pan speed, in screen pixels per second.
@export var free_cam_speed := 1200.0

var _normal_zoom := Vector2.ONE

func _process(delta: float) -> void:
	# Checked every frame, not just in _ready(): a Node's _ready() fires before
	# its parent's, so at _ready() time the parent hasn't set the real
	# multiplayer authority yet -- this would always read the default (1).
	enabled = is_multiplayer_authority()
	if not enabled:
		return
	if DebugState.free_cam != top_level:
		_set_free(DebugState.free_cam)
	if top_level:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# Divided by zoom so the pan feels the same speed at any zoom level.
		global_position += dir * free_cam_speed * delta / zoom.x
		return
	var owner_global: Vector2 = get_parent().global_position
	# The aim point: the mouse, or the left stick on a controller (PlayerController.aim_position).
	var parent := get_parent()
	var mouse_world: Vector2 = parent.aim_position() if parent.has_method("aim_position") else get_global_mouse_position()
	var to_mouse := (mouse_world - owner_global) * mouse_weight
	if to_mouse.length() > max_offset:
		to_mouse = to_mouse.normalized() * max_offset
	position = to_mouse

## top_level = true cuts the camera loose from the player: it keeps its world
## position and stops moving with its parent. Turning it back off snaps home.
func _set_free(on: bool) -> void:
	var here := global_position
	top_level = on
	if on:
		global_position = here
		_normal_zoom = zoom
	else:
		zoom = _normal_zoom

## Mouse wheel zooms, only while free.
func _unhandled_input(event: InputEvent) -> void:
	if not (top_level and event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom = (zoom * 1.1).clamp(Vector2.ONE, Vector2(12, 12))
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom = (zoom / 1.1).clamp(Vector2.ONE, Vector2(12, 12))
