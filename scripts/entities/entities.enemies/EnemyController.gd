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
var _was_alert := false
var _size_px: float = 16.0
var _base_move_time := 0.2

var _attack_amount: int = 0
var _attack_type: String = ""
var _attack_interval: float = 1.0
var _attack_range: int = 1
var _attack_effect: Dictionary = {}
var _attack_timer := 0.0

const ATTACK_EFFECT_SCENE := preload("res://scenes/entities/AttackEffect.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/ProjectileController.tscn")
const ALERTNESS_DATA := {
	"texture": "res://resources/gfx/effects/Alertness.png",
	"frame_count": 3,
	"speed": 10.0,
}

const ENEMY_TYPES := {
	"rat": "res://game/entities/entities.enemies/rat.json",
	"rat_blind": "res://game/entities/entities.enemies/rat_blind.json",
	"bat": "res://game/entities/entities.enemies/bat.json",
	"hamster": "res://game/entities/entities.enemies/hamster.json",
	"hamster_flying": "res://game/entities/entities.enemies/hamster_flying.json",
	"hamster_demonic": "res://game/entities/entities.enemies/hamster_demonic.json",
	"wolf": "res://game/entities/entities.enemies/wolf.json",
	"skeleton_archer": "res://game/entities/entities.enemies/skeleton_archer.json",
}

func set_enemy_type(enemy_id: String) -> void:
	var data := JsonOnloading.load_dict(ENEMY_TYPES[enemy_id])
	stats.load_from_data(data)
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])
	_size_px = data.get("size_tiles", 1) * grid_mover.tile_size
	($CollisionShape2D.shape as RectangleShape2D).size = Vector2(_size_px, _size_px)
	$HealthPixelBar.position = Vector2(_size_px / 2.0, _size_px + 2.0)
	$HealthPixelBar.setup(stats, 32 if _size_px > grid_mover.tile_size else 16)
	senses.apply_overrides(data.get("senses", {}))
	grid_mover.move_time = _base_move_time / float(data.get("speed_multiplier", 1.0))
	var attack_data: Dictionary = data.get("attack", {})
	_attack_amount = attack_data.get("amount", 0)
	_attack_type = attack_data.get("type", "")
	_attack_interval = attack_data.get("interval", 1.0)
	_attack_range = attack_data.get("range_tiles", 1)
	_attack_effect = attack_data.get("effect", {})

func take_damage(amount: int, type: String = "") -> void:
	stats.take_damage(amount, type)

func _ready() -> void:
	add_to_group("antagonist")
	_base_move_time = grid_mover.move_time
	if default_enemy_type != "":
		set_enemy_type(default_enemy_type)
	_home_position = global_position
	stats.died.connect(queue_free)

func _process(delta: float) -> void:
	var can_attack := (
		senses.state == EnemySenses.State.ATTACK
		and _target
		and _in_attack_range(_target)
	)
	if grid_mover.is_moving:
		animator.animate_moving(grid_mover.facing_direction)
	elif senses.state == EnemySenses.State.ATTACK and _target:
		animator.animate_facing(_target.global_position - global_position)
	else:
		animator.animate_idle()
	if can_attack:
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
	if _attack_effect.has("attacker") or _attack_effect.has("target"):
		_perform_ranged_attack(target)
		return
	if target.has_method("take_damage"):
		target.take_damage(_attack_amount, _attack_type)
	if _attack_effect.is_empty():
		return
	var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = AttackEffect.effect_position(global_position, target.global_position, _attack_effect)
	effect.play(_attack_effect, target.global_position - global_position)

## Mirrors PlayerController's bow handling: an "attacker" shot effect plays
## here (cosmetic), a projectile travels to the target if the data has one,
## and only on arrival does the "target" hit effect play and damage land.
## A magic attack (no "projectile") skips the travel and lands immediately.
func _perform_ranged_attack(target: Node2D) -> void:
	var target_global: Vector2 = target.global_position
	var direction := target_global - global_position
	var attacker_data: Dictionary = _attack_effect.get("attacker", {})
	if not attacker_data.is_empty():
		var shot: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(shot)
		shot.global_position = AttackEffect.effect_position(global_position, target_global, attacker_data)
		shot.play(attacker_data, direction)
	var projectile_texture: String = _attack_effect.get("projectile", "")
	if projectile_texture == "":
		_land_ranged_hit(target, target_global)
		return
	var projectile: ProjectileController = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(_size_px / 2.0, _size_px / 2.0)
	projectile.launch(projectile_texture, target_global + Vector2(8, 8), grid_mover.tile_size, func():
		_land_ranged_hit(target, target_global))

func _land_ranged_hit(target: Node2D, target_global: Vector2) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(_attack_amount, _attack_type)
	var target_data: Dictionary = _attack_effect.get("target", {})
	if not target_data.is_empty():
		var hit: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(hit)
		hit.global_position = AttackEffect.effect_position(global_position, target_global, target_data)
		hit.play(target_data, target_global - global_position)

func _try_step() -> void:
	_target = _nearest_player()
	var state := senses.update(global_position, _target, grid_mover.is_tile_blocked, wander_interval)
	var is_alert := state == EnemySenses.State.ATTACK
	if is_alert and not _was_alert:
		_show_alertness()
	_was_alert = is_alert
	if state == EnemySenses.State.ATTACK:
		_try_pursue_step(_target)
	else:
		_try_wander_step()

## One-shot popup above the enemy's head the moment it first notices a
## player (Patrol -> Attack), reusing AttackEffect as a generic "play this
## animation once at a position" -- direction is irrelevant here so it's
## left at the default (no flip/rotation).
func _show_alertness() -> void:
	var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector2(_size_px / 2.0 - 8.0, -12.0)
	effect.play(ALERTNESS_DATA)

## Greedy step toward the target -- not real pathfinding, so a straight wall
## with no way around it still stops the enemy cold. This only covers the
## simple case: if the preferred axis is blocked, try the other one instead
## of just standing there (e.g. blocked going right, try down/up).
func _try_pursue_step(target: Node2D) -> void:
	if _in_attack_range(target):
		return
	var offset := target.global_position - global_position
	var horizontal := Vector2.RIGHT if offset.x > 0 else Vector2.LEFT
	var vertical := Vector2.DOWN if offset.y > 0 else Vector2.UP
	var primary := vertical if abs(offset.y) > abs(offset.x) else horizontal
	var secondary := horizontal if primary == vertical else vertical
	if not _try_move(primary) and offset.x != 0 and offset.y != 0:
		_try_move(secondary)

## Tile-grid (Chebyshev) distance check against _attack_range -- melee stays
## at the old adjacency-only behavior (range 1), ranged/magic attacks (from
## JSON's attack.range_tiles) can engage and stop pursuing further out. Both
## entities are always grid-aligned when idle, so this offset divides evenly.
func _in_attack_range(target: Node2D) -> bool:
	var offset := Vector2i((target.global_position - global_position) / grid_mover.tile_size)
	return absi(offset.x) <= _attack_range and absi(offset.y) <= _attack_range

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
