class_name EnemyController
extends CharacterBody2D

## Generic AI-driven body -- wanders its spawn point for now. Real behavior
## (aggro, attacking) comes later once the antagonist/boss shape is settled.

@onready var grid_mover: GridMover = $GridMover
@onready var animator: DirectionalAnimator = $DirectionalAnimator

@export var wander_radius_tiles: int = 3
@export var wander_interval := 1.4

var _home_position: Vector2 = Vector2.ZERO
var _wander_timer := 0.0

func _ready() -> void:
	_home_position = global_position

func _process(delta: float) -> void:
	if grid_mover.is_moving:
		animator.animate_moving(grid_mover.facing_direction)
	else:
		animator.animate_idle()
	_wander_timer += delta
	if _wander_timer < wander_interval or grid_mover.is_moving:
		return
	_wander_timer = 0.0
	_try_wander_step()

const MOVE_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

func _try_wander_step() -> void:
	var direction: Vector2 = MOVE_DIRECTIONS.pick_random()
	var target := global_position + direction * grid_mover.tile_size
	if target.distance_to(_home_position) > wander_radius_tiles * grid_mover.tile_size:
		return
	grid_mover.move_one_tile(direction)
