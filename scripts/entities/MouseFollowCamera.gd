class_name MouseFollowCamera
extends Camera2D

## Nudges the camera toward the mouse, capped to a max offset. Shared by any
## locally-controlled body with an on-screen camera -- players, and antagonist
## when a human opts to play that role (bot-controlled antagonist has no camera).
## Relies on multiplayer authority being set (with the default recursive=true)
## on an ancestor, so this node inherits it.

@export var mouse_weight := 0.3
@export var max_offset := 96.0

func _process(_delta: float) -> void:
	# Checked every frame, not just in _ready(): a Node's _ready() fires before
	# its parent's, so at _ready() time the parent hasn't set the real
	# multiplayer authority yet -- this would always read the default (1).
	enabled = is_multiplayer_authority()
	if not enabled:
		return
	var owner_global: Vector2 = get_parent().global_position
	var mouse_world := get_global_mouse_position()
	var to_mouse := (mouse_world - owner_global) * mouse_weight
	if to_mouse.length() > max_offset:
		to_mouse = to_mouse.normalized() * max_offset
	position = to_mouse
