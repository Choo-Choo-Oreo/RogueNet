extends Node

## Voice chat, push to talk or voice activated (Settings > Audio > Voice, voice_activation). Press
## push_to_talk (V, or Share on a pad) to turn the mic on and
## again to turn it off. The game records the microphone itself (MicInput, with the mic and gain
## picked in Settings > Audio > Voice; not Steam's recording) and sends each chunk squeezed to a byte a
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

## Flip by hand (or in Settings > Audio > Voice) to hear your own voice played back.
var loopback := false
## Players this player does not want to hear, by Steam ID -> true, kept across sessions (the
## "voice_muted" settings). Local only.
var muted: Dictionary = {}
## How loud each player's voice plays for us (1.0 as sent, up to MAX_PLAYER_VOLUME), by Steam ID
## so it is kept across sessions (the "voice_players" settings). Missing = 1.0.
var player_volumes: Dictionary = {}
const MAX_PLAYER_VOLUME := 3.0

## The host drops anything bigger (a chunk is a few hundred bytes).
const MAX_PACKET_BYTES := 8192
## A speaker counts as talking until this long after their last packet.
const SPEAKING_TIMEOUT_MSEC := 300
## A voice's dB in the dungeon (Sound, in dB like every noise; a footstep is
## PlayerController.FOOTSTEP_DB): this player's mic level (RMS, in dB under the loudest the mic
## can record) moved so their normal talking is TALK_DB, one dB for one dB (voice_db): talking
## 10 dB louder in real life is 10 dB louder in the dungeon. Settings > Audio > Voice calibrates
## where their talking sits on their mic (talk_mic_db); until then it is DEFAULT_TALK_MIC_DB.
## A whisper and a yell are about WHISPER_DB and YELL_DB; never over Sound.LOUDEST_DB.
const WHISPER_DB := 30.0
const TALK_DB := 50.0
const YELL_DB := 70.0
const DEFAULT_TALK_MIC_DB := -25.0
## A calibration take is kept within this of DEFAULT_TALK_MIC_DB (before the mic gain), so
## shouting while calibrating can make your talking at most this much quieter in the dungeon.
## A mic outside it evens out with the gain slider.
const TALK_MIC_RANGE_DB := 15.0
## Quieter than this far under a whisper (TALK_DB - WHISPER_DB under talking) is not talking:
## not sent, no noise.
const GATE_UNDER_WHISPER_DB := 6.0
## Once open, the gate stays open down to this far under gate_db (so a voice hovering around
## the gate doesn't flicker on and off).
const GATE_CLOSE_UNDER_DB := 6.0
## The voice level the game goes by (envelope_db) jumps straight up to a louder chunk and falls
## only this share of the way per quieter chunk (40 ms), so the dips between syllables don't count
## as the player going quiet. The meter, the dB sent, the noise and calibration all use it.
const ENVELOPE_ATTACK := 1.0
const ENVELOPE_RELEASE := 0.1
## The volume a voice plays at in everyone's speakers (dBFS, RMS; not the dungeon's dB): talking
## (TALK_DB) at PLAYBACK_TALK_DBFS, the usual level for voice chat, louder and quieter one dB for
## one dB (playback_dbfs). The sender turns their whole voice up or down by one fixed amount for
## that (playback_boost_db, from their calibration), at most MAX_BOOST_DB; samples near the top
## bend instead of clipping (MicInput.soft_limit). Each listener turns all voices up to 300% with
## the Voice Chat volume (the VoiceChat bus; the limiter on Master stops it clipping, since a
## bus's own volume comes after its effects).
const PLAYBACK_TALK_DBFS := -18.0
const MAX_BOOST_DB := 36.0
## A voice starts playing once this much of it has arrived (and again after it ran dry), so a
## late chunk doesn't leave a gap; more than MAX_QUEUE_SECONDS waiting is dropped, so the delay
## can't build up.
const PREBUFFER_SECONDS := 0.1
const MAX_QUEUE_SECONDS := 0.3
## The gate stays open this long after the last chunk over it, so words keep their ends.
const GATE_HOLD_MSEC := 300
## At most one voice noise this often while talking, as loud as the loudest bit since the last
## (each one floods the map and restarts a listener's search, so a sentence isn't a stream of
## them), sooner if the voice got NOISE_LOUDER_DB louder than the last noise (a sudden yell).
const VOICE_NOISE_SECONDS := 2.0
const NOISE_LOUDER_DB := 6.0
## The auto gate is never under the room's background noise plus this (a loud fan can't keep the
## mic open and alert minions).
const GATE_OVER_BACKGROUND_DB := 6.0
## How quickly background_db follows each new quiet chunk (its share of the average).
const BACKGROUND_FOLLOW := 0.05

