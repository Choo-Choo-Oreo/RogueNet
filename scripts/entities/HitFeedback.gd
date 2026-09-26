class_name HitFeedback
extends Node

## What a hit sounds like, for players and minions alike. Listens to its body's EntityStats
## (damaged, died, health_changed), which fire on every peer, and never touches game state.
## On every peer: a player's hurt sound (by what hurt it) or a minion's impact, "block" when
## resistances stopped the whole hit; a minion's death. Heard through walls and doors like
## every sound (CombatSounds).
## Only on the hurt player's own machine: a grunt now and then, and a heartbeat while health
## is under LOW_HEALTH.
## Silvery's branch adds the looks here (flash, damage numbers, shake, hurt overlay); see
## docs/SILVERY_MERGE_TRACKER.md.

## Grunts at most this often (game seconds), so a swarm folds into a steady rhythm.
const MIN_GAP := 0.25
const LOW_HEALTH := 0.25
## About one hit in GRUNT_CHANCE grunts, never twice running.
const GRUNT_CHANCE := 3
const HEARTBEAT_SECONDS := 1.1
const GRUNT_VOLUME_DB := -3.0
const HEARTBEAT_VOLUME_DB := -6.0

var _body: Node2D
var _stats: EntityStats
var _is_player := false
var _last_grunt_msec := -100000
var _last_grunt := false
var _low := false
var _next_beat_msec := 0

func setup(body: Node2D, stats: EntityStats) -> void:
	_body = body
	_stats = stats
	_is_player = body.is_in_group("protagonist")
	stats.damaged.connect(_on_damaged)
	if _is_player:
		stats.health_changed.connect(_on_health_changed)
		GameTick.ticked.connect(_on_tick)
	else:
		stats.died.connect(_on_died)

## A minion's tags, from its json (they change with its type, so read when needed).
func _tags() -> Array:
	var id = _body.get("minion_id")
	return MinionIndex.load_data(str(id)).get("tags", []) if id else []

func _is_local_player() -> bool:
	return _is_player and _body.is_multiplayer_authority()

func _on_damaged(amount: int, type: String, cause: String) -> void:
	if not _body.is_inside_tree():
		return
	if amount <= 0 or not _is_player:
		CombatSounds.play_impact(_body, _tags(), amount, cause)
		return
	CombatSounds.play_hurt(_body, type, cause, float(_stats.current_health) / float(maxi(_stats.max_health, 1)))
	if _is_local_player() and _stats.current_health > 0:
		_grunt()

func _grunt() -> void:
	var now := GameTick.msec()
	if now - _last_grunt_msec < int(MIN_GAP * 1000.0):
		return
	_last_grunt_msec = now
	if _last_grunt or randi() % GRUNT_CHANCE != 0:
		_last_grunt = false
		return
	_last_grunt = true
	var grunts := SoundPlayer.numbered(CombatSounds.PROTAGONIST_DIR + "grunt")
	if not grunts.is_empty():
		SoundPlayer.play(_body, grunts.pick_random(), {"jitter": 0.05, "max_voices": 1, "volume_db": GRUNT_VOLUME_DB})

func _on_health_changed(current: int, max_health: int) -> void:
	if _is_local_player():
		_low = current > 0 and float(current) / float(maxi(max_health, 1)) < LOW_HEALTH

func _on_tick(_tick: int) -> void:
	if not _low or not is_inside_tree():
		return
	var now := GameTick.msec()
	if now >= _next_beat_msec:
		_next_beat_msec = now + int(HEARTBEAT_SECONDS * 1000.0)
		SoundPlayer.play(_body, CombatSounds.PROTAGONIST_DIR + "heartbeat.wav", {"volume_db": HEARTBEAT_VOLUME_DB, "max_voices": 1})

func _on_died() -> void:
	CombatSounds.play_death(_body, _tags())
