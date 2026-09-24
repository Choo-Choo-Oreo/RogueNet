extends Node

## Launcher for the development hub (test/lab/development/, not a real biome). Right-click TestLab.tscn in the
## editor and choose "Run" (or open it and press F6): it builds the dungeon with the development biome
## and a fixed seed, then adds the LabPanel over it. Nothing else to click through.
##
## Seed 1 always, so a report ("cell bug3_smash_plain, seed 1") can be replayed by me exactly.

const DUNGEON := "res://scenes/dungeon/Dungeon.tscn"

func _ready() -> void:
	NetworkSync.dungeon_seed = 1
	NetworkSync.dungeon_biome = "res://test/lab/development"
	# The panel goes on the root, not on this scene, because this scene is replaced by the dungeon.
	get_tree().root.add_child.call_deferred(LabPanel.new())
	get_tree().change_scene_to_file.call_deferred(DUNGEON)
