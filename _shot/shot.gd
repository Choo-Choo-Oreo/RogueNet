extends SceneTree
## Scratch: opens the town and its storage, saves a screenshot. Deleted after use.
var _f := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/ui/town/MainTown.tscn")
func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		var inv = root.get_node("PlayerInventory")
		for id in ["militia_rusty_sword", "cleric_mace", "arcane_orb", "ruby_ring", "backpack", "poison_vial_amulet", "health_potion", "iron_ore", "seraph_aegis", "voidstar_ring"]:
			inv.add_item(id, 1, "storage")
		current_scene._on_storage_button_pressed()
	if _f == 40:
		var img := root.get_texture().get_image()
		img.save_png(OS.get_environment("SHOT"))
		quit()
	return false
