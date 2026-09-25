class_name MicInput
extends Node

## Records a microphone through Godot (not Steam) while on: 16-bit mono PCM at RATE, handed out
## CHUNK_SAMPLES at a time (the chunk signal), with `gain_db` added. Which mic is AudioServer's
## input device (devices(), set_device()). It listens on its own muted bus (BUS), so the mic is
## never played back out loud. No game knowledge: VoiceChat decides what the chunks are for.
## Needs audio/driver/enable_input in project.godot.

signal chunk(pcm: PackedByteArray)

const RATE := 16000
## 40 ms of sound per chunk.
const CHUNK_SAMPLES := 640
const BUS := "MicInput"
## The device name that means "whatever the system uses".
const DEFAULT_DEVICE := "Default"

var gain_db := 0.0
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
## Mono input not yet turned into output samples, and where the next output sample is read
## from in it (a fraction: the input's rate is the mixer's, not RATE).
var _input := PackedFloat32Array()
var _read_at := 0.0
var _pending := PackedByteArray()

func _ready() -> void:
	set_process(false)

static func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()

static func set_device(device: String) -> void:
	AudioServer.input_device = device if devices().has(device) else DEFAULT_DEVICE

func is_on() -> bool:
	return is_processing()

func start() -> void:
	if _player == null:
		_set_up()
	_capture.clear_buffer()
	_input.clear()
	_read_at = 0.0
	_pending.clear()
	_player.play()
	set_process(true)

func stop() -> void:
	if _player != null:
		_player.stop()
	set_process(false)

func _set_up() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS)
		AudioServer.set_bus_mute(bus, true)
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(bus, 0)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)

func _process(_delta: float) -> void:
	var frames := _capture.get_buffer(_capture.get_frames_available())
	for frame in frames:
		_input.append((frame.x + frame.y) * 0.5)
	# Down to RATE, reading between input samples (straight-line blend of the two either side).
	var step := AudioServer.get_mix_rate() / RATE
	var gain := db_to_linear(gain_db)
	while _read_at + 1.0 < _input.size():
		var i := int(_read_at)
		var sample := lerpf(_input[i], _input[i + 1], _read_at - i) * gain
		var at := _pending.size()
		_pending.resize(at + 2)
		_pending.encode_s16(at, clampi(int(sample * 32767.0), -32768, 32767))
		_read_at += step
	var used := int(_read_at)
	_input = _input.slice(used)
	_read_at -= used
	while _pending.size() >= CHUNK_SAMPLES * 2:
		chunk.emit(_pending.slice(0, CHUNK_SAMPLES * 2))
		_pending = _pending.slice(CHUNK_SAMPLES * 2)
