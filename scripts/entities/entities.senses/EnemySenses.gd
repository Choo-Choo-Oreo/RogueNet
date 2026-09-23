class_name EnemySenses
extends Node

## Interprets the raw per-sense checks into one alert state for the enemy to
## act on. Touch and Sight both fire straight to Attack; Hearing/Smell/Taste
## are unbuilt stubs that always pass (never detect) for now, standing in for
## the Investigate state they'll eventually drive. So today this only ever
## toggles Patrol <-> Attack. See the enemy senses design memory for the full
## planned behavior.

enum State { PATROL, ATTACK }

## Once a sense actually fires, stay Attack for this long even if every sense
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
## delta is the time since the last call (not necessarily a frame -- callers
## may throttle how often they call update()).
func update(origin: Vector2, target: Node2D, is_blocked: Callable, delta: float) -> State:
	if target == null:
		_active_timer = 0.0
		state = State.PATROL
		return state
	var attack_sense := (
		touch.detects(origin, target)
		or sight.detects(origin, target, is_blocked)
		or hearing.detects(origin, target)
		or smell.detects(origin, target)
		or taste.detects(origin, target)
	)
	if attack_sense:
		_active_timer = ACTIVE_ALERT_SECONDS
	else:
		_active_timer = maxf(_active_timer - delta, 0.0)
	state = State.ATTACK if (attack_sense or _active_timer > 0.0) else State.PATROL
	return state
