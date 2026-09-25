class_name HealthBar
extends PanelContainer

## Top-left player frame for the locally-controlled player: portrait, name, mic
## and health bar. Hides itself once that player dies (turns into a ghost) --
## no more health to track for the rest of the run.
## Hooks for later: set_player_name(), set_portrait(), and the hidden ResourceBar
## (mana or stamina, if the game gets one).

@onready var fill: ColorRect = $Row/Column/Background/Fill
@onready var label: Label = $Row/Column/Background/Label
@onready var name_label: Label = $Row/Column/Top/Name
@onready var mic: Control = $Row/Column/Top/Mic
@onready var portrait: Panel = $Row/Portrait

## How the mic prompt looks while push-to-talk is off / on.
const MIC_IDLE := Color(1, 1, 1, 0.45)
const MIC_LIVE := Color(0.6, 1.0, 0.6, 1)

var _stats: EntityStats

func _process(_delta: float) -> void:
	if _stats == null:
		var player := PlayerLookup.find_local(get_tree())
		if player:
			_stats = player.stats
			_stats.health_changed.connect(_on_health_changed)
			_on_health_changed(_stats.current_health, _stats.max_health)
	mic.modulate = MIC_LIVE if VoiceChat.talking else MIC_IDLE

func _on_health_changed(current: int, max_health: int) -> void:
	fill.anchor_right = 0.0 if max_health <= 0 else float(current) / float(max_health)
	label.text = "%d / %d" % [current, max_health]
	visible = current > 0

func set_player_name(player_name: String) -> void:
	name_label.text = player_name

## Puts a picture in the portrait box (nothing there until the game has portraits).
func set_portrait(texture: Texture2D) -> void:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	for child in portrait.get_children():
		child.queue_free()
	portrait.add_child(picture)
