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
## Index into GameView.ZOOM_LEVELS while free; _normal_level is the usual view (1.0).
var _normal_level := GameView.ZOOM_LEVELS.find(1.0)
var _level := _normal_level

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
		# Divided by the zoom so the pan feels the same speed at any zoom level.
		global_position += dir * free_cam_speed * delta / (_normal_zoom.x * GameView.ZOOM_LEVELS[_level])
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
		set_zoom_level(_normal_level)

## Mouse wheel steps through GameView.ZOOM_LEVELS, only while free, stopping at the ends.
func _unhandled_input(event: InputEvent) -> void:
	if not (top_level and event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_zoom_level(_level + 1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_zoom_level(_level - 1)

## Zooming in is the camera's zoom (2x, 4x); zooming out is GameView.set_view_scale (more world at
## fewer UI pixels per art pixel), since a camera zoom below 1 drops art pixels.
func set_zoom_level(index: int) -> void:
	_level = clampi(index, 0, GameView.ZOOM_LEVELS.size() - 1)
	var level: float = GameView.ZOOM_LEVELS[_level]
	zoom = _normal_zoom * maxf(level, 1.0)
	var view := GameView.of(self)
	if view:
		view.set_view_scale(roundi(1.0 / minf(level, 1.0)))
