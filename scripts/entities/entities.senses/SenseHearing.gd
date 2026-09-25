class_name SenseHearing
extends Node

## Hears noises (see Sound): unlike sight and touch it is not a check made every tick against a
## player, it is told when something made a sound. A noise carries `loudness`; this creature
## hears it when it is within `range_tiles * loudness` tiles, straight-line, walls do not
## muffle it (yet). So `range_tiles` is how far it hears a footstep (loudness 1.0), and a
## thrown rock (loudness 3.0) carries three times as far. A blind rat has a big range.
## What a hit does is MinionSenses.hear(): the creature goes to look at where the noise was.
@export var enabled: bool = true
@export var range_tiles: float = 3.0
@export var tile_size: float = 16.0

func hears(origin: Vector2, noise_position: Vector2, loudness: float) -> bool:
	if not enabled:
		return false
	return origin.distance_to(noise_position) <= range_tiles * loudness * tile_size

## Debug overlay (show-minion-senses): a solid ring where a footstep (loudness 1) is heard, a
## faint one where a thrown rock (loudness 3) is.
const DEBUG_COLOR := Color(0.3, 0.9, 1.0)

func debug_draw(canvas: CanvasItem, centre: Vector2) -> void:
	if enabled:
		canvas.draw_arc(centre, range_tiles * tile_size, 0.0, TAU, 48, Color(DEBUG_COLOR, 0.6), 1.0)
		canvas.draw_arc(centre, range_tiles * 3.0 * tile_size, 0.0, TAU, 64, Color(DEBUG_COLOR, 0.2), 1.0)
