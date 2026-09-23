class_name SenseSight
extends Node

## A clear, unobstructed line of sight from the enemy to the target, within
## range -- LineOfSight's grid walk. The other way the target gives itself
## away (their real light touching this enemy's tile, even without a clear
## line) is handled separately in EnemySenses, against the actual LightMap
## instead of an approximated radius here.
@export var enabled: bool = true
@export var range_tiles: float = 6.0
@export var tile_size: float = 16.0

func detects(origin: Vector2, target: Node2D, is_blocked: Callable) -> bool:
	if not enabled:
		return false
	if origin.distance_to(target.global_position) > range_tiles * tile_size:
		return false
	# floori(), not a plain Vector2i cast -- that truncates toward zero, which
	# rounds the wrong way for negative-side positions (this dungeon spans
	# both), so a player standing west/north of the origin could silently
	# fail this check even when actually visible.
	var origin_cell := Vector2i(floori(origin.x / tile_size), floori(origin.y / tile_size))
	var target_cell := Vector2i(floori(target.global_position.x / tile_size), floori(target.global_position.y / tile_size))
	return LineOfSight.clear(origin_cell, target_cell, is_blocked)
