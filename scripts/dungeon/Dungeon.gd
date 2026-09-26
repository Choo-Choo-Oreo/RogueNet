extends Node2D

## The HUD is not in this scene: GameView puts it next to the world's viewport (MissionHud).

func _ready() -> void:
	GameView.debug_parent(self).add_child(DebugDraw.new())
	add_child(BodySweep.new())
	# Root layer (real screen pixels): outside the world's viewport, next to DebugDraw.
	GameView.debug_parent(self).add_child(DebugMenu.new())