## This player's calibration (Settings > Audio > Voice, the "voice" settings): their normal
## talking's mic level, and whether they recorded it (false: talk_mic_db is the default).
var talk_mic_db := DEFAULT_TALK_MIC_DB
var calibrated := false
## The mic right now: the last chunk's level, and the background (the chunks under the gate,
## averaged). -INF before there is any.
var level_db := -INF
var background_db := -INF
## The voice level the game goes by (ENVELOPE_ATTACK / _RELEASE): the meter, the dB sent, the
## noise and calibration. -INF before there is any.
var envelope_db := -INF
## Whether the gate is open (held GATE_HOLD_MSEC past the last chunk over it): this player is
## talking, for sending, the noise, the meter and the Test Lab.
var gate_open := false
## Keeps the mic running without sending anything (Settings > Audio > Voice's meter and calibration).
var monitoring := false
## Settings > Audio > Voice (the "voice" settings), each saved at once by its set_ function:
## - auto_gain: turn this voice up or down so its talking plays at PLAYBACK_TALK_DBFS like
##   everyone's (playback_boost_db); off sends the mic as is.
## - auto_gate: the gate is GATE_UNDER_WHISPER_DB under a whisper; off, it is manual_gate_db.
## - voice_activation: the mic is always on and the gate alone decides what is sent;
##   push_to_talk then mutes and unmutes. Off, push_to_talk turns the mic on and off.
## - stereo: voices come from left or right of where the speaker stands; off, all from the
##   middle. How loud stays the same either way (that part is the sound spreading, gameplay).
var auto_gain := true
var auto_gate := true
var manual_gate_db := DEFAULT_TALK_MIC_DB - (TALK_DB - WHISPER_DB) - GATE_UNDER_WHISPER_DB
var voice_activation := false
var stereo := true

var mic := MicInput.new()
var _players: Dictionary = {}     # peer_id -> AudioStreamPlayer
var _capacity: Dictionary = {}    # peer_id -> frames their player's buffer holds
var _waiting: Dictionary = {}     # peer_id -> [msec it began, PackedVector2Array not yet played]
var _lost: Dictionary = {}        # speaker -> [msec, dB their voice loses on the way to us]
## How often a living speaker's way to us is worked out again (they or we may have moved).
const SPREAD_SECONDS := 0.25
var _last_heard: Dictionary = {}  # peer_id -> msec of their last packet
var _next_noise_msec := 0
var _last_noise_db := -INF
## The loudest voice level (dB) not yet made into a noise; -INF when there is none.
var _loudest_db := -INF
var _gate_open_until := 0
var _over_gate := false

