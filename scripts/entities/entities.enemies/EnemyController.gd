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

## True once a failed move confirms every orthogonal neighbor is blocked or
## occupied -- see _is_boxed_in() and its use in _process().
var _stuck := false

## Aggro / target lock (see AGGRO_AI_TRACKER.md). Once alerted, an enemy keeps
## the same player (_lock) instead of re-picking the nearest every tick. It is
## released when the alert window ends (senses decay back to Patrol), the
## target dies / becomes a ghost / is freed, the target sits UNREACHABLE by
## walls for UNREACHABLE_MSEC, or it is more than LEASH_TILES away. A player
## standing in the way for BLOCKED_MSEC becomes a temporary attack override
## (_override) that never touches _lock. A taunt (force_target) hard-locks for
## its duration. All timers are msec -- waiting enemies skip frames. Untyped
## vars on purpose: a freed node can't be assigned to a typed Node2D.
const LEASH_TILES := 24
const UNREACHABLE_MSEC := 4000
const BLOCKED_MSEC := 1000
const OVERRIDE_MSEC := 1500
const AVOID_MSEC := 5000
var _lock = null
var _taunt_until_msec := 0
var _override = null
var _override_until_msec := 0
var _blocker = null
var _blocked_since_msec := 0
var _unreachable_since_msec := 0
var _avoid_id := 0
var _avoid_until_msec := 0

const IDLE_RETHINK_FRAMES := 6
var _idle_until_frame := 0
var _skipped_delta := 0.0

const RELAY_HEARTBEAT_MSEC := 1000
var _relayed_state := -1
var _relayed_position := Vector2.INF
var _relayed_msec := 0

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

## Pathfinding.full_path() rebuilds and solves a whole AStarGrid2D from
## scratch -- fine for a handful of enemies, but with hundreds pursuing
## at once (the "development" stress room) it tanks the frame rate. This caps
## how many enemies may actually call into it in a single frame; the rest
## just wait for their next _process() tick instead of piling more solves
## onto an already-slow frame. Shared across every EnemyController via
## `static` (Godot 4 script statics), reset the first time any enemy checks
## it on a new frame -- cheap on purpose, not meant to be perfectly fair
## between enemies. Raised from 16 once FlowField (shared, most enemies never
## reach this tier at all) and the per-enemy path cache (an enemy that does
## reach it mostly reuses its last solve instead of re-asking every frame)
## both landed -- real solves-per-frame dropped a lot, so a higher cap for
## the ones that still happen is cheap. Tune by testing with the F4 debug
## menu's time-usage readout in a heavy biome (cathedral).
const MAX_PATHFINDS_PER_FRAME := 32
static var _pathfind_budget_frame: int = -1
static var _pathfind_budget_used: int = 0

static func _consume_pathfind_budget() -> bool:
	var frame := Engine.get_process_frames()
	if frame != _pathfind_budget_frame:
		_pathfind_budget_frame = frame
		_pathfind_budget_used = 0
	if _pathfind_budget_used >= MAX_PATHFINDS_PER_FRAME:
		return false
	_pathfind_budget_used += 1
	return true

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

const ENEMY_TYPES_DIR := "res://game/entities/entities.enemies/"

## enemy_id is always exactly its JSON's filename (see ENEMY_TYPES_DIR) -- no
## separate registry to keep in sync, so a new enemy is really just a new
## JSON file dropped in that folder, nothing here needs to change.
var _can_open_doors := false

func set_enemy_type(enemy_id: String) -> void:
	var data := JsonOnloading.load_dict(ENEMY_TYPES_DIR + enemy_id + ".json")
	stats.load_from_data(data)
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])
	_size_px = data.get("size_tiles", 1) * grid_mover.tile_size
	# The scene's shape resource is shared by every enemy, so each one needs its own
	# copy or the last enemy spawned resizes them all (a boss would shrink to 1 tile).
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_size_px, _size_px)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(_size_px, _size_px) / 2.0
	$HealthPixelBar.position = Vector2(_size_px / 2.0, _size_px + 2.0)
	$HealthPixelBar.setup(stats, 32 if _size_px > grid_mover.tile_size else 16)
	senses.apply_overrides(data.get("senses", {}))
	# One "flying" flag: wings never freeze (animation), terrain never slows
	# it, and its routes ignore terrain cost (GridMover.flies).
	var flying: bool = data.get("flying", false)
	animator.continuous_animation = flying
	grid_mover.flies = flying
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
	# "doors": "none" (default) can't open doors, "open" can (see-through doors any
	# time, solid ones only while investigating or pursuing), "phase" passes through
	# closed doors without opening them.
	var door_mode: String = data.get("doors", "none")
	_can_open_doors = door_mode == "open"
	grid_mover.phases_doors = door_mode == "phase"

