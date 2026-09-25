class_name SenseHearing
extends Node

## Hears noises (see Sound): unlike sight and touch it is not a check made every tick against a
## player, it is told when something made a sound. A sound arrives at some level in dB (what is
## left after SoundSpread's walls, doors and distance); this creature hears it when that is at
## least `threshold_db`. Lower is keener: across open floor (1 dB per tile) it hears a footstep
## (PlayerController.FOOTSTEP_DB) from FOOTSTEP_DB - threshold_db tiles away. A blind rat's is low.
## What a hit does is MinionSenses.hear(): the creature goes to look at where the noise was.
## Fallback only (a footstep from 3 tiles): every creature JSON defines its own.
const DEFAULT_THRESHOLD_DB := 27.0
@export var enabled: bool = true
@export var threshold_db: float = DEFAULT_THRESHOLD_DB
@export var tile_size: float = 16.0

## The quietest level this creature hears; INF when it has no hearing.
func threshold() -> float:
	return threshold_db if enabled else INF

## How many tiles of open floor a sound of `db` carries for this creature.
func reach_tiles(db: float) -> float:
	return maxf(db - threshold(), 0.0) / SoundSpread.AIR_DB_PER_TILE

## Debug overlay (show-sound): one ring per RING_STEP_DB of source level, where a sound that
## loud is heard across open floor (walls shrink it, see the sound flood). Fainter the louder;
## DebugDraw writes the level on each.
const DEBUG_COLOR := Color(0.3, 0.9, 1.0)
const RING_STEP_DB := 10
const RING_LOUDEST_DB := 70

func debug_draw(canvas: CanvasItem, centre: Vector2) -> void:
	if enabled:
		for db in debug_ring_levels():
			canvas.draw_arc(centre, reach_tiles(db) * tile_size, 0.0, TAU, 64, Color(DEBUG_COLOR, 0.6 - 0.006 * db), 1.0)

## The source levels a ring is drawn for: every RING_STEP_DB this creature can hear at all.
func debug_ring_levels() -> Array[int]:
	var levels: Array[int] = []
	for db in range(RING_STEP_DB, RING_LOUDEST_DB + 1, RING_STEP_DB):
		if reach_tiles(db) > 0.0:
			levels.append(db)
	return levels
