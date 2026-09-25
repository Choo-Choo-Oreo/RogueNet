class_name LabMicCheck
extends Node

## The Test Lab's mic check (the voice_mic_check cell). Turns your mic on (VoiceChat: the mic,
## gain and calibration from Settings > Voice) and asks you to whisper, then talk, then yell:
## GAP_SECONDS to get ready, then TAKE_SECONDS of recording each. It shows your background level
## (the mic when you are not talking, VoiceChat.background_db). For every take it keeps:
## - what the game made of it: the noises your talking made (VoiceChat.voice_noise, the dB
##   minions hear, one every half second at most);
## - the recording itself (VoiceChat.own_voice): its average and loudest level, turned into dB
##   the same way (VoiceChat.my_voice_db), and saved as a WAV in user://test_lab/ to play back.
## The two should agree; the target is where a whisper, talking and a yell are meant to land.

const TAKES := [["whisper", 30.0], ["talk", 50.0], ["yell", 70.0]]
const GAP_SECONDS := 3.0
const TAKE_SECONDS := 5.0
const WAV_DIR := "user://test_lab/"

## What LabPanel shows: where the check is up to, and one line per finished take.
var status := "Press M to start."
var results: Array[String] = []

var _take := -1  # index into TAKES, -1 while not running
var _recording := false  # false during the pause before a take
var _until_msec := 0
var _pcm := PackedByteArray()
var _levels: Array[float] = []  # each mic chunk's level (VoiceChat.mic_level_db)
var _noises: Array[float] = []

func _ready() -> void:
	VoiceChat.own_voice.connect(_on_own_voice)
	VoiceChat.voice_noise.connect(_on_voice_noise)

func _exit_tree() -> void:
	if _take >= 0:
		VoiceChat.set_talking(false)

func start() -> void:
	results.clear()
	VoiceChat.set_talking(true)
	_begin(0)

func _begin(take: int) -> void:
	_take = take
	_recording = false
	_until_msec = Time.get_ticks_msec() + int(GAP_SECONDS * 1000.0)
	_pcm = PackedByteArray()
	_levels.clear()
	_noises.clear()

func _process(_delta: float) -> void:
	if _take < 0:
		return
	var left := (_until_msec - Time.get_ticks_msec()) / 1000.0
	var word: String = TAKES[_take][0]
	status = ("%s NOW  %d" if _recording else "Get ready to %s...  %d") % [word.to_upper(), ceili(left)]
	if left > 0.0:
		return
	if not _recording:
		_recording = true
		_until_msec = Time.get_ticks_msec() + int(TAKE_SECONDS * 1000.0)
		return
	results.append(_result())
	if _take + 1 < TAKES.size():
		_begin(_take + 1)
	else:
		_take = -1
		VoiceChat.set_talking(false)
		status = "Done (WAVs in %s). Press M to go again." % ProjectSettings.globalize_path(WAV_DIR)

## The background level and the gate (under it is not talking), for the panel.
func background_line() -> String:
	return "background %.0f dB under the mic's limit, gate %.0f (calibrated: %s)" % [
		VoiceChat.background_db, VoiceChat.gate_db(), "yes" if VoiceChat.is_calibrated() else "no, defaults"]

func _on_own_voice(pcm: PackedByteArray) -> void:
	if _recording:
		_pcm.append_array(pcm)
		_levels.append(VoiceChat.mic_level_db(pcm))

func _on_voice_noise(db: float) -> void:
	if _recording:
		_noises.append(db)

## One finished take as a line of the table, its recording saved beside it.
func _result() -> String:
	var word: String = TAKES[_take][0]
	var wav := _save(word)
	var game := "no noise made (too quiet?)"
	if not _noises.is_empty():
		var total := 0.0
		for db in _noises:
			total += db
		game = "%.0f avg, %.0f max (%d noises)" % [total / _noises.size(), _noises.max(), _noises.size()]
	var heard := _levels.filter(func(level: float) -> bool: return level >= VoiceChat.gate_db())
	var recording := "silent"
	if not heard.is_empty():
		var average := VoiceChat.average_db(heard)
		var loudest: float = heard.max()
		recording = "%.0f avg (%.0f dB under the mic's limit), %.0f loudest (%.0f)" % [
			VoiceChat.my_voice_db(average), average, VoiceChat.my_voice_db(loudest), loudest]
	return "%s, target %.0f dB\n   game: %s\n   recording: %s\n   %s" % [word.to_upper(), TAKES[_take][1], game, recording, wav]

## Saves the take as a WAV; returns where, or why not.
func _save(word: String) -> String:
	if _pcm.is_empty():
		return "(nothing recorded)"
	DirAccess.make_dir_recursive_absolute(WAV_DIR)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MicInput.RATE
	wav.stereo = false
	wav.data = _pcm
	var path := WAV_DIR + word + ".wav"
	return ProjectSettings.globalize_path(path) if wav.save_to_wav(path) == OK else "(could not save %s)" % path