func take_damage(amount: int, type: String = "") -> void:
	stats.take_damage(amount, type)
	senses.note_hit()

## Called by NetworkSync.receive_enemy_state on every peer that isn't this
## enemy's authority (the host) -- the host told everyone where it is and
## what state it's in, this just applies that locally instead of deciding
## anything itself.
func receive_network_state(pos: Vector2, state: int) -> void:
	global_position = pos
	var enemy_state := state as EnemySenses.State
	if enemy_state != _last_state:
		_show_alertness(enemy_state)
	_last_state = enemy_state

func _ready() -> void:
	add_to_group("antagonist")
	_base_move_time = grid_mover.move_time
	_light_map = get_tree().current_scene.find_child("LightMap", true, false)
	if default_enemy_type != "":
		set_enemy_type(default_enemy_type)
	_home_position = global_position
	stats.died.connect(queue_free)
	# Which doors this enemy may open depends on its "doors" field (see set_enemy_type).
	grid_mover.open_predicate = func(door: DoorRegistry.Door) -> bool:
		return _can_open_doors and (door.transparent or _last_state != EnemySenses.State.PATROL)

## Enemies are always host-owned (see EnemySpawning.spawn_one) -- a client
## never runs AI for one, it only ever renders whatever position/state the
## host last relayed, the same split PlayerController uses for a remote peer's
## body (animate_from_position instead of reading local input).
func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_process_inner(delta)
	DebugState.add_time("enemy AI", Time.get_ticks_usec() - started)

func _process_inner(delta: float) -> void:
	if not is_multiplayer_authority():
		animator.animate_from_position(delta, global_position)
		return
	# Aggro validity runs BEFORE the idle-skip / boxed-in early returns below so
	# a waiting enemy still notices a dead, ghost or freed target.
	var now := Time.get_ticks_msec()
	if _lock != null and not _is_valid_target(_lock):
		_lock = null
		_wake_up()
	if _override != null and (now >= _override_until_msec or not _is_valid_target(_override)):
		_override = null
		_wake_up()
	if _override == null and _blocked_since_msec != 0 and now - _blocked_since_msec >= BLOCKED_MSEC \
			and now >= _taunt_until_msec and _is_valid_target(_blocker):
		_override = _blocker
		_override_until_msec = now + OVERRIDE_MSEC
		_blocked_since_msec = 0
		_wake_up()
	# A boxed-in enemy can't act on senses/targeting/attacking anyway (it has
	# nowhere to go and, per _try_direct_step, isn't in attack range either --
	# that case never sets _stuck), and it can only ever be freed by some
	# OTHER body moving off a neighboring tile, not by anything this enemy's
	# own full AI tick would decide. So skip straight to the cheap re-check
	# instead of repeating the same doomed senses/relay/animate work every
	# frame -- in the packed development stress room this is most of the 500+
	# enemies most of the time.
	# Same idea for a rat that just failed to advance (waiting on a crowded
	# tile): re-think a few frames later instead of every frame. The skipped
	# time is carried into the next real tick so senses/attack timers still
	# run at true speed instead of crawling.
	if Engine.get_process_frames() < _idle_until_frame:
		_skipped_delta += delta
		return
	if _stuck:
		if _is_boxed_in():
			_skipped_delta += delta
			return
		_stuck = false
	delta += _skipped_delta
	_skipped_delta = 0.0
	if _lock != null and _override == null and now >= _taunt_until_msec \
			and _cheb(_to_tile(_lock.global_position) - _to_tile(global_position)) > LEASH_TILES:
		_drop_lock(now)
	if _override != null:
		_target = _override
	elif _lock != null:
		_target = _lock
	else:
		_target = _nearest_player()
	var lit := _target != null and _light_map != null and _light_map.is_tile_lit(_to_tile(global_position))
	var state := senses.update(global_position, _target, grid_mover.blocks_sight, lit, delta)
	if _override == null:
		if state == EnemySenses.State.PATROL:
			_lock = null
		elif _lock == null and _target != null:
			_lock = _target
			_unreachable_since_msec = 0
			_blocked_since_msec = 0
	var is_engaging := state == EnemySenses.State.ATTACK
	var is_tracking := is_engaging or state == EnemySenses.State.INVESTIGATE
	if state != _last_state:
		_show_alertness(state)
	_last_state = state
	# Only tell peers when something they'd render changed (plus a slow
	# heartbeat so a late joiner still gets a parked enemy's position).
	if state != _relayed_state or global_position != _relayed_position or Time.get_ticks_msec() - _relayed_msec > RELAY_HEARTBEAT_MSEC:
		_relayed_state = state
		_relayed_position = global_position
		_relayed_msec = Time.get_ticks_msec()
		NetworkSync.relay_enemy_state(int(str(name)), global_position, state)

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
		var reached_range := _target != null and _in_attack_range(_target)
		if not reached_range:
			_try_pursue_step(_target, is_engaging)
			if grid_mover.is_moving:
				_blocked_since_msec = 0
			else:
				_note_blocked_by_player(now)
				if _unreachable_since_msec != 0:
					if now < _taunt_until_msec or _override != null:
						_unreachable_since_msec = 0
					elif now - _unreachable_since_msec >= UNREACHABLE_MSEC and _lock != null:
						_drop_lock(now)
				if _is_boxed_in():
					_stuck = true
				else:
					_idle_until_frame = Engine.get_process_frames() + IDLE_RETHINK_FRAMES + get_instance_id() % 4
		elif is_engaging:
			_try_slide_step(_target)
		return
	_wander_timer += delta
	if _wander_timer < wander_interval:
		return
	_wander_timer = 0.0
	_try_wander_step()
	if not grid_mover.is_moving and _is_boxed_in():
		_stuck = true

