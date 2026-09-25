class_name MinionController
extends CharacterBody2D

## Generic AI-driven body -- wanders its spawn point for now. Real behavior
## (aggro, attacking) comes later once the antagonist/boss shape is settled.

@onready var grid_mover: GridMover = $GridMover
@onready var animator: DirectionalAnimator = $DirectionalAnimator
@onready var stats: EntityStats = $EntityStats
@onready var senses: MinionSenses = $MinionSenses

@export var wander_radius_tiles: int = 3
@export var wander_interval := 1.4

## Lets a hand-placed instance (or, later, a spawner) configure itself without
## an external script call. Empty means "leave unconfigured."
@export var default_minion_type: String = ""

var _home_position: Vector2 = Vector2.ZERO
var _wander_timer := 0.0
var _target: Node2D = null
var _last_state: MinionSenses.State = MinionSenses.State.PATROL
var _size_px: float = 16.0
## Which minion this is (set by set_minion_type); BodySweep and the test tools name creatures by it.
var minion_id := ""
## Tiles per side (json "size_tiles"): 1 normally, 2 for a boss like the minotaur.
var size_tiles := 1
## True for a minion whose json sits in a bosses/ folder (MinionIndex.is_boss). Bosses get privileges over their allies: they walk through
## them (GridMover) and the allies step out of the way (_yield_to_boss).
var is_boss := false
## Every living boss, so an ally can ask "am I in a boss's way" without scanning the group.
static var bosses: Array[MinionController] = []
var _base_move_time := 0.2
var _light_map: LightMap = null

## True once a failed move confirms every neighbor (all 8) is blocked or
## occupied -- see _is_boxed_in() and its use in _process().
var _stuck := false

## Aggro / target lock (see AGGRO_AI_TRACKER.md). Once alerted, a minion keeps
## the same player (_lock) instead of re-picking the nearest every tick. It is
## released when the alert window ends (senses decay back to Patrol), the
## target dies / becomes a ghost / is freed, the target sits UNREACHABLE by
## walls for UNREACHABLE_MSEC, or it is more than LEASH_TILES away. A player
## standing in the way for BLOCKED_MSEC becomes a temporary attack override
## (_override) that never touches _lock. A taunt (force_target) hard-locks for
## its duration. All timers are msec -- waiting minions skip frames. Untyped
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
## too small to even see the target makes a minion that's still "aggro'd"
## just stand still, which looks identical to de-aggroing. Capped by
## PATHFIND_RADIUS_MAX so a target that's run very far doesn't blow up the
## per-frame search cost.
const PATHFIND_RADIUS_MARGIN := 4
const PATHFIND_RADIUS_MAX := 24

## Pathfinding.full_path() rebuilds and solves a whole AStarGrid2D from
## scratch -- fine for a handful of minions, but with hundreds pursuing
## at once (the "development" stress room) it tanks the frame rate. This caps
## how many minions may actually call into it in a single frame; the rest
## just wait for their next _process() tick instead of piling more solves
## onto an already-slow frame. Shared across every MinionController via
## `static` (Godot 4 script statics), reset the first time any minion checks
## it on a new frame -- cheap on purpose, not meant to be perfectly fair
## between minions. Raised from 16 once FlowField (shared, most minions never
## reach this tier at all) and the per-minion path cache (a minion that does
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

## The default attack: the first of the json "actions".
## It drives movement -- the minion walks until THIS one is in range -- so all the
## approach / surround / detour logic keys off _attack_range. Keys: amount, type,
## range_tiles, interval, effect.
var _primary_attack: Dictionary = {}
var _attack_interval: float = 1.0
var _attack_range: int = 1
var _attack_timer := 0.0
## The other entries of "actions". Each has its own range and cooldown and is used
## while the minion is engaging whenever it is ready and in range; none of them
## changes how the minion walks. Entries: {"attack", "range", "interval", "timer", "sight"}.
var _specials: Array[Dictionary] = []
const ATTACK_EFFECT_SCENE := preload("res://scenes/entities/AttackEffect.tscn")
const ALERTNESS_DATA := {
	"texture": "res://resources/gfx/effects/Alertness.png",
	"frame_count": 3,
	"speed": 10.0,
}
const ALERTNESS_HOLD_SECONDS := 3.0
## Alertness.png's 3 frames (left to right) are distinct static icons, not a
## sequence -- which one shows depends on the state just entered.
const ALERTNESS_FRAME := {
	MinionSenses.State.PATROL: 0,
	MinionSenses.State.INVESTIGATE: 1,
	MinionSenses.State.ATTACK: 2,
}

