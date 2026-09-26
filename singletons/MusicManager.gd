extends Node

const DEFAULT_MUSIC := "res://resources/sfx/music/Groovy.mp3"
const MENU_MUSIC := "res://resources/sfx/music/Menu-Music.mp3"
## A biome's ambience (its defines "ambience": cave drips, wind) under the music, on the
## effects bus: this loud, fading in over this many seconds and out over a fifth of that.
const AMBIENCE_DB := -10.0
const AMBIENCE_FADE := 2.0
## While this machine's player performs (BardPerformance), the music drops this far,
## fading over this many seconds.
const DUCK_DB := -40.0
const DUCK_FADE := 0.6

var _player: AudioStreamPlayer
var _current_path := ""
var _ambience: AudioStreamPlayer
var _ambience_path := ""
var _ambience_fade: Tween
var _duck_fade: Tween

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.finished.connect(func(): _player.play())
	add_child(_player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "SFX"
	# for a file not imported looping; one that is never finishes
	_ambience.finished.connect(func(): _ambience.play())
	add_child(_ambience)

# defines: the dictionary from DungeonAssembler.load_defines(biome). Falls back to
# Groovy.mp3 if the biome has no "music" entry, same as the room-count/tag-weight fallback.
# No "ambience" entry: no ambience.
func play_for_biome(defines: Dictionary) -> void:
	_play(defines.get("music", DEFAULT_MUSIC))
	_play_ambience(defines.get("ambience", ""))

func play_menu() -> void:
	_play(MENU_MUSIC)
	_play_ambience("")

func _play(path: String) -> void:
	if path == _current_path:
		return
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("MusicManager: couldn't load music \"%s\"" % path)
		return
	_current_path = path
	_player.stream = stream
	_player.play()

## Fades the music down (true) for a solo, or back up (false).
func duck(on: bool) -> void:
	if _duck_fade:
		_duck_fade.kill()
	_duck_fade = create_tween()
	_duck_fade.tween_property(_player, "volume_db", DUCK_DB if on else 0.0, DUCK_FADE)

func stop() -> void:
	_current_path = ""
	_player.stop()
	_play_ambience("")

# Fades the ambience over to `path` ("" = none). Starts somewhere in the loop, so two dives
# don't begin the same way.
func _play_ambience(path: String) -> void:
	if path == _ambience_path:
		return
	_ambience_path = path
	if _ambience_fade:
		_ambience_fade.kill()
	var stream: AudioStream = load(path) if path != "" and ResourceLoader.exists(path) else null
	if path != "" and stream == null:
		push_warning("MusicManager: couldn't load ambience \"%s\"" % path)
	_ambience_fade = create_tween()
	if stream == null:
		_ambience_fade.tween_property(_ambience, "volume_db", -60.0, AMBIENCE_FADE / 5.0)
		_ambience_fade.tween_callback(_ambience.stop)
		return
	_ambience.stream = stream
	_ambience.volume_db = -60.0
	_ambience.play(randf() * stream.get_length())
	_ambience_fade.tween_property(_ambience, "volume_db", AMBIENCE_DB, AMBIENCE_FADE)
