class_name GameView
extends Control

## The world's pixel grid (resources/gfx/TODO.md): the world draws into a SubViewport of VIEW
## art pixels, shown at ART_PX UI units per art pixel, so every world pixel is a whole 2x2 block
## of the 640x360 UI grid. The camera is the one exception and slides smoothly: just before
## drawing, this rounds the viewport's camera offset to a whole art pixel itself and shifts the
## finished picture by the remainder (a shader, so input is not moved). BORDER extra art pixels on
## every side keep world under that shift; this Control clips them, so exactly VIEW is ever shown.
## Technique: apples/godot-smooth-pixel-subviewport-container.
##
## A world scene (Dungeon.tscn) is loaded into it with change_to(), with its HUD next to the
## viewport (on the 640x360 UI grid, not in the world). The GameView is then the current scene,
## since Godot only allows a direct child of the root there, so world code finds its scene with
## world_scene(), not current_scene.
const VIEW := Vector2i(320, 180)
const BORDER := 1
## UI units (640x360 pixels) per world art pixel, at view scale 1.
const ART_PX := 2
## Zoom levels, as world magnification: 4x out, 2x out, normal, 2x in, 4x in. Whole steps only, so
## art pixels stay whole blocks. Out = set_view_scale (more world), in = camera zoom.
const ZOOM_LEVELS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const OFFSET_SHADER := preload("res://resources/shaders/game_view_offset.gdshader")

## Where the world scene goes. Every node here has a fixed name: RPCs find nodes by path, so the
## path must be the same on every peer (an automatic "@SubViewport@27" can differ).
var world: SubViewport
var _container: SubViewportContainer
## How many times VIEW the world viewport shows (1, 2 or 4), see set_view_scale.
var view_scale := 1
## UI units per art pixel now: ART_PX / view_scale (2, 1 or 0.5).
var art_px := float(ART_PX)
var _offset_material := ShaderMaterial.new()
## The HUD scene next to the viewport, or null.
var hud: Node
## Debug drawing (DebugDraw): full screen resolution, outside the pixel grid. Its transform maps
## world coordinates to where the world is on screen, from the same snapped camera and leftover
## as the picture, so debug lines stay on their tiles.
var debug_layer := CanvasLayer.new()
## The scene files loaded, for reload().
var _world_path := ""
var _hud_path := ""

func _init() -> void:
	name = "GameView"
	clip_contents = true
	mouse_filter = MOUSE_FILTER_PASS
	size = VIEW * ART_PX
	# First child, so it is ready before the world scene adds DebugDraw to it; it still draws
	# over the world (a layer), and under the HUD (same layer, added later).
	debug_layer.name = "DebugLayer"
	add_child(debug_layer)
	_container = SubViewportContainer.new()
	_container.name = "WorldContainer"
	# Sized by set_view_scale, not stretched: stretch_shrink cannot go below 1 (4x out).
	_container.stretch = false
	_offset_material.shader = OFFSET_SHADER
	_container.material = _offset_material
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
	set_view_scale(1)

## Shows `times` VIEW of world (1, 2 or 4) in the same on-screen area: the world viewport grows and
## its picture is drawn smaller (2 UI px per art pixel, then 1, then 0.5). Zooming out this way
## keeps every art pixel, where a camera zoom below 1 would drop some. The hidden border grows with
## it, so it stays BORDER * ART_PX whole UI pixels. The free cam's zoom-out uses it, and so will
## the "better vision" zoom-out.
func set_view_scale(times: int) -> void:
	view_scale = times
	art_px = float(ART_PX) / times
	world.size = (VIEW + Vector2i.ONE * BORDER * 2) * times
	_container.scale = Vector2.ONE * art_px
	_container.size = world.size
	_container.position = -Vector2.ONE * BORDER * ART_PX

func _ready() -> void:
	get_viewport().size_changed.connect(_centre)
	_centre()

## Centred in the window's UI area on whole UI pixels. Centre anchors would put it on a half pixel
## when the area is an odd number wider (aspect "expand": 685x360 leaves 22.5 each side).
func _centre() -> void:
	position = ((get_viewport().get_visible_rect().size - size) / 2).floor()

func _enter_tree() -> void:
	RenderingServer.frame_pre_draw.connect(_snap_camera)

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_snap_camera)

## Runs after everything has moved this frame, just before drawing: the viewport draws with its
## camera offset rounded to a whole art pixel, and the picture is shifted by what was left over.
func _snap_camera() -> void:
	var split := snap(world.canvas_transform.origin)
	world.canvas_transform.origin = split[0]
	# The shader works in the container's own units, one per world viewport pixel.
	_offset_material.set_shader_parameter("vertex_offset", split[1])
	var shift: Vector2 = split[1] * art_px
	var to_container := Transform2D(0.0, Vector2.ONE * art_px, 0.0, _container.position + shift)
	debug_layer.transform = get_global_transform() * to_container * world.canvas_transform

## Size factor for debug drawing (DebugMenu, DebugDraw's labels): the window's height over 720,
## the 1280x720 base their sizes were made for, so debug text keeps its share of the screen at
## any window size. Debug drawing is full resolution, off the grid, so a fraction is fine.
static func debug_scale(tree: SceneTree) -> float:
	return tree.root.size.y / 720.0

## The GameView `node` is in, or null (a scene loaded on its own, like the tests do).
static func of(node: Node) -> GameView:
	while node and not node is GameView:
		node = node.get_parent()
	return node as GameView

## Where debug drawing goes for `node`'s scene: the debug layer, or the scene itself when it is not
## in a GameView.
static func debug_parent(node: Node) -> Node:
	var view := of(node)
	return view.debug_layer if view else node

## [a camera offset rounded to whole pixels, what is left over (each axis within 0.5)].
static func snap(origin: Vector2) -> Array:
	return [origin.round(), origin - origin.round()]

## Changes scene like SceneTree.change_scene_to_file, with the scene at `path` inside a new
## GameView and the HUD at `hud_path` (if any) next to it.
static func change_to(tree: SceneTree, path: String, hud_path := "") -> void:
	var view := GameView.new()
	view._world_path = path
	view._hud_path = hud_path
	view.world.add_child(load(path).instantiate())
	if hud_path != "":
		view.hud = load(hud_path).instantiate()
		view.add_child(view.hud)
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
		change_to(tree, view._world_path, view._hud_path)
	else:
		tree.reload_current_scene()

## NetworkSync.receive_chat() calls add_chat_line() on the current scene: pass it to the HUD.
func add_chat_line(line: String) -> void:
	if hud and hud.has_method("add_chat_line"):
		hud.add_chat_line(line)
