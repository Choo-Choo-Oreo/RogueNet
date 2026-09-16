extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2

@onready var wall_data: TileMapLayer = get_node("../WallData")

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

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return
	var direction := Vector2.ZERO
	if event.is_action_pressed("ui_right"): direction = Vector2.RIGHT
	elif event.is_action_pressed("ui_left"): direction = Vector2.LEFT
	elif event.is_action_pressed("ui_up"): direction = Vector2.UP
	elif event.is_action_pressed("ui_down"): direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		_move_one_tile(direction)
