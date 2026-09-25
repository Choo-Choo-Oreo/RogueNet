class_name Sound
extends RefCounted

## A sound in the dungeon: a footstep, a thrown rock landing, a voice. make() is host only
## (minion AI only runs there; NetworkSync.report_noise gets a client's noise to it): every
## minion that hears it is told to go and look at it. What players hear is lost_to_local /
## play_heard, run on each machine for its own adventurer.
##
## How far a sound gets is SoundSpread's (dB lost per quad, walls and doors muffle, corners
## cost a little). A minion hears it when the level left where it stands is at least its
## hearing threshold (SenseHearing.threshold_db). The flood only runs as far down as the
## lowest threshold among the minions close enough to possibly hear it.
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

## Sound levels are clamped to this: a footstep is PlayerController.FOOTSTEP_DB, a thrown rock
## its action's `loudness_db`, a voice VoiceChat.voice_db.
const LOUDEST_DB := 90.0

## Debug (show-sound): the last floods, each {"levels": {quad: dB}, "db", "source", "sums", "msec"}.
const SHOW_SECONDS := 2.0
static var recent: Array = []

static func make(tree: SceneTree, position: Vector2, db: float) -> void:
	db = clampf(db, 0.0, LOUDEST_DB)
	# Every step loses at least AIR_DB_PER_TILE per tile of straight-line distance, so a minion
	# farther away than its spare dB allows cannot hear it and is skipped before the flood.
	var listeners: Array = []
	var quietest := INF
	for minion in tree.get_nodes_in_group("antagonist"):
		if not minion.has_method("hearing_threshold"):
			continue
		var threshold: float = minion.hearing_threshold()
		var spare_tiles := (db - threshold) / SoundSpread.AIR_DB_PER_TILE
		if spare_tiles >= 0.0 and minion.global_position.distance_to(position) <= (spare_tiles + minion.size_tiles) * TILE_SIZE:
			listeners.append([minion, threshold])
			quietest = minf(quietest, threshold)
	var showing := DebugState.on("show-sound")
	if listeners.is_empty() and not showing:
		return
	if showing:
		quietest = minf(quietest, SoundSpread.FLOOR_DB)
	var source := SoundSpread.quad_at(position)
	var levels := SoundSpread.flood(source, db, quietest, SoundSpread.reader(tree))
	# Each listener's level, kept for the debug labels: [where it stood, level, its threshold].
	var sums: Array = []
	if showing:
		recent.append({"levels": levels, "db": db, "source": source, "sums": sums, "msec": Time.get_ticks_msec()})
		while recent.size() > 8:
			recent.pop_front()
	var marker: Node2D = null
	for entry in listeners:
		var minion = entry[0]
		var tile := Vector2i((minion.global_position / TILE_SIZE).floor())
		var level := SoundSpread.level_at(levels, tile, minion.grid_mover.footprint)
		if showing:
			sums.append([minion.global_position, level, entry[1]])
		if level < entry[1]:
			continue
		if marker == null:
			marker = marker_at(tree, position)
			if marker == null:
				return
		minion.hear_noise(marker, level)

## What players hear: the same spread, run on each machine for its own adventurer (Viewer.local,
## threshold Viewer.hearing). The dB a sound made at `position` loses on its way to them, or
## INF when a sound of `db` would arrive quieter than they hear (or there is nobody to hear).
static func lost_to_local(tree: SceneTree, position: Vector2, db: float) -> float:
	var me := Viewer.local()
	if me == null or db < me.hearing:
		return INF
	var tile := Vector2i((me.position / TILE_SIZE).floor())
	if me.position.distance_to(position) > ((db - me.hearing) / SoundSpread.AIR_DB_PER_TILE + 1.0) * TILE_SIZE:
		return INF
	var ears := SoundSpread.quads_of(tile)
	var levels := SoundSpread.flood(SoundSpread.quad_at(position), db, me.hearing, SoundSpread.reader(tree), ears)
	return db - SoundSpread.level_at(levels, tile)

## Plays `path` (SoundPlayer) as a sound of `db` made at `position`: only if this machine's
## adventurer hears it, as much quieter as the dB it lost on the way (walls, doors, distance).
static func play_heard(from: Node, path: String, position: Vector2, db: float, options: Dictionary = {}) -> Node:
	var lost := lost_to_local(from.get_tree(), position, db)
	if lost == INF:
		return null
	var heard := options.duplicate()
	heard["volume_db"] = float(heard.get("volume_db", 0.0)) - lost
	heard["at"] = position
	heard["heard"] = true
	return SoundPlayer.play(from, path, heard)

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
	marker.set_meta("until_msec", GameTick.msec() + int(MARKER_SECONDS * 1000.0))
	return marker

## Frees the marker once its last refresh has run out (a reuse pushes the deadline back).
static func _expire(tree: SceneTree, marker) -> void:
	if not is_instance_valid(marker):
		return
	var left_msec: int = int(marker.get_meta("until_msec")) - GameTick.msec()
	if left_msec <= 0:
		marker.queue_free()
	else:
		tree.create_timer(left_msec / 1000.0).timeout.connect(_expire.bind(tree, marker))
