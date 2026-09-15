extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2
@export var attack_damage := 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stone_wall_layer: TileMapLayer = get_node("../Stone Wall")
@onready var health: Health = $Health

var is_moving := false
var facing_direction := Vector2.DOWN
var grid_cell: Vector2i

func _ready() -> void:
	add_to_group("players")
	grid_cell = _to_cell(global_position)

func _to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(round(pos.x / tile_size), round(pos.y / tile_size))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_attack()

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
	var target_cell := _to_cell(target_global)
	_update_facing(direction)

	if _is_blocked(target_global, target_cell):
		sprite.stop()
		sprite.frame = 0
		return

	grid_cell = target_cell
	is_moving = true
	sprite.play()

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global, move_time)
	tween.finished.connect(func():
		is_moving = false
		sprite.stop()
		sprite.frame = 0
	)

func _is_blocked(target_global: Vector2, target_cell: Vector2i) -> bool:
	var cell: Vector2i = stone_wall_layer.local_to_map(stone_wall_layer.to_local(target_global))
	var tile_data := stone_wall_layer.get_cell_tile_data(cell)
	if tile_data != null and tile_data.get_custom_data("solid"):
		return true

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.grid_cell == target_cell:
			return true

	return false

func _update_facing(direction: Vector2) -> void:
	facing_direction = direction

	if direction == Vector2.LEFT:
		sprite.animation = "Side"
		sprite.flip_h = true
	elif direction == Vector2.RIGHT:
		sprite.animation = "Side"
		sprite.flip_h = false
	elif direction == Vector2.DOWN:
		sprite.animation = "Front"
		sprite.flip_h = false
	elif direction == Vector2.UP:
		sprite.animation = "Back"
		sprite.flip_h = false

func _attack() -> void:
	var target_global := global_position + facing_direction * tile_size
	var target_cell := _to_cell(target_global)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.grid_cell == target_cell:
			var enemy_health: Health = enemy.get_node("Health")
			if enemy_health:
				enemy_health.take_damage(attack_damage)
