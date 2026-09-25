extends Control

## The Storage screen in town: the inventory (what you wear and carry) next to
## the storage. Whatever you're wearing when the party dives is what you wear
## in the dungeon. Both panels build themselves (InventoryPanel, StoragePanel);
## this scene lays them out on a storeroom wall (Wall.png, darker at the edges),
## puts the title on a scroll, and has Back (a main-menu scroll, or Esc).
## Opening it fades the panels in and unrolls the Back scroll.

signal back_pressed

const WALL := "res://resources/gfx/ui/storage/Wall.png"
## Screen pixels per art pixel for the wall planks.
const WALL_PX := 3

@onready var _column: Control = $CenterContainer/VBoxContainer
@onready var _back: MenuScrollButton = $CenterContainer/VBoxContainer/TitleRow/BackButton

func _ready() -> void:
	$Backdrop.texture = Parchment.pixel_texture(WALL, WALL_PX)
	$Shade.texture = _vignette()
	# the title sits in the middle of the row: the empty Balance matches Back's width
	$CenterContainer/VBoxContainer/TitleRow/Balance.custom_minimum_size.x = _back.custom_minimum_size.x
	var title := Parchment.ink_label("Storage", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var banner := Parchment.strip(Parchment.MENU_DIR + "ScrollPaper.png", title)
	banner.custom_minimum_size = Vector2(240, 20 * Parchment.PX)
	banner.size = banner.custom_minimum_size
	var holder: Control = $CenterContainer/VBoxContainer/TitleRow/Title
	holder.add_child(banner)
	holder.resized.connect(func(): banner.position = ((holder.size - banner.size) / 2.0).round())
	visibility_changed.connect(_on_shown)

func _on_shown() -> void:
	if not is_visible_in_tree():
		return
	_back.unroll(0.1)
	_column.modulate.a = 0.0
	create_tween().tween_property(_column, "modulate:a", 1.0, 0.2)

# Esc goes back to town; while typing (the search, the chat) it only stops the typing.
# _input, so it comes before the pause menu's _unhandled_input.
func _input(event: InputEvent) -> void:
	if not (is_visible_in_tree() and event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	var typing := get_viewport().gui_get_focus_owner()
	if typing is LineEdit:
		typing.release_focus()
	else:
		back_pressed.emit()

func _on_back_button_pressed() -> void:
	back_pressed.emit()

# Clear in the middle, darkening towards the edges, so the panels stand out.
static func _vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.8)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	return texture
