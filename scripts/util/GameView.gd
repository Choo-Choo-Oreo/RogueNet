class_name GameView
extends Control

## The world's pixel grid (resources/gfx/TODO.md): the world draws into a SubViewport of VIEW
## art pixels, shown at ART_PX UI units per art pixel, so every world pixel is a whole 2x2 block
## of the 640x360 UI grid. The camera is the one exception and slides smoothly: the viewport
## draws with the camera snapped to a whole art pixel, and this shifts the finished picture by
## the leftover fraction. BORDER extra art pixels on every side keep world under that shift;
## this Control clips them, so exactly VIEW is ever shown.
const VIEW := Vector2i(320, 180)
const BORDER := 1
## UI units (640x360 pixels) per world art pixel.
const ART_PX := 2

## Where world scenes go.
var world: SubViewport
var _container: SubViewportContainer

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_PASS
	size = VIEW * ART_PX
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.stretch_shrink = ART_PX
	_container.size = (VIEW + Vector2i.ONE * BORDER * 2) * ART_PX
	add_child(_container)
	world = SubViewport.new()
	world.snap_2d_transforms_to_pixel = true
	world.snap_2d_vertices_to_pixel = true
	_container.add_child(world)
	# After the camera has moved this frame.
	process_priority = 100

func _process(_delta: float) -> void:
	var camera := world.get_camera_2d()
	var offset := leftover(camera.get_screen_center_position() * camera.zoom) if camera else Vector2.ZERO
	_container.position = -(Vector2.ONE * BORDER + offset) * ART_PX

## How far (in viewport pixels) the camera sits from where the viewport snapped it. The viewport
## rounds positions as floor(x + 0.5), so this is in (-0.5, 0.5].
static func leftover(centre: Vector2) -> Vector2:
	return centre + (Vector2(0.5, 0.5) - centre).floor()
