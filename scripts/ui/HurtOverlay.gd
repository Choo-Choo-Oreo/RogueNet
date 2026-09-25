class_name HurtOverlay
extends CanvasLayer

## What only the hurt player's own screen shows (HitFeedback drives it, for the local player):
## - a red edge (resources/gfx/ui/hud/hurt_vignette.png) that flashes on a big hit,
## - a slow faint red pulse on the edges and a heartbeat while health is low,
## - a short muffle on a big hit (a low-pass on the Master bus, see AudioBusLayout.tres).
## The edge flash and pulse obey the "Screen flash" setting (ConfigFileHandler.feedback).
## One per scene, made on first use by `get_for`.

const VIGNETTE := preload("res://resources/gfx/ui/hud/hurt_vignette.png")
const HEARTBEAT := "res://resources/sfx/combat/player/heartbeat.wav"
const LAYER := 90
const FLASH_ALPHA := 0.9
const FLASH_FADE := 0.45
const PULSE_ALPHA := 0.35
const PULSE_SECONDS := 1.1   # one heartbeat
const MUFFLE_SECONDS := 0.3
const MUFFLE_CUTOFF := 900.0
const OPEN_CUTOFF := 20000.0

var _edge: TextureRect
var _flash := 0.0
var _low := false
var _beat := 0.0

static func get_for(node: Node) -> HurtOverlay:
	var scene := node.get_tree().current_scene
	if scene == null:
		return null
	var found := scene.get_node_or_null("HurtOverlay")
	if found:
		return found
	var overlay := HurtOverlay.new()
	overlay.name = "HurtOverlay"
	scene.add_child(overlay)
	return overlay

func _ready() -> void:
	layer = LAYER
	_edge = TextureRect.new()
	_edge.texture = VIGNETTE
	_edge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.modulate.a = 0.0
	add_child(_edge)

## A big hit: the edge flashes red and the sound muffles for a moment.
func big_hit() -> void:
	if ConfigFileHandler.feedback("screen_flash"):
		_flash = 1.0
	_muffle()

## Low health on or off: the edge pulse and the heartbeat.
func set_low_health(low: bool) -> void:
	if low and not _low:
		_beat = 0.0
	_low = low

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta / FLASH_FADE)
	var pulse := 0.0
	if _low:
		var before := _beat
		_beat = fmod(_beat + delta, PULSE_SECONDS)
		if _beat < before:
			SoundPlayer.play(self, HEARTBEAT, {"volume_db": -6.0, "max_voices": 1, "merge": 0.3})
		pulse = PULSE_ALPHA * (1.0 - _beat / PULSE_SECONDS)
		if not ConfigFileHandler.feedback("screen_flash"):
			pulse = 0.0
	_edge.modulate.a = maxf(_flash * FLASH_ALPHA, pulse)

func _muffle() -> void:
	var filter := _low_pass()
	if filter == null:
		return
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_effect_enabled(bus, 0, true)
	filter.cutoff_hz = MUFFLE_CUTOFF
	var open := create_tween()
	open.tween_property(filter, "cutoff_hz", OPEN_CUTOFF, MUFFLE_SECONDS).set_ease(Tween.EASE_IN)
	open.tween_callback(func(): AudioServer.set_bus_effect_enabled(bus, 0, false))

## Leaving the scene mid-muffle kills the tween before it switches the filter off, which
## would leave every sound muffled from then on.
func _exit_tree() -> void:
	var filter := _low_pass()
	if filter:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Master"), 0, false)
		filter.cutoff_hz = OPEN_CUTOFF

## The Master bus's first effect, a low-pass left disabled until a big hit.
static func _low_pass() -> AudioEffectLowPassFilter:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return null
	return AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
