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

# --- Cleaning up the voice (2026-09-25, "Hear yourself" was quiet): each piece on its own.

func test_high_pass_takes_out_a_steady_offset() -> void:
	var mic := MicInput.new()
	var out := 0.0
	for i in 1600:  # 0.1 s of a mic stuck at half
		out = mic.high_pass(0.5)
	assert_almost_eq(out, 0.0, 0.001)
	mic.free()

func test_high_pass_lets_speech_through() -> void:
	var mic := MicInput.new()
	var peak := 0.0
	for i in 1600:  # 1 kHz, in the middle of speech
		var out := mic.high_pass(sin(TAU * 1000.0 * i / MicInput.RATE))
		if i > 800:
			peak = maxf(peak, absf(out))
	assert_gt(peak, 0.95)
	mic.free()

func test_envelope_rises_fast_and_falls_slowly() -> void:
	var up := VoiceChat.follow_envelope(-50.0, -20.0)
	var down := VoiceChat.follow_envelope(-20.0, -50.0)
	assert_gt(up - -50.0, 15.0, "most of the way up in one chunk")
	assert_lt(-20.0 - down, 5.0, "only a little down in one chunk")
	assert_eq(VoiceChat.follow_envelope(-INF, -30.0), -30.0, "starts at the first level")

func test_gate_opens_at_the_gate_and_closes_lower() -> void:
	assert_false(VoiceChat.gate_stays_open(false, -41.0, -40.0), "closed, just under: stays shut")
	assert_true(VoiceChat.gate_stays_open(false, -40.0, -40.0), "opens at the gate")
	assert_true(VoiceChat.gate_stays_open(true, -45.0, -40.0), "open, a bit under: stays open")
	assert_false(VoiceChat.gate_stays_open(true, -47.0, -40.0), "open, well under: closes")

func test_a_quiet_mic_is_played_as_loud_as_its_dungeon_db() -> void:
	# Talking at -30 on the calibrated mic above (whisper -34, yell -15): turned up to where
	# that loudness in the dungeon plays.
	var db := VoiceChat.voice_db(-30.0, -34.0, -15.0)
	var boost := VoiceChat.playback_boost_db(-30.0, db)
	var target := lerpf(VoiceChat.PLAYBACK_WHISPER_DBFS, VoiceChat.PLAYBACK_YELL_DBFS, (db - VoiceChat.WHISPER_DB) / (VoiceChat.YELL_DB - VoiceChat.WHISPER_DB))
	assert_almost_eq(-30.0 + boost, target, 0.001)
	assert_almost_eq(VoiceChat.mic_level_db(VoiceChat.scaled(_tone(0.05), 6.0)), VoiceChat.mic_level_db(_tone(0.05)) + 6.0, 0.1)

func test_hiss_is_not_turned_up_past_the_limit() -> void:
	assert_eq(VoiceChat.playback_boost_db(-80.0, VoiceChat.WHISPER_DB), VoiceChat.MAX_BOOST_DB)

func test_a_manual_gate_replaces_the_whisper_one() -> void:
	var chat := VoiceChat.new()
	assert_eq(chat.gate_db(), chat.whisper_mic_db - VoiceChat.GATE_UNDER_WHISPER_DB, "auto")
	chat.auto_gate = false
	chat.manual_gate_db = -50.0
	assert_eq(chat.gate_db(), -50.0, "by hand")
	chat.mic.free()
	chat.free()
