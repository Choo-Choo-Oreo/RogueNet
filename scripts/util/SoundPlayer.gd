class_name SoundPlayer
extends RefCounted

## The one place a one-shot sound is started from (ItemSounds for the inventory, CombatSounds for
## fights). A sound is a res:// path. What keeps a busy screen from turning into noise lives
## here, so every caller gets it:
## - **merge**: the same sound again within `merge` seconds starts no new copy; the copy already
##   playing gets `boost` dB louder instead (capped at BOOST_MAX). Five bites in one instant sound
##   like one bigger bite.
## - **max_voices**: at most this many copies of one sound at once; extras are dropped.
## - **jitter**: a random pitch change of up to +-jitter, so a repeat doesn't grate.
## - **max_length**: anything still playing after this many seconds fades out over `fade`.
## - **at**: a world position makes it a positional sound (quieter with distance from the
##   camera) that is skipped entirely when the spot is off screen.
## - **heard**: with `at`, the caller already set the volume from what reaches the listener
##   (Sound.play_heard): no off-screen skip and no fade with distance, only left/right, and
##   CENTRE_PAN_MAKEUP_DB on top.
## `always` skips merge, max_voices and the off-screen check (a boss's attack).

const DEFAULTS := {
	"bus": "SFX",
	"volume_db": 0.0,
	"pitch": 1.0,
	"jitter": 0.0,
	"merge": 0.05,
	"boost": 1.5,
	"max_voices": 3,
	"max_length": 0.7,
	"fade": 0.15,
	"always": false,
	"heard": false,
}
const BOOST_MAX := 4.0
## How far past the screen edge a sound still plays, in screen pixels.
const OFF_SCREEN_MARGIN := 48.0
## Positional sounds fade to nothing at this distance from the camera, in world pixels.
const HEARING_DISTANCE := 480.0
## A `heard` sound is never cut off by distance (the flood already decided it reaches).
const HEARD_MAX_DISTANCE := 1000000.0
## A 2D player in the middle of the screen gives each ear half (-6 dB, Godot's panning): heard
## sounds and voices get it back, so one from the centre plays at its volume.
const CENTRE_PAN_MAKEUP_DB := 6.0

static var _streams := {}   # path -> AudioStream (null if missing)
static var _playing := {}   # path -> Array of players still sounding
static var _last := {}      # path -> {"msec": int, "player": Node, "boost": float}

## Plays `path`. `from` is any node in the tree (used to reach it). Returns the player, or null
## when nothing was started (missing file, merged, capped or off screen).
static func play(from: Node, path: String, options: Dictionary = {}) -> Node:
	if from == null or not from.is_inside_tree() or path == "":
		return null
	var o := DEFAULTS.duplicate()
	o.merge(options, true)
	var stream := _stream(path)
	if stream == null:
		return null
	var at = o.get("at")
	var always: bool = o["always"]
	if at != null and not always and not o["heard"] and not on_screen(from, at):
		return null
	var now := Time.get_ticks_msec()
	var sounding: Array = _alive(path)
	if not always:
		var last: Dictionary = _last.get(path, {})
		if not last.is_empty() and now - int(last["msec"]) < int(float(o["merge"]) * 1000.0):
			var earlier = last["player"]
			if is_instance_valid(earlier) and float(o["boost"]) > 0.0 and float(last["boost"]) < BOOST_MAX:
				last["boost"] = float(last["boost"]) + float(o["boost"])
				earlier.volume_db += float(o["boost"])
			return null
		if sounding.size() >= int(o["max_voices"]):
			return null
	var player: Node
	if at != null:
		var p2 := heard_player()
		if not o["heard"]:
			p2.max_distance = HEARING_DISTANCE
			p2.attenuation = 1.0
		p2.position = at
		player = p2
	else:
		player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = o["bus"]
	player.volume_db = float(o["volume_db"]) + (CENTRE_PAN_MAKEUP_DB if o["heard"] else 0.0)
	var jitter: float = o["jitter"]
	player.pitch_scale = float(o["pitch"]) * randf_range(1.0 - jitter, 1.0 + jitter)
	player.finished.connect(player.queue_free)
	from.get_tree().root.add_child(player)
	player.play()
	sounding.append(player)
	_playing[path] = sounding
	_last[path] = {"msec": now, "player": player, "boost": 0.0}
	var max_length: float = o["max_length"]
	if stream.get_length() / player.pitch_scale > max_length:
		var fade := player.create_tween()
		fade.tween_interval(max_length)
		fade.tween_property(player, "volume_db", -40.0, o["fade"])
		fade.tween_callback(player.queue_free)
	return player

## A 2D player for a sound whose volume the caller sets from what reaches the listener
## (`heard`, VoiceChat's voices): left/right only, never cut off by distance.
static func heard_player() -> AudioStreamPlayer2D:
	return set_up_heard(AudioStreamPlayer2D.new())

## Makes `p2` a heard player (see heard_player); returns it.
static func set_up_heard(p2: AudioStreamPlayer2D) -> AudioStreamPlayer2D:
	p2.max_distance = HEARD_MAX_DISTANCE
	p2.attenuation = 0.0
	return p2

## The middle of the screen in the world, where the listener is, for the camera `from` is seen
## through.
static func screen_centre(from: Node) -> Vector2:
	var viewport := from.get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size / 2.0)

## The takes of one sound: `start` + "_1.wav", "_2.wav"... up to the first one missing
## (".../grunt" gives grunt_1.wav to grunt_3.wav). Empty if there are none.
static func numbered(start: String) -> Array[String]:
	var paths: Array[String] = []
	while ResourceLoader.exists("%s_%d.wav" % [start, paths.size() + 1]):
		paths.append("%s_%d.wav" % [start, paths.size() + 1])
	return paths

## True if a world position is on screen (or within OFF_SCREEN_MARGIN of it) for the camera
## `from` is seen through.
static func on_screen(from: Node, world: Vector2) -> bool:
	var viewport := from.get_viewport()
	if viewport == null:
		return true
	var screen := viewport.get_canvas_transform() * world
	return viewport.get_visible_rect().grow(OFF_SCREEN_MARGIN).has_point(screen)

## How many copies of `path` are sounding right now.
static func voices(path: String) -> int:
	return _alive(path).size()

static func _alive(path: String) -> Array:
	return (_playing.get(path, []) as Array).filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())

static func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]
