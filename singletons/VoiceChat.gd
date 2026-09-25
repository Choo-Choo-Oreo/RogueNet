extends Node

## Push-to-talk voice chat over Steam. Hold push_to_talk (V): Steam records the microphone
## picked in the Steam client and hands back compressed voice. It goes to the host, which
## passes it on to everyone in the same place as the speaker (the town, or the same started
## mission), the same way chat goes through the host (NetworkSync.send_chat). Every speaker
## gets their own AudioStreamPlayer on the VoiceChat bus.
##
## Talking in the dungeon is also a noise (NetworkSync.report_noise) that minions can hear.
## Needs Steam (SteamManager.online); without it V does nothing.

signal speaking_changed(peer_id: int, speaking: bool)

## Flip by hand to hear your own voice played back: tests the mic and playback alone.
var loopback := false
## Peers this player does not want to hear: peer_id -> true. Local only.
var muted: Dictionary = {}

## Steam's k_EVoiceResultOK (GodotSteam binds the other results, not this one).
const VOICE_OK := 0
## The host drops anything bigger (Steam voice is a few hundred bytes a frame).
const MAX_PACKET_BYTES := 8192
## A speaker counts as talking until this long after their last packet.
const SPEAKING_TIMEOUT_MSEC := 300
## How far talking carries for minions' hearing goes with how loud the player talks: the
## voice level (RMS, in dB under the loudest the mic can record) on a straight line from
## QUIET_DB (MIN_VOICE_LOUDNESS, a whisper) to LOUD_DB (MAX_VOICE_LOUDNESS, yelling). Quieter
## than QUIET_DB is background hiss and makes no noise. A footstep is loudness 1.0, a rock 3.0.
const QUIET_DB := -45.0
const LOUD_DB := -6.0
const MIN_VOICE_LOUDNESS := 1.0
const MAX_VOICE_LOUDNESS := 10.0
## A chunk with this share of its samples at the mic's limit is peaking: MAX_VOICE_LOUDNESS.
const CLIPPED_FRACTION := 0.02
## At most one voice noise this often while talking, as loud as the loudest bit since the last.
const VOICE_NOISE_SECONDS := 0.5

var _sample_rate := 24000
var _players: Dictionary = {}     # peer_id -> AudioStreamPlayer
var _last_heard: Dictionary = {}  # peer_id -> msec of their last packet
var _next_noise_msec := 0
## The loudest voice level (dB) not yet made into a noise; -INF when there is none.
var _loudest_db := -INF

func _ready() -> void:
	if SteamManager.online:
		_sample_rate = Steam.getVoiceOptimalSampleRate()
	multiplayer.peer_disconnected.connect(_drop)
	multiplayer.server_disconnected.connect(func():
		for peer_id in _players.keys() + _last_heard.keys():
			_drop(peer_id))

func _unhandled_input(event: InputEvent) -> void:
	# Exact match, so Ctrl+V (paste in the Dungeon Maker) is not a push to talk. Typing a V in
	# a text box never gets here: the box eats the key.
	if event.is_action_pressed("push_to_talk", false, true) and SteamManager.online:
		Steam.startVoiceRecording()
		Steam.setInGameVoiceSpeaking(Steam.getSteamID(), true)

func _process(_delta: float) -> void:
	if not SteamManager.online:
		return
	if Input.is_action_just_released("push_to_talk"):
		Steam.stopVoiceRecording()
		Steam.setInGameVoiceSpeaking(Steam.getSteamID(), false)
	# Read every frame, not just while V is held: Steam still has the last bit buffered after
	# the key goes up, and says NOT_RECORDING / NO_DATA when there is nothing.
	_send_available_voice()
	_make_noise()
	var now := Time.get_ticks_msec()
	for peer_id in _last_heard.keys():
		if now - _last_heard[peer_id] > SPEAKING_TIMEOUT_MSEC:
			_last_heard.erase(peer_id)
			speaking_changed.emit(peer_id, false)

func is_speaking(peer_id: int) -> bool:
	return _last_heard.has(peer_id)

func set_muted(peer_id: int, on: bool) -> void:
	if on:
		muted[peer_id] = true
	else:
		muted.erase(peer_id)

# --- Sending: this player's voice, to the host.

func _send_available_voice() -> void:
	var available: Dictionary = Steam.getAvailableVoice()
	if available["result"] != VOICE_OK or available["size"] == 0:
		return
	var voice: Dictionary = Steam.getVoice(available["size"])
	if voice["result"] != VOICE_OK:
		return
	var data: PackedByteArray = voice["buffer"].slice(0, voice["size"])
	var me := multiplayer.get_unique_id()
	_note_speaking(me)
	# Our own voice is decoded only for the minions' ears (and loopback), never played.
	var pcm := _decompress(data)
	_loudest_db = maxf(_loudest_db, _level_db(pcm))
	if loopback:
		_play(me, pcm)
	if multiplayer.get_peers().is_empty():
		return
	if multiplayer.is_server():
		_relay(me, data)
	else:
		report_voice.rpc_id(1, data)