func _ready() -> void:
	add_child(mic)
	mic.chunk.connect(_on_mic_chunk)
	MicInput.set_device(ConfigFileHandler.get_setting("voice", "device", MicInput.DEFAULT_DEVICE))
	mic.gain_db = ConfigFileHandler.get_setting("voice", "gain_db", 0.0)
	# Saved before talk_mic_db: a whisper and a yell; talking sits between them.
	var old_talk := (float(ConfigFileHandler.get_setting("voice", "whisper_mic_db", DEFAULT_TALK_MIC_DB)) + float(ConfigFileHandler.get_setting("voice", "yell_mic_db", DEFAULT_TALK_MIC_DB))) / 2.0
	talk_mic_db = ConfigFileHandler.get_setting("voice", "talk_mic_db", old_talk)
	# Saved before "calibrated": calibrated meant not the default.
	calibrated = ConfigFileHandler.get_setting("voice", "calibrated", talk_mic_db != DEFAULT_TALK_MIC_DB)
	mic.rumble_filter = ConfigFileHandler.get_setting("voice", "rumble_filter", true)
	auto_gain = ConfigFileHandler.get_setting("voice", "auto_gain", true)
	auto_gate = ConfigFileHandler.get_setting("voice", "auto_gate", true)
	manual_gate_db = ConfigFileHandler.get_setting("voice", "manual_gate_db", manual_gate_db)
	stereo = ConfigFileHandler.get_setting("voice", "stereo", true)
	var output: String = ConfigFileHandler.get_setting("voice", "output_device", DEFAULT_DEVICE)
	AudioServer.output_device = output if output_devices().has(output) else DEFAULT_DEVICE
	voice_activation = ConfigFileHandler.get_setting("voice", "voice_activation", false)
	if voice_activation:
		set_talking(true)
	if ConfigFileHandler.config.has_section("voice_players"):
		for steam_id in ConfigFileHandler.config.get_section_keys("voice_players"):
			player_volumes[steam_id.to_int()] = float(ConfigFileHandler.get_setting("voice_players", steam_id, 1.0))
	if ConfigFileHandler.config.has_section("voice_muted"):
		for steam_id in ConfigFileHandler.config.get_section_keys("voice_muted"):
			if ConfigFileHandler.get_setting("voice_muted", steam_id, false):
				muted[steam_id.to_int()] = true
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()  # the first scene doesn't fire scene_changed
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

## True while this player's mic is on for talking: push_to_talk toggled it on, or with voice
## activation, not muted. The HUD's mic icon reads it.
var talking := false

## Whether the current scene is a mission (the dungeon).
var _in_mission := false

## Leaving a mission any way (ended by the host, Main Menu, a disconnect) turns a push-to-talk
## mic off, so a toggled-on mic does not follow the player into the town or the menus.
func _on_scene_changed() -> void:
	var was_in_mission := _in_mission
	var scene := get_tree().current_scene
	_in_mission = scene != null and scene.scene_file_path.ends_with("Dungeon.tscn")
	if was_in_mission and not _in_mission and talking and not voice_activation:
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
	if talking or monitoring or voice_activation:
		if not mic.is_on():
			mic.start()
	else:
		mic.stop()
		level_db = -INF
		envelope_db = -INF
		_over_gate = false
		gate_open = false

# --- Settings > Audio > Voice: each saved at once.

func set_device(device: String) -> void:
	# Godot's audio driver moves a running mic to the new device by itself. Don't restart it here:
	# starting straight after a switch fails (WASAPI: init_input_device error).
	MicInput.set_device(device)
	ConfigFileHandler.save_setting("voice", "device", device)

## A new gain moves the calibration and the manual gate with it (all are levels after the gain),
## so, calibrated, it changes neither how loud you are in the dungeon, nor how loud friends hear
## you, nor what counts as talking; it only helps a mic too quiet to record well. Uncalibrated, it
## changes how loud you are.
func set_gain(db: float) -> void:
	var change := db - mic.gain_db
	if is_calibrated():
		set_calibration(talk_mic_db + change)
	set_gate(auto_gate, manual_gate_db + change)
	mic.gain_db = db
	ConfigFileHandler.save_setting("voice", "gain_db", db)

## The device name that means "whatever the system uses", for the speaker as for the mic.
const DEFAULT_DEVICE := MicInput.DEFAULT_DEVICE

