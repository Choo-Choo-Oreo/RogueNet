class_name BardPerformance
extends Node2D

## A player's solo: the song of the instrument in their main hand (the item's "song"),
## looping until stopped. The performer hears it at full volume while the game's music
## ducks (MusicManager.duck). Everyone else hears it from where the performer stands.
## Started and stopped on every screen by NetworkSync.receive_performing.

## How far away (px) other players still hear someone's solo.
const HEARING_DISTANCE := 480.0

var song := ""
var _local: AudioStreamPlayer
var _positional: AudioStreamPlayer2D

func _ready() -> void:
	_local = AudioStreamPlayer.new()
	_local.bus = "Music"
	add_child(_local)
	_positional = AudioStreamPlayer2D.new()
	_positional.bus = "Music"
	_positional.max_distance = HEARING_DISTANCE
	add_child(_positional)
	# a file not imported looping would otherwise play once
	_local.finished.connect(_local.play)
	_positional.finished.connect(_positional.play)

## path "" stops. mine: this machine's own player, heard up close with the music ducked.
func play(path: String, mine: bool) -> void:
	if path == song:
		return
	stop()
	var stream: AudioStream = load(path) if path != "" and ResourceLoader.exists(path) else null
	if stream == null:
		if path != "":
			push_warning("BardPerformance: couldn't load song \"%s\"" % path)
		return
	song = path
	var player: Node = _local if mine else _positional
	player.stream = stream
	player.play()
	if mine:
		MusicManager.duck(true)

func stop() -> void:
	if song == "":
		return
	if _local.playing:
		MusicManager.duck(false)
	song = ""
	_local.stop()
	_positional.stop()

func _exit_tree() -> void:
	stop()
