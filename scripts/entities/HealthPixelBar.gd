class_name HealthPixelBar
extends Node2D

## Discrete pixel-strip health readout drawn under an entity's hitbox: each
## pixel is either the full-health color or the lost-health color, no
## gradient. Lost-pixel count always rounds up, so even 1 damage out of a
## big health pool shows as at least one pixel.

const PIXEL_HEIGHT := 2
const COLOR_FULL := Color(0.2, 0.85, 0.2)
const COLOR_LOST := Color(0.85, 0.15, 0.15)

var _stats: EntityStats
var _pixel_count := 16

func setup(stats: EntityStats, pixel_count: int) -> void:
	_stats = stats
	_pixel_count = pixel_count
	_stats.health_changed.connect(_on_health_changed)
	queue_redraw()

func _on_health_changed(_current: int, _max: int) -> void:
	queue_redraw()

func _draw() -> void:
	if _stats == null or _stats.max_health <= 0:
		return
	var lost_fraction: float = 1.0 - float(_stats.current_health) / float(_stats.max_health)
	var lost_pixels: int = ceili(lost_fraction * _pixel_count)
	var start_x := -_pixel_count / 2.0
	for i in _pixel_count:
		var lost: bool = i >= _pixel_count - lost_pixels
		draw_rect(Rect2(start_x + i, 0.0, 1.0, PIXEL_HEIGHT), COLOR_LOST if lost else COLOR_FULL)
