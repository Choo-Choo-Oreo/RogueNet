class_name SenseTaste
extends Node

## Not developed yet -- range 0, no design given. Always passes (never
## detects).

@export var enabled: bool = true

func detects(_origin: Vector2, _target: Node2D) -> bool:
	return false
