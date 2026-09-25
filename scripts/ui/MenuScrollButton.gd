class_name MenuScrollButton
extends Button

## A main-menu button drawn as a parchment scroll (art in resources/gfx/ui/main_menu/).
## The Button's text is moved onto the paper. The scroll unrolls when the menu opens,
## lifts and glows while hovered, and MainMenu's weapon can cut it in half (cut()) or
## burn it away (burn()) before the button's action runs. restore() puts it back.
##
## The paper is two halves (top and bottom rows), so a cut can split it. Each half
## clips its own copy of the caption to the pixels it draws (clip_children), so the
## words split with the paper and burn away with it.

const ART := "res://resources/gfx/ui/main_menu/"
## Screen pixels per art pixel.
const PX := 3
const PAPER_SIZE := Vector2i(72, 14)
const ROLLER_SIZE := Vector2i(6, 20)
## Where the paper's top row sits on the rollers.
const PAPER_Y := 3
## The cut runs between the halves: rows 0-6 on top, 7-13 below.
const CUT_ROW := 7
const BURN_FRAMES := 12
const BURN_TIME := 0.9
## ScrollBurnFlames.png frames start this many rows above the paper.
const FLAMES_ABOVE := 6
const SLASH_SIZE := Vector2i(88, 9)
const SLASH_FRAMES := 5
## Row of ScrollSlash.png that lines up with the cut.
const SLASH_LINE := 4
const INK := Color(0.24, 0.13, 0.08)    # brown ink, to suit the parchment
const CAPTION_SIZE := 20

const PAPER_TEX := preload(ART + "ScrollPaper.png")
const ROLLER_TEX := preload(ART + "ScrollRoller.png")
const GLOW_TEX := preload(ART + "ScrollGlow.png")
const BURN_TEX := preload(ART + "ScrollBurn.png")
const FLAMES_TEX := preload(ART + "ScrollBurnFlames.png")
const SLASH_TEX := preload(ART + "ScrollSlash.png")

## 0 = rolled up, 1 = fully open. Animated by unroll().
var unroll_amount := 1.0:
	set(value):
		unroll_amount = clampf(value, 0.0, 1.0)
		_layout()

## True once a cut or burn has started, until restore().
var destroyed := false
## True while a cut or burn is still playing; effect_finished fires when it ends.
var effect_running := false
signal effect_finished

var _visual: Control        # everything that lifts on hover
var _paper_clip: Control    # grows from the middle while the scroll unrolls
var _halves: Array[TextureRect] = []
var _roller_left: TextureRect
var _roller_right: TextureRect
var _glow: TextureRect
var _flames: TextureRect
var _slash: TextureRect
var _glow_tween: Tween

func _ready() -> void:
	var caption := text
	text = ""
	for style in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(PAPER_SIZE.x + 2 * ROLLER_SIZE.x, ROLLER_SIZE.y) * PX
	_build(caption)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_layout()

func _build(caption: String) -> void:
	_visual = _add(Control.new(), self)
	_visual.size = custom_minimum_size

	_glow = _add(_texture_rect(GLOW_TEX), _visual)
	_glow.position = -Vector2.ONE * PX
	_glow.visible = false

	_paper_clip = _add(Control.new(), _visual)
	_paper_clip.clip_contents = true
	_paper_clip.size.y = custom_minimum_size.y
	for i in 2:
		var half := _add(_texture_rect(_region(PAPER_TEX, _half_rect(i))), _paper_clip)
		half.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		half.pivot_offset = half.size / 2.0
		var label: Label = _add(Label.new(), half)
		label.text = caption
		label.size = Vector2(PAPER_SIZE) * PX
		label.position.y = -i * CUT_ROW * PX
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", CAPTION_SIZE)
		_halves.append(half)

	_roller_left = _add(_texture_rect(ROLLER_TEX), _visual)
	_roller_right = _add(_texture_rect(ROLLER_TEX), _visual)
	_roller_right.flip_h = true

	_flames = _add(_texture_rect(_region(FLAMES_TEX, Rect2(0, 0, PAPER_SIZE.x, PAPER_SIZE.y + FLAMES_ABOVE))), _visual)
	_flames.position = Vector2(ROLLER_SIZE.x, PAPER_Y - FLAMES_ABOVE) * PX
	_flames.visible = false

	_slash = _add(_texture_rect(_region(SLASH_TEX, Rect2(0, 0, SLASH_SIZE.x, SLASH_SIZE.y))), _visual)
	_slash.position = Vector2(ROLLER_SIZE.x - (SLASH_SIZE.x - PAPER_SIZE.x) / 2, PAPER_Y + CUT_ROW - SLASH_LINE) * PX
	_slash.visible = false

