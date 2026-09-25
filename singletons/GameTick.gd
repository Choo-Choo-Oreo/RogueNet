extends Node

## The game's fixed clock. Game rules (minion AI, senses, doors, cooldowns, the host's
## network state) run on `ticked`, TICKS_PER_SECOND times per second of game time, whatever
## the frame rate. Drawing (step tweens, animations, the camera) and this machine's own
## input stay per frame, so they are smooth and never lag.
##
## `speed` runs the whole game faster or slower than real time (Engine.time_scale, so tweens,
## animations and timers follow). Only offline or in headless sims: in multiplayer every
## machine has to run at 1.

## Emitted first each tick: movers finish the steps that are due (GridMover.on_tick), so
## every rule run on `ticked` sees where bodies really are.
signal steps_due(tick: int)
signal ticked(tick: int)
## Emitted last each tick, once every rule has run: the host sends what changed (NetworkSync).
signal tick_ended(tick: int)

const TICKS_PER_SECOND := 20
const TICK_SECONDS := 1.0 / TICKS_PER_SECOND

## A frame longer than this (a load, a breakpoint) only counts as this long, so the game
## slows down for a moment instead of running a burst of ticks to catch up.
const MAX_FRAME_SECONDS := 0.25

## Ticks run since the game started. Never reset: compare two ticks, don't store absolutes.
var tick := 0
var paused := false

## Game seconds waiting for the next tick (always below TICK_SECONDS).
var _carry := 0.0

var speed: float:
	get:
		return Engine.time_scale
	set(value):
		if value != 1.0 and NetworkSync.is_online():
			push_warning("GameTick: speed stays 1 in multiplayer")
			return
		Engine.time_scale = maxf(value, 0.0)

func _ready() -> void:
	# Before every other node's _process, so a frame sees this frame's ticks.
	process_priority = -1000

func _process(delta: float) -> void:
	# delta is already scaled by Engine.time_scale (speed).
	if not paused:
		advance(minf(delta, MAX_FRAME_SECONDS * speed))

## Moves game time on by `game_seconds`, running every tick that passes. _process calls it
## each frame; tests call it directly.
func advance(game_seconds: float) -> void:
	_carry += game_seconds
	while _carry >= TICK_SECONDS:
		_carry -= TICK_SECONDS
		tick += 1
		steps_due.emit(tick)
		ticked.emit(tick)
		tick_ended.emit(tick)

## Game time in seconds, counted in whole ticks.
func seconds() -> float:
	return tick * TICK_SECONDS

## Game time in milliseconds, including the part since the last tick. The drop-in for
## Time.get_ticks_msec() in game rules: it follows `speed` and stops while paused.
func msec() -> int:
	return roundi((tick * TICK_SECONDS + _carry) * 1000.0)

## How many ticks `duration` game seconds is, to the nearest tick.
static func ticks_for(duration: float) -> int:
	return roundi(duration * TICKS_PER_SECOND)

## How far game time is between the last tick and the next (0 to 1), for drawing between ticks.
func fraction() -> float:
	return _carry / TICK_SECONDS
