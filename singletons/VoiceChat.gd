extends Node

## Push-to-talk voice chat over Steam. Press push_to_talk (V, or Share on a pad) to turn the
## mic on and again to turn it off: Steam records the microphone picked in the Steam client and hands back compressed
## voice. It goes to the host, which passes it on to everyone in the same place as the
## speaker (the town, or the same started mission), the same way chat goes through the host
## (NetworkSync.send_chat). In a mission the living and the ghosts are two channels: ghosts
## hear only ghosts, from anywhere; the living hear only the living, from where the speaker
## stands: the voice spreads like any other sound (Sound.lost_to_local, through walls and doors
## and round corners), and a listener whose hearing it doesn't reach hears nothing. Every
## speaker gets their own player on the VoiceChat bus.
##
## Talking in the dungeon is also a noise (NetworkSync.report_noise) that minions can hear.
## Needs Steam (SteamManager.online); without it V does nothing.

signal speaking_changed(peer_id: int, speaking: bool)
## This player's own voice, as each chunk comes off the mic (16-bit mono at sample_rate). The
## Test Lab's mic check records it.
signal own_voice(pcm: PackedByteArray)
## This player's talking made a noise of `db` (what minions hear, voice_db).
signal voice_noise(db: float)

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
## How loud talking is for minions' hearing (Sound, in dB like every noise) goes with how loud
## the player talks: the voice level (RMS, in dB under the loudest the mic can record) plus
## MIC_TO_WORLD_DB, from WHISPER_DB at QUIET_DB to YELL_DB. Quieter than QUIET_DB is
## background hiss and makes no noise. A footstep is 30 dB (PlayerController.FOOTSTEP_DB).
const QUIET_DB := -45.0
const MIC_TO_WORLD_DB := 75.0
const WHISPER_DB := 30.0
const YELL_DB := 70.0
## A chunk with this share of its samples at the mic's limit is peaking: MAX_VOICE_LOUDNESS.
const CLIPPED_FRACTION := 0.02
## At most one voice noise this often while talking, as loud as the loudest bit since the last.
const VOICE_NOISE_SECONDS := 0.5

## Steam's voice sample rate, set once Steam is up.
var sample_rate := 24000
var _players: Dictionary = {}     # peer_id -> AudioStreamPlayer
var _lost: Dictionary = {}        # speaker -> [msec, dB their voice loses on the way to us]
## How often a living speaker's way to us is worked out again (they or we may have moved).
const SPREAD_SECONDS := 0.25
var _last_heard: Dictionary = {}  # peer_id -> msec of their last packet
var _next_noise_msec := 0
## The loudest voice level (dB) not yet made into a noise; -INF when there is none.
var _loudest_db := -INF

func _ready() -> void:
	if SteamManager.online:
		sample_rate = Steam.getVoiceOptimalSampleRate()
	get_tree().scene_changed.connect(_on_scene_changed)
	multiplayer.peer_disconnected.connect(_drop)
	multiplayer.server_disconnected.connect(func():
		for peer_id in _players.keys() + _last_heard.keys():
			_drop(peer_id))

func _unhandled_input(event: InputEvent) -> void:
	# Exact match, so Ctrl+V (paste in the Dungeon Maker) is not a push to talk. Typing a V in
	# a text box never gets here: the box eats the key.
	if not (event.is_action_pressed("push_to_talk", false, true) and SteamManager.online):
		return
	# V and the pad's Share button both toggle: one press on, the next off.
	set_talking(not talking)

## True while this player's mic is on (push_to_talk toggled it on). The HUD's mic icon reads it.
var talking := false

## Whether the current scene is a mission (the dungeon).
var _in_mission := false

## Leaving a mission any way (ended by the host, Main Menu, a disconnect) turns the mic off,
## so a toggled-on mic does not follow the player into the town or the menus.
func _on_scene_changed() -> void:
	var was_in_mission := _in_mission
	_in_mission = get_tree().current_scene.scene_file_path.ends_with("Dungeon.tscn")
	if was_in_mission and not _in_mission and talking:
		set_talking(false)

func set_talking(on: bool) -> void:
	talking = on
	if on:
		Steam.startVoiceRecording()
	else:
		Steam.stopVoiceRecording()
	Steam.setInGameVoiceSpeaking(Steam.getSteamID(), on)

func _process(_delta: float) -> void:
	if not SteamManager.online:
		return
	# Read every frame, not just while talking: Steam still has the last bit buffered after
	# talking is toggled off, and says NOT_RECORDING / NO_DATA when there is nothing.
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
	_loudest_db = maxf(_loudest_db, mic_level_db(pcm))
	own_voice.emit(pcm)
	if loopback:
		_play(me, pcm)
	if multiplayer.get_peers().is_empty():
		return
	if multiplayer.is_server():
		_relay(me, data)
	else:
		report_voice.rpc_id(1, data)

