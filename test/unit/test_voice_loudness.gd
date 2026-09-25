extends GutTest

## VoiceChat: how loud a player talks (RMS in dB under the mic's limit) as a noise in the
## dungeon for minions' hearing: a straight line from the whisper's mic level (WHISPER_DB) to the
## yell's (YELL_DB), never past either. Also MuLaw, how the voice is sent.
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
	assert_eq(VoiceChat.voice_db(VoiceChat.DEFAULT_WHISPER_MIC_DB), VoiceChat.WHISPER_DB)
	assert_eq(VoiceChat.voice_db(VoiceChat.DEFAULT_YELL_MIC_DB), VoiceChat.YELL_DB)
	var halfway := (VoiceChat.DEFAULT_WHISPER_MIC_DB + VoiceChat.DEFAULT_YELL_MIC_DB) / 2.0
	assert_almost_eq(VoiceChat.voice_db(halfway), (VoiceChat.WHISPER_DB + VoiceChat.YELL_DB) / 2.0, 0.001)

func test_voice_stays_between_whisper_and_yell() -> void:
	assert_eq(VoiceChat.voice_db(-100.0), VoiceChat.WHISPER_DB, "hiss")
	assert_eq(VoiceChat.voice_db(0.0), VoiceChat.YELL_DB, "peaking the mic")

func test_a_calibrated_mic_maps_its_own_whisper_and_yell() -> void:
	# A hot mic with a narrow range (the Test Lab mic check, 2026-09-25): whisper -34, yell -15.
	assert_eq(VoiceChat.voice_db(-34.0, -34.0, -15.0), VoiceChat.WHISPER_DB)
	assert_eq(VoiceChat.voice_db(-15.0, -34.0, -15.0), VoiceChat.YELL_DB)

func test_a_fake_talker_level_turns_back_into_its_db() -> void:
	assert_almost_eq(VoiceChat.voice_db(VoiceChat.mic_level_for(50.0)), 50.0, 0.001)

func test_mu_law_keeps_speech_close() -> void:
	var pcm := _tone(0.3)
	var back := MuLaw.decode(MuLaw.encode(pcm))
	assert_eq(back.size(), pcm.size())
	assert_eq(MuLaw.encode(pcm).size(), pcm.size() / 2, "one byte a sample")
	assert_almost_eq(VoiceChat.mic_level_db(back), VoiceChat.mic_level_db(pcm), 0.2, "same loudness")
	for i in range(0, pcm.size(), 2):
		assert_almost_eq(back.decode_s16(i), pcm.decode_s16(i), 400, "sample %d" % (i / 2))