func _perform_attack(target: Node2D) -> void:
	if _attack_effect.has("attacker") or _attack_effect.has("target"):
		_perform_ranged_attack(target)
		return
	# Enemy AI only ever runs on the host, so the host is always the source of
	# this hit -- relay it rather than calling target.take_damage() directly,
	# which would only ever update the host's own local copy of that player.
	NetworkSync.relay_player_hit(int(str(target.name)), _attack_amount, _attack_type)
	if _attack_effect.is_empty():
		return
	NetworkSync.play_effect(
		AttackEffect.effect_position(global_position, target.global_position, _attack_effect),
		_attack_effect, target.global_position - global_position)

## Mirrors PlayerController's bow handling: an "attacker" shot effect plays
## here (cosmetic), a projectile travels to the target if the data has one,
## and only on arrival does the "target" hit effect play and damage land.
## A magic attack (no "projectile") skips the travel and lands immediately.
func _perform_ranged_attack(target: Node2D) -> void:
	var target_global: Vector2 = target.global_position
	var direction := target_global - global_position
	var attacker_data: Dictionary = _attack_effect.get("attacker", {})
	if not attacker_data.is_empty():
		NetworkSync.play_effect(
			AttackEffect.effect_position(global_position, target_global, attacker_data),
			attacker_data, direction)
	var projectile_texture: String = _attack_effect.get("projectile", "")
	if projectile_texture == "":
		_land_ranged_hit(target, target_global)
		return
	var projectile: ProjectileController = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(_size_px / 2.0, _size_px / 2.0)
	# The arrow hits the first living player whose tile it passes through, not
	# whoever it was aimed at: stepping out of its way makes it miss, stepping
	# into it gets you hit. Reaching the aimed tile with nobody there is a miss.
	var hit_on_the_way := func(pos: Vector2) -> bool:
		var tile := _to_tile(pos)
		for player: PlayerController in get_tree().get_nodes_in_group("protagonist"):
			if player.stats.is_ghost or _to_tile(player.global_position + Vector2(8, 8)) != tile:
				continue
			NetworkSync.relay_player_hit(int(str(player.name)), _attack_amount, _attack_type)
			_play_ranged_target_effect(Vector2(tile) * grid_mover.tile_size)
			return true
		return false
	projectile.launch(projectile_texture, target_global + Vector2(8, 8), grid_mover.tile_size, func():
		_play_ranged_target_effect(target_global), grid_mover.is_position_blocked, hit_on_the_way)
	NetworkSync.share_projectile(projectile_texture, projectile.global_position, target_global + Vector2(8, 8))

