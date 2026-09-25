class_name MinionSenses
extends Node

## Interprets the raw per-sense checks into one alert state for the minion to
## act on. Touch and Sight (a direct, unobstructed detection) fire straight
## to Attack -- full pursuit speed, will engage once in range. Being lit by
## the target's actual light without a direct detection (e.g. round a corner
## from a clear line of sight) fires Investigate instead -- half-speed, closes
## in on the target's location but won't attack even if it arrives adjacent;
## next tick's direct check is what promotes it to Attack. Hearing is heard
## by event, not checked here: Sound tells the minion (hear) and it goes to look
## at the spot. Investigate always walks to `investigate_marker`, a place, never
## the player. Smell/Taste are still unbuilt stubs that always pass. See the
## minion senses design memory for the full planned behavior.

enum State { PATROL, INVESTIGATE, ATTACK }

## Once a sense actually fires, stay at that tier for this long even if every
## check fails on later ticks -- only reverts to Patrol if nothing re-fires
## within the window. See the minion senses design memory's "active window".
const ACTIVE_ALERT_SECONDS := 10.0

@onready var sight: SenseSight = $SenseSight
@onready var touch: SenseTouch = $SenseTouch
@onready var hearing: SenseHearing = $SenseHearing
@onready var smell: SenseSmell = $SenseSmell
@onready var taste: SenseTaste = $SenseTaste

var state: State = State.PATROL
var _active_timer := 0.0
var _active_tier: State = State.PATROL

## Where Investigate is heading: a Sound marker (a spot, see Sound). Invalid outside Investigate.
var investigate_marker: Node2D

## Which sense last raised the alert, for the debug overlay: "touch", "sight", "smell", "taste",
## "hearing", "light" (lit by the player's glow), "hit", "pack" (a packmate raised the alarm) or "" (nothing yet / gave up).
var last_trigger := ""
## How much of its hearing budget the last sound it heard had spent getting here (debug inspector).
var last_heard_cost := -1.0

## Getting hit always means the minion now knows roughly where its attacker
## is, even with no direct sense of them (e.g. shot from off-screen or from
## behind) -- forces Attack and (re)starts the same sticky window as a real
## detection. Simple fallback: it doesn't track who actually hit it, just
## goes straight for whichever player update() finds nearest next tick.
func note_hit(trigger := "hit") -> void:
	last_trigger = trigger
	_active_timer = ACTIVE_ALERT_SECONDS
	_active_tier = State.ATTACK

## A noise was heard at `marker`: go and look, unless already attacking someone. The newest
## noise wins if this minion was already investigating another.
func hear(marker: Node2D, trigger := "hearing") -> void:
	if state == State.ATTACK:
		return
	investigate_marker = marker
	last_trigger = trigger
	_active_timer = ACTIVE_ALERT_SECONDS
	_active_tier = State.INVESTIGATE
	state = State.INVESTIGATE

## Gives up entirely (leash / unreachable target): drops the sticky window so
## the minion falls back to Patrol until a sense fires again.
func forget() -> void:
	_active_timer = 0.0
	_active_tier = State.PATROL
	state = State.PATROL
	investigate_marker = null
	last_trigger = ""

## Per-minion-type toggle, e.g. rat_blind's "senses": {"sight": false} JSON
## key -- keys match this node's own property names (touch/sight/hearing/
## smell/taste). A plain bool is shorthand for "enabled"; a dictionary (e.g.
## rat_blind's "senses": {"hearing": {"range_tiles": 15.0}}) instead sets
## whichever @export properties of that sense it names, so this stays
## generic as more senses -- and more per-sense tuning -- come online.
func apply_overrides(overrides: Dictionary) -> void:
	for key: String in overrides:
		var sense: Node = get(key)
		if sense == null:
			continue
		var value = overrides[key]
		if value is Dictionary:
			for prop: String in value:
				sense.set(prop, value[prop])
		else:
			sense.enabled = value

## origin/is_blocked describe the owning entity's position and tile-blocked
## check (e.g. MinionController's GridMover) -- kept as parameters rather
## than a stored reference, same reasoning as the sense components use.
## lit is whether the target's real light (the same LightMap the local
## player's own vision uses, not an approximated radius) currently touches
## origin's tile -- being seen gives you away even without a clear line back.
## Only a creature with sight notices it (a blind one ignores light).
## delta is the time since the last call (not necessarily a frame -- callers
## may throttle how often they call update()).
func update(origin: Vector2, target: Node2D, is_blocked: Callable, lit: bool, delta: float) -> State:
	# Debug "unseen": every sense reads nothing, same as having no target at all.
	if target == null or DebugState.unseen:
		_active_timer = 0.0
		_active_tier = State.PATROL
		state = State.PATROL
		return state
	var direct := ""
	if touch.detects(origin, target):
		direct = "touch"
	elif sight.detects(origin, target, is_blocked):
		direct = "sight"
	elif smell.detects(origin, target):
		direct = "smell"
	elif taste.detects(origin, target):
		direct = "taste"
	if direct != "":
		last_trigger = direct
		_active_timer = ACTIVE_ALERT_SECONDS
		_active_tier = State.ATTACK
	elif lit and sight.enabled and state != State.ATTACK:
		# Noticing a light is seeing it: a creature without sight ignores it.
		last_trigger = "light"
		# The glow gives away where the light is: investigate that spot (once, not the player).
		if state != State.INVESTIGATE or not is_instance_valid(investigate_marker):
			investigate_marker = Sound.marker_at(target.get_tree(), target.global_position)
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