## minion_id is always exactly its JSON's filename; MinionIndex finds the file in the minion
## folder or any subfolder, so a new minion is really just a new JSON file dropped
## there, nothing here needs to change.
var _can_open_doors := false

func set_minion_type(id: String) -> void:
	minion_id = id
	var data := MinionIndex.load_data(id)
	stats.load_from_data(data)
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])
	size_tiles = int(data.get("size_tiles", 1))
	is_boss = MinionIndex.is_boss(id)
	_size_px = size_tiles * grid_mover.tile_size
	grid_mover.footprint = size_tiles
	set_meta("is_boss", is_boss)
	if is_boss and not bosses.has(self):
		bosses.append(self)
	$AnimatedSprite2D.position = Vector2(_size_px, _size_px) / 2.0
	# The scene's shape resource is shared by every minion, so each one needs its own
	# copy or the last minion spawned resizes them all (a boss would shrink to 1 tile).
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
	# "actions" is a list of action ids (game/actions/): the first is the default attack,
	# the rest are specials.
	var attacks: Array = ActionIndex.resolve(data.get("actions", []))
	_primary_attack = attacks[0] if not attacks.is_empty() else {}
	_attack_interval = _primary_attack.get("interval", 1.0)
	_attack_range = _primary_attack.get("range_tiles", 1)
	_specials.clear()
	for i in range(1, attacks.size()):
		var extra: Dictionary = attacks[i]
		var interval: float = extra.get("interval", 1.0)
		_specials.append({
			"attack": extra,
			"range": int(extra.get("range_tiles", 1)),
			"interval": interval,
			"timer": interval,
			"sight": bool(extra.get("needs_sight", true)),
			"through_walls": bool(extra.get("only_through_walls", false)),
		})
	# "doors": "none" (default) can't open doors, "open" can (see-through doors any
	# time, solid ones only while investigating or pursuing), "phase" passes through
	# closed doors without opening them.
	var door_mode: String = data.get("doors", "none")
	_can_open_doors = door_mode == "open"
	grid_mover.phases_doors = door_mode == "phase"

func take_damage(amount: int, type: String = "") -> void:
	stats.take_damage(amount, type)
	senses.note_hit()

## Called by NetworkSync.receive_minion_state on every peer that isn't this
## minion's authority (the host) -- the host told everyone where it is and
## what state it's in, this just applies that locally instead of deciding
## anything itself.
func receive_network_state(pos: Vector2, state: int) -> void:
	global_position = pos
	grid_mover.note_move("network")
	var minion_state := state as MinionSenses.State
	if minion_state != _last_state:
		_show_alertness(minion_state)
	_last_state = minion_state

func _ready() -> void:
	add_to_group("antagonist")
	_base_move_time = grid_mover.move_time
	_light_map = get_tree().current_scene.find_child("LightMap", true, false)
	if default_minion_type != "":
		set_minion_type(default_minion_type)
	_home_position = global_position
	stats.died.connect(queue_free)
	tree_exiting.connect(func(): bosses.erase(self))
	# Which doors this minion may open depends on its "doors" field (see set_minion_type).
	grid_mover.open_predicate = func(door: DoorRegistry.Door) -> bool:
		return _can_open_doors and (door.transparent or _last_state != MinionSenses.State.PATROL)

## Minions are always host-owned (see MinionSpawning.spawn_one) -- a client
## never runs AI for one, it only ever renders whatever position/state the
## host last relayed, the same split PlayerController uses for a remote peer's
## body (animate_from_position instead of reading local input).
func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_process_inner(delta)
	DebugState.add_time("minion AI", Time.get_ticks_usec() - started)

