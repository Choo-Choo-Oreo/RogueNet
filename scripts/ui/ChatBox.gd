class_name ChatBox
extends Control

## Hooks into NetworkSync's existing chat relay (send_chat() / receive_chat())
## -- that side was already built, this is just the missing UI for it.
## Enter opens the input when it isn't focused; Enter again sends and closes
## it, so normal movement input isn't stuck waiting on chat focus in between.

@onready var chat_log: RichTextLabel = $Log
@onready var input: LineEdit = $Input

func _ready() -> void:
	input.text_submitted.connect(_on_text_submitted)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not input.has_focus():
		input.grab_focus()
		get_viewport().set_input_as_handled()

func _on_text_submitted(text: String) -> void:
	input.clear()
	input.release_focus()
	var trimmed := text.strip_edges()
	if not trimmed.is_empty():
		NetworkSync.send_chat(trimmed)

func add_chat_line(line: String) -> void:
	chat_log.append_text(line + "\n")
