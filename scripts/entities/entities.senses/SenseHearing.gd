class_name SenseHearing
extends Node

## Hears noises (see Sound): unlike sight and touch it is not a check made every tick against a
## player, it is told when something made a sound. A noise carries `loudness`; this creature's
## budget for it is `range_tiles * loudness`, and it hears the noise when the sound's path to it
## costs no more than that (Sound.flood: a floor tile costs 1, a wall 3). So `range_tiles` is how
## many open tiles away it hears a footstep (loudness 1.0); a thrown rock (3.0) carries three
## times as far. A blind rat has a big range.
## What a hit does is MinionSenses.hear(): the creature goes to look at where the noise was.
const DEFAULT_RANGE_TILES := 3.0
@export var enabled: bool = true
@export var range_tiles: float = DEFAULT_RANGE_TILES
@export var tile_size: float = 16.0

## How much sound cost this creature can hear through, for a noise of `loudness`.
func budget(loudness: float) -> float:
	return range_tiles * loudness if enabled else 0.0

## Debug overlay (show-sound): one ring per loudness from Sound.LOUDNESS_MIN to LOUDNESS_MAX,
## where a sound that loud is heard across open floor (walls shrink it, see the sound flood).
## Fainter the louder; DebugDraw writes the loudness on each.
const DEBUG_COLOR := Color(0.3, 0.9, 1.0)

func debug_draw(canvas: CanvasItem, centre: Vector2) -> void:
	if enabled:
		for loudness in range(Sound.LOUDNESS_MIN, Sound.LOUDNESS_MAX + 1):
			canvas.draw_arc(centre, budget(loudness) * tile_size, 0.0, TAU, 64, Color(DEBUG_COLOR, 0.6 - 0.04 * loudness), 1.0)