static func output_devices() -> PackedStringArray:
	return AudioServer.get_output_device_list()

## Where all the game's sound plays, not only voices.
func set_output_device(device: String) -> void:
	AudioServer.output_device = device if output_devices().has(device) else DEFAULT_DEVICE
	ConfigFileHandler.save_setting("voice", "output_device", device)

func set_rumble_filter(on: bool) -> void:
	mic.rumble_filter = on
	ConfigFileHandler.save_setting("voice", "rumble_filter", on)

func set_auto_gain(on: bool) -> void:
	auto_gain = on
	ConfigFileHandler.save_setting("voice", "auto_gain", on)

func set_gate(auto: bool, manual_db: float) -> void:
	auto_gate = auto
	manual_gate_db = manual_db
	ConfigFileHandler.save_setting("voice", "auto_gate", auto)
	ConfigFileHandler.save_setting("voice", "manual_gate_db", manual_db)

## Switching to voice activation unmutes (talking on); back to push to talk, the mic starts off.
func set_voice_activation(on: bool) -> void:
	voice_activation = on
	ConfigFileHandler.save_setting("voice", "voice_activation", on)
	set_talking(on)

func set_stereo(on: bool) -> void:
	stereo = on
	ConfigFileHandler.save_setting("voice", "stereo", on)

## A take's talking level (`level`, after the mic `gain`) kept within TALK_MIC_RANGE_DB.
static func allowed_talk_mic(level: float, gain: float) -> float:
	return clampf(level, DEFAULT_TALK_MIC_DB - TALK_MIC_RANGE_DB + gain, DEFAULT_TALK_MIC_DB + TALK_MIC_RANGE_DB + gain)

## `recorded`: false puts back the default (Reset).
func set_calibration(talk_mic: float, recorded := true) -> void:
	talk_mic_db = talk_mic
	calibrated = recorded
	ConfigFileHandler.save_setting("voice", "talk_mic_db", talk_mic)
	ConfigFileHandler.save_setting("voice", "calibrated", recorded)

func is_calibrated() -> bool:
	return calibrated

func _process(_delta: float) -> void:
	_make_noise()
	var now := Time.get_ticks_msec()
	# The last bit of a short word, still waiting to fill the prebuffer: play it rather than
	# hold it until the next word.
	for peer_id in _waiting.keys():
		if now - int(_waiting[peer_id][0]) > int(PREBUFFER_SECONDS * 2000.0):
			_push(peer_id, _waiting[peer_id][1])
			_waiting.erase(peer_id)
	for peer_id in _last_heard.keys():
		if now - _last_heard[peer_id] > SPEAKING_TIMEOUT_MSEC:
			_last_heard.erase(peer_id)
			speaking_changed.emit(peer_id, false)

func is_speaking(peer_id: int) -> bool:
	return _last_heard.has(peer_id)

## A peer's Steam ID, what their volume and mute are kept by (0 offline).
func _steam_id(peer_id: int) -> int:
	return NetworkSync.peer_steam_ids.get(peer_id, 0)

## A player's voice volume for us (player_volumes), by their peer id.
func player_volume(peer_id: int) -> float:
	return player_volumes.get(_steam_id(peer_id), 1.0)

func set_player_volume(peer_id: int, volume: float) -> void:
	var steam_id := _steam_id(peer_id)
	player_volumes[steam_id] = clampf(volume, 0.0, MAX_PLAYER_VOLUME)
	ConfigFileHandler.save_setting("voice_players", str(steam_id), player_volumes[steam_id])

func is_muted(peer_id: int) -> bool:
	return muted.has(_steam_id(peer_id))

func set_muted(peer_id: int, on: bool) -> void:
	var steam_id := _steam_id(peer_id)
	if on:
		muted[steam_id] = true
	else:
		muted.erase(steam_id)
	ConfigFileHandler.save_setting("voice_muted", str(steam_id), on)