func _land_ranged_hit(target: Node2D, target_global: Vector2) -> void:
	if not is_instance_valid(target):
		return
	NetworkSync.relay_player_hit(int(str(target.name)), _attack_amount, _attack_type)
	_play_ranged_target_effect(target_global)

## The "target" impact animation on a tile (cosmetic only).
func _play_ranged_target_effect(target_global: Vector2) -> void:
	var target_data: Dictionary = _attack_effect.get("target", {})
	if not target_data.is_empty():
		NetworkSync.play_effect(
			AttackEffect.effect_position(global_position, target_global, target_data),
			target_data, target_global - global_position)

## One-shot icon above the enemy's head on any alert-state change -- which of
## Alertness.png's 3 frames shows depends on the state just entered (see
## ALERTNESS_FRAME): returning to Patrol, Investigate, or Attack. Held
## statically for ALERTNESS_HOLD_SECONDS rather than animated as a sequence.
## Parented to the enemy itself (not current_scene, like the swing/hit
## effects) so it tracks as the enemy keeps moving during the 3s hold instead
## of staying pinned to wherever it spawned.
func _show_alertness(state: EnemySenses.State) -> void:
	# Newest state wins: Investigate -> Attack in quick succession would
	# otherwise leave both icons stacked on top of each other for 3 seconds.
	if is_instance_valid(_alertness_icon):
		_alertness_icon.hide()
		_alertness_icon.queue_free()
	var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
	add_child(effect)
	effect.position = Vector2(_size_px / 2.0 - 8.0, -12.0)
	effect.play_frame(ALERTNESS_DATA, ALERTNESS_FRAME[state], ALERTNESS_HOLD_SECONDS)
	_alertness_icon = effect

var _alertness_icon: AttackEffect = null

## Step toward the target, shared by both Investigate and Attack tracking --
## this is the one place either of them actually moves. full_speed is false
## while merely Investigating (half speed, see _try_move).
##
## Tries three tiers in order, cheapest/most-shared first:
## 1. FlowField -- shared across every enemy chasing this same target, so a
##    whole crowd (the swarm room) pays for one BFS between them instead of
##    one search each. Only covers cells within FlowField.RADIUS of the
##    target, and only knows about walls, not occupancy (see FlowField.gd).
## 2. LOS-clear direct stepping (_try_direct_step) or a real, per-enemy
##    cached search (_try_pathfind_step) toward the target -- or, if the
##    target is farther than this enemy's own search can ever reach, toward
##    the next room's door instead (RoomGraph.next_waypoint), so a
##    cross-dungeon chase advances room by room instead of just giving up.
func _try_pursue_step(target: Node2D, full_speed: bool) -> void:
	if _in_attack_range(target):
		return
	var origin_cell := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)

	if _try_surround_step(target, origin_cell, target_cell, full_speed):
		return

	var flow_step := FlowField.get_step(target.get_instance_id(), target_cell, origin_cell, grid_mover.is_tile_blocked, _terrain_cost())
	if flow_step != Vector2i.ZERO:
		_unreachable_since_msec = 0
		# FlowField only routes around walls, same as _try_direct_step's own
		# occupancy handling below -- if occupancy alone is in the way, wait
		# rather than fall through to a real search that would just recommend
		# this exact same blocked step.
		if not grid_mover.is_tile_occupied(origin_cell + flow_step):
			_try_move(Vector2(flow_step), full_speed)
		return

	var local_target := target_cell
	var distance := maxi(absi(target_cell.x - origin_cell.x), absi(target_cell.y - origin_cell.y))
	if distance > PATHFIND_RADIUS_MAX and RoomGraph.current != null:
		var waypoint := RoomGraph.current.next_waypoint(origin_cell, target_cell)
		if waypoint != Vector2i.ZERO:
			local_target = waypoint

	if not LineOfSight.clear(origin_cell, local_target, grid_mover.is_tile_blocked):
		_try_pathfind_step(origin_cell, local_target, full_speed)
		return
	_try_direct_step(origin_cell, local_target, full_speed)

