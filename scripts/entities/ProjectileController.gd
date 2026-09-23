class_name ProjectileController
extends Node2D

## A visible projectile (e.g. an arrow) that flies in a straight line from
## its spawn position to a target position at a constant speed, then fires
## a callback and frees itself. Rotates to face its travel direction --
## assumes the art is drawn pointing right, same baseline as AttackEffect.

const TILES_PER_SECOND := 10.0

@onready var _sprite: Sprite2D = $Sprite2D

var _target: Vector2
var _speed: float
var _on_arrival: Callable

func launch(texture_path: String, to: Vector2, tile_size: float, on_arrival: Callable) -> void:
	_sprite.texture = load(texture_path)
	_target = to
	_speed = TILES_PER_SECOND * tile_size
	_on_arrival = on_arrival
	rotation = (to - global_position).angle()

func _process(delta: float) -> void:
	var to_target := _target - global_position
	var step := _speed * delta
	if to_target.length() <= step:
		global_position = _target
		_on_arrival.call()
		queue_free()
		return
	global_position += to_target.normalized() * step
