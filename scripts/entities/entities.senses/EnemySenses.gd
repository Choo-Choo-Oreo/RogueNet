class_name EnemySenses
extends Node

## Interprets the raw per-sense checks into one alert state for the enemy to
## act on. Touch and Sight (a direct, unobstructed detection) fire straight
## to Attack -- full pursuit speed, will engage once in range. Being lit by
## the target's actual light without a direct detection (e.g. round a corner
## from a clear line of sight) fires Investigate instead -- half-speed, closes
## in on the target's location but won't attack even if it arrives adjacent;
## next tick's direct check is what promotes it to Attack. Hearing/Smell/
## Taste are still unbuilt stubs that always pass (never detect). See the
## enemy senses design memory for the full planned behavior.

enum State { PATROL, INVESTIGATE, ATTACK }

## Once a sense actually fires, stay at that tier for this long even if every
## check fails on later ticks -- only reverts to Patrol if nothing re-fires
## within the window. See the enemy senses design memory's "active window".
const ACTIVE_ALERT_SECONDS := 10.0

@onready var sight: SenseSight = $SenseSight
@onready var touch: SenseTouch = $SenseTouch
@onready var hearing: SenseHearing = $SenseHearing
@onready var smell: SenseSmell = $SenseSmell
@onready var taste: SenseTaste = $SenseTaste

var state: State = State.PATROL
var _active_timer := 0.0
var _active_tier: State = State.PATROL

## Getting hit always means the enemy now knows roughly where its attacker
## is, even with no direct sense of them (e.g. shot from off-screen or from
## behind) -- forces Attack and (re)starts the same sticky window as a real
## detection. Simple fallback: it doesn't track who actually hit it, just
## goes straight for whichever player update() finds nearest next tick.
func note_hit() -> void:
	_active_timer = ACTIVE_ALERT_SECONDS
	_active_tier = State.ATTACK

## Per-enemy-type toggle, e.g. rat_blind's "senses": {"sight": false} JSON
## key -- keys match this node's own property names (touch/sight/hearing/
## smell/taste), so this stays generic as more senses come online.
func apply_overrides(overrides: Dictionary) -> void:
	for key: String in overrides:
		var sense: Node = get(key)
		if sense:
			sense.enabled = overrides[key]

## origin/is_blocked describe the owning entity's position and tile-blocked
## check (e.g. EnemyController's GridMover) -- kept as parameters rather
## than a stored reference, same reasoning as the sense components use.
## lit is whether the target's real light (the same LightMap the local
## player's own vision uses, not an approximated radius) currently touches
## origin's tile -- being seen gives you away even without a clear line back.
## delta is the time since the last call (not necessarily a frame -- callers
## may throttle how often they call update()).
func update(origin: Vector2, target: Node2D, is_blocked: Callable, lit: bool, delta: float) -> State:
	if target == null:
		_active_timer = 0.0
		_active_tier = State.PATROL
		state = State.PATROL
		return state
	var direct_sense := (
		touch.detects(origin, target)
		or sight.detects(origin, target, is_blocked)
		or hearing.detects(origin, target)
		or smell.detects(origin, target)
		or taste.detects(origin, target)
	)
	if direct_sense:
		_active_timer = ACTIVE_ALERT_SECONDS
		_active_tier = State.ATTACK
	elif lit and state != State.ATTACK:
		# state (not _active_tier) is checked here on purpose: it's the tier
		# already decayed for the elapsed timer, so once a real Attack sticky
		# window has actually run out this correctly re-arms Investigate --
		# _active_tier alone would still read stale ATTACK from before it
		# decayed and permanently block ever re-entering Investigate.
		_active_timer = ACTIVE_ALERT_SECONDS
		_active_tier = State.INVESTIGATE
	else:
		_active_timer = maxf(_active_timer - delta, 0.0)
	state = _active_tier if _active_timer > 0.0 else State.PATROL
	return state
