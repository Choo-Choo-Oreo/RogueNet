extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2
@export var move_interval := 0.3
@export var detection_radius := 8  # in tiles
@export var attack_damage := 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stone_wall_layer: TileMapLayer = get_node("../Stone Wall")
@onready var move_timer: Timer = $MoveTimer
@onready var health: Health = $Health
@onready var health_label: Label = $HealthLabel

var is_moving := false
var grid_cell: Vector2i

func _ready() -> void:
	add_to_group("enemies")
	grid_cell = _to_cell(global_position)
	move_timer.wait_time = move_interval
	move_timer.timeout.connect(_on_move_timer_timeout)
	move_timer.start()
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)

func _to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(round(pos.x / tile_size), round(pos.y / tile_size))

func _on_died() -> void:
	queue_free()

func _on_health_changed(current: int, max_hp: int) -> void:
	health_label.text = str(current) + "/" + str(max_hp)

func _on_move_timer_timeout() -> void:
	if is_moving:
		return

	var target := _find_nearest_player_in_range()
	if target != null:
		_move_towards(target.grid_cell)
	else:
		var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		directions.shuffle()
		_move_one_tile(directions[0])

func _find_nearest_player_in_range() -> Node:
	var nearest: Node = null
	var nearest_dist := INF

	for player in get_tree().get_nodes_in_group("players"):
		var dist := Vector2(player.grid_cell - grid_cell).length()
		if dist <= detection_radius and dist < nearest_dist:
			nearest = player
			nearest_dist = dist

	return nearest

func _move_towards(target_cell: Vector2i) -> void:
	var delta := target_cell - grid_cell
	var primary := Vector2.ZERO
	var secondary := Vector2.ZERO

	if abs(delta.x) > abs(delta.y):
		primary = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
		if delta.y != 0:
			secondary = Vector2.DOWN if delta.y > 0 else Vector2.UP
	else:
		primary = Vector2.DOWN if delta.y > 0 else Vector2.UP
		if delta.x != 0:
			secondary = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT

	if _try_move_or_attack(primary):
		return

	if secondary != Vector2.ZERO:
		_try_move_or_attack(secondary)

func _try_move_or_attack(direction: Vector2) -> bool:
	var target_cell := _to_cell(global_position + direction * tile_size)
	var player := _get_player_at(target_cell)
	if player != null:
		_update_facing(direction)
		_attack(player)
		return true

	return _move_one_tile(direction)

func _get_player_at(cell: Vector2i) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.grid_cell == cell:
			return player
	return null

func _attack(player: Node) -> void:
	var player_health: Health = player.get_node("Health")
	if player_health:
		player_health.take_damage(attack_damage)

func _move_one_tile(direction: Vector2) -> bool:
	var target_global := global_position + direction * tile_size
	var target_cell := _to_cell(target_global)
	_update_facing(direction)

	if _is_blocked(target_global, target_cell):
		sprite.stop()
		sprite.frame = 0
		return false

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
	return true

func _is_blocked(target_global: Vector2, target_cell: Vector2i) -> bool:
	var cell: Vector2i = stone_wall_layer.local_to_map(stone_wall_layer.to_local(target_global))
	var tile_data := stone_wall_layer.get_cell_tile_data(cell)
	if tile_data != null and tile_data.get_custom_data("solid"):
		return true

	for player in get_tree().get_nodes_in_group("players"):
		if player.grid_cell == target_cell:
			return true

	return false

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
