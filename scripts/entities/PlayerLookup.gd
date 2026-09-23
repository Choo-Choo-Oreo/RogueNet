class_name PlayerLookup
extends RefCounted

## The single PlayerController this peer actually controls, or null before
## it's spawned. Every local-only HUD element (Hotbar, HealthBar, ...) needs
## this, and there's no signal for "the local player just spawned" to hook
## instead -- callers just retry each frame until it returns non-null.
static func find_local(tree: SceneTree) -> Node2D:
	for player in tree.get_nodes_in_group("protagonist"):
		if player.is_multiplayer_authority():
			return player
	return null
