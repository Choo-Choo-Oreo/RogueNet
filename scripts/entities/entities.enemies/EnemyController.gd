class_name EnemyController
extends CharacterBody2D

## Generic AI-driven body -- wanders its spawn point for now. Real behavior
## (aggro, attacking) comes later once the antagonist/boss shape is settled.

@onready var grid_mover: GridMover = $GridMover
@onready var animator: DirectionalAnimator = $DirectionalAnimator
@onready var stats: EntityStats = $EntityStats
@onready var senses: EnemySenses = $EnemySenses

@export var wander_radius_tiles: int = 3
@export var wander_interval := 1.4

## Lets a hand-placed instance (or, later, a spawner) configure itself without
## an external script call. Empty means "leave unconfigured."
@export var default_enemy_type: String = ""

var _home_position: Vector2 = Vector2.ZERO
var _wander_timer := 0.0
var _target: Node2D = null

var _attack_amount: int = 0
var _attack_type: String = ""
var _attack_interval: float = 1.0
var _attack_effect: Dictionary = {}
var _attack_timer := 0.0

const ATTACK_EFFECT_SCENE := preload("res://scenes/entities/AttackEffect.tscn")

const ENEMY_TYPES := {
	"rat": "res://game/entities/entities.enemies/rat.json",
	"rat_blind": "res://game/entities/entities.enemies/rat_blind.json",
}

func set_enemy_type(enemy_id: String) -> void:
	var data := JsonOnloading.load_dict(ENEMY_TYPES[enemy_id])
	stats.load_from_data(data)
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])
	var size_px: float = data.get("size_tiles", 1) * grid_mover.tile_size
	($CollisionShape2D.shape as RectangleShape2D).size = Vector2(size_px, size_px)
	$HealthPixelBar.position = Vector2(size_px / 2.0, size_px + 2.0)
	$HealthPixelBar.setup(stats, 32 if size_px > grid_mover.tile_size else 16)
	senses.apply_overrides(data.get("senses", {}))
	var attack_data: Dictionary = data.get("attack", {})
	_attack_amount = attack_data.get("amount", 0)
	_attack_type = attack_data.get("type", "")
	_attack_interval = attack_data.get("interval", 1.0)
	_attack_effect = attack_data.get("effect", {})

func take_damage(amount: int, type: String = "") -> void:
	stats.take_damage(amount, type)

func _ready() -> void:
	add_to_group("antagonist")
	if default_enemy_type != "":
		set_enemy_type(default_enemy_type)
	_home_position = global_position
	stats.died.connect(queue_free)

func _process(delta: float) -> void:
	var adjacent_target := (
		senses.state == EnemySenses.State.ATTACK
		and _target
		and _is_adjacent(_target)
	)
	if grid_mover.is_moving:
		animator.animate_moving(grid_mover.facing_direction)
	elif senses.state == EnemySenses.State.ATTACK and _target:
		animator.animate_facing(_target.global_position - global_position)
	else:
		animator.animate_idle()
	if adjacent_target:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = _attack_interval
			_perform_attack(_target)
	else:
		_attack_timer = 0.0
	_wander_timer += delta
	if _wander_timer < wander_interval or grid_mover.is_moving:
		return
	_wander_timer = 0.0
	_try_step()

func _perform_attack(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(_attack_amount, _attack_type)
	if _attack_effect.is_empty():
		return
	var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = AttackEffect.effect_position(global_position, target.global_position, _attack_effect)
	effect.play(_attack_effect, target.global_position - global_position)

func _try_step() -> void:
	_target = _nearest_player()
	var state := senses.update(global_position, _target, grid_mover.is_tile_blocked, wander_interval)
	if state == EnemySenses.State.ATTACK:
		_try_pursue_step(_target)
	else:
		_try_wander_step()

## Greedy step toward the target -- not real pathfinding, so a straight wall
## with no way around it still stops the enemy cold. This only covers the
## simple case: if the preferred axis is blocked, try the other one instead
## of just standing there (e.g. blocked going right, try down/up).
func _try_pursue_step(target: Node2D) -> void:
	if _is_adjacent(target):
		return
	var offset := target.global_position - global_position
	var horizontal := Vector2.RIGHT if offset.x > 0 else Vector2.LEFT
	var vertical := Vector2.DOWN if offset.y > 0 else Vector2.UP
	var primary := vertical if abs(offset.y) > abs(offset.x) else horizontal
	var secondary := horizontal if primary == vertical else vertical
	if not _try_move(primary) and offset.x != 0 and offset.y != 0:
		_try_move(secondary)

## Tile-grid (Chebyshev) adjacency -- true for all 8 surrounding tiles, not
## just the 4 orthogonal ones a raw Euclidean distance<=tile_size check would
## give (a diagonal neighbor is tile_size*sqrt(2) away). Both entities are
## always grid-aligned when idle, so this offset divides evenly.
func _is_adjacent(target: Node2D) -> bool:
	var offset := Vector2i((target.global_position - global_position) / grid_mover.tile_size)
	return absi(offset.x) <= 1 and absi(offset.y) <= 1

func _try_move(direction: Vector2) -> bool:
	var target_tile := Vector2i((global_position + direction * grid_mover.tile_size) / grid_mover.tile_size)
	if grid_mover.is_tile_blocked(target_tile):
		return false
	grid_mover.move_one_tile(direction)
	return true

func _nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for player in get_tree().get_nodes_in_group("protagonist"):
		if player.stats.is_ghost:
			continue
		var dist: float = global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest = player
			nearest_dist = dist
	return nearest

const MOVE_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

func _try_wander_step() -> void:
	var direction: Vector2 = MOVE_DIRECTIONS.pick_random()
	var target := global_position + direction * grid_mover.tile_size
	if target.distance_to(_home_position) > wander_radius_tiles * grid_mover.tile_size:
		return
	grid_mover.move_one_tile(direction)
