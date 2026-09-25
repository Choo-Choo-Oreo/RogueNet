class_name Parchment
extends RefCounted

## The main menu's parchment look (resources/gfx/ui/main_menu/), for the screens
## built in code that match it: the storage, the party wipe's graves. Paper strips
## between wooden rollers, paper boxes with a dark edge, brown ink. Also the wooden
## panels with brass corners the inventory and storage sit in (wood_panel, heading).

const MENU_DIR := "res://resources/gfx/ui/main_menu/"
const STORAGE_DIR := "res://resources/gfx/ui/storage/"
## Screen pixels per art pixel.
const PX := 2
const INK := MenuScrollButton.INK
const PAPER := Color("#e2ca9a")
const PAPER_LIGHT := Color("#f6e8c4")
const PAPER_DARK := Color("#96724a")
const OUTLINE := Color("#2c1a16")
const GOLD := Color("#f0ca68")

static var _pixel_cache: Dictionary = {}

## A pixel-art texture blown up `factor` times with no smoothing, for places that
## draw textures at their own size (button icons, nine-patches).
static func pixel_texture(path: String, factor: int = PX) -> Texture2D:
	var key := "%s@%d" % [path, factor]
	if not _pixel_cache.has(key):
		var image := (load(path) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
		_pixel_cache[key] = ImageTexture.create_from_image(image)
	return _pixel_cache[key]

## A scroll like the main menu's: paper between two wooden rollers, `content` on
## the paper. Lays itself out whenever it's resized. The paper is its "paper" meta.
static func strip(paper_path: String, content: Control) -> Control:
	var scroll := Control.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := NinePatchRect.new()
	paper.texture = pixel_texture(paper_path)
	paper.patch_margin_left = 3 * PX
	paper.patch_margin_right = 3 * PX
	paper.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := pixel_rect(MENU_DIR + "ScrollRoller.png")
	var right := pixel_rect(MENU_DIR + "ScrollRoller.png")
	scroll.add_child(paper)
	scroll.add_child(content)
	scroll.add_child(left)
	scroll.add_child(right)
	scroll.set_meta("paper", paper)
	var roller := left.size.x
	var lay := func():
		var w := scroll.size.x
		paper.position = Vector2(roller / 2.0, 3 * PX)
		paper.size = Vector2(w - roller, 14 * PX)
		right.position = Vector2(w - roller, 0)
		content.position = Vector2(roller, 3 * PX)
		content.size = Vector2(w - roller * 2, 14 * PX)
	# resized only fires inside the tree, so lay out again on entering it too
	scroll.resized.connect(lay)
	scroll.tree_entered.connect(lay)
	return scroll

static func pixel_rect(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = pixel_texture(path)
	rect.size = rect.texture.get_size()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func ink_label(text: String, font_size: int) -> Label:
	var label := InventoryPanel._label(text, INK, font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Parchment buttons with ink text: lighter when hovered, gold-edged when on.
static func button_look(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	parchment(button, ["normal"])
	var hover := paper_box(PAPER_LIGHT, OUTLINE)
	var on := paper_box(PAPER_LIGHT, GOLD.darkened(0.2))
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_constant_override("h_separation", 6)

static func parchment(control: Control, states: Array) -> void:
	for state in states:
		control.add_theme_stylebox_override(state, paper_box(PAPER, OUTLINE))

static func paper_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(PX)
	box.border_width_bottom = PX * 2
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

## A page of parchment for a PanelContainer: paper, a dark edge thicker at the bottom, a shadow.
static func page_style(margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = OUTLINE
	style.set_border_width_all(PX)
	style.border_width_bottom = PX * 2
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	style.set_content_margin_all(margin)
	return style

## A wooden panel with brass corners and a dark inside (Frame.png, a nine-patch with
## 8-pixel edges), for a PanelContainer. `padding` is the room inside the wood.
static func wood_panel(padding: int = 8) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = pixel_texture(STORAGE_DIR + "Frame.png")
	box.set_texture_margin_all(8 * PX)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.set_content_margin_all(6 * PX + padding)
	return box

## A section title on a wooden panel: the words, a brass rule across the rest of the
## row (Divider.png), then `extra` (a count, a close button) if given.
static func heading(text: String, font_size: int = 16, extra: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := InventoryPanel._label(text, InventoryPanel.COLOR_TEXT, font_size)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(title)
	var rule := NinePatchRect.new()
	rule.texture = pixel_texture(STORAGE_DIR + "Divider.png")
	rule.patch_margin_left = 6 * PX
	rule.patch_margin_right = 6 * PX
	rule.custom_minimum_size = Vector2(12 * PX, 5 * PX)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	if extra:
		row.add_child(extra)
	return row