## Melee enemies near their target fan out around it instead of queueing
## single file. FlowField.get_distances gives each tile's walking distance to
## the target -- tiles at the same distance form a "layer" (a diamond shell)
## around it, and there's no fixed cap on how many layers there are. Each
## step: prefer a free neighbor one layer closer, choosing whichever leads into
## the least crowded of 16 pie slices around the target (SurroundSectors); if
## none is free, sidestep to a free tile that has a free way forward of its
## own (never straight back to the tile it just left, which keeps two rats from
## trading places forever). Returns false (caller uses the normal chase) for
## ranged enemies or ones too far / unreachable.
const SURROUND_RADIUS := 12
const SLIDE_COOLDOWN_MSEC := 1500
var _slide_ready_msec := 0
var _prev_cell := Vector2i.ZERO

func _try_surround_step(target: Node2D, origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool) -> bool:
	if _attack_range != 1 or _cheb(target_cell - origin_cell) > SURROUND_RADIUS:
		return false
	var target_id := target.get_instance_id()
	var distances := FlowField.get_distances(target_id, target_cell, grid_mover.is_tile_blocked)
	if not distances.has(origin_cell):
		return false
	var here: int = distances[origin_cell]
	var counts := SurroundSectors.counts_for(get_tree(), target_id, grid_mover.tile_size)
	var sector_count := func(cell: Vector2i) -> int:
		if counts.is_empty():
			return 0
		return counts[SurroundSectors.sector_of(Vector2(cell - target_cell))]

	var best_step := Vector2i.ZERO
	var best_score := 1 << 30
	var blocked_forward: Array[Vector2i] = []
	var avoided_hazard := false
	for direction in MOVE_DIRECTIONS:
		var step := Vector2i(direction)
		var next_cell := origin_cell + step
		if not distances.has(next_cell) or distances[next_cell] >= here:
			continue
		if grid_mover.tile_cost(next_cell) > HAZARD_COST and grid_mover.tile_cost(origin_cell) <= HAZARD_COST:
			avoided_hazard = true  # do not fan out into lava or water
			continue
		if grid_mover.is_tile_occupied(next_cell):
			blocked_forward.append(step)
			continue
		# Stable per-rat tie-break so equal options don't flip between frames.
		var score: int = sector_count.call(next_cell) * 2 + ((get_instance_id() + step.x + step.y * 2) & 1)
		if score < best_score:
			best_score = score
			best_step = step
	# Every way forward is taken: sidestep to a free tile that has a free way
	# forward of its own, toward the emptier slice. (Neighbors on this grid are
	# always exactly one tile farther or closer, never the same distance, so the
	# sidestep itself is one tile farther -- the tile it lands beside is what
	# puts it back on the same layer, one column over.)
	if best_step == Vector2i.ZERO:
		for forward in blocked_forward:
			for side_dir in [Vector2i(forward.y, forward.x), Vector2i(-forward.y, -forward.x)]:
				var side_cell: Vector2i = origin_cell + side_dir
				if side_cell == _prev_cell or not distances.has(side_cell) or grid_mover.is_tile_occupied(side_cell):
					continue
				var ahead: Vector2i = side_cell + forward
				if not distances.has(ahead) or grid_mover.is_tile_occupied(ahead):
					continue
				var score: int = sector_count.call(side_cell) * 2 + ((get_instance_id() + side_dir.x + side_dir.y * 2) & 1)
				if score < best_score:
					best_score = score
					best_step = side_dir
	if best_step == Vector2i.ZERO and avoided_hazard:
		return false  # only hazard tiles lead closer: use the weighted chase instead
	var chosen := best_step
	if chosen != Vector2i.ZERO and _try_move(Vector2(chosen), full_speed):
		_prev_cell = origin_cell
	return true

