extends Node2D

## NetworkSync.receive_chat() looks for add_chat_line() on the current scene
## root -- this just forwards to the actual UI.

@onready var chat_box: ChatBox = $UILayer/ChatBox

func _ready() -> void:
	add_child(DebugDraw.new())
	add_child(DebugMenu.new())

func add_chat_line(line: String) -> void:
	chat_box.add_chat_line(line)
