class_name InteractPrompt
extends Control

## "(A) Open door" over whatever the player can interact with (doors, loot, graves).
## Nothing calls it yet: the interact action (A; no keyboard key chosen) has no
## gameplay behind it. Whoever builds that calls show_at() / hide_prompt().

@onready var box: PanelContainer = $Box
@onready var prompt: InputPrompt = $Box/Prompt

func _ready() -> void:
	hide()

## `screen_position` is where the thing is on screen; the prompt sits just above it.
func show_at(screen_position: Vector2, what: String) -> void:
	prompt.set_text(what)
	show()
	await get_tree().process_frame   # the box only knows its width after layout
	box.position = (screen_position - Vector2(box.size.x / 2.0, box.size.y + 4.0)).floor()

func hide_prompt() -> void:
	hide()