## A melee enemy already touching its target that has another creature
## queued right behind it (one tile farther out) shuffles one tile sideways to
## a free tile that still touches the target, opening its spot for whoever's
## waiting. Repeated down the line this rolls the crowd around the target
## instead of leaving the front row parked and everyone else stuck behind it.
## Stops by itself once the ring is full (no free touching tile to slide to).
func _try_slide_step(target: Node2D) -> void:
	if _attack_range != 1:
		return
	if Time.get_ticks_msec() < _slide_ready_msec:
		return
	var origin_cell := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)
	if _cheb(origin_cell - target_cell) != 1:
		return
	var someone_behind := false
	for direction in MOVE_DIRECTIONS:
		var behind := origin_cell + Vector2i(direction)
		if _cheb(behind - target_cell) == 2 and grid_mover.is_tile_occupied(behind):
			someone_behind = true
			break
	if not someone_behind:
		return
	for direction in MOVE_DIRECTIONS:
		var side := origin_cell + Vector2i(direction)
		if _cheb(side - target_cell) != 1:
			continue
		if grid_mover.is_tile_blocked(side) or grid_mover.is_tile_occupied(side):
			continue
		if _try_move(direction, true):
			# Just-moved rats go to the back of the line: without this cooldown,
			# two rats trade places forever (each ends up with the other
			# behind it), which wiggles in place and blocks everyone else.
			# Staggered per rat so a crowd doesn't all come off cooldown together.
			_slide_ready_msec = Time.get_ticks_msec() + SLIDE_COOLDOWN_MSEC + (get_instance_id() % 5) * 250
		return

func _cheb(offset: Vector2i) -> int:
	return maxi(absi(offset.x), absi(offset.y))

## Fast path for the common case (open rooms, short corridors): with a clear
## line to the target, just step straight toward it -- axis with the bigger
## offset first, the other as a fallback -- instead of paying for a full grid
## search. Falls back to _try_pathfind_step only if a wall (not just a
## crowded tile) actually blocks both preferred directions, since that's the
## one case a real search can do something about. If both directions are
## merely occupied by another creature, that's deliberately left alone:
## Pathfinding.full_path doesn't know about occupancy either, so it would
## just recompute this exact same step and waste a search on a wall that was
## never the problem -- better to wait a frame and let whoever's in the way
## move first.
func _try_direct_step(origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool) -> void:
	var offset := target_cell - origin_cell
	var primary := Vector2(signf(offset.x), 0.0) if absi(offset.x) >= absi(offset.y) else Vector2(0.0, signf(offset.y))
	var secondary := Vector2(0.0, signf(offset.y)) if primary.x != 0.0 else Vector2(signf(offset.x), 0.0)
	var saw_wall := false
	for direction in [primary, secondary]:
		if direction == Vector2.ZERO:
			continue
		var step_tile := origin_cell + Vector2i(direction)
		if grid_mover.is_tile_blocked(step_tile):
			saw_wall = true
			continue
		if grid_mover.tile_cost(step_tile) > HAZARD_COST and grid_mover.tile_cost(origin_cell) <= HAZARD_COST:
			# Difficult or severe ground ahead (water, lava): let the weighted
			# search decide whether crossing is worth it, same escalation as a wall.
			saw_wall = true
			continue
		if grid_mover.is_tile_occupied(step_tile):
			continue
		_try_move(direction, full_speed)
		return
	if saw_wall:
		_try_pathfind_step(origin_cell, target_cell, full_speed)
	# else: only occupancy in the way -- wait, don't escalate

## Tiles costing more than this (difficult 2.0, severe 5.0; rough 1.25 is fine)
## are not stepped onto blindly by _try_direct_step.
const HAZARD_COST := 1.5

## The terrain cost callable for routes, or an unset one for a flyer (its
## routes then use the plain, unweighted field and search).
func _terrain_cost() -> Callable:
	return Callable() if grid_mover.flies else grid_mover.tile_cost

## Real pathfinding step for when the direct approach can't work -- no clear
## line to the target, or a wall blocks both preferred directions and a
## detour is actually needed. First tries to keep following this enemy's own
## cached route (_next_cached_step) instead of re-solving an identical
## AStarGrid2D every frame for a target that's barely moved; only falls
## through to an actual solve (budget-gated, see MAX_PATHFINDS_PER_FRAME)
## when the cache can't answer.
func _try_pathfind_step(origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool) -> void:
	var step := _next_cached_step(origin_cell, target_cell)
	if step == Vector2i.ZERO:
		step = _solve_and_cache_path(origin_cell, target_cell)
	if step != Vector2i.ZERO:
		_try_move(Vector2(step), full_speed)

