class_name SenseTouch
extends Node

## Range 1 -- adjacent tile. Always jumps straight to Attack when it fires,
## no uncertainty involved.
##
## Player-triggered: a player's TouchArea (see PlayerController.tscn) reports
## overlap here via notify_enter()/notify_exit() as it physically happens,
## instead of this node sampling distance once per minion poll tick (the old
## way -- a fast walk-by could slip between polls and never register).
@export var enabled: bool = true

var _touching := false

func notify_enter() -> void:
	_touching = true

func notify_exit() -> void:
	_touching = false

func detects(_origin: Vector2, _target: Node2D) -> bool:
	return enabled and _touching