func _process_inner(delta: float) -> void:
	if not is_multiplayer_authority():
		animator.animate_from_position(delta, global_position)
		return
	# Boss privilege: an ally standing in a boss's way steps aside before anything else.
	if not bosses.is_empty() and not is_boss and not grid_mover.is_moving and _yield_to_boss():
		return
	# Aggro validity runs BEFORE the idle-skip / boxed-in early returns below so
	# a waiting minion still notices a dead, ghost or freed target.
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
	# A boxed-in minion can't act on senses/targeting/attacking anyway (it has
	# nowhere to go and, per _try_direct_step, isn't in attack range either --
	# that case never sets _stuck), and it can only ever be freed by some
	# OTHER body moving off a neighboring tile, not by anything this minion's
	# own full AI tick would decide. So skip straight to the cheap re-check
	# instead of repeating the same doomed senses/relay/animate work every
	# frame -- in the packed development stress room this is most of the 500+
	# minions most of the time.
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
		if state == MinionSenses.State.PATROL:
			_lock = null
		elif _lock == null and _target != null and state == MinionSenses.State.ATTACK:
			_lock = _target
			_unreachable_since_msec = 0
			_blocked_since_msec = 0
	var is_engaging := state == MinionSenses.State.ATTACK
	# Attack chases the player; Investigate walks to the spot (a Sound marker), never the player.
	var goal: Node2D = _target
	if state == MinionSenses.State.INVESTIGATE:
		goal = senses.investigate_marker if is_instance_valid(senses.investigate_marker) else null
	var is_tracking := goal != null and state != MinionSenses.State.PATROL
	if state != _last_state:
		_show_alertness(state)
	_last_state = state
	# Only tell peers when something they'd render changed (plus a slow
	# heartbeat so a late joiner still gets a parked minion's position).
	if state != _relayed_state or global_position != _relayed_position or Time.get_ticks_msec() - _relayed_msec > RELAY_HEARTBEAT_MSEC:
		_relayed_state = state
		_relayed_position = global_position
		_relayed_msec = Time.get_ticks_msec()
		NetworkSync.relay_minion_state(int(str(name)), global_position, state)

	var can_attack := is_engaging and _target and _in_attack_range(_target)
	if grid_mover.is_moving:
		animator.animate_moving(grid_mover.facing_direction)
	elif can_attack:
		animator.animate_facing(_target.global_position - global_position)
	else:
		animator.animate_idle()
	var used_special := is_engaging and not _specials.is_empty() and is_instance_valid(_target) and _try_specials(_target, delta)
	if can_attack and not used_special:
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
	# minion's own move_time allows, same as a player holding a direction key.
	# Investigate closes in the same way but at half speed (see _try_move),
	# and never attacks even if it ends up adjacent. Only idle wandering
	# stays throttled by wander_interval.
	if is_tracking:
		var reached_range := _in_attack_range(goal)
		if not reached_range:
			if is_boss and _make_way_for_allies(goal):
				return
			_try_pursue_step(goal, is_engaging)
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

## Ticks every special's cooldown (they run down even while out of range) and fires
## the first one that is ready and in range, at most one per tick. Returns true if one
## fired, so the default attack holds off that tick.
func _try_specials(target: Node2D, delta: float) -> bool:
	var fired := false
	for special in _specials:
		special["timer"] = maxf(special["timer"] - delta, 0.0)
		if fired or special["timer"] > 0.0:
			continue
		if not _in_range(target, special["range"], special["sight"]):
			continue
		# "only_through_walls": fire only when a wall is between us and the target, so a
		# wall-breaker does not chew the scenery while the way to the target is open.
		# The way counts as open only if the whole body fits along it: a 2x2 boss facing a 1-wide gap
		# has a clear line of sight through it but cannot follow, so it must still smash.
		if special["through_walls"] and _body_can_walk_line_to(target):
			continue
		if ActionRunner.perform(self, target.global_position, special["attack"]):
			special["timer"] = special["interval"]
			fired = true
	return fired

## True when a straight line to `target` is open for this whole body (footprint-aware, like
## walking), not just for a point.
func _body_can_walk_line_to(target: Node2D) -> bool:
	var target_tile := _to_tile(target.global_position)
	var fits := func(tile: Vector2i) -> bool:
		return tile != target_tile and grid_mover.is_tile_blocked(tile)
	return LineOfSight.clear(_to_tile(global_position), target_tile, fits)

## `attack` is one attack entry (amount, type, effect); empty = the default attack.
func _perform_attack(target: Node2D, attack: Dictionary = {}) -> void:
	if attack.is_empty():
		attack = _primary_attack
	ActionRunner.perform(self, target.global_position, attack)

## One-shot icon above the minion's head on any alert-state change -- which of
## Alertness.png's 3 frames shows depends on the state just entered (see
## ALERTNESS_FRAME): returning to Patrol, Investigate, or Attack. Held
## statically for ALERTNESS_HOLD_SECONDS rather than animated as a sequence.
## Parented to the minion itself (not current_scene, like the swing/hit
## effects) so it tracks as the minion keeps moving during the 3s hold instead
## of staying pinned to wherever it spawned.
func _show_alertness(state: MinionSenses.State) -> void:
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

## See _make_way_for_allies: how far away an ally is looked for, and how long the boss holds still.
const MAKE_WAY_TILES := 4
const MAKE_WAY_MSEC := 1500
var _make_way_until_msec := 0

## FlowField shares one map per key, and a map is only right for one body size (a 2x2 boss
## cannot use the route a rat takes through a 1-wide gap), so the key carries the size.
func _flow_key(target_id: int) -> Array:
	return [target_id, size_tiles]

