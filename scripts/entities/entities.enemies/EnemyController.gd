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
var _last_state: EnemySenses.State = EnemySenses.State.PATROL
var _size_px: float = 16.0
var _base_move_time := 0.2
var _light_map: LightMap = null

## Half speed while Investigate is closing in on a lit-but-not-directly-seen
## target -- full speed once Attack actually confirms it.
const INVESTIGATE_SPEED_SCALE := 0.5

## Pathfinding search radius is sized to the actual current distance to the
## target (plus this margin for detours around walls), not a fixed number --
## the 10s sticky alert window means the target can easily run further than
## any fixed sight-range-based radius before the window expires, and a radius
## too small to even see the target makes an enemy that's still "aggro'd"
## just stand still, which looks identical to de-aggroing. Capped by
## PATHFIND_RADIUS_MAX so a target that's run very far doesn't blow up the
## per-frame search cost.
const PATHFIND_RADIUS_MARGIN := 4
const PATHFIND_RADIUS_MAX := 24

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
const ALERTNESS_HOLD_SECONDS := 3.0
## Alertness.png's 3 frames (left to right) are distinct static icons, not a
## sequence -- which one shows depends on the state just entered.
const ALERTNESS_FRAME := {
	EnemySenses.State.PATROL: 0,
	EnemySenses.State.INVESTIGATE: 1,
	EnemySenses.State.ATTACK: 2,
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
	animator.continuous_animation = data.get("continuous_animation", false)
	# speed_tiles_per_second is a flat, absolute rate -- 1.0 always means
	# exactly one tile per second, not "1.0x whatever the player's current
	# move_time is." Missing the field falls back to this node's own
	# pre-set move_time (e.g. a hand-placed prefab with no JSON override).
	var speed: float = data.get("speed_tiles_per_second", 1.0 / _base_move_time)
	grid_mover.move_time = 1.0 / speed
	var attack_data: Dictionary = data.get("attack", {})
	_attack_amount = attack_data.get("amount", 0)
	_attack_type = attack_data.get("type", "")
	_attack_interval = attack_data.get("interval", 1.0)
	_attack_range = attack_data.get("range_tiles", 1)
	_attack_effect = attack_data.get("effect", {})

func take_damage(amount: int, type: String = "") -> void:
	stats.take_damage(amount, type)
	senses.note_hit()

func _ready() -> void:
	add_to_group("antagonist")
	_base_move_time = grid_mover.move_time
	_light_map = get_tree().current_scene.find_child("LightMap", true, false)
	if default_enemy_type != "":
		set_enemy_type(default_enemy_type)
	_home_position = global_position
	stats.died.connect(queue_free)

func _process(delta: float) -> void:
	_target = _nearest_player()
	var lit := _target != null and _light_map != null and _light_map.is_tile_lit(_to_tile(global_position))
	var state := senses.update(global_position, _target, grid_mover.is_tile_blocked, lit, delta)
	var is_engaging := state == EnemySenses.State.ATTACK
	var is_tracking := is_engaging or state == EnemySenses.State.INVESTIGATE
	if state != _last_state:
		_show_alertness(state)
	_last_state = state

	var can_attack := is_engaging and _target and _in_attack_range(_target)
	if grid_mover.is_moving:
		animator.animate_moving(grid_mover.facing_direction)
	elif can_attack:
		animator.animate_facing(_target.global_position - global_position)
	else:
		animator.animate_idle()
	if can_attack:
		# Only counts down while actually in range -- pauses (doesn't reset)
		# the moment can_attack drops out, so a single frame of range flicker
		# at a tile boundary can't zero the cooldown and cause a rapid re-fire.
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = _attack_interval
			_perform_attack(_target)

	if grid_mover.is_moving:
		return
	# Chasing re-steps the instant the last move finishes -- as fast as this
	# enemy's own move_time allows, same as a player holding a direction key.
	# Investigate closes in the same way but at half speed (see _try_move),
	# and never attacks even if it ends up adjacent. Only idle wandering
	# stays throttled by wander_interval.
	if is_tracking:
		_try_pursue_step(_target, is_engaging)
		return
	_wander_timer += delta
	if _wander_timer < wander_interval:
		return
	_wander_timer = 0.0
	_try_wander_step()

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
		_land_ranged_hit(target, target_global), grid_mover.is_position_blocked)

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

## One-shot icon above the enemy's head on any alert-state change -- which of
## Alertness.png's 3 frames shows depends on the state just entered (see
## ALERTNESS_FRAME): returning to Patrol, Investigate, or Attack. Held
## statically for ALERTNESS_HOLD_SECONDS rather than animated as a sequence.
## Parented to the enemy itself (not current_scene, like the swing/hit
## effects) so it tracks as the enemy keeps moving during the 3s hold instead
## of staying pinned to wherever it spawned.
func _show_alertness(state: EnemySenses.State) -> void:
	var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
	add_child(effect)
	effect.position = Vector2(_size_px / 2.0 - 8.0, -12.0)
	effect.play_frame(ALERTNESS_DATA, ALERTNESS_FRAME[state], ALERTNESS_HOLD_SECONDS)

## Real pathfinding step toward the target (Pathfinding.next_step, shared by
## both Investigate and Attack tracking -- this is the one place either of
## them actually moves). Search radius is sized to the live distance to the
## target (see PATHFIND_RADIUS_MARGIN/_MAX) so a target that's run off doesn't
## just give up searching before it's actually out of reach.
## full_speed is false while merely Investigating (half speed, see _try_move).
func _try_pursue_step(target: Node2D, full_speed: bool) -> void:
	if _in_attack_range(target):
		return
	var origin_cell := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)
	var distance := maxi(absi(target_cell.x - origin_cell.x), absi(target_cell.y - origin_cell.y))
	var radius := mini(distance + PATHFIND_RADIUS_MARGIN, PATHFIND_RADIUS_MAX)
	var step := Pathfinding.next_step(origin_cell, target_cell, grid_mover.is_tile_blocked, radius)
	if step != Vector2i.ZERO:
		_try_move(Vector2(step), full_speed)

## Vector2i(pos / tile_size) truncates toward zero, which rounds the wrong
## way for a fractional position on the negative side of the origin (this
## dungeon spans both) -- floori() matches what TileMapLayer.local_to_map
## actually does, same fix DungeonMaker/LightMap already use.
func _to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / grid_mover.tile_size), floori(pos.y / grid_mover.tile_size))

## Tile-grid (Chebyshev) distance check against _attack_range -- melee stays
## at the old adjacency-only behavior (range 1), ranged/magic attacks (from
## JSON's attack.range_tiles) can engage and stop pursuing further out.
## Also requires an unobstructed line to the target (same grid-walk SenseSight
## uses for vision) -- a ranged enemy standing behind a wall is in range but
## not in sight, so this returns false and _try_pursue_step keeps closing in
## instead of shooting through the wall.
func _in_attack_range(target: Node2D) -> bool:
	var origin_cell := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)
	var offset := target_cell - origin_cell
	if absi(offset.x) > _attack_range or absi(offset.y) > _attack_range:
		return false
	return LineOfSight.clear(origin_cell, target_cell, grid_mover.is_tile_blocked)

func _try_move(direction: Vector2, full_speed: bool = true) -> bool:
	var target_tile := _to_tile(global_position + direction * grid_mover.tile_size)
	if grid_mover.is_tile_blocked(target_tile):
		return false
	grid_mover.move_one_tile(direction, 1.0 if full_speed else INVESTIGATE_SPEED_SCALE)
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
