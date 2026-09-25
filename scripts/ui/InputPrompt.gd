class_name InputPrompt
extends HBoxContainer

## A button prompt: the key or pad button, then what it does ("[Space] Attack",
## "(A) Open door"). It follows InputDevice, so it shows the key while the player
## uses keyboard + mouse and the pad button while they use a controller.
## The look of each glyph comes from HudTheme.tres (PromptKey, PromptA, PromptShoulder...).

## What the prompt says after the glyph. Empty = glyph only.
@export var text := ""
## Key(s) shown for keyboard + mouse, e.g. "Space" or "1–0". Empty = no key yet.
@export var key_text := ""
## Pad button(s), e.g. "A", "RT" or "LB RB". Empty = no pad button yet.
@export var pad_text := ""
## Hide the whole prompt when the player is on keyboard + mouse (LB/RB beside the hotbar).
@export var pad_only := false

const FACE_BUTTONS := ["A", "B", "X", "Y"]

var _glyphs: HBoxContainer
var _label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyphs = HBoxContainer.new()
	_glyphs.add_theme_constant_override("separation", 3)
	add_child(_glyphs)
	_label = Label.new()
	_label.theme_type_variation = &"HudSmall"
	add_child(_label)
	InputDevice.changed.connect(_show)
	_show(InputDevice.using_pad)

func set_text(new_text: String) -> void:
	text = new_text
	if _label:
		_label.text = text
		_label.visible = text != ""

func _show(using_pad: bool) -> void:
	visible = using_pad or not pad_only
	for glyph in _glyphs.get_children():
		glyph.queue_free()
	var names := (pad_text if using_pad else key_text).split(" ", false)
	for glyph_name in names:
		var glyph := Label.new()
		glyph.text = glyph_name
		glyph.theme_type_variation = _style_for(glyph_name, using_pad)
		_glyphs.add_child(glyph)
	_glyphs.visible = not names.is_empty()
	set_text(text)

func _style_for(glyph_name: String, using_pad: bool) -> StringName:
	if not using_pad:
		return &"PromptKey"
	if glyph_name in FACE_BUTTONS:
		return StringName("Prompt" + glyph_name)
	return &"PromptShoulder"
