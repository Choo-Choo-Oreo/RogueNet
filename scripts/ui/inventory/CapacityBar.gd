class_name CapacityBar
extends HBoxContainer

## How full the bag or the storage is: "12 / 21" and a thin bar that fills in gold, red
## once it's nearly full. The bar slides to its new length when the count changes.

const WARN_AT := 0.9
const BAR_SIZE := Vector2(64, 8)
const TROUGH := Color("#140d0c")
const FILL := Parchment.GOLD
const FULL := Color("#d8584a")

var _label := InventoryPanel._label("", InventoryPanel.COLOR_DIM, 13)
var _bar := Control.new()
var _shown := 0.0
var _target := 0.0
var _tween: Tween

func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	add_child(_bar)

func set_count(used: int, total: int) -> void:
	_label.text = "%d / %d" % [used, total]
	var share := float(used) / float(maxi(total, 1))
	if is_equal_approx(share, _target):
		return
	_target = share
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float):
		_shown = v
		_bar.queue_redraw(), _shown, share, 0.25)

func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, BAR_SIZE)
	_bar.draw_rect(r, TROUGH)
	var inner := r.grow(-2)
	inner.size.x = roundf(inner.size.x * _shown / 2.0) * 2.0
	if inner.size.x > 0:
		_bar.draw_rect(inner, FULL if _target >= WARN_AT else FILL)
		_bar.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), Color(1, 1, 1, 0.25))
