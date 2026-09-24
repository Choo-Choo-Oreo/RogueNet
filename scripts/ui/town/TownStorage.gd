extends Control

## The Storage screen in town: the inventory (what you wear and carry) next to
## the storage. Whatever you're wearing when the party dives is what you wear
## in the dungeon. Both panels build themselves (InventoryPanel, StoragePanel);
## this scene only lays them out and has the Back button.

signal back_pressed

func _on_back_button_pressed() -> void:
	back_pressed.emit()
