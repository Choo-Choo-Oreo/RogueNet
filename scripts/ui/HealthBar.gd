class_name HealthBar
extends Control

## Top-left health bar for the locally-controlled player. Hides itself once
## that player dies (turns into a ghost) -- no more health to track for the
## rest of the run.
## A hit leaves the lost part standing pale (Trail) for TRAIL_HOLD, then drains it, so you can
## see how big the hit was; the bar also jolts. Under HitFeedback.LOW_HEALTH the fill blinks.

@onready var fill: ColorRect = $Background/Fill
@onready var trail: ColorRect = $Background/Trail
@onready var label: Label = $Background/Label

const TRAIL_HOLD := 0.4
const TRAIL_DRAIN := 0.35
const JOLT_PX := 3.0
const JOLT_SECONDS := 0.15
const BLINK_SECONDS := 0.5
const FILL_COLOR := Color(0.2, 0.75, 0.2)
const LOW_COLOR := Color(0.85, 0.25, 0.2)

var _trail_tween: Tween
var _jolt_left := 0.0
var _home := Vector2.ZERO
var _low := false
var _blink := 0.0

var _stats: EntityStats

func _ready() -> void:
	_home = position

func _process(delta: float) -> void:
	if _jolt_left > 0.0:
		_jolt_left = maxf(_jolt_left - delta, 0.0)
		var push := JOLT_PX * _jolt_left / JOLT_SECONDS
		position = _home + Vector2(randf_range(-push, push), randf_range(-push, push)).round()
	if _low:
		_blink = fmod(_blink + delta, BLINK_SECONDS)
		fill.color = LOW_COLOR if _blink < BLINK_SECONDS / 2.0 else FILL_COLOR
	if _stats == null:
		var player := PlayerLookup.find_local(get_tree())
		if player:
			_stats = player.stats
			_stats.health_changed.connect(_on_health_changed)
			_on_health_changed(_stats.current_health, _stats.max_health)

func _on_health_changed(current: int, max_health: int) -> void:
	var share := 0.0 if max_health <= 0 else float(current) / float(max_health)
	var dropped := share < fill.anchor_right
	fill.anchor_right = share
	if _trail_tween:
		_trail_tween.kill()
	if dropped:
		_jolt_left = JOLT_SECONDS
		_trail_tween = create_tween()
		_trail_tween.tween_interval(TRAIL_HOLD)
		_trail_tween.tween_property(trail, "anchor_right", share, TRAIL_DRAIN)
	else:
		trail.anchor_right = share
	_low = current > 0 and share < HitFeedback.LOW_HEALTH
	if not _low:
		fill.color = FILL_COLOR
	label.text = "%d / %d" % [current, max_health]
	visible = current > 0