## Step toward the target, shared by both Investigate and Attack tracking --
## this is the one place either of them actually moves. full_speed is false
## while merely Investigating (half speed, see _try_move).
##
## Tries three tiers in order, cheapest/most-shared first:
## 1. FlowField -- shared across every minion chasing this same target, so a
##    whole crowd (the swarm room) pays for one BFS between them instead of
##    one search each. Only covers cells within FlowField.RADIUS of the
##    target, and only knows about walls, not occupancy (see FlowField.gd).
## 2. LOS-clear direct stepping (_try_direct_step) or a real, per-minion
##    cached search (_try_pathfind_step) toward the target -- or, if the
##    target is farther than this minion's own search can ever reach, toward
##    the next room's door instead (RoomGraph.next_waypoint), so a
##    cross-dungeon chase advances room by room instead of just giving up.
func _try_pursue_step(target: Node2D, full_speed: bool) -> void:
	if _in_attack_range(target):
		return
	var origin_cell := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)

	if _try_surround_step(target, origin_cell, target_cell, full_speed):
		return

	var flow_step := FlowField.get_step(_flow_key(target.get_instance_id()), target_cell, origin_cell, grid_mover.is_tile_blocked, _terrain_cost())
	if flow_step != Vector2i.ZERO:
		_unreachable_since_msec = 0
		# FlowField only routes around walls, same as _try_direct_step's own
		# occupancy handling below -- if occupancy alone is in the way, wait
		# rather than fall through to a real search that would just recommend
		# this exact same blocked step.
		if not grid_mover.is_tile_occupied(origin_cell + flow_step):
			_try_move(Vector2(flow_step), full_speed)
		elif not _try_swap_with_ranged(origin_cell + flow_step):
			_try_detour_step(target, origin_cell, target_cell, full_speed)
		return

	var local_target := target_cell
	var distance := maxi(absi(target_cell.x - origin_cell.x), absi(target_cell.y - origin_cell.y))
	if distance > PATHFIND_RADIUS_MAX and RoomGraph.current != null:
		var waypoint := RoomGraph.current.next_waypoint(origin_cell, target_cell)
		if waypoint != Vector2i.ZERO:
			local_target = waypoint

	if not LineOfSight.clear(origin_cell, local_target, grid_mover.is_tile_blocked):
		_try_pathfind_step(origin_cell, local_target, full_speed)
		# No route (a wall-breaker's target walled in): walk straight at it until the wall
		# is in smashing range, instead of standing where no special can reach.
		if not grid_mover.is_moving and _can_break_walls():
			_try_direct_step(origin_cell, local_target, full_speed, target)
		return
	_try_direct_step(origin_cell, local_target, full_speed, target)

## Melee minions near their target fan out around it instead of queueing
## single file. FlowField.get_distances gives each tile's walking distance to
## the target -- tiles at the same distance form a "layer" (a square ring)
## around it, and there's no fixed cap on how many layers there are. Each
## step: prefer a free neighbor one layer closer, choosing whichever leads into
## the least crowded of 16 pie slices around the target (SurroundSectors); if
## none is free, sidestep to a free tile that has a free way forward of its
## own (never straight back to the tile it just left, which keeps two rats from
## trading places forever). Returns false (caller uses the normal chase) for
## ranged minions or ones too far / unreachable.
const SURROUND_RADIUS := 12
## How much longer (in tile-steps of time) a route has to be than plain ground before the surround
## step stops fanning out and sticks to the quickest route.
const TERRAIN_MATTERS_EXTRA := 0.75

## Time one step from `cell` takes for this walker: its length times the average terrain cost of
## the two tiles, the same sum FlowField uses to build its times.
func _step_time(cell: Vector2i, step: Vector2i) -> float:
	var length := FlowField.DIAGONAL_LENGTH if step.x != 0 and step.y != 0 else 1.0
	return length * (grid_mover.tile_cost(cell) + grid_mover.tile_cost(cell + step)) * 0.5
const SLIDE_COOLDOWN_MSEC := 1500
var _slide_ready_msec := 0
var _prev_cell := Vector2i.ZERO