# --- Sending: this player's voice, to the host.

## Every chunk the mic records: measured (level_db, envelope_db, background_db, gate_open) and,
## while talking with the gate open, turned to its playback volume and sent with its dB in the
## dungeon in front.
func _on_mic_chunk(pcm: PackedByteArray) -> void:
	level_db = mic_level_db(pcm)
	envelope_db = follow_envelope(envelope_db, level_db)
	var now := Time.get_ticks_msec()
	_over_gate = gate_stays_open(_over_gate, level_db, gate_db())
	if _over_gate:
		_gate_open_until = now + GATE_HOLD_MSEC
	elif level_db > -INF:
		background_db = level_db if background_db == -INF else lerpf(background_db, level_db, BACKGROUND_FOLLOW)
	gate_open = now <= _gate_open_until
	var me := my_id()
	var db := my_voice_db(envelope_db)
	# What is played: this voice's talking turned to PLAYBACK_TALK_DBFS (own_voice keeps the mic's own).
	var played := scaled(pcm, playback_boost_db(talk_mic_db)) if auto_gain else pcm
	# Loopback also while only monitoring, so Settings > Audio > Voice can play you back; not
	# while muted.
	if loopback and gate_open and (talking or monitoring):
		_play(me, played, db)
	if not talking:
		return
	own_voice.emit(pcm)
	if not gate_open:
		return
	_note_speaking(me)
	if _over_gate:
		_loudest_db = maxf(_loudest_db, envelope_db)
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	var data := PackedByteArray([roundi(db)]) + MuLaw.encode(played)
	if multiplayer.is_server():
		_relay(me, data)
	else:
		report_voice.rpc_id(1, data)

## Talking where minions are: a noise at this player, like a footstep (PlayerController),
## as loud as the loudest the player talked since the last one. A ghost makes no noise.
func _make_noise() -> void:
	var now := Time.get_ticks_msec()
	if _loudest_db == -INF:
		return
	var db := my_voice_db(_loudest_db)
	if not noise_due(now, _next_noise_msec, db, _last_noise_db):
		return
	_loudest_db = -INF
	var me: Node2D = NetworkSync._player(my_id())
	if me == null or _is_ghost(me):
		return
	_next_noise_msec = now + int(VOICE_NOISE_SECONDS * 1000.0)
	_last_noise_db = db
	NetworkSync.report_noise(me.global_position, db)
	voice_noise.emit(db)

## Whether a voice of `db` makes a noise now: VOICE_NOISE_SECONDS since the last (due at
## `next_msec`), or NOISE_LOUDER_DB louder than it (`last_db`).
static func noise_due(now: int, next_msec: int, db: float, last_db: float) -> bool:
	return now >= next_msec or db >= last_db + NOISE_LOUDER_DB

## This player's peer id; 1 (as offline) while no peer is set (the menus, or a match still
## setting up), when the mic can still run.
func my_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

## The mic level under which this player is not talking.
func gate_db() -> float:
	if not auto_gate:
		return manual_gate_db
	return maxf(talk_mic_db - (TALK_DB - WHISPER_DB) - GATE_UNDER_WHISPER_DB, background_db + GATE_OVER_BACKGROUND_DB)

## This player's mic level as dB in the dungeon, with their calibration.
func my_voice_db(mic_db: float) -> float:
	return voice_db(mic_db, talk_mic_db)

## A mic level (dB under the mic's limit) as dB in the dungeon: `talk_mic` is TALK_DB, one dB
## for one dB either way, between 0 and Sound.LOUDEST_DB.
static func voice_db(mic_db: float, talk_mic := DEFAULT_TALK_MIC_DB) -> float:
	return clampf(mic_db - talk_mic + TALK_DB, 0.0, Sound.LOUDEST_DB)

