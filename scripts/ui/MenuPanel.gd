class_name MenuPanel
extends Panel

## The panel a menu opens its sub-screens in (Settings, Multiplayer, Characters), one at a time.
## MainMenu and PauseMenu both use it. A sub-screen's Back button may hide the panel and free
## itself (LobbyMenu, CharacterSelect do).

## Shows a new `scene` here in place of whatever was shown, and returns it.
func open(scene: PackedScene) -> Node:
	close()
	show()
	var screen := scene.instantiate()
	add_child(screen)
	return screen

## Removes what is shown and hides the panel.
func close() -> void:
	for child in get_children():
		child.queue_free()
	hide()
