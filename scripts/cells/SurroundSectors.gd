class_name SurroundSectors
extends RefCounted

## How many chasing enemies are currently in each of 16 pie slices around a
## target, so an approaching enemy can pick the emptier side (see
## EnemyController._try_surround_step). One pass over every enemy, redone at
## most every REFRESH_FRAMES -- cheap, and exact counts don't matter, only
## which side is relatively crowded.

const SECTORS := 16
const REFRESH_FRAMES := 6
const RADIUS_TILES := 12

static var _last_frame := -1000
# target instance id -> PackedInt32Array of SECTORS counts
static var _counts := {}

static func clear() -> void:
	_counts.clear()
	_last_frame = -1000

static func sector_of(offset: Vector2) -> int:
	return int((atan2(offset.y, offset.x) + PI) / TAU * SECTORS) % SECTORS

static func counts_for(tree: SceneTree, target_id: int, tile_size: int) -> PackedInt32Array:
	var frame := Engine.get_process_frames()
	if frame - _last_frame >= REFRESH_FRAMES:
		_last_frame = frame
		_refresh(tree, tile_size)
	return _counts.get(target_id, PackedInt32Array())

static func _refresh(tree: SceneTree, tile_size: int) -> void:
	_counts.clear()
	var players: Array[Node2D] = []
	for player: Node2D in tree.get_nodes_in_group("protagonist"):
		if not player.stats.is_ghost:
			players.append(player)
	if players.is_empty():
		return
	var max_px := float(RADIUS_TILES * tile_size)
	for enemy: Node2D in tree.get_nodes_in_group("antagonist"):
		var nearest: Node2D = players[0]
		var nearest_dist := INF
		for player in players:
			var dist := enemy.global_position.distance_squared_to(player.global_position)
			if dist < nearest_dist:
				nearest = player
				nearest_dist = dist
		if nearest_dist > max_px * max_px:
			continue
		var counts: PackedInt32Array = _counts.get(nearest.get_instance_id(), PackedInt32Array())
		if counts.is_empty():
			counts.resize(SECTORS)
		counts[sector_of(enemy.global_position - nearest.global_position)] += 1
		_counts[nearest.get_instance_id()] = counts
