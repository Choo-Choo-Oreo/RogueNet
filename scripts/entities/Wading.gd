class_name Wading
extends Node

## Makes a creature look (and sound) like it's wading when it stands in water
## (the floor_water tile). Only looks: it never changes speed or anything else, so it
## needs no networking -- every machine works it out from where the body is.
## - The body sinks a pixel and everything below the surface is tinted blue and
##   see-through, with a pale rim where the water meets the legs, wobbling gently
##   (resources/shaders/wading.gdshader). Gear sinks with the body.
## - Stepping in splashes (droplets, a ring, resources/sfx/effects/water/enter.wav);
##   each wading step sloshes (step_1-3); stepping out drips (exit).
## - Walking leaves a trail of rings; standing still sends out a slow ring now and then.
## Ghosts and fliers don't wade (GridMover ignores terrain for them).

const SHADER := preload("res://resources/shaders/wading.gdshader")
const SFX := "res://resources/sfx/effects/water/"
const WATER_TILE := "floor_water"
## How long the body takes to sink in or rise out, in seconds.
const FADE_SECONDS := 0.15
## How high the water comes above the ground, in pixels (matches the shader's depth).
const DEPTH := 4.0
## Rings while walking, and the wait between rings while standing (seconds).
const WAKE_EVERY := 0.16
const IDLE_RING_EVERY := Vector2(1.4, 2.8)
## Over the water tiles, under walls and bodies.
const RIPPLE_Z := 50
## Wading is quieter than fighting: this much under CombatSounds' volume for the same body.
const QUIETER_DB := 10.0
const FOAM := Color(0.85, 0.93, 1.0)

var _body: Node2D
var _sprite: AnimatedSprite2D
var _mover: GridMover
var _material := ShaderMaterial.new()
var _water_id := -1
var _amount := 0.0
var _wet := false
var _tile := Vector2i.MAX
var _last_position := Vector2.INF
var _wake_left := 0.0
var _idle_left := 0.0
var _step := 0

func setup(body: Node2D, sprite: AnimatedSprite2D, mover: GridMover) -> void:
	_body = body
	_sprite = sprite
	_mover = mover
	_material.shader = SHADER
	_material.set_shader_parameter("phase", randf() * TAU)
	_material.set_shader_parameter("depth", DEPTH)
	sprite.material = _material
	# the gear layers (GearLayers) are the body sprite's children: they sink with it
	for child in sprite.get_children():
		if child is AnimatedSprite2D:
			child.use_parent_material = true
	_water_id = GridMover._tile_ids().get_id(WATER_TILE)

func _process(delta: float) -> void:
	if _body == null or _mover.floor_data == null:
		return
	var feet := _feet()
	# the tile under the middle of the body (big bodies: the middle of their footprint)
	var centre := _body.global_position + Vector2.ONE * (_mover.footprint * 8.0)
	var tile: Vector2i = _mover.floor_data.local_to_map(_mover.floor_data.to_local(centre))
	# _ignores_terrain: ghosts and fliers, the same rule that stops water slowing them
	var wet := _water_id >= 0 and not _mover._ignores_terrain() and _mover.floor_data.get_cell_source_id(tile) == _water_id
	var surface := feet - Vector2(0, DEPTH)
	if wet != _wet:
		_wet = wet
		if _last_position != Vector2.INF:   # not when a body is placed in water to begin with
			_splash(surface, 12 if wet else 5)
			_play("enter" if wet else "exit", surface)
			if wet:
				_ring(surface, 2.0, 8.0, 0.6)
	elif wet and tile != _tile:
		_splash(surface, 5)
		_play("step_%d" % (_step % 3 + 1), surface)
		_step += 1
	if wet:
		if _body.global_position != _last_position:
			_wake_left -= delta
			if _wake_left <= 0.0:
				_wake_left = WAKE_EVERY
				_ring(surface, 2.0, 6.0, 0.55)
		else:
			_idle_left -= delta
			if _idle_left <= 0.0:
				_idle_left = randf_range(IDLE_RING_EVERY.x, IDLE_RING_EVERY.y)
				_ring(surface, 3.0, 7.0, 1.2)
	_tile = tile
	_last_position = _body.global_position
	var amount := move_toward(_amount, 1.0 if wet else 0.0, delta / FADE_SECONDS)
	if amount != _amount:
		_amount = amount
		_material.set_shader_parameter("amount", _amount)
		_material.set_shader_parameter("feet_y", _frame_height() / 2.0)

# The middle of the bottom edge of the body's drawn frame (the sprite is centred).
func _feet() -> Vector2:
	return _sprite.global_position + Vector2(0, _frame_height() / 2.0)

func _frame_height() -> float:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(_sprite.animation):
		return 16.0
	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	return texture.get_size().y if texture else 16.0

# ---------------------------------------------------------------- effects

func _ring(at: Vector2, from_radius: float, to_radius: float, seconds: float) -> void:
	var ring := Ripple.new()
	ring.position = at
	ring.z_index = RIPPLE_Z
	_body.get_parent().add_child(ring)
	ring.radius = from_radius
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "radius", to_radius, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "alpha", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)

# Droplets thrown up in front of the body and falling back.
func _splash(at: Vector2, count: int) -> void:
	var drops := CPUParticles2D.new()
	drops.position = at
	drops.z_index = _body.z_index + 1
	drops.one_shot = true
	drops.explosiveness = 0.9
	drops.amount = count
	drops.lifetime = 0.45
	drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drops.emission_rect_extents = Vector2(4, 1)
	drops.direction = Vector2.UP
	drops.spread = 55.0
	drops.gravity = Vector2(0, 180)
	drops.initial_velocity_min = 20.0
	drops.initial_velocity_max = 42.0
	var fade := Gradient.new()
	fade.set_color(0, Color(FOAM, 0.95))
	fade.set_color(1, Color(FOAM, 0.0))
	drops.color_ramp = fade
	_body.get_parent().add_child(drops)
	drops.emitting = true
	drops.finished.connect(drops.queue_free)

func _play(sound: String, at: Vector2) -> void:
	var team := "protagonist" if _body.is_in_group("protagonist") else ""
	var peer := int(str(_body.name)) if team != "" else 0
	var db := CombatSounds.who_db(_body, team, peer, false) - QUIETER_DB
	SoundPlayer.play(_body, SFX + sound + ".wav", {"at": at, "volume_db": db, "jitter": 0.08})

## A flat ring on the water, drawn in whole pixels, growing and fading (Wading._ring).
class Ripple extends Node2D:
	var radius := 2.0:
		set(value):
			radius = value
			queue_redraw()
	var alpha := 0.8:
		set(value):
			alpha = value
			queue_redraw()

	func _draw() -> void:
		var rx := roundf(radius)
		var ry := maxf(1.0, roundf(radius * 0.4))
		var points := {}
		var count := int(rx * 8.0) + 8
		for i in count:
			var angle := TAU * i / count
			points[Vector2(roundf(cos(angle) * rx), roundf(sin(angle) * ry))] = angle
		for p in points:
			# the far half of the ring a little fainter than the near half
			var near := 1.0 if p.y >= 0.0 else 0.6
			draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2.ONE), Color(FOAM, alpha * near))