## Talking where minions are: a noise at this player, like a footstep (PlayerController),
## as loud as the loudest the player talked since the last one.
func _make_noise() -> void:
	var now := Time.get_ticks_msec()
	if now < _next_noise_msec or _loudest_db < QUIET_DB:
		return
	var loudness := voice_loudness(_loudest_db)
	_loudest_db = -INF
	var scene := get_tree().current_scene
	var me: Node2D = scene.get_node_or_null("Player/" + str(multiplayer.get_unique_id())) if scene else null
	if me == null:
		return
	_next_noise_msec = now + int(VOICE_NOISE_SECONDS * 1000.0)
	NetworkSync.report_noise(me.global_position, loudness)

## A voice level (dB) as a noise loudness, see QUIET_DB.
static func voice_loudness(db: float) -> float:
	var t := clampf(inverse_lerp(QUIET_DB, LOUD_DB, db), 0.0, 1.0)
	return lerpf(MIN_VOICE_LOUDNESS, MAX_VOICE_LOUDNESS, t)

## How loud a chunk of voice is: its RMS in dB under the loudest the mic can record (0 dB).
## A chunk peaking the mic (CLIPPED_FRACTION of it at the limit) counts as 0 dB.
static func _level_db(pcm: PackedByteArray) -> float:
	var count := pcm.size() / 2
	if count == 0:
		return -INF
	var sum := 0.0
	var clipped := 0
	for i in count:
		var sample := pcm.decode_s16(i * 2)
		sum += float(sample * sample)
		if absi(sample) >= 32767:
			clipped += 1
	if clipped >= count * CLIPPED_FRACTION:
		return 0.0
	return linear_to_db(sqrt(sum / count) / 32768.0)

# --- The host: pass it on to everyone in the same place. Channel 1, so voice never waits
# behind the game's own messages on channel 0.

@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func report_voice(data: PackedByteArray) -> void:
	if not multiplayer.is_server() or data.size() > MAX_PACKET_BYTES:
		return
	_relay(multiplayer.get_remote_sender_id(), data)

func _relay(sender_id: int, data: PackedByteArray) -> void:
	var place := _place_of(sender_id)
	if sender_id != 1 and not NetworkSync.is_dedicated and _place_of(1) == place:
		receive_voice(sender_id, data)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and _place_of(peer_id) == place:
			receive_voice.rpc_id(peer_id, sender_id, data)

## Host only (it holds the missions). Where a peer is, for who hears whom: the id of the
## started mission they dove into, or -1 for the town.
func _place_of(peer_id: int) -> int:
	for mission_id in NetworkSync.missions:
		var mission: Dictionary = NetworkSync.missions[mission_id]
		if mission.get("started", false) and peer_id in mission["members"]:
			return mission_id
	return -1

# --- Hearing: everyone else's voice.

@rpc("authority", "unreliable_ordered", "call_remote", 1)
func receive_voice(sender_id: int, data: PackedByteArray) -> void:
	if muted.has(sender_id):
		return
	_note_speaking(sender_id)
	_play(sender_id, _decompress(data))

## 16-bit mono samples at _sample_rate, or empty when Steam could not read the packet.
func _decompress(data: PackedByteArray) -> PackedByteArray:
	# Room for a whole second of samples; one packet is a small part of that.
	var out: Dictionary = Steam.decompressVoice(data, _sample_rate, _sample_rate * 2)
	if out["result"] != VOICE_OK:
		return PackedByteArray()
	return out["uncompressed"].slice(0, out["size"])

func _play(peer_id: int, pcm: PackedByteArray) -> void:
	if pcm.is_empty():
		return
	var playback: AudioStreamGeneratorPlayback = _player_for(peer_id).get_stream_playback()
	var frames := PackedVector2Array()
	frames.resize(pcm.size() / 2)
	for i in frames.size():
		var sample := pcm.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(sample, sample)
	# A full buffer means playback has fallen behind: drop this bit rather than lag further.
	if playback.get_frames_available() >= frames.size():
		playback.push_buffer(frames)

## Each speaker's own player, made the first time they talk.
func _player_for(peer_id: int) -> AudioStreamPlayer:
	if not _players.has(peer_id):
		var generator := AudioStreamGenerator.new()
		generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
		generator.mix_rate = _sample_rate
		generator.buffer_length = 0.5
		var player := AudioStreamPlayer.new()
		player.stream = generator
		player.bus = "VoiceChat"
		add_child(player)
		player.play()
		_players[peer_id] = player
	return _players[peer_id]

func _note_speaking(peer_id: int) -> void:
	var was_speaking := _last_heard.has(peer_id)
	_last_heard[peer_id] = Time.get_ticks_msec()
	if not was_speaking:
		speaking_changed.emit(peer_id, true)

func _drop(peer_id: int) -> void:
	if _players.has(peer_id):
		_players[peer_id].queue_free()
		_players.erase(peer_id)
	if _last_heard.erase(peer_id):
		speaking_changed.emit(peer_id, false)
	muted.erase(peer_id)
