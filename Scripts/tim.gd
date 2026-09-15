extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.12

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stone_wall_layer: TileMapLayer = get_node("../Stone Wall")

var is_moving := false
var step_frame := 0

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return

	var direction := Vector2.ZERO
	if event.is_action_pressed("ui_right"):
		direction = Vector2.RIGHT
	elif event.is_action_pressed("ui_left"):
		direction = Vector2.LEFT
	elif event.is_action_pressed("ui_up"):
		direction = Vector2.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2.DOWN

	if direction != Vector2.ZERO:
		_move_one_tile(direction)

func _move_one_tile(direction: Vector2) -> void:
	var target_global := global_position + direction * tile_size
	_update_facing(direction)

	if _is_blocked(target_global):
		return

	is_moving = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global, move_time)
	tween.finished.connect(func(): is_moving = false)

func _is_blocked(target_global: Vector2) -> bool:
	var cell: Vector2i = stone_wall_layer.local_to_map(stone_wall_layer.to_local(target_global))
	var tile_data := stone_wall_layer.get_cell_tile_data(cell)
	return tile_data != null and tile_data.get_custom_data("solid")

func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.LEFT:
		sprite.animation = "side"
		sprite.flip_h = true
	elif direction == Vector2.RIGHT:
		sprite.animation = "side"
		sprite.flip_h = false
	elif direction == Vector2.DOWN:
		sprite.animation = "front"
		sprite.flip_h = false
	elif direction == Vector2.UP:
		sprite.animation = "front"
		sprite.flip_h = false

	step_frame = 1 - step_frame
	sprite.frame = step_frame
