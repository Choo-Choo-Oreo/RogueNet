extends GutTest

## VoiceChat: how loud a player talks (RMS in dB under the mic's limit) as a noise in the
## dungeon for minions' hearing: the mic level moved so the player's normal talking is TALK_DB,
## one dB for one dB (2026-09-25: the old whisper-to-yell line squeezed real dB). Also
## MuLaw, how the voice is sent.
## The voice here is a made-up sine wave; a sine's RMS is its peak / sqrt(2), about 3 dB under it.

const VoiceChat := preload("res://singletons/VoiceChat.gd")

## 480 16-bit samples of a sine with peak `amplitude` (1.0 = the mic's limit; more clips).
func _tone(amplitude: float) -> PackedByteArray:
	var samples := PackedFloat32Array()
	samples.resize(480)
	for i in 480:
		samples[i] = sin(i * 0.2) * amplitude
	return MicInput.pcm_of(samples)

func test_level_is_rms_in_db() -> void:
	assert_almost_eq(VoiceChat.mic_level_db(_tone(0.08)), -25.0, 0.5)

func test_peaking_the_mic_reads_what_it_measures() -> void:
	# Once counted as 0 dB outright, which ducked the voice every time the mic peaked (2026-09-25).
	var level := VoiceChat.mic_level_db(_tone(3.0))
	assert_between(level, -3.0, 0.0, "a squared-off wave: loud, but never over the limit")

func test_silence_has_no_level() -> void:
	assert_eq(VoiceChat.mic_level_db(PackedByteArray()), -INF)

func test_voice_is_the_mic_level_moved_into_the_dungeon() -> void:
	assert_eq(VoiceChat.voice_db(VoiceChat.DEFAULT_TALK_MIC_DB), VoiceChat.TALK_DB)
	assert_eq(VoiceChat.voice_db(VoiceChat.DEFAULT_TALK_MIC_DB + 10.0), VoiceChat.TALK_DB + 10.0, "10 dB louder is 10 dB louder")

func test_voice_stays_between_nothing_and_the_loudest() -> void:
	assert_eq(VoiceChat.voice_db(-200.0), 0.0, "hiss")
	assert_eq(VoiceChat.voice_db(100.0, -60.0), Sound.LOUDEST_DB)

func test_a_calibrated_mic_maps_its_own_talking() -> void:
	# A hot mic (the Test Lab mic check, 2026-09-25): whisper -34, talk -25, yell -15.
	assert_eq(VoiceChat.voice_db(-25.0, -25.0), VoiceChat.TALK_DB)
	assert_eq(VoiceChat.voice_db(-15.0, -25.0), VoiceChat.TALK_DB + 10.0)

func test_a_fake_talker_level_turns_back_into_its_db() -> void:
	assert_almost_eq(VoiceChat.voice_db(VoiceChat.mic_level_for(50.0)), 50.0, 0.001)

func test_mu_law_keeps_speech_close() -> void:
	var pcm := _tone(0.3)
	var back := MuLaw.decode(MuLaw.encode(pcm))
	assert_eq(back.size(), pcm.size())
	assert_eq(MuLaw.encode(pcm).size(), pcm.size() / 2, "one byte a sample")
	assert_almost_eq(VoiceChat.mic_level_db(back), VoiceChat.mic_level_db(pcm), 0.2, "same dB")
	var back_samples := MicInput.samples_of(back)
	var samples := MicInput.samples_of(pcm)
	for i in samples.size():
		assert_almost_eq(back_samples[i] * 32768.0, samples[i] * 32768.0, 400.0, "sample %d" % i)

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

func test_envelope_rises_at_once_and_falls_slowly() -> void:
	# A word's start once read ~8 dB low while the envelope caught up (2026-09-25 audit).
	var up := VoiceChat.follow_envelope(-50.0, -20.0)
	var down := VoiceChat.follow_envelope(-20.0, -50.0)
	assert_eq(up, -20.0, "all the way up in one chunk")
	assert_lt(-20.0 - down, 5.0, "only a little down in one chunk")
	assert_eq(VoiceChat.follow_envelope(-INF, -30.0), -30.0, "starts at the first level")