## Per-enemy path cache (technique 4/5 from the Factorio pathfinding
## research: reuse + negative caching), distinct from FlowField's shared
## per-target cache -- this is for the individual, often-distant search this
## enemy alone needed (FlowField didn't cover the cell, or a wall forced a
## real detour). CACHED_PATH_TARGET_TOLERANCE lets the target drift a couple
## tiles without invalidating the route (a fleeing target rarely changes the
## right general direction over 1-2 tiles); anything past that, or a tile on
## the route becoming newly blocked, forces a fresh solve.
## For the route debug draw: the tile the last step tried to enter, and when.
var _debug_step_tile := Vector2i.ZERO
var _debug_step_msec := -100000

var _cached_path: Array[Vector2i] = []
var _cached_path_index: int = 0
var _cached_path_target: Vector2i = Vector2i.ZERO
const CACHED_PATH_TARGET_TOLERANCE := 2

## A search that failed (target unreachable within radius) is remembered for
## a short cooldown so an unreachable target doesn't get hammered with a
## fresh solve every single frame -- negative caching. Short enough that a
## door opening or a wall coming down is still noticed quickly.
var _failed_target: Vector2i = Vector2i.ZERO
var _failed_until_frame: int = -1
const FAILED_SEARCH_COOLDOWN_FRAMES := 30