func _try_surround_step(target: Node2D, origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool) -> bool:
	# The fan-out is built for 1x1 bodies; a big one just walks straight at its target.
	if size_tiles > 1 or _attack_range != 1 or _cheb(target_cell - origin_cell) > SURROUND_RADIUS:
		return false
	var target_id := target.get_instance_id()
	var distances := FlowField.get_distances(_flow_key(target_id), target_cell, grid_mover.is_tile_blocked)
	if not distances.has(origin_cell):
		return false
	var here: int = distances[origin_cell]
	# A walker on uneven ground only takes steps that get it there sooner (not merely nearer), or
	# the fan-out would drift along a tie into water or acid the flow field would have gone round.
	var times := {}
	var terrain_matters := false
	if _terrain_cost().is_valid():
		times = FlowField.get_times(_flow_key(target_id), target_cell, grid_mover.is_tile_blocked, _terrain_cost())
		# On plain ground the time is just the walking distance; well above that, slow ground is
		# steering the route, and then only steps ON the quickest route are safe to fan out with.
		var offset := (target_cell - origin_cell).abs()
		var ideal: float = maxi(offset.x, offset.y) + (FlowField.DIAGONAL_LENGTH - 1.0) * mini(offset.x, offset.y)
		terrain_matters = float(times.get(origin_cell, ideal)) > ideal + TERRAIN_MATTERS_EXTRA
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
		if not times.is_empty() and float(times.get(next_cell, INF)) >= float(times.get(origin_cell, INF)):
			avoided_hazard = true  # nearer but not sooner: leave it to the weighted chase below
			continue
		if terrain_matters and _step_time(origin_cell, step) + float(times.get(next_cell, INF)) > float(times[origin_cell]) + 0.01:
			avoided_hazard = true  # not on the quickest route round the slow ground
			continue
		if not _step_open(origin_cell, step):
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
	# Every way forward is taken: sidestep at right angles to a blocked way
	# forward, onto a free tile that has a free way forward of its own, toward
	# the emptier slice. The sidestep usually stays on the same layer (a tile
	# beside this one is often the same number of steps from the target).
	if best_step == Vector2i.ZERO:
		for forward in blocked_forward:
			for side_dir in [Vector2i(-forward.y, forward.x), Vector2i(forward.y, -forward.x)]:
				var side_cell: Vector2i = origin_cell + side_dir
				if side_cell == _prev_cell or not distances.has(side_cell) or grid_mover.is_tile_occupied(side_cell):
					continue
				if not _step_open(origin_cell, side_dir):
					continue
				var ahead: Vector2i = side_cell + forward
				if not distances.has(ahead) or grid_mover.is_tile_occupied(ahead) or not _step_open(side_cell, forward):
					continue
				var score: int = sector_count.call(side_cell) * 2 + ((get_instance_id() + side_dir.x + side_dir.y * 2) & 1)
				if score < best_score:
					best_score = score
					best_step = side_dir
	if best_step == Vector2i.ZERO:
		for forward in blocked_forward:
			if _try_swap_with_ranged(origin_cell + forward):
				return true
	if best_step == Vector2i.ZERO and avoided_hazard:
		return false  # only hazard tiles lead closer: use the weighted chase instead
	var chosen := best_step
	if chosen != Vector2i.ZERO and _try_move(Vector2(chosen), full_speed):
		_prev_cell = origin_cell
	return true

## The step toward the target is only blocked by another creature (a ranged minion
## standing and shooting, a big body in a corridor mouth): take a free neighbouring
## tile that keeps us about as close instead of waiting behind it. Uses the same
## flow-field distances as the surround step, allows one tile of sidestep, never
## steps straight back to the tile it just left (no ping-pong), and skips hazard
## terrain. Returns true if it moved.
var _detour_prev := Vector2i.ZERO

func _try_detour_step(target: Node2D, origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool) -> bool:
	var distances := FlowField.get_distances(_flow_key(target.get_instance_id()), target_cell, grid_mover.is_tile_blocked)
	if not distances.has(origin_cell):
		return false
	var here: int = distances[origin_cell]
	var best_step := Vector2i.ZERO
	var best_score := 1 << 30
	for direction in MOVE_DIRECTIONS:
		var step := Vector2i(direction)
		var next_cell := origin_cell + step
		if next_cell == _detour_prev or not distances.has(next_cell) or distances[next_cell] > here + 1:
			continue
		if not _step_open(origin_cell, step) or grid_mover.is_tile_occupied(next_cell):
			continue
		if grid_mover.tile_cost(next_cell) > HAZARD_COST and grid_mover.tile_cost(origin_cell) <= HAZARD_COST:
			continue
		if not is_boss and not bosses.is_empty() and _in_boss_zone(next_cell):
			continue
		var score: int = int(distances[next_cell]) * 2 + ((get_instance_id() + step.x + step.y * 2) & 1)
		if score < best_score:
			best_score = score
			best_step = step
	if best_step == Vector2i.ZERO:
		return false
	if _try_move(Vector2(best_step), full_speed):
		_detour_prev = origin_cell
		return true
	return false