## Talking where minions are: a noise at this player, like a footstep (PlayerController),
## as loud as the loudest the player talked since the last one. A ghost makes no noise.
func _make_noise() -> void:
	var now := Time.get_ticks_msec()
	if now < _next_noise_msec or _loudest_db < QUIET_DB:
		return
	var db := voice_db(_loudest_db)
	_loudest_db = -INF
	var me: Node2D = NetworkSync._player(multiplayer.get_unique_id())
	if me == null or _is_ghost(me):
		return
	_next_noise_msec = now + int(VOICE_NOISE_SECONDS * 1000.0)
	NetworkSync.report_noise(me.global_position, db)
	voice_noise.emit(db)

## A voice level (dB under the mic's limit) as a noise in the dungeon, see MIC_TO_WORLD_DB.
static func voice_db(mic_db: float) -> float:
	return clampf(mic_db + MIC_TO_WORLD_DB, WHISPER_DB, YELL_DB)

## How loud a chunk of voice is: its RMS in dB under the loudest the mic can record (0 dB).
## A chunk peaking the mic (CLIPPED_FRACTION of it at the limit) counts as 0 dB.
static func mic_level_db(pcm: PackedByteArray) -> float:
	@warning_ignore("integer_division")  # 2 bytes per sample
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
	if sender_id != 1 and not NetworkSync.is_dedicated and _hears(1, sender_id):
		receive_voice(sender_id, data)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and _hears(peer_id, sender_id):
			receive_voice.rpc_id(peer_id, sender_id, data)

## Host only. Whether `listener` gets `speaker`'s voice: same place, and in a mission the
## same side of death (a peer with no body there, e.g. in the town, counts as living).
func _hears(listener: int, speaker: int) -> bool:
	return _place_of(listener) == _place_of(speaker) and _is_ghost(NetworkSync._player(listener)) == _is_ghost(NetworkSync._player(speaker))

static func _is_ghost(body: Node) -> bool:
	return body != null and body.stats.is_ghost

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

## 16-bit mono samples at sample_rate, or empty when Steam could not read the packet.
func _decompress(data: PackedByteArray) -> PackedByteArray:
	# Room for a whole second of samples; one packet is a small part of that.
	var out: Dictionary = Steam.decompressVoice(data, sample_rate, sample_rate * 2)
	if out["result"] != VOICE_OK:
		return PackedByteArray()
	return out["uncompressed"].slice(0, out["size"])

func _play(peer_id: int, pcm: PackedByteArray) -> void:
	if pcm.is_empty():
		return
	var player := _player_for(peer_id)
	_place_voice(peer_id, player, pcm)
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var frames := PackedVector2Array()
	@warning_ignore("integer_division")  # 2 bytes per sample
	frames.resize(pcm.size() / 2)
	for i in frames.size():
		var sample := pcm.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(sample, sample)
	# A full buffer means playback has fallen behind: drop this bit rather than lag further.
	if playback.get_frames_available() >= frames.size():
		playback.push_buffer(frames)

## Each speaker's own player, made the first time they talk. Positional, so a living speaker
## can be placed where they stand (_place_voice).
func _player_for(peer_id: int) -> AudioStreamPlayer2D:
	if not _players.has(peer_id):
		var generator := AudioStreamGenerator.new()
		generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
		generator.mix_rate = sample_rate
		generator.buffer_length = 0.5
		var player := AudioStreamPlayer2D.new()
		player.stream = generator
		player.bus = "VoiceChat"
		player.attenuation = 0.0  # left/right only: how loud is _place_voice's
		player.max_distance = SoundPlayer.HEARD_MAX_DISTANCE
		add_child(player)
		player.play()
		_players[peer_id] = player
	return _players[peer_id]

## A living speaker in the dungeon is heard from their body, as loud as what reaches us of
## how loud they talk (voice_db), or not at all below our hearing. Anyone else (the town, a
## ghost, loopback) is heard at full volume: the player sits on the listener, the screen's centre.
func _place_voice(peer_id: int, player: AudioStreamPlayer2D, pcm: PackedByteArray) -> void:
	var body: Node2D = NetworkSync._player(peer_id)
	if _in_mission and Viewer.local() != null and body != null and not _is_ghost(body) and peer_id != multiplayer.get_unique_id():
		player.global_position = body.global_position
		player.volume_db = heard_volume_db(peer_id, body.global_position, voice_db(mic_level_db(pcm)))
	else:
		var viewport := get_viewport()
		player.global_position = viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size / 2.0)
		player.volume_db = 0.0

const SILENT_DB := -80.0

## The volume a voice of `db` (voice_db) talked at `at` plays at for us: as much quieter as
## the dB it loses on its way to our adventurer, or SILENT_DB when what reaches us is under our
## hearing. The way is worked out for a yell (the loudest voice, so it covers every level) at
## most every SPREAD_SECONDS per `speaker` (a peer id; the Test Lab's fake talkers use their own).
func heard_volume_db(speaker: Variant, at: Vector2, db: float) -> float:
	var me := Viewer.local()
	if me == null:
		return SILENT_DB
	var now := Time.get_ticks_msec()
	var known: Array = _lost.get(speaker, [])
	if known.is_empty() or now - int(known[0]) > int(SPREAD_SECONDS * 1000.0):
		known = [now, Sound.lost_to_local(get_tree(), at, YELL_DB)]
		_lost[speaker] = known
	var lost: float = known[1]
	return -lost if db - lost >= me.hearing else SILENT_DB

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
	_lost.erase(peer_id)
