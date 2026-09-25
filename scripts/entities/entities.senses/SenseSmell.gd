class_name SenseSmell
extends Node

## Not developed yet -- pheromone-trail cell data, decaying scent strength
## players deposit by standing on a tile (see the minion senses design
## memory). Always passes (never detects) until that's built.

@export var enabled: bool = true

func detects(_origin: Vector2, _target: Node2D) -> bool:
	return false

## Debug overlay (show-smell): nothing to draw until this sense is built (give it a
## range ring like SenseHearing's).
const DEBUG_COLOR := Color(0.4, 1.0, 0.4)

func debug_draw(_canvas: CanvasItem, _centre: Vector2) -> void:
	pass