## The other way, uncalibrated: the mic level a voice of `db` has.
static func mic_level_for(db: float) -> float:
	return db - TALK_DB + DEFAULT_TALK_MIC_DB

## How loud a voice of `db` plays (dBFS, RMS), before the way to the listener: talking at
## PLAYBACK_TALK_DBFS, one dB for one dB (the Test Lab's fake talkers play at it).
static func playback_dbfs(db: float) -> float:
	return PLAYBACK_TALK_DBFS + db - TALK_DB

## One step of envelope_db: `level` (this chunk) pulls it up fast and lets it down slowly.
static func follow_envelope(envelope: float, level: float) -> float:
	if envelope == -INF or level == -INF:
		return level if envelope == -INF else envelope - 2.0
	return lerpf(envelope, level, ENVELOPE_ATTACK if level > envelope else ENVELOPE_RELEASE)

## Whether the gate is open after a chunk of `level`: it opens at `gate` and, once open, closes
## only under `gate` - GATE_CLOSE_UNDER_DB.
static func gate_stays_open(was_open: bool, level: float, gate: float) -> bool:
	return level >= (gate - GATE_CLOSE_UNDER_DB if was_open else gate)

## How much a player whose talking sits at `talk_mic` on their mic is turned up (or down) so
## their talking plays at PLAYBACK_TALK_DBFS. One amount for their whole voice, so louder and
## quieter keep their real difference; at most MAX_BOOST_DB up.
static func playback_boost_db(talk_mic: float) -> float:
	return minf(PLAYBACK_TALK_DBFS - talk_mic, MAX_BOOST_DB)

## 16-bit samples `boost_db` louder (or quieter), bent near the top instead of clipping
## (MicInput.soft_limit).
static func scaled(pcm: PackedByteArray, boost_db: float) -> PackedByteArray:
	var gain := db_to_linear(boost_db)
	var samples := MicInput.samples_of(pcm)
	for i in samples.size():
		samples[i] = MicInput.soft_limit(samples[i] * gain)
	return MicInput.pcm_of(samples)

## The middle one of several levels (dB): a few peaking or silent chunks don't move it.
static func median_db(levels: Array) -> float:
	if levels.is_empty():
		return -INF
	var sorted := levels.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")  # the middle index
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) / 2.0

## The average of several levels (dB) as the ear hears it: of their power, not of the dB numbers.
static func average_db(levels: Array) -> float:
	var power := 0.0
	for level in levels:
		power += db_to_linear(level) ** 2
	return linear_to_db(sqrt(power / levels.size())) if not levels.is_empty() else -INF

## How loud a chunk of voice is: its RMS in dB under the loudest the mic can record (0 dB).
## A chunk peaking the mic reads what it measures (near 0 dB), nothing more.
static func mic_level_db(pcm: PackedByteArray) -> float:
	var samples := MicInput.samples_of(pcm)
	if samples.is_empty():
		return -INF
	var sum := 0.0
	for sample in samples:
		sum += sample * sample
	return linear_to_db(sqrt(sum / samples.size()))

# --- The host: pass it on to everyone in the same place. Channel 1, so voice never waits
# behind the game's own messages on channel 0.

@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func report_voice(data: PackedByteArray) -> void:
	if not multiplayer.is_server() or data.size() > MAX_PACKET_BYTES or data.is_empty():
		return
	data[0] = mini(data[0], int(Sound.LOUDEST_DB))  # no voice over the loudest sound there is
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

## `data`: the speaker's dB in the dungeon (one byte, voice_db), then their voice (MuLaw).
@rpc("authority", "unreliable_ordered", "call_remote", 1)
func receive_voice(sender_id: int, data: PackedByteArray) -> void:
	if is_muted(sender_id) or data.size() < 2:
		return
	_note_speaking(sender_id)
	_play(sender_id, MuLaw.decode(data.slice(1)), data[0])

