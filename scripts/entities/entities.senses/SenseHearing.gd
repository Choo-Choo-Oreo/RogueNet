class_name SenseHearing
extends Node

## Not developed yet -- static range 3, Warden-style directional noise
## tracking on player movement (see the minion senses design memory). Always
## passes (never detects) until that's built.

@export var enabled: bool = true

func detects(_origin: Vector2, _target: Node2D) -> bool:
	return false