func test_gate_opens_at_the_gate_and_closes_lower() -> void:
	assert_false(VoiceChat.gate_stays_open(false, -41.0, -40.0), "closed, just under: stays shut")
	assert_true(VoiceChat.gate_stays_open(false, -40.0, -40.0), "opens at the gate")
	assert_true(VoiceChat.gate_stays_open(true, -45.0, -40.0), "open, a bit under: stays open")
	assert_false(VoiceChat.gate_stays_open(true, -47.0, -40.0), "open, well under: closes")

func test_talking_plays_at_the_same_level_on_every_mic() -> void:
	for talk_mic in [-40.0, -25.0, -12.0]:
		assert_almost_eq(talk_mic + VoiceChat.playback_boost_db(talk_mic), VoiceChat.PLAYBACK_TALK_DBFS, 0.001)
	assert_almost_eq(VoiceChat.mic_level_db(VoiceChat.scaled(_tone(0.05), 6.0)), VoiceChat.mic_level_db(_tone(0.05)) + 6.0, 0.1)

func test_louder_plays_louder_by_the_same_db() -> void:
	# "Same dB, different volume" (2026-09-25): the boost chased each chunk, so it undid real differences.
	# Now it is one amount per player: 10 dB more into the mic is 10 dB more played.
	var boost := VoiceChat.playback_boost_db(-25.0)
	var quiet := VoiceChat.mic_level_db(VoiceChat.scaled(_tone(0.02), boost))
	var loud := VoiceChat.mic_level_db(VoiceChat.scaled(_tone(0.02 * db_to_linear(10.0)), boost))
	assert_almost_eq(loud - quiet, 10.0, 0.2)
	assert_almost_eq(VoiceChat.playback_dbfs(VoiceChat.TALK_DB + 10.0), VoiceChat.PLAYBACK_TALK_DBFS + 10.0, 0.001)

func test_a_yell_bends_instead_of_clipping() -> void:
	var out := VoiceChat.scaled(_tone(0.9), 6.0)  # twice what fits
	var top := 0
	for sample in MicInput.samples_of(out):
		if absf(sample) >= 32767.0 / 32768.0:
			top += 1
	assert_eq(top, 0, "no sample flat at the limit")

func test_a_mic_that_barely_hears_is_not_turned_up_past_the_limit() -> void:
	assert_eq(VoiceChat.playback_boost_db(-80.0), VoiceChat.MAX_BOOST_DB)

func test_a_manual_gate_replaces_the_whisper_one() -> void:
	var chat := VoiceChat.new()
	assert_eq(chat.gate_db(), chat.talk_mic_db - (VoiceChat.TALK_DB - VoiceChat.WHISPER_DB) - VoiceChat.GATE_UNDER_WHISPER_DB, "auto")
	chat.auto_gate = false
	chat.manual_gate_db = -50.0
	assert_eq(chat.gate_db(), -50.0, "by hand")
	chat.mic.free()
	chat.free()

func test_calibration_takes_the_typical_chunk_not_the_peaks() -> void:
	# A yell at about -22 with a few peaking chunks (0 dB): once saved as -4.5 (2026-09-25).
	var take := [-22.0, -21.0, -23.0, -22.0, 0.0, -20.0, 0.0, -24.0, -22.0]
	assert_eq(VoiceChat.median_db(take), -22.0)
	assert_gt(VoiceChat.average_db(take), -10.0, "the average is thrown off")
	assert_eq(VoiceChat.median_db([-30.0, -20.0]), -25.0, "even count: halfway")
	assert_eq(VoiceChat.median_db([]), -INF)

func test_a_high_gain_bends_instead_of_clipping() -> void:
	# +20 dB mic gain once clipped flat before anything could soften it (2026-09-25).
	assert_eq(MicInput.soft_limit(0.5), 0.5, "under the limit: untouched")
	assert_lt(MicInput.soft_limit(4.0), 1.0, "far over: still under the top")
	assert_gt(MicInput.soft_limit(4.0), MicInput.soft_limit(1.0), "louder stays louder")
