extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2
@export var move_interval := 1.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stone_wall_layer: TileMapLayer = get_node("../Stone Wall")
@onready var move_timer: Timer = $MoveTimer
@onready var health: Health = $Health

var is_moving := false

func _ready() -> void:
	move_timer.wait_time = move_interval
	move_timer.timeout.connect(_on_move_timer_timeout)
	move_timer.start()
	health.died.connect(_on_died)

func _on_died() -> void:
	queue_free()

func _on_move_timer_timeout() -> void:
	if is_moving:
		return
	var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	directions.shuffle()
	_move_one_tile(directions[0])

func _move_one_tile(direction: Vector2) -> void:
	var target_global := global_position + direction * tile_size
	_update_facing(direction)

	if _is_blocked(target_global):
		sprite.stop()
		sprite.frame = 0
		return

	is_moving = true
	sprite.play()

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global, move_time)
	tween.finished.connect(func():
		is_moving = false
		sprite.stop()
		sprite.frame = 0
	)

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
	elif direction == Vector2.DOWN or direction == Vector2.UP:
		sprite.animation = "front"
		sprite.flip_h = false
