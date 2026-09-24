class_name TileHit
extends RefCounted

## Damages every creature of the other team standing on a tile. The one place that decides
## "who is on this tile and how the hit reaches them", used by melee hits and by where a
## projectile lands. A creature covers the tiles from the one its centre is over, as many as
## its footprint (a 2x2 boss is hit on any of its four), so a body caught mid-step counts
## for the tile it is mostly on. A ghost cannot be hit.

## Returns true if something was hit.
static func apply(caster: Node2D, tile: Vector2i, amount: int, type: String) -> bool:
	var tile_size: float = caster.grid_mover.tile_size
	var half := Vector2(tile_size, tile_size) / 2.0
	var hit := false
	for creature: Node2D in caster.get_tree().get_nodes_in_group(target_team(caster)):
		if creature.stats.is_ghost:
			continue
		var origin := Vector2i(((creature.global_position + half) / tile_size).floor())
		var size: int = creature.get_meta("footprint", 1)
		if tile.x < origin.x or tile.x >= origin.x + size or tile.y < origin.y or tile.y >= origin.y + size:
			continue
		_damage(creature, amount, type)
		hit = true
	return hit

## The group a caster's attacks land on: the other team.
static func target_team(caster: Node2D) -> String:
	return "antagonist" if caster.is_in_group("protagonist") else "protagonist"

## Minions are host-owned, so a hit on one is reported to the host, which applies it and
## tells everyone. Minion AI only runs on the host, so a hit on a player is already coming
## from the host and is broadcast. (A player-driven antagonist will need this to change.)
static func _damage(creature: Node2D, amount: int, type: String) -> void:
	if creature.is_in_group("antagonist"):
		NetworkSync.report_minion_hit(int(str(creature.name)), amount, type)
	else:
		NetworkSync.relay_player_hit(int(str(creature.name)), amount, type)
