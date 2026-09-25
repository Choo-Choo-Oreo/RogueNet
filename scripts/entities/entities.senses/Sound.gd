class_name Sound
extends RefCounted

## A sound in the dungeon: a footstep, a thrown rock landing. Host only (minion AI only runs
## there; NetworkSync.report_noise gets a client's noise to it). Every minion whose
## SenseHearing reaches the spot is told to go and look at it.
##
## Going to look needs somewhere to go, and pathing wants a node, so a noise becomes a
## marker: a bare Node2D left where it was made for MARKER_SECONDS. Minions share markers
## (one per spot, see marker_at), so a crowd that hears the same noise shares one flow field
## instead of paying for one each. A marker is a place, never a player: investigating walks
## to where the sound was, not to whoever made it.

const GROUP := "noise_marker"
const MARKER_SECONDS := 15.0
## A noise this close to a live marker reuses it instead of making another.
const REUSE_TILES := 2.0
const TILE_SIZE := 16.0

static func make(tree: SceneTree, position: Vector2, loudness: float) -> void:
	var marker: Node2D = null
	for minion in tree.get_nodes_in_group("antagonist"):
		if not minion.has_method("hear_noise") or not minion.can_hear(position, loudness):
			continue
		if marker == null:
			marker = marker_at(tree, position)
			if marker == null:
				return
		minion.hear_noise(marker)

## The live marker within REUSE_TILES of `position` (kept alive another MARKER_SECONDS), or a
## new one there. Null when there is no scene to put it in.
static func marker_at(tree: SceneTree, position: Vector2) -> Node2D:
	var scene := tree.current_scene
	if scene == null:
		return null
	var marker: Node2D = null
	for existing: Node2D in tree.get_nodes_in_group(GROUP):
		if existing.global_position.distance_to(position) <= REUSE_TILES * TILE_SIZE:
			marker = existing
			break
	if marker == null:
		marker = Node2D.new()
		marker.name = "NoiseMarker"
		marker.add_to_group(GROUP)
		scene.add_child(marker)
		marker.global_position = position
		tree.create_timer(MARKER_SECONDS).timeout.connect(_expire.bind(tree, marker))
	marker.set_meta("until_msec", Time.get_ticks_msec() + int(MARKER_SECONDS * 1000.0))
	return marker

## Frees the marker once its last refresh has run out (a reuse pushes the deadline back).
static func _expire(tree: SceneTree, marker) -> void:
	if not is_instance_valid(marker):
		return
	var left_msec: int = int(marker.get_meta("until_msec")) - Time.get_ticks_msec()
	if left_msec <= 0:
		marker.queue_free()
	else:
		tree.create_timer(left_msec / 1000.0).timeout.connect(_expire.bind(tree, marker))
