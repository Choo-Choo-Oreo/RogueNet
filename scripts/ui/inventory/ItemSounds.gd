class_name ItemSounds
extends RefCounted

## The inventory's sounds (resources/sfx/ui/inventory/<name>.mp3, from Pixabay), on the UI bus.
## An item sounds like what it's made of (ItemDatabase.sound): a deep metallic thud
## for plate, a glass clink for a potion. The same material decides how hard the
## icon squashes when it lands, so heavy things feel heavy.

const DIR := "res://resources/sfx/ui/inventory/"
const BUS := "UI"

## Material -> how much a dropped icon squashes (0.2 = 20%). These are also the only
## names an item's or set's "sound" may use.
const MATERIALS := {
	"metal": 0.22, "stone": 0.2, "wood": 0.15, "leather": 0.12, "bone": 0.12,
	"organic": 0.1, "cloth": 0.08, "glass": 0.08, "paper": 0.06, "jewel": 0.06,
}
## Sounds of the storage screen itself.
const TAB := "tab"
const SORT := "sort"
const LOCK := "lock"
const REFUSE := "refuse"
## Sounds that play quieter than the rest (dB). Tidying is background noise, not news.
const VOLUMES := {SORT: -12.0, TAB: -4.0}
## The same sound can't start again within this many seconds, so a burst of moves
## (sorting, "Store all", fast clicks) makes one sound instead of a pile of them.
const REPEAT_GAP := 0.08
## A few of the recordings run long (the leather one is nearly 5 s): anything still
## playing after this many seconds fades out, so a click never outlasts the action.
const MAX_LENGTH := 0.7
const FADE_OUT := 0.15

## Plays the sound of what item_id is made of.
static func play_item(from: Node, item_id: String) -> void:
	play(from, ItemDatabase.sound(item_id), randf_range(0.93, 1.07))

## How hard item_id lands (see MATERIALS).
static func weight(item_id: String) -> float:
	return MATERIALS.get(ItemDatabase.sound(item_id), 0.1)

## One-shot on the UI bus (SoundPlayer does the overlap and fade rules).
static func play(from: Node, sound_name: String, pitch: float = 1.0) -> void:
	SoundPlayer.play(from, DIR + sound_name + ".mp3", {
		"bus": BUS,
		"pitch": pitch,
		"volume_db": VOLUMES.get(sound_name, 0.0),
		"merge": REPEAT_GAP,
		"boost": 0.0,
		"max_voices": 8,
		"max_length": MAX_LENGTH,
		"fade": FADE_OUT,
	})
