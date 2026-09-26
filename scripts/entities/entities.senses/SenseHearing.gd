class_name SenseHearing
extends Node

## Hears noises (see Sound): unlike sight and touch it is not a check made every tick against a
## player, it is told when something made a sound. A sound arrives at some level in dB (what is
## left after SoundSpread's walls, doors and distance); this creature hears it when that is at
## least `threshold_db`. Lower is keener: across open floor (SoundSpread.AIR_DB_PER_TILE) it
## hears a footstep on stone (CombatSounds.footstep_db) from reach_tiles of it tiles away.
## What a hit does is MinionSenses.hear(): the creature goes to look at where the noise was.
## Fallback only (a footstep from 5 tiles): every creature JSON defines its own.
const DEFAULT_THRESHOLD_DB := 27.0
@export var enabled: bool = true
@export var threshold_db: float = DEFAULT_THRESHOLD_DB
@export var tile_size: float = 16.0

## The quietest level this creature hears; INF when it has no hearing.
func threshold() -> float:
	return threshold_db if enabled else INF

## Noises that reach this creature within SUM_SECONDS add up, as sound does: two at 50 dB make
## 53, 35 and 40 make 41.2 (sum_db). So a fight (swords, hits, yells) is louder than any one
## part of it. A noise down to SUM_UNDER_DB under the threshold still counts toward the sum
## (four of those together are heard); quieter ones are not worth the flood.
const SUM_SECONDS := 1.0
const SUM_UNDER_DB := 6.0
## The noises in the window: [game msec, level here, where it was made].
var _recent: Array = []

## Levels in dB added as sound adds (their power), -INF for none.
static func sum_db(levels: Array) -> float:
	var power := 0.0
	for db: float in levels:
		power += pow(10.0, db / 10.0)
	return 10.0 * log(power) / log(10.0) if power > 0.0 else -INF

## A noise reached this creature at `level` from `position`: returns [the sum of the window's
## noises, where the loudest of them was made] (go and look there).
func add_noise(level: float, position: Vector2, now := GameTick.msec()) -> Array:
	_recent = _recent.filter(func(noise: Array) -> bool: return now - noise[0] <= SUM_SECONDS * 1000.0)
	_recent.append([now, level, position])
	var levels: Array = []
	var loudest: Array = _recent[0]
	for noise: Array in _recent:
		levels.append(noise[1])
		if noise[1] > loudest[1]:
			loudest = noise
	return [sum_db(levels), loudest[2]]

## How many tiles of open floor a sound of `db` carries for this creature.
func reach_tiles(db: float) -> float:
	return maxf(db - threshold(), 0.0) / SoundSpread.AIR_DB_PER_TILE

## Debug overlay (show-sound): no rings (Orea 2026-09-25, too many to read). The sound's own
## spread shows the dB on every tile, so DebugDraw only writes this creature's threshold over it
## (_label_rings) and, when a sound lands, heard or missed under it.
const DEBUG_COLOR := Color(0.3, 0.9, 1.0)

func debug_draw(_canvas: CanvasItem, _centre: Vector2) -> void:
	pass
