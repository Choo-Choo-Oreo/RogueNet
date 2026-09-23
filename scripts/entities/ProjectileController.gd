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
var _is_blocked: Callable
var _on_arrival: Callable

## is_blocked mirrors GridMover.is_position_blocked (pixel space, not a tile
## index -- the projectile's position is fractional almost every frame) -- a
## wall (or void) between launch and target stops the projectile there
## instead of letting it fly through, and on_arrival is never called, so no
## damage/hit-effect lands.
func launch(texture_path: String, to: Vector2, tile_size: float, on_arrival: Callable, is_blocked: Callable) -> void:
	_sprite.texture = load(texture_path)
	_target = to
	_speed = TILES_PER_SECOND * tile_size
	_is_blocked = is_blocked
	_on_arrival = on_arrival
	rotation = (to - global_position).angle()

func _process(delta: float) -> void:
	# _is_blocked is bound to the shooter's own GridMover -- if the shooter
	# died mid-flight (e.g. a point-blank shot that also got it killed), that
	# node is gone and the callable goes stale. Same for on_arrival's target
	# lookup, so just vanish rather than trying to resolve either one.
	if not _is_blocked.is_valid():
		queue_free()
		return
	var to_target := _target - global_position
	var step := _speed * delta
	var arrived := to_target.length() <= step
	var next_position: Vector2 = _target if arrived else global_position + to_target.normalized() * step
	if _is_blocked.call(next_position):
		queue_free()
		return
	global_position = next_position
	if arrived:
		_on_arrival.call()
		queue_free()
