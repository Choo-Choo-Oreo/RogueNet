extends Node

## Push-to-talk voice chat. Press push_to_talk (V, or Share on a pad) to turn the mic on and
## again to turn it off. The game records the microphone itself (MicInput, with the mic and gain
## picked in Settings > Voice; not Steam's recording) and sends each chunk squeezed to a byte a
## sample (MuLaw), with how loud it is in the dungeon (voice_db) in front. Only talking is sent:
## a chunk quieter than the gate (gate_db, a little under this player's whisper) is background.
## It goes to the host, which passes it on to everyone in the same place as the
## speaker (the town, or the same started mission), the same way chat goes through the host
## (NetworkSync.send_chat). In a mission the living and the ghosts are two channels: ghosts
## hear only ghosts, from anywhere; the living hear only the living, from where the speaker
## stands: the voice spreads like any other sound (Sound.lost_to_local, through walls and doors
## and round corners), and a listener whose hearing it doesn't reach hears nothing. Every
## speaker gets their own player on the VoiceChat bus.
##
## Talking in the dungeon is also a noise (NetworkSync.report_noise) that minions can hear.

signal speaking_changed(peer_id: int, speaking: bool)
## This player's own voice while the mic is on for talking, each chunk as it comes off the mic
## (16-bit mono at MicInput.RATE). The Test Lab's mic check records it.
signal own_voice(pcm: PackedByteArray)
## This player's talking made a noise of `db` (what minions hear, voice_db).
signal voice_noise(db: float)

## Flip by hand (or in Settings > Voice) to hear your own voice played back.
var loopback := false
## Peers this player does not want to hear: peer_id -> true. Local only.
var muted: Dictionary = {}

## The host drops anything bigger (a chunk is a few hundred bytes).
const MAX_PACKET_BYTES := 8192
## A speaker counts as talking until this long after their last packet.
const SPEAKING_TIMEOUT_MSEC := 300
## How loud talking is in the dungeon (Sound, in dB like every noise; a footstep is
## PlayerController.FOOTSTEP_DB): from WHISPER_DB to YELL_DB, in a straight line between this
## player's whisper and yell as their mic records them (RMS, in dB under the loudest the mic
## can record). Settings > Voice calibrates the two (whisper_mic_db, yell_mic_db); until then
## they are the DEFAULT_ ones.
const WHISPER_DB := 30.0
const YELL_DB := 70.0
const DEFAULT_WHISPER_MIC_DB := -45.0
const DEFAULT_YELL_MIC_DB := -5.0
## Quieter than this far under the whisper is not talking: not sent, no noise.
const GATE_UNDER_WHISPER_DB := 6.0
## The gate stays open this long after the last chunk over it, so words keep their ends.
const GATE_HOLD_MSEC := 300
## A chunk with this share of its samples at the mic's limit is peaking: 0 dB.
const CLIPPED_FRACTION := 0.02
## At most one voice noise this often while talking, as loud as the loudest bit since the last.
const VOICE_NOISE_SECONDS := 0.5
## How quickly background_db follows each new quiet chunk (its share of the average).
const BACKGROUND_FOLLOW := 0.05

## This player's calibration (Settings > Voice, the "voice" settings).
var whisper_mic_db := DEFAULT_WHISPER_MIC_DB
var yell_mic_db := DEFAULT_YELL_MIC_DB
## The mic right now, for Settings > Voice's meter: the last chunk's level, and the background
## (the chunks under the gate, averaged). -INF before there is any.
var level_db := -INF
var background_db := -INF
## Keeps the mic running without sending anything (Settings > Voice's meter and calibration).
var monitoring := false

var mic := MicInput.new()
var _players: Dictionary = {}     # peer_id -> AudioStreamPlayer
var _lost: Dictionary = {}        # speaker -> [msec, dB their voice loses on the way to us]
## How often a living speaker's way to us is worked out again (they or we may have moved).
const SPREAD_SECONDS := 0.25
var _last_heard: Dictionary = {}  # peer_id -> msec of their last packet
var _next_noise_msec := 0
## The loudest voice level (dB) not yet made into a noise; -INF when there is none.
var _loudest_db := -INF
var _gate_open_until := 0

func _ready() -> void:
	add_child(mic)
	mic.chunk.connect(_on_mic_chunk)
	MicInput.set_device(ConfigFileHandler.get_setting("voice", "device", MicInput.DEFAULT_DEVICE))
	mic.gain_db = ConfigFileHandler.get_setting("voice", "gain_db", 0.0)
	whisper_mic_db = ConfigFileHandler.get_setting("voice", "whisper_mic_db", DEFAULT_WHISPER_MIC_DB)
	yell_mic_db = ConfigFileHandler.get_setting("voice", "yell_mic_db", DEFAULT_YELL_MIC_DB)
	get_tree().scene_changed.connect(_on_scene_changed)
	multiplayer.peer_disconnected.connect(_drop)
	multiplayer.server_disconnected.connect(func():
		for peer_id in _players.keys() + _last_heard.keys():
			_drop(peer_id))

func _unhandled_input(event: InputEvent) -> void:
	# Exact match, so Ctrl+V (paste in the Dungeon Maker) is not a push to talk. Typing a V in
	# a text box never gets here: the box eats the key.
	if not event.is_action_pressed("push_to_talk", false, true):
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
	_update_mic()
	if SteamManager.online:
		Steam.setInGameVoiceSpeaking(Steam.getSteamID(), on)

func set_monitoring(on: bool) -> void:
	monitoring = on
	_update_mic()

func _update_mic() -> void:
	if talking or monitoring:
		if not mic.is_on():
			mic.start()
	else:
		mic.stop()
		level_db = -INF

# --- Settings > Voice: each saved at once.

