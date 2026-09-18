extends CharacterBody2D

class_name PlaceholderMouse

## Stand-in enemy for the Dungeon Maker's enemy spawners until real enemy
## content exists. Used both as the (non-wandering) editor marker and as the
## live, wandering actor spawned during a Test session.

const TILE_SIZE := 16
const BODY_COLOR := Color(0.55, 0.52, 0.5)
const EAR_COLOR := Color(0.75, 0.6, 0.6)
const WANDER_INTERVAL := 1.4
const WANDER_MOVE_TIME := 0.35

@export var wander: bool = false
@export var wander_radius_tiles: int = 3

@onready var sprite: Sprite2D = $Sprite2D

var _home_position: Vector2 = Vector2.ZERO
var _wall_data: TileMapLayer
var _is_moving := false
var _wander_timer := 0.0

static func make_icon() -> Texture2D:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_plot_filled_circle(image, Vector2(8, 10), 5.0, BODY_COLOR)
	_plot_filled_circle(image, Vector2(4, 4), 2.0, EAR_COLOR)
	_plot_filled_circle(image, Vector2(12, 4), 2.0, EAR_COLOR)
	return ImageTexture.create_from_image(image)

static func _plot_filled_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2 := radius * radius
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
				continue
			if Vector2(x - center.x, y - center.y).length_squared() <= r2:
				image.set_pixel(x, y, color)

func _ready() -> void:
	sprite.texture = make_icon()
	_home_position = global_position
	if wander:
		_wall_data = get_tree().current_scene.find_child("WallData", true, false)

func _process(delta: float) -> void:
	if not wander or _is_moving:
		return
	_wander_timer += delta
	if _wander_timer < WANDER_INTERVAL:
		return
	_wander_timer = 0.0
	_try_wander_step()

func _try_wander_step() -> void:
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	dirs.shuffle()
	for direction in dirs:
		var target: Vector2 = global_position + direction * TILE_SIZE
		if target.distance_to(_home_position) > wander_radius_tiles * TILE_SIZE:
			continue
		if _is_blocked(target):
			continue
		_is_moving = true
		var tween := create_tween()
		tween.tween_property(self, "global_position", target, WANDER_MOVE_TIME)
		tween.finished.connect(func(): _is_moving = false)
		return

func _is_blocked(target_global: Vector2) -> bool:
	if _wall_data == null:
		return false
	var cell: Vector2i = _wall_data.local_to_map(_wall_data.to_local(target_global))
	return _wall_data.get_cell_source_id(cell) != -1
