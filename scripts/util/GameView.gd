class_name GameView
extends Control

## The world's pixel grid (resources/gfx/TODO.md): the world draws into a SubViewport of VIEW
## art pixels, shown at ART_PX UI units per art pixel, so every world pixel is a whole 2x2 block
## of the 640x360 UI grid. The camera is the one exception and slides smoothly: the viewport
## draws with the camera snapped to a whole art pixel, and this shifts the finished picture by
## the leftover fraction. BORDER extra art pixels on every side keep world under that shift;
## this Control clips them, so exactly VIEW is ever shown.
##
## A world scene (Dungeon.tscn) is loaded into it with change_to(). The GameView is then the
## current scene, since Godot only allows a direct child of the root there, so world code finds
## its scene with world_scene(), not current_scene.
const VIEW := Vector2i(320, 180)
const BORDER := 1
## UI units (640x360 pixels) per world art pixel.
const ART_PX := 2

## Where the world scene goes. Every node here has a fixed name: RPCs find nodes by path, so the
## path must be the same on every peer (an automatic "@SubViewport@27" can differ).
var world: SubViewport
var _container: SubViewportContainer
## The scene file loaded into `world`, for reload().
var _world_path := ""

func _init() -> void:
	name = "GameView"
	clip_contents = true
	mouse_filter = MOUSE_FILTER_PASS
	size = VIEW * ART_PX
	_container = SubViewportContainer.new()
	_container.name = "WorldContainer"
	_container.stretch = true
	_container.stretch_shrink = ART_PX
	_container.size = (VIEW + Vector2i.ONE * BORDER * 2) * ART_PX
	# Art pixels are hard blocks. A new SubViewport filters LINEAR by default (the project's
	# Nearest setting only reaches the root window), which blurs anything scaled inside it.
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_container)
	world = SubViewport.new()
	world.name = "World"
	world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
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

## Changes scene like SceneTree.change_scene_to_file, with the scene at `path` inside a new
## GameView.
static func change_to(tree: SceneTree, path: String) -> void:
	var view := GameView.new()
	view._world_path = path
	view.world.add_child(load(path).instantiate())
	tree.change_scene_to_node(view)

## The scene the world code works in: the one inside the GameView, or the current scene when
## there is no GameView (the town, the Dungeon Maker, a test that loads Dungeon.tscn directly).
static func world_scene(tree: SceneTree) -> Node:
	var view := tree.current_scene as GameView
	if view and view.world.get_child_count() > 0:
		return view.world.get_child(0)
	return tree.current_scene

## SceneTree.reload_current_scene, for a scene inside a GameView too.
static func reload(tree: SceneTree) -> void:
	var view := tree.current_scene as GameView
	if view:
		change_to(tree, view._world_path)
	else:
		tree.reload_current_scene()