## Advances along the cached path if it's still usable for `target_cell`,
## returning the next step direction, or Vector2i.ZERO (and clearing the
## cache) if it can't answer -- empty, finished, gone stale, or blocked --
## in which case the caller falls back to a real solve.
func _next_cached_step(origin_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	if _cached_path.is_empty():
		return Vector2i.ZERO
	var drift := _cached_path_target - target_cell
	if maxi(absi(drift.x), absi(drift.y)) > CACHED_PATH_TARGET_TOLERANCE:
		_cached_path.clear()
		return Vector2i.ZERO
	if origin_cell == _cached_path[_cached_path_index]:
		_cached_path_index += 1
	if _cached_path_index >= _cached_path.size():
		_cached_path.clear()
		return Vector2i.ZERO
	var next_cell: Vector2i = _cached_path[_cached_path_index]
	if grid_mover.is_tile_blocked(next_cell):
		_cached_path.clear()  # a door closed or similar -- force a fresh solve
		return Vector2i.ZERO
	var step := next_cell - origin_cell
	if absi(step.x) + absi(step.y) != 1:
		# _try_pursue_step can hop this enemy over to _try_direct_step on a
		# frame where line of sight happens to open up, moving it somewhere
		# the cached route never accounted for -- a stale route handed
		# straight to _try_move here would multiply a multi-tile offset by
		# tile_size and warp the enemy instead of taking one legal step, so
		# treat any non-adjacent mismatch as a cache miss rather than trust it.
		_cached_path.clear()
		return Vector2i.ZERO
	return step

func _solve_and_cache_path(origin_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	if target_cell == _failed_target and Engine.get_process_frames() < _failed_until_frame:
		return Vector2i.ZERO
	if not _consume_pathfind_budget():
		return Vector2i.ZERO
	var distance := maxi(absi(target_cell.x - origin_cell.x), absi(target_cell.y - origin_cell.y))
	var radius := mini(distance + PATHFIND_RADIUS_MARGIN, PATHFIND_RADIUS_MAX)
	var path := Pathfinding.full_path(origin_cell, target_cell, grid_mover.is_tile_blocked, radius, _terrain_cost())
	if path.is_empty():
		_failed_target = target_cell
		_failed_until_frame = Engine.get_process_frames() + FAILED_SEARCH_COOLDOWN_FRAMES
		# A real wall-based failed solve is the ONLY thing that starts the
		# unreachable timer -- the budget / cooldown early-outs above and plain
		# crowding never do.
		if _unreachable_since_msec == 0 and _override == null:
			_unreachable_since_msec = Time.get_ticks_msec()
		return Vector2i.ZERO
	_unreachable_since_msec = 0
	_cached_path = path
	_cached_path_index = 1  # path[0] is origin_cell itself
	_cached_path_target = target_cell
	return path[1] - path[0]

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
	return LineOfSight.clear(origin_cell, target_cell, grid_mover.blocks_shot)

## True when all 4 orthogonal neighbor tiles are blocked or occupied -- a
## stronger check than "the two directions _try_direct_step happened to
## prefer were full," since a third direction could still be open even when
## those two aren't. Cheap on purpose (grid_mover's own O(1)-per-tile checks,
## see GridMover.is_tile_occupied's per-frame index): this is what runs every
## frame INSTEAD of the full AI tick while _stuck is true, so it needs to
## stay far cheaper than the senses/relay/animate work it's standing in for.
func _is_boxed_in() -> bool:
	var origin_cell := _to_tile(global_position)
	for direction in MOVE_DIRECTIONS:
		var tile := origin_cell + Vector2i(direction)
		if not grid_mover.is_tile_blocked(tile) and not grid_mover.is_tile_occupied(tile):
			return false
	return true

func _try_move(direction: Vector2, full_speed: bool = true) -> bool:
	var target_tile := _to_tile(global_position + direction * grid_mover.tile_size)
	_debug_step_tile = target_tile
	_debug_step_msec = Time.get_ticks_msec()
	if grid_mover.is_tile_blocked(target_tile) or grid_mover.is_tile_occupied(target_tile):
		return false
	var moved := grid_mover.move_one_tile(direction, 1.0 if full_speed else INVESTIGATE_SPEED_SCALE)
	if moved:
		_unreachable_since_msec = 0
	return moved

## Not freed and not a ghost -- the only things that make a locked target
## invalid right away. Takes an untyped arg so a freed node is safe to pass.
func _is_valid_target(target) -> bool:
	return is_instance_valid(target) and not target.stats.is_ghost

## Makes a waiting / boxed-in enemy run a full AI tick next frame.
func _wake_up() -> void:
	_stuck = false
	_idle_until_frame = 0

## Gives up on the locked player (leash / unreachable): forgets the alert
## window so it falls back to Patrol, and ignores that player for AVOID_MSEC
## so it can pick someone else instead of instantly re-locking.
func _drop_lock(now: int) -> void:
	if is_instance_valid(_lock):
		_avoid_id = _lock.get_instance_id()
		_avoid_until_msec = now + AVOID_MSEC
	_lock = null
	_unreachable_since_msec = 0
	_blocked_since_msec = 0
	senses.forget()
	_wake_up()

## Taunt entry point (host-side, called from NetworkSync). Hard-locks onto
## `player` for `seconds` and refreshes the alert window (note_hit re-arms
## Attack for the full sticky window). The caster stays the target after the
## taunt ends -- normal release rules apply then, no snap-back.
func force_target(player: Node2D, seconds: float) -> void:
	if not is_multiplayer_authority() or not _is_valid_target(player):
		return
	_lock = player
	_override = null
	_taunt_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	_unreachable_since_msec = 0
	_blocked_since_msec = 0
	_avoid_id = 0
	senses.note_hit()
	_wake_up()

## Called when this enemy just failed to advance. If a living non-target
## player is on an adjacent tile that is closer to the locked target than we
## are (i.e. standing in the way), start / keep the blocked timer; otherwise
## clear it. Ranged enemies never count (they don't need to walk up).
func _note_blocked_by_player(now: int) -> void:
	if _attack_range > 1 or _override != null or not is_instance_valid(_lock):
		_blocked_since_msec = 0
		return
	var origin := _to_tile(global_position)
	var lock_tile := _to_tile(_lock.global_position)
	var origin_dist := absi(origin.x - lock_tile.x) + absi(origin.y - lock_tile.y)
	var found = null
	for player in get_tree().get_nodes_in_group("protagonist"):
		if player == _lock or player.stats.is_ghost:
			continue
		var tile := _to_tile(player.global_position)
		if absi(tile.x - origin.x) + absi(tile.y - origin.y) != 1:
			continue
		if absi(tile.x - lock_tile.x) + absi(tile.y - lock_tile.y) >= origin_dist:
			continue
		found = player
		break
	if found == null:
		_blocked_since_msec = 0
		return
	_blocker = found
	if _blocked_since_msec == 0:
		_blocked_since_msec = now

func _nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	var avoiding := Time.get_ticks_msec() < _avoid_until_msec
	for player in get_tree().get_nodes_in_group("protagonist"):
		if player.stats.is_ghost:
			continue
		if avoiding and player.get_instance_id() == _avoid_id:
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
