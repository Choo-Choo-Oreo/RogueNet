extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2

@onready var wall_data: TileMapLayer = get_tree().current_scene.find_child("WallData", true, false)

## An open connector is painted onto WallData like any other wall cell (see
## DungeonPainter.gd), so it needs to be excluded here by source_id or an
## open doorway would block movement exactly like a solid wall.
@onready var _open_door_source_id: int = load("res://resources/tiles/tile_type_registry.tres").get_id("wall_door_open")

@export var camera_mouse_weight := 0.3
@export var camera_max_offset := 96.0

var _last_anim_position := Vector2.ZERO
var _facing_direction := Vector2.DOWN
var _anim_idle_time := 0.0

func _process(delta: float) -> void:
	_update_facing_animation(delta)
	if not is_multiplayer_authority():
		return
	if multiplayer.is_server():
		NetworkSync._relay_position(1, global_position)
	else:
		NetworkSync.report_position.rpc_id(1, global_position)
	var mouse_world := get_global_mouse_position()
	var to_mouse := (mouse_world - global_position) * camera_mouse_weight
	if to_mouse.length() > camera_max_offset:
		to_mouse = to_mouse.normalized() * camera_max_offset
	$Camera2D.position = to_mouse

func _update_facing_animation(delta: float) -> void:
	if is_multiplayer_authority():
		if not is_moving:
			$AnimatedSprite2D.stop()
			return
		if abs(_facing_direction.x) > abs(_facing_direction.y):
			$AnimatedSprite2D.play("Side")
			$AnimatedSprite2D.flip_h = _facing_direction.x < 0
		else:
			$AnimatedSprite2D.play("Back" if _facing_direction.y < 0 else "Front")
		return
	var delta_pos := global_position - _last_anim_position
	_last_anim_position = global_position
	if delta_pos.length() < 0.5:
		_anim_idle_time += delta
		if _anim_idle_time > 0.15:
			$AnimatedSprite2D.stop()
		return
	_anim_idle_time = 0.0
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
	if wall_data == null:
		return false
	var cell: Vector2i = wall_data.local_to_map(wall_data.to_local(target_global))
	var source_id := wall_data.get_cell_source_id(cell)
	return source_id != -1 and source_id != _open_door_source_id

var is_moving := false

func _move_one_tile(direction: Vector2) -> void:
	var target_global := global_position + direction * tile_size
	if _is_blocked(target_global):
		return
	_facing_direction = direction
	is_moving = true

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global, move_time)
	tween.finished.connect(func(): is_moving = false)

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
