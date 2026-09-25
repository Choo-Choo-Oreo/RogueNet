extends Node

## Which kind of input the player touched last: keyboard + mouse, or a controller.
## Button prompts on the HUD (InputPrompt) listen to `changed` and swap between key
## names and pad buttons, so the screen always shows the buttons in the player's hands.

signal changed(using_pad: bool)

## A stick has to move this far before it counts, so a resting stick that drifts a
## little doesn't flip the prompts back to the pad while someone uses the mouse.
const STICK_DEADZONE := 0.5
## Same for the mouse: a bumped desk is not someone picking the mouse up (pixels per event).
const MOUSE_NUDGE := 4.0

var using_pad := false

func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= STICK_DEADZONE:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() >= MOUSE_NUDGE:
		pad = false
	if pad != using_pad:
		using_pad = pad
		changed.emit(using_pad)