## A melee minion whose way forward is blocked by a ranged ally that is already shooting (in
## range of its own target, standing still) swaps places with it: the shooter does not need the
## front, and in a corridor nobody can step aside. They walk through each other one tile, not jump. Only 1x1 bodies swap. Returns true if it did.
func _try_swap_with_ranged(tile: Vector2i) -> bool:
	if _attack_range != 1 or size_tiles > 1 or grid_mover.is_moving:
		return false
	var here := _to_tile(global_position)
	for other in grid_mover.occupants_at(tile):
		if not is_instance_valid(other) or not (other is MinionController) or other == self or other.size_tiles > 1 or other.is_boss:
			continue
		if other._attack_range <= 1 or other.grid_mover.is_moving or not is_instance_valid(other._target):
			continue
		if not other._in_attack_range(other._target) or _cheb(_to_tile(other.global_position) - here) != 1:
			continue
		if not grid_mover.swap_step(Vector2(_to_tile(other.global_position) - here), other.grid_mover):
			continue
		other._wake_up()
		return true
	return false

## Has a special that only fires through a wall (json "only_through_walls").
func _can_break_walls() -> bool:
	for special in _specials:
		if special["through_walls"]:
			return true
	return false

## The tiles a boss claims: its own body, plus the body's next step when it is
## heading for a target. Allies keep out of it and step out when caught inside.
func boss_zone() -> Rect2i:
	var top_left := _to_tile(global_position)
	var body := Vector2i(size_tiles, size_tiles)
	var zone := Rect2i(top_left, body)
	if _target != null:
		zone = zone.merge(Rect2i(top_left + Vector2i(grid_mover.facing_direction.round()), body))
	return zone

func _in_boss_zone(tile: Vector2i) -> bool:
	for boss in bosses:
		if is_instance_valid(boss) and boss != self and boss.boss_zone().has_point(tile):
			return true
	return false

## Boss privilege, ally side: caught inside a boss's zone, step to a free tile
## outside it (or, when none is next to us, the free neighbour farthest from the
## boss). Returns true if it moved, so the rest of this tick is skipped and the
## normal AI cannot walk straight back in.
func _yield_to_boss() -> bool:
	var my_tile := _to_tile(global_position)
	for boss in bosses:
		if not is_instance_valid(boss) or boss == self:
			continue
		var zone := boss.boss_zone()
		if not zone.has_point(my_tile):
			continue
		var centre := Vector2(zone.position) + Vector2(zone.size) / 2.0
		var best := Vector2.ZERO
		var best_score := -1.0e9
		for direction in MOVE_DIRECTIONS:
			var next_cell := my_tile + Vector2i(direction)
			if not _step_open(my_tile, Vector2i(direction)) or grid_mover.is_tile_occupied(next_cell):
				continue
			var score := Vector2(next_cell).distance_to(centre) + (100.0 if not zone.has_point(next_cell) else 0.0)
			if score > best_score:
				best_score = score
				best = direction
		if best != Vector2.ZERO:
			_wake_up()
			# Move directly: _try_move refuses tiles inside a boss zone.
			return grid_mover.move_one_tile(best, 1.0)
	return false

## Boss with no route to its target (a gap it cannot fit, a wall it is about to smash): if a
## smaller ally's next step toward the same target is inside this boss's body, step one tile
## away and hold there for MAKE_WAY_MSEC so the ally can get by and find its own way round.
## Returns true while making way (the boss then does nothing else this tick).
func _make_way_for_allies(target: Node2D) -> bool:
	var now := Time.get_ticks_msec()
	if now < _make_way_until_msec:
		return true
	var here := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)
	if FlowField.get_step(_flow_key(target.get_instance_id()), target_cell, here, grid_mover.is_tile_blocked, _terrain_cost()) != Vector2i.ZERO:
		return false  # it has a route: it moves on by itself
	var body := Rect2i(here, Vector2i(size_tiles, size_tiles))
	var blocked_ally_tile := Vector2i.ZERO
	var found := false
	for other in get_tree().get_nodes_in_group("antagonist"):
		if not is_instance_valid(other) or not (other is MinionController) or other == self or other.is_boss or other.size_tiles > 1:
			continue
		var ally_tile: Vector2i = _to_tile(other.global_position)
		if _cheb(ally_tile - here) > MAKE_WAY_TILES:
			continue
		var step := FlowField.get_step([target.get_instance_id(), 1], target_cell, ally_tile, other.grid_mover.is_tile_blocked, other._terrain_cost())
		if step != Vector2i.ZERO and body.has_point(ally_tile + step):
			blocked_ally_tile = ally_tile
			found = true
			break
	if not found:
		return false
	var best := Vector2i.ZERO
	var best_score := -1.0e9
	for direction in MOVE_DIRECTIONS:
		var step := Vector2i(direction)
		if not _step_open(here, step) or grid_mover.is_tile_occupied(here + step):
			continue
		var score := Vector2(here + step).distance_to(Vector2(blocked_ally_tile))
		if score > best_score:
			best_score = score
			best = step
	if best == Vector2i.ZERO:
		return false
	_make_way_until_msec = now + MAKE_WAY_MSEC
	grid_mover.move_one_tile(Vector2(best), 1.0)
	return true

