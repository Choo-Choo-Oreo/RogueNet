extends Node

const DEFAULT_MUSIC := "res://resources/sfx/music/Groovy.mp3"
const MENU_MUSIC := "res://resources/sfx/music/Menu-Music.mp3"

var _player: AudioStreamPlayer
var _current_path := ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.finished.connect(func(): _player.play())
	add_child(_player)

# defines: the dictionary from DungeonAssembler.load_defines(biome). Falls back to
# Groovy.mp3 if the biome has no "music" entry, same as the room-count/tag-weight fallback.
func play_for_biome(defines: Dictionary) -> void:
	_play(defines.get("music", DEFAULT_MUSIC))

func play_menu() -> void:
	_play(MENU_MUSIC)

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

func stop() -> void:
	_current_path = ""
	_player.stop()