## Places the halves and rollers for unroll_amount; the paper stays put and the clip
## around it grows from the middle, with the rollers riding its edges.
func _layout() -> void:
	if _paper_clip == null:
		return
	var full := PAPER_SIZE.x * PX
	var width := roundf(full * unroll_amount / PX) * PX
	var left := ROLLER_SIZE.x * PX + (full - width) / 2.0
	_paper_clip.position.x = left
	_paper_clip.size.x = width
	for i in 2:
		_halves[i].position = Vector2(ROLLER_SIZE.x * PX - left, (PAPER_Y + i * CUT_ROW) * PX)
	_roller_left.position = Vector2(left - ROLLER_SIZE.x * PX, 0)
	_roller_right.position = Vector2(left + width, 0)

## Rolls the scroll up and opens it again after `delay` seconds.
func unroll(delay: float = 0.0) -> void:
	unroll_amount = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "unroll_amount", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_hovered(hovered: bool) -> void:
	if destroyed:
		return
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", -float(PX) if hovered else 0.0, 0.08)
	_glow.visible = hovered
	if _glow_tween:
		_glow_tween.kill()
	if hovered:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_glow, "modulate:a", 0.45, 0.5)
		_glow_tween.tween_property(_glow, "modulate:a", 1.0, 0.5)

## The point a weapon aims at: the right end of the cut line, in global coordinates.
func strike_point() -> Vector2:
	return _visual.global_position + Vector2(ROLLER_SIZE.x + PAPER_SIZE.x - 2, PAPER_Y + CUT_ROW) * PX

## A slash runs right to left along the cut, then the two halves fall apart.
func cut() -> void:
	_start_destroying()
	_slash.visible = true
	for f in SLASH_FRAMES:
		(_slash.texture as AtlasTexture).region.position.x = f * SLASH_SIZE.x
		await get_tree().create_timer(0.045).timeout
		if f == 1:
			_fall_apart()
	_slash.visible = false
	await get_tree().create_timer(0.35).timeout
	_finish_effect()

func _fall_apart() -> void:
	_paper_clip.clip_contents = false    # let the halves fall out past the scroll's box
	var tween := create_tween().set_parallel()
	for i in 2:
		var half := _halves[i]
		var drop := (14.0 if i == 0 else 22.0) * PX
		tween.tween_property(half, "position", half.position + Vector2(-2 * PX if i == 0 else 3 * PX, drop), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(half, "rotation", -0.12 if i == 0 else 0.18, 0.45)
		tween.tween_property(half, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for roller in [_roller_left, _roller_right]:
		tween.tween_property(roller, "modulate:a", 0.0, 0.3)

## Fire eats the paper from the right-hand end (where the staff is) to the left.
func burn() -> void:
	_start_destroying()
	for i in 2:
		(_halves[i].texture as AtlasTexture).atlas = BURN_TEX
	_flames.visible = true
	for f in BURN_FRAMES:
		for i in 2:
			(_halves[i].texture as AtlasTexture).region.position.x = f * PAPER_SIZE.x
		(_flames.texture as AtlasTexture).region.position.x = f * PAPER_SIZE.x
		await get_tree().create_timer(BURN_TIME / BURN_FRAMES).timeout
	_flames.visible = false
	var tween := create_tween().set_parallel()
	for roller in [_roller_left, _roller_right]:
		tween.tween_property(roller, "modulate:a", 0.0, 0.25)
	await tween.finished
	_finish_effect()

func _start_destroying() -> void:
	destroyed = true
	effect_running = true
	_glow.visible = false
	if _glow_tween:
		_glow_tween.kill()

func _finish_effect() -> void:
	effect_running = false
	effect_finished.emit()

## Back to a whole scroll, unrolling again.
func restore() -> void:
	destroyed = false
	_paper_clip.clip_contents = true
	_visual.position.y = 0.0
	for i in 2:
		var half := _halves[i]
		half.texture = _region(PAPER_TEX, _half_rect(i))
		half.rotation = 0.0
		half.modulate.a = 1.0
	for roller in [_roller_left, _roller_right]:
		roller.modulate.a = 1.0
	unroll()
	if is_hovered():
		_set_hovered(true)

func _half_rect(i: int) -> Rect2:
	return Rect2(0, i * CUT_ROW, PAPER_SIZE.x, CUT_ROW if i == 0 else PAPER_SIZE.y - CUT_ROW)

static func _region(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	return atlas

static func _texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = texture.get_size() * PX
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

static func _add(node: Control, parent: Node) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
