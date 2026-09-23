class_name SenseSight
extends Node

## Two ways a player gives themselves away: a clear line of sight from the
## enemy (LineOfSight's grid walk), or the player's own light spilling onto
## the enemy's tile even without a clear line (a fresh LightFlood run from
## the player's position -- kept separate from whatever LightMap is
## rendering, same "share the algorithm, not the live data" reasoning as
## LightFlood/LineOfSight themselves).
@export var enabled: bool = true
@export var range_tiles: float = 6.0
@export var light_radius_tiles: float = 4.0
@export var tile_size: float = 16.0

func detects(origin: Vector2, target: Node2D, is_blocked: Callable) -> bool:
	if not enabled:
		return false
	var origin_cell := Vector2i(origin / tile_size)
	var target_cell := Vector2i(target.global_position / tile_size)
	if origin.distance_to(target.global_position) <= range_tiles * tile_size:
		if LineOfSight.clear(origin_cell, target_cell, is_blocked):
			return true
	var lit: Dictionary = LightFlood.flood(target_cell, light_radius_tiles, is_blocked)
	return lit["reached"].has(origin_cell)
