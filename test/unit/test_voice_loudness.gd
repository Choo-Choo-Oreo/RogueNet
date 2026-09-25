extends GutTest

## VoiceChat: how loud a player talks (RMS in dB) as a noise loudness for minions' hearing, from
## MIN_VOICE_LOUDNESS at QUIET_DB to MAX_VOICE_LOUDNESS at LOUD_DB. The voice here is a made-up
## sine wave; a sine's RMS is its peak / sqrt(2), about 3 dB under it.

const VoiceChat := preload("res://singletons/VoiceChat.gd")

## 480 16-bit samples of a sine with peak `amplitude` (1.0 = the mic's limit; more clips).
func _tone(amplitude: float) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(960)
	for i in 480:
		pcm.encode_s16(i * 2, clampi(int(sin(i * 0.2) * amplitude * 32767.0), -32768, 32767))
	return pcm

func test_level_is_rms_in_db() -> void:
	assert_almost_eq(VoiceChat._level_db(_tone(0.08)), -25.0, 0.5)

func test_peaking_the_mic_counts_as_zero_db() -> void:
	assert_eq(VoiceChat._level_db(_tone(3.0)), 0.0)

func test_silence_has_no_level() -> void:
	assert_eq(VoiceChat._level_db(PackedByteArray()), -INF)

func test_loudness_runs_from_quiet_to_loud() -> void:
	assert_eq(VoiceChat.voice_loudness(VoiceChat.QUIET_DB), VoiceChat.MIN_VOICE_LOUDNESS)
	assert_eq(VoiceChat.voice_loudness(VoiceChat.LOUD_DB), VoiceChat.MAX_VOICE_LOUDNESS)
	var middle := (VoiceChat.QUIET_DB + VoiceChat.LOUD_DB) / 2.0
	assert_almost_eq(VoiceChat.voice_loudness(middle), (VoiceChat.MIN_VOICE_LOUDNESS + VoiceChat.MAX_VOICE_LOUDNESS) / 2.0, 0.001)

func test_loudness_stays_in_range() -> void:
	assert_eq(VoiceChat.voice_loudness(-100.0), VoiceChat.MIN_VOICE_LOUDNESS, "a whisper under QUIET_DB")
	assert_eq(VoiceChat.voice_loudness(0.0), VoiceChat.MAX_VOICE_LOUDNESS, "a yell over LOUD_DB")