func set_device(device: String) -> void:
	MicInput.set_device(device)
	ConfigFileHandler.save_setting("voice", "device", device)

## A new gain moves the calibration with it (both are levels after the gain), so it changes how
## loud friends hear you, not how loud you are in the dungeon. Uncalibrated, it changes both.
func set_gain(db: float) -> void:
	if is_calibrated():
		set_calibration(whisper_mic_db + db - mic.gain_db, yell_mic_db + db - mic.gain_db)
	mic.gain_db = db
	ConfigFileHandler.save_setting("voice", "gain_db", db)

func set_calibration(whisper: float, yell: float) -> void:
	whisper_mic_db = whisper
	yell_mic_db = yell
	ConfigFileHandler.save_setting("voice", "whisper_mic_db", whisper)
	ConfigFileHandler.save_setting("voice", "yell_mic_db", yell)

func is_calibrated() -> bool:
	return whisper_mic_db != DEFAULT_WHISPER_MIC_DB or yell_mic_db != DEFAULT_YELL_MIC_DB

func _process(_delta: float) -> void:
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

## Every chunk the mic records: measured (level_db, background_db) and, while talking with the
## gate open, sent with its loudness in the dungeon in front.
func _on_mic_chunk(pcm: PackedByteArray) -> void:
	level_db = mic_level_db(pcm)
	var now := Time.get_ticks_msec()
	if level_db >= gate_db():
		_gate_open_until = now + GATE_HOLD_MSEC
	elif level_db > -INF:
		background_db = level_db if background_db == -INF else lerpf(background_db, level_db, BACKGROUND_FOLLOW)
	var open := now <= _gate_open_until
	var me := multiplayer.get_unique_id()
	var db := my_voice_db(level_db)
	# Loopback also while only monitoring, so Settings > Voice can play you back.
	if loopback and open:
		_play(me, pcm, db)
	if not talking:
		return
	own_voice.emit(pcm)
	if not open:
		return
	_note_speaking(me)
	if level_db >= gate_db():
		_loudest_db = maxf(_loudest_db, level_db)
	if multiplayer.get_peers().is_empty():
		return
	var data := PackedByteArray([roundi(db)]) + MuLaw.encode(pcm)
	if multiplayer.is_server():
		_relay(me, data)
	else:
		report_voice.rpc_id(1, data)

## Talking where minions are: a noise at this player, like a footstep (PlayerController),
## as loud as the loudest the player talked since the last one. A ghost makes no noise.
func _make_noise() -> void:
	var now := Time.get_ticks_msec()
	if now < _next_noise_msec or _loudest_db == -INF:
		return
	var db := my_voice_db(_loudest_db)
	_loudest_db = -INF
	var me: Node2D = NetworkSync._player(multiplayer.get_unique_id())
	if me == null or _is_ghost(me):
		return
	_next_noise_msec = now + int(VOICE_NOISE_SECONDS * 1000.0)
	NetworkSync.report_noise(me.global_position, db)
	voice_noise.emit(db)

## The mic level under which this player is not talking.
func gate_db() -> float:
	return whisper_mic_db - GATE_UNDER_WHISPER_DB

## This player's mic level as a loudness in the dungeon, with their calibration.
func my_voice_db(mic_db: float) -> float:
	return voice_db(mic_db, whisper_mic_db, yell_mic_db)

## A mic level (dB under the mic's limit) as a loudness in the dungeon: `whisper_mic` is
## WHISPER_DB, `yell_mic` YELL_DB, a straight line between, never past either.
static func voice_db(mic_db: float, whisper_mic := DEFAULT_WHISPER_MIC_DB, yell_mic := DEFAULT_YELL_MIC_DB) -> float:
	var along := (mic_db - whisper_mic) / maxf(yell_mic - whisper_mic, 1.0)
	return clampf(lerpf(WHISPER_DB, YELL_DB, along), WHISPER_DB, YELL_DB)

## The other way, uncalibrated: the mic level a voice of `db` has (the Test Lab's fake talkers).
static func mic_level_for(db: float) -> float:
	return lerpf(DEFAULT_WHISPER_MIC_DB, DEFAULT_YELL_MIC_DB, (db - WHISPER_DB) / (YELL_DB - WHISPER_DB))

## The average of several levels (dB) as the ear hears it: of their power, not of the dB numbers.
static func average_db(levels: Array) -> float:
	var power := 0.0
	for level in levels:
		power += db_to_linear(level) ** 2
	return linear_to_db(sqrt(power / levels.size())) if not levels.is_empty() else -INF

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

## `data`: the speaker's loudness in the dungeon (one byte, voice_db), then their voice (MuLaw).
@rpc("authority", "unreliable_ordered", "call_remote", 1)
func receive_voice(sender_id: int, data: PackedByteArray) -> void:
	if muted.has(sender_id) or data.size() < 2:
		return
	_note_speaking(sender_id)
	_play(sender_id, MuLaw.decode(data.slice(1)), data[0])

func _play(peer_id: int, pcm: PackedByteArray, db: float) -> void:
	if pcm.is_empty():
		return
	var player := _player_for(peer_id)
	_place_voice(peer_id, player, db)
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
		generator.mix_rate = MicInput.RATE
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
## how loud they talk (`db`, voice_db), or not at all below our hearing. Anyone else (the town,
## a ghost, loopback) is heard at full volume: the player sits on the listener, the screen's centre.
func _place_voice(peer_id: int, player: AudioStreamPlayer2D, db: float) -> void:
	var body: Node2D = NetworkSync._player(peer_id)
	if _in_mission and Viewer.local() != null and body != null and not _is_ghost(body) and peer_id != multiplayer.get_unique_id():
		player.global_position = body.global_position
		player.volume_db = heard_volume_db(peer_id, body.global_position, db)
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