## A melee minion already touching its target that has another creature
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
		if not _step_open(origin_cell, Vector2i(direction)) or grid_mover.is_tile_occupied(side):
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

## Wall-wise, can this minion step from `origin_cell` to the neighbour `step`
## away? A straight step only needs that tile open; a diagonal also must not
## cut a wall corner or pass through a doorway (GridMover.can_step_diagonally).
## Occupancy is separate (grid_mover.is_tile_occupied).
func _step_open(origin_cell: Vector2i, step: Vector2i) -> bool:
	if grid_mover.is_tile_blocked(origin_cell + step):
		return false
	return step.x == 0 or step.y == 0 or grid_mover.can_step_diagonally(origin_cell, step)

## Fast path for the common case (open rooms, short corridors): with a clear
## line to the target, just step straight toward it -- diagonally when the
## target is off both axes, then the axis with the bigger offset, then the
## other, as fallbacks -- instead of paying for a full grid search. (Any order
## is equally short, as long as it takes one diagonal per tile the smaller
## offset has.) Falls back to _try_pathfind_step only if a wall (not just a
## crowded tile) actually blocks every preferred direction, since that's the
## one case a real search can do something about. If both directions are
## merely occupied by another creature, that's deliberately left alone:
## Pathfinding.full_path doesn't know about occupancy either, so it would
## just recompute this exact same step and waste a search on a wall that was
## never the problem -- better to wait a frame and let whoever's in the way
## move first.
func _try_direct_step(origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool, target: Node2D = null) -> void:
	var offset := target_cell - origin_cell
	var x_step := Vector2(signf(offset.x), 0.0)
	var y_step := Vector2(0.0, signf(offset.y))
	var candidates: Array[Vector2] = []
	if x_step != Vector2.ZERO and y_step != Vector2.ZERO:
		candidates.append(x_step + y_step)
	if absi(offset.x) >= absi(offset.y):
		candidates.append_array([x_step, y_step])
	else:
		candidates.append_array([y_step, x_step])
	var saw_wall := false
	for direction in candidates:
		if direction == Vector2.ZERO:
			continue
		var step_tile := origin_cell + Vector2i(direction)
		if grid_mover.is_tile_blocked(step_tile):
			saw_wall = true
			continue
		# A wall corner or doorway the diagonal can't squeeze past: the straight
		# steps come next (a corner's wall is found, and counted, there).
		if direction.x != 0.0 and direction.y != 0.0 and not grid_mover.can_step_diagonally(origin_cell, Vector2i(direction)):
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
	elif target != null and target_cell == _to_tile(target.global_position):
		# Only creatures in the way: go around them instead of waiting behind them.
		_try_detour_step(target, origin_cell, target_cell, full_speed)

## Tiles costing more than this (difficult 2.0, severe 5.0; rough 1.25 is fine)
## are not stepped onto blindly by _try_direct_step.
const HAZARD_COST := 1.5

## The terrain cost callable for routes, or an unset one for a flyer (its
## routes then use the plain, unweighted field and search).
func _terrain_cost() -> Callable:
	return Callable() if grid_mover.flies else grid_mover.tile_cost

## Real pathfinding step for when the direct approach can't work -- no clear
## line to the target, or a wall blocks both preferred directions and a
## detour is actually needed. First tries to keep following this minion's own
## cached route (_next_cached_step) instead of re-solving an identical
## AStarGrid2D every frame for a target that's barely moved; only falls
## through to an actual solve (budget-gated, see MAX_PATHFINDS_PER_FRAME)
## when the cache can't answer.
func _try_pathfind_step(origin_cell: Vector2i, target_cell: Vector2i, full_speed: bool) -> void:
	var step := _next_cached_step(origin_cell, target_cell)
	if step == Vector2i.ZERO:
		step = _solve_and_cache_path(origin_cell, target_cell)
	if step == Vector2i.ZERO:
		return
	if step.x != 0 and step.y != 0 and not grid_mover.can_step_diagonally(origin_cell, step):
		# AStarGrid2D already avoids wall corners but knows nothing about doors,
		# so it can plan a diagonal through a wide doorway that GridMover then
		# refuses: take it as two straight steps instead (the cached route
		# still accepts the diagonal's tile as the next one, one step away).
		if not _try_move(Vector2(step.x, 0), full_speed):
			_try_move(Vector2(0, step.y), full_speed)
		return
	_try_move(Vector2(step), full_speed)

