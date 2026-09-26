class_name LabVoice
extends AudioStreamPlayer2D

## A fake teammate talking without a break at one dB, for the Test Lab's voice_* cells.
## It is a buzz as loud as a teammate's voice of `db` plays (VoiceChat.playback_dbfs), played
## exactly the way a teammate is
## (VoiceChat.heard_volume_db: through the sound spread, silent under your hearing). Like a
## real talker it is also a noise minions hear (NetworkSync.report_noise, as often as
## VoiceChat's), so show-sound draws its spread. It draws itself: a dot, its level, and what
## reaches you.

## VoiceChat's script, for its static functions (the VoiceChat autoload is an instance).
const VoiceChatScript := preload("res://singletons/VoiceChat.gd")
const PITCH_HZ := 130.0
const MIX_RATE := 24000.0

## How loud it talks, in dB like every sound (VoiceChat.voice_db).
var db := 50.0
## What the last frame played at (VoiceChat.SILENT_DB when you don't hear it). LabPanel shows it.
var heard_volume_db := VoiceChat.SILENT_DB
var _phase := 0.0
var _next_noise_msec := 0
const DOT_COLOR := Color(0.3, 0.9, 1.0)
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25
	stream = generator
	bus = "VoiceChat"
	SoundPlayer.set_up_heard(self)  # left/right only, like VoiceChat's players
	z_index = 100  # over the map and the fog
	play()
	_playback = get_stream_playback()

func _process(_delta: float) -> void:
	heard_volume_db = VoiceChat.heard_volume_db(self, global_position, db)
	volume_db = heard_volume_db + SoundPlayer.CENTRE_PAN_MAKEUP_DB
	queue_redraw()
	var now := Time.get_ticks_msec()
	if now >= _next_noise_msec:
		_next_noise_msec = now + int(VoiceChat.VOICE_NOISE_SECONDS * 1000.0)
		NetworkSync.report_noise(global_position, db)
	# A sawtooth's RMS is its peak / sqrt(3).
	var peak := sqrt(3.0) * db_to_linear(VoiceChatScript.playback_dbfs(db))
	var frames := PackedVector2Array()
	frames.resize(_playback.get_frames_available())
	for i in frames.size():
		_phase = fmod(_phase + PITCH_HZ / MIX_RATE, 1.0)
		var sample := peak * (2.0 * _phase - 1.0)
		frames[i] = Vector2(sample, sample)
	_playback.push_buffer(frames)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, DOT_COLOR)
	var heard := "you don't hear it" if heard_volume_db == VoiceChat.SILENT_DB else "reaches you at %.0f dB" % (db + heard_volume_db)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-40, -10), "talking %.0f dB" % db, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, DOT_COLOR)
	draw_string(font, Vector2(-40, 16), heard, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, DOT_COLOR)
