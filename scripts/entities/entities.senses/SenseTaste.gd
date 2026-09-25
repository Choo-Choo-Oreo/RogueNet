class_name SenseTaste
extends Node

## Not developed yet -- range 0, no design given. Always passes (never
## detects).

@export var enabled: bool = true

func detects(_origin: Vector2, _target: Node2D) -> bool:
	return false

## Debug overlay (show-taste): nothing to draw until this sense is built (give it a
## range ring like SenseHearing's).
const DEBUG_COLOR := Color(1.0, 0.6, 0.2)

func debug_draw(_canvas: CanvasItem, _centre: Vector2) -> void:
	pass
