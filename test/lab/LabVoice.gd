class_name LabVoice
extends AudioStreamPlayer2D

## A fake teammate talking without a break at one loudness, for the Test Lab's voice_* cells.
## It is a buzz whose level is what a real voice of `db` has coming off the mic (db -
## VoiceChat.MIC_TO_WORLD_DB under the mic's limit), played exactly the way a teammate is
## (VoiceChat.heard_volume_db: through the sound spread, silent under your hearing).

const PITCH_HZ := 130.0
const MIX_RATE := 24000.0

## How loud it talks, in dB like every sound (VoiceChat.voice_db).
var db := 50.0
## What the last frame played at (VoiceChat.SILENT_DB when you don't hear it). LabPanel shows it.
var heard_volume_db := VoiceChat.SILENT_DB
var _phase := 0.0
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25
	stream = generator
	bus = "VoiceChat"
	attenuation = 0.0  # left/right only, like VoiceChat's players
	max_distance = SoundPlayer.HEARD_MAX_DISTANCE
	play()
	_playback = get_stream_playback()

func _process(_delta: float) -> void:
	heard_volume_db = VoiceChat.heard_volume_db(self, global_position, db)
	volume_db = heard_volume_db
	# A sawtooth's RMS is its peak / sqrt(3).
	var peak := sqrt(3.0) * db_to_linear(db - VoiceChat.MIC_TO_WORLD_DB)
	var frames := PackedVector2Array()
	frames.resize(_playback.get_frames_available())
	for i in frames.size():
		_phase = fmod(_phase + PITCH_HZ / MIX_RATE, 1.0)
		var sample := peak * (2.0 * _phase - 1.0)
		frames[i] = Vector2(sample, sample)
	_playback.push_buffer(frames)
