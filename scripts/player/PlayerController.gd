extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2

@onready var wall_data: TileMapLayer = get_tree().current_scene.get_node("WallData")

@export var camera_mouse_weight := 0.3
@export var camera_max_offset := 96.0

var _last_anim_position := Vector2.ZERO

func _process(_delta: float) -> void:
	_update_facing_animation()
	if not is_multiplayer_authority():
		return
	var mouse_world := get_global_mouse_position()
	var to_mouse := (mouse_world - global_position) * camera_mouse_weight
	if to_mouse.length() > camera_max_offset:
		to_mouse = to_mouse.normalized() * camera_max_offset
	$Camera2D.position = to_mouse

func _update_facing_animation() -> void:
	var delta_pos := global_position - _last_anim_position
	_last_anim_position = global_position
	if delta_pos.length() < 0.5:
		$AnimatedSprite2D.stop()
		return
	if abs(delta_pos.x) > abs(delta_pos.y):
		$AnimatedSprite2D.play("Side")
		$AnimatedSprite2D.flip_h = delta_pos.x < 0
	else:
		$AnimatedSprite2D.play("Back" if delta_pos.y < 0 else "Front")

func _ready() -> void:
	set_multiplayer_authority(int(str(name)))
	if is_multiplayer_authority():
		$Camera2D.enabled = true

func _is_blocked(target_global: Vector2) -> bool:
	var cell: Vector2i = wall_data.local_to_map(wall_data.to_local(target_global))
	return wall_data.get_cell_source_id(cell) != -1

var is_moving := false

func _move_one_tile(direction: Vector2) -> void:
	var target_global := global_position + direction * tile_size
	if _is_blocked(target_global):
		return
	is_moving = true

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global, move_time)
	tween.finished.connect(func(): is_moving = false)

	if direction == Vector2.UP:
		$AnimatedSprite2D.play("Back")
	elif direction == Vector2.DOWN:
		$AnimatedSprite2D.play("Front")
	else:
		$AnimatedSprite2D.play("Side")
		$AnimatedSprite2D.flip_h = direction == Vector2.LEFT

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if is_moving:
		return
	var direction := Vector2.ZERO
	if event.is_action_pressed("ui_right"): direction = Vector2.RIGHT
	elif event.is_action_pressed("ui_left"): direction = Vector2.LEFT
	elif event.is_action_pressed("ui_up"): direction = Vector2.UP
	elif event.is_action_pressed("ui_down"): direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		_move_one_tile(direction)

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_moving:
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): direction = Vector2.RIGHT
	elif Input.is_action_pressed("ui_left"): direction = Vector2.LEFT
	elif Input.is_action_pressed("ui_up"): direction = Vector2.UP
	elif Input.is_action_pressed("ui_down"): direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		_move_one_tile(direction)
		
