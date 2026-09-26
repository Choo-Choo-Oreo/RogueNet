class_name ChatBox
extends Control

## Hooks into NetworkSync's existing chat relay (send_chat() / receive_chat())
## -- that side was already built, this is just the missing UI for it.
## Enter opens the input when it isn't focused. Sending keeps it open for the next line;
## Enter on an empty line or Esc closes it, so movement input is free again.
## The mouse wheel scrolls the log (its mouse_filter is Pass, not Ignore).

@onready var chat_log: RichTextLabel = $Log
@onready var input: LineEdit = $Input

func _ready() -> void:
	input.text_submitted.connect(_on_text_submitted)
	input.gui_input.connect(_on_input_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not input.has_focus():
		input.grab_focus()
		get_viewport().set_input_as_handled()

func _on_text_submitted(text: String) -> void:
	input.clear()
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		input.release_focus()
	else:
		NetworkSync.send_chat(trimmed)

## Esc leaves the chat instead of opening the pause menu.
func _on_input_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		input.release_focus()
		input.accept_event()

## Players' "[" is escaped, so chat cannot start BBCode (append_text parses it even with
## bbcode_enabled off).
func add_chat_line(line: String) -> void:
	chat_log.append_text(line.replace("[", "[lb]") + "\n")
