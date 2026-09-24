class_name SenseSmell
extends Node

## Not developed yet -- pheromone-trail cell data, decaying scent strength
## players deposit by standing on a tile (see the minion senses design
## memory). Always passes (never detects) until that's built.

@export var enabled: bool = true

func detects(_origin: Vector2, _target: Node2D) -> bool:
	return false