func _play(peer_id: int, pcm: PackedByteArray, db: float) -> void:
	if pcm.is_empty():
		return
	var player := _player_for(peer_id)
	_place_voice(peer_id, player, db)
	var samples := MicInput.samples_of(pcm)
	var frames := PackedVector2Array()
	frames.resize(samples.size())
	for i in samples.size():
		frames[i] = Vector2(samples[i], samples[i])
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var queued: int = _capacity[peer_id] - playback.get_frames_available()
	if queued <= 0 or _waiting.has(peer_id):
		# Ran dry (or never started): gather PREBUFFER_SECONDS before playing again.
		var waiting: Array = _waiting.get(peer_id, [Time.get_ticks_msec(), PackedVector2Array()])
		var gathered: PackedVector2Array = waiting[1]
		gathered.append_array(frames)
		if gathered.size() < int(PREBUFFER_SECONDS * MicInput.RATE):
			_waiting[peer_id] = [waiting[0], gathered]
			return
		_waiting.erase(peer_id)
		frames = gathered
	elif queued > int(MAX_QUEUE_SECONDS * MicInput.RATE):
		return  # fallen behind: drop this bit so the delay doesn't build up
	_push(peer_id, frames)

func _push(peer_id: int, frames: PackedVector2Array) -> void:
	if not _players.has(peer_id):
		return
	var playback: AudioStreamGeneratorPlayback = _players[peer_id].get_stream_playback()
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
		var player := SoundPlayer.heard_player()  # left/right only: how loud is _place_voice's
		player.stream = generator
		player.bus = "VoiceChat"
		add_child(player)
		player.play()
		_players[peer_id] = player
		_capacity[peer_id] = player.get_stream_playback().get_frames_available()
	return _players[peer_id]

## A living speaker in the dungeon is heard from their body, as loud as what reaches us of
## how loud they talk (`db`, voice_db), or not at all below our hearing. Anyone else (the town,
## a ghost, loopback) is heard at full volume, from the screen's centre (no left or right), as
## is everyone with `stereo` off. Left or right is from our adventurer, not the camera (which
## follows the mouse): the player sits as far from the screen's centre as the speaker is from us.
func _place_voice(peer_id: int, player: AudioStreamPlayer2D, db: float) -> void:
	var body: Node2D = NetworkSync._player(peer_id)
	var me := Viewer.local()
	var heard := _in_mission and me != null and body != null and not _is_ghost(body) and peer_id != my_id()
	player.volume_db = (heard_volume_db(peer_id, body.global_position, db) if heard else 0.0) + SoundPlayer.CENTRE_PAN_MAKEUP_DB + linear_to_db(maxf(player_volume(peer_id), 0.0001))
	player.global_position = SoundPlayer.screen_centre(self)
	if heard and stereo:
		player.global_position += body.global_position - me.position

const SILENT_DB := -80.0

## The volume a voice of `db` (voice_db) talked at `at` plays at for us: as much quieter as
## the dB it loses on its way to our adventurer, or SILENT_DB when what reaches us is under our
## hearing. The way is worked out for Sound.LOUDEST_DB (the loudest sound, so it covers every level)
## at most every SPREAD_SECONDS per `speaker` (a peer id; the Test Lab's fake talkers use their own).
func heard_volume_db(speaker: Variant, at: Vector2, db: float) -> float:
	var me := Viewer.local()
	if me == null:
		return SILENT_DB
	var now := Time.get_ticks_msec()
	var known: Array = _lost.get(speaker, [])
	if known.is_empty() or now - int(known[0]) > int(SPREAD_SECONDS * 1000.0):
		known = [now, Sound.lost_to_local(get_tree(), at, Sound.LOUDEST_DB)]
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
	_capacity.erase(peer_id)
	_waiting.erase(peer_id)
	if _last_heard.erase(peer_id):
		speaking_changed.emit(peer_id, false)
	_lost.erase(peer_id)