## Per-minion path cache (technique 4/5 from the Factorio pathfinding
## research: reuse + negative caching), distinct from FlowField's shared
## per-target cache -- this is for the individual, often-distant search this
## minion alone needed (FlowField didn't cover the cell, or a wall forced a
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
	if _cheb(step) != 1:
		# _try_pursue_step can hop this minion over to _try_direct_step on a
		# frame where line of sight happens to open up, moving it somewhere
		# the cached route never accounted for -- a stale route handed
		# straight to _try_move here would multiply a multi-tile offset by
		# tile_size and warp the minion instead of taking one legal step, so
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
## uses for vision) -- a ranged minion standing behind a wall is in range but
## not in sight, so this returns false and _try_pursue_step keeps closing in
## instead of shooting through the wall.
func _in_attack_range(target: Node2D) -> bool:
	return _in_range(target, _attack_range, true)

## The same check for any reach (a special attack's own range_tiles). `needs_sight`
## false skips the line-of-sight test, for attacks that work through walls.
func _in_range(target: Node2D, reach: int, needs_sight: bool = true) -> bool:
	var origin_cell := _to_tile(global_position)
	var target_cell := _to_tile(target.global_position)
	var offset := target_cell - origin_cell
	# A big body reaches from any tile of its footprint, not only its top-left one.
	var reach_far := reach + size_tiles - 1
	if offset.x < -reach or offset.x > reach_far or offset.y < -reach or offset.y > reach_far:
		return false
	return not needs_sight or LineOfSight.clear(origin_cell, target_cell, grid_mover.blocks_shot)

## True when all 8 neighbor tiles are blocked or occupied -- a
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
		if _step_open(origin_cell, Vector2i(direction)) and not grid_mover.is_tile_occupied(tile):
			return false
	return true

func _try_move(direction: Vector2, full_speed: bool = true) -> bool:
	var target_tile := _to_tile(global_position + direction * grid_mover.tile_size)
	_debug_step_tile = target_tile
	_debug_step_msec = Time.get_ticks_msec()
	if grid_mover.is_tile_blocked(target_tile) or grid_mover.is_tile_occupied(target_tile):
		return false
	if not is_boss and not bosses.is_empty() and _in_boss_zone(target_tile):
		return false
	var moved := grid_mover.move_one_tile(direction, 1.0 if full_speed else INVESTIGATE_SPEED_SCALE)
	if moved:
		_unreachable_since_msec = 0
	return moved

## Not freed and not a ghost -- the only things that make a locked target
## invalid right away. Takes an untyped arg so a freed node is safe to pass.
func _is_valid_target(target) -> bool:
	return is_instance_valid(target) and not target.stats.is_ghost

## Makes a waiting / boxed-in minion run a full AI tick next frame.
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

## Noise entry points (host-side, from Sound.make): whether this minion's ears reach the
## spot, and the order to go and look at its marker. Ignored while it is already attacking.
func can_hear(noise_position: Vector2, loudness: float) -> bool:
	return is_multiplayer_authority() and senses.hearing.hears(global_position, noise_position, loudness)

func hear_noise(marker: Node2D) -> void:
	senses.hear(marker)
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

## Called when this minion just failed to advance. If a living non-target
## player is on an adjacent tile that is closer to the locked target than we
## are (i.e. standing in the way), start / keep the blocked timer; otherwise
## clear it. Ranged minions never count (they don't need to walk up).
func _note_blocked_by_player(now: int) -> void:
	if _attack_range > 1 or _override != null or not is_instance_valid(_lock):
		_blocked_since_msec = 0
		return
	var origin := _to_tile(global_position)
	var lock_tile := _to_tile(_lock.global_position)
	var origin_dist := _cheb(origin - lock_tile)
	var found = null
	for player in get_tree().get_nodes_in_group("protagonist"):
		if player == _lock or player.stats.is_ghost:
			continue
		var tile := _to_tile(player.global_position)
		if _cheb(tile - origin) != 1:
			continue
		if _cheb(tile - lock_tile) >= origin_dist:
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

## The 8 neighbouring tiles, straight ones first. Diagonal steps obey
## GridMover.can_step_diagonally (no cutting wall corners or doorways).
const MOVE_DIRECTIONS: Array[Vector2] = [
	Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
]

func _try_wander_step() -> void:
	var direction: Vector2 = MOVE_DIRECTIONS.pick_random()
	var target := global_position + direction * grid_mover.tile_size
	if target.distance_to(_home_position) > wander_radius_tiles * grid_mover.tile_size:
		return
	grid_mover.move_one_tile(direction)
