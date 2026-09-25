extends GutTest

## VoiceChat: how loud a player talks (RMS in dB under the mic's limit) as a noise in the
## dungeon for minions' hearing: MIC_TO_WORLD_DB louder, kept between WHISPER_DB and YELL_DB.
## The voice here is a made-up sine wave; a sine's RMS is its peak / sqrt(2), about 3 dB under it.

const VoiceChat := preload("res://singletons/VoiceChat.gd")

## 480 16-bit samples of a sine with peak `amplitude` (1.0 = the mic's limit; more clips).
func _tone(amplitude: float) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(960)
	for i in 480:
		pcm.encode_s16(i * 2, clampi(int(sin(i * 0.2) * amplitude * 32767.0), -32768, 32767))
	return pcm

func test_level_is_rms_in_db() -> void:
	assert_almost_eq(VoiceChat.mic_level_db(_tone(0.08)), -25.0, 0.5)

func test_peaking_the_mic_counts_as_zero_db() -> void:
	assert_eq(VoiceChat.mic_level_db(_tone(3.0)), 0.0)

func test_silence_has_no_level() -> void:
	assert_eq(VoiceChat.mic_level_db(PackedByteArray()), -INF)

func test_voice_is_the_mic_level_moved_into_the_dungeon() -> void:
	assert_eq(VoiceChat.voice_db(VoiceChat.QUIET_DB), VoiceChat.WHISPER_DB, "the quietest voice that counts is a whisper")
	assert_almost_eq(VoiceChat.voice_db(-25.0), -25.0 + VoiceChat.MIC_TO_WORLD_DB, 0.001)

func test_voice_stays_between_whisper_and_yell() -> void:
	assert_eq(VoiceChat.voice_db(-100.0), VoiceChat.WHISPER_DB, "hiss under QUIET_DB")
	assert_eq(VoiceChat.voice_db(0.0), VoiceChat.YELL_DB, "peaking the mic")
