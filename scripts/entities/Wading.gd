class_name Wading
extends Node

## Makes a creature look (and sound) like it's wading when it stands in a liquid
## (water, lava, acid...). Only looks: it never changes speed or anything else, so it
## needs no networking -- every machine works it out from where the body is.
## A floor is a liquid when resources/sfx/effects/<tile name without "floor_">/ has its
## sounds (water/, lava/, acid/): adding a liquid is adding that folder. For each liquid:
## - The body sinks a pixel and everything below the surface takes the liquid's colour and
##   is partly see-through, with a pale rim where it meets the legs, wobbling gently
##   (resources/shaders/wading.gdshader). Gear sinks with the body.
## - Stepping in splashes (droplets, a ring, enter.wav); each wading step splashes a
##   little (step_1.wav...); stepping out drips (exit).
## - Walking leaves a trail of rings; standing still sends out a slow ring now and then.
## - Near it or in it, moving or not, the player on this machine hears the liquid itself
##   (lava bubbling and sizzling), if its folder has those sounds (LiquidAmbience).
## The colours come from the floor tile's own art (liquid_look); how see-through it is,
## from "see_through" in its game/tiles JSON.
## Dry ground has its steps here too, as they come from the same step onto a new tile: each
## plays the floor's step sounds (the folder its JSON names in "footsteps", see TileType),
## quieter than wading, and kicks up a little puff of dust in the floor's colour.
## Ghosts and fliers don't wade or step (GridMover ignores terrain for them).

const SHADER := preload("res://resources/shaders/wading.gdshader")
const SFX_ROOT := "res://resources/sfx/effects/"
const TILES_DIR := "res://game/tiles/"
## How long the body takes to sink in or rise out, in seconds.
const FADE_SECONDS := 0.15
## How high the liquid comes above the ground, in pixels (matches the shader's depth).
const DEPTH := 4.0
## Rings while walking, and the wait between rings while standing (seconds).
const WAKE_EVERY := 0.16
const IDLE_RING_EVERY := Vector2(1.4, 2.8)
## Over the liquid tiles, under walls and bodies.
const RIPPLE_Z := 50
## Wading is quieter than fighting: this much under CombatSounds' volume for the same body.
const QUIETER_DB := 10.0
## The rim, droplets and rings: the tile's lightest colour, this far towards white.
const RIM_PALE := 0.6
## Steps on dry ground are this much quieter again than wading ones.
const DRY_QUIETER_DB := 4.0

var _body: Node2D
var _sprite: AnimatedSprite2D
var _mover: GridMover
var _material := ShaderMaterial.new()
var _amount := 0.0
var _liquid := ""   # the sfx folder of the liquid the body stands in, "" on dry ground
var _rim := Color.WHITE   # the rim colour of the liquid it's in (or was last in, while it drips)
## Floor tile id -> its sfx folder name, for the floors that have one (built once).
static var _liquids := {}
## Sfx folder name -> liquid_look() (built the first time each liquid is waded into).
static var _looks := {}
## Floor tile id -> its step sounds (built the first time a body steps on that floor).
static var _steps := {}
var _tile := Vector2i.MAX
var _last_position := Vector2.INF
var _wake_left := 0.0
var _idle_left := 0.0
var _step := 0
var _ambience: LiquidAmbience   # players only: what the liquids around sound like to them

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
	if _liquids.is_empty():
		_liquids = liquid_folders()
	# not minions: they wade too, and on the host every one of them is its authority
	if body.is_in_group("protagonist"):
		_ambience = LiquidAmbience.new()
		add_child(_ambience)
		_ambience.setup(_liquids)

## Floor tile id -> sfx folder name, for every floor with an enter.wav in its folder.
static func liquid_folders() -> Dictionary:
	var result := {}
	var registry := GridMover._tile_ids()
	for tile_name: String in registry.ids:
		var folder := tile_name.trim_prefix("floor_")
		if tile_name.begins_with("floor_") and ResourceLoader.exists(SFX_ROOT + folder + "/enter.wav"):
			result[registry.ids[tile_name]] = folder
	return result

## How a liquid looks, worked out from its floor tile (game/tiles/floor_<folder>.json):
## "colour" is the tile art's most common colour, "rim" its lightest one made paler (the rim,
## droplets and rings), "see_through" how much of a body shows below the surface (the tile's
## see_through). A murkier liquid also tints what shows more strongly ("tint").
static func liquid_look(folder: String) -> Dictionary:
	if _looks.has(folder):
		return _looks[folder]
	var tile := TileType.new()
	tile.load_from_file(TILES_DIR + "floor_" + folder + ".json")
	var counts := TileType.art_colours(tile.atlas_texture)
	var colour := Color(0.22, 0.42, 0.72)   # only if the tile has no art
	var lightest := Color(0.4, 0.6, 1.0)
	for c: Color in counts:
		if counts[c] > counts.get(colour, 0):
			colour = c
		if c.get_luminance() > lightest.get_luminance() or not counts.has(lightest):
			lightest = c
	var look := {
		"colour": colour,
		"rim": lightest.lerp(Color.WHITE, RIM_PALE),
		"see_through": tile.see_through,
		"tint": 1.0 - 0.9 * tile.see_through,
	}
	_looks[folder] = look
	return look

func _process(delta: float) -> void:
	if _body == null or _mover.floor_data == null:
		return
	var feet := _feet()
	# the tile under the middle of the body (big bodies: the middle of their footprint)
	var centre := _body.global_position + Vector2.ONE * (_mover.footprint * 8.0)
	var tile: Vector2i = _mover.floor_data.local_to_map(_mover.floor_data.to_local(centre))
	if _ambience and _body.is_multiplayer_authority():
		_ambience.hear(_mover.floor_data, tile, delta)
	# _ignores_terrain: ghosts and fliers, the same rule that stops water slowing them
	var floor_id := -1 if _mover._ignores_terrain() else _mover.floor_data.get_cell_source_id(tile)
	var liquid: String = _liquids.get(floor_id, "")
	var wet := liquid != ""
	var surface := feet - Vector2(0, DEPTH)
	var placed := _last_position == Vector2.INF   # put down in it to begin with: no splash
	if liquid != _liquid:
		# stepping out drips the old liquid's colour; stepping in (from dry ground or from
		# another liquid) takes on the new one's look before it splashes
		if not placed and _liquid != "":
			_play(SFX_ROOT + _liquid + "/exit.wav", surface)
			if not wet:
				_splash(surface, 5)
		if wet:
			_wear(liquid)
			if not placed:
				_play(SFX_ROOT + liquid + "/enter.wav", surface)
				_splash(surface, 12)
				_ring(surface, 2.0, 8.0, 0.6)
		_liquid = liquid
	elif tile != _tile and not placed and floor_id != -1:
		# another step: wading splashes a little, dry ground puffs dust
		if wet:
			_splash(surface, 5)
		else:
			_dust_puff(floor_id, feet)
		_play_step(floor_id, surface if wet else feet, wet)
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

# Gives the body (and its splashes and rings) the look of the liquid it stepped into.
func _wear(liquid: String) -> void:
	var look := liquid_look(liquid)
	_rim = look.rim
	_material.set_shader_parameter("water", look.colour)
	_material.set_shader_parameter("foam", look.rim)
	_material.set_shader_parameter("tint", look.tint)
	_material.set_shader_parameter("underwater_alpha", look.see_through)

# The middle of the bottom edge of the body's drawn frame (the sprite is centred).
func _feet() -> Vector2:
	return _sprite.global_position + Vector2(0, _frame_height() / 2.0)

func _frame_height() -> float:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(_sprite.animation):
		return 16.0
	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	return texture.get_size().y if texture else 16.0

# ---------------------------------------------------------------- effects

# Splashes and rings go on the scene, like the other effects (DamageNumber, ParticleBurst).
# Never next to the body: everything under the players' node is taken to be a player
# (LightMap reads each one's stats).
func _effects_parent() -> Node:
	return get_tree().current_scene

func _ring(at: Vector2, from_radius: float, to_radius: float, seconds: float) -> void:
	var scene := _effects_parent()
	if scene == null:
		return
	var ring := Ripple.new()
	ring.colour = _rim
	ring.z_index = RIPPLE_Z
	scene.add_child(ring)
	ring.global_position = at
	ring.radius = from_radius
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "radius", to_radius, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "alpha", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)

# Droplets thrown up in front of the body and falling back.
func _splash(at: Vector2, count: int) -> void:
	var scene := _effects_parent()
	if scene == null:
		return
	var drops := CPUParticles2D.new()
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
	fade.set_color(0, Color(_rim, 0.95))
	fade.set_color(1, Color(_rim, 0.0))
	drops.color_ramp = fade
	scene.add_child(drops)
	drops.global_position = at
	drops.emitting = true
	drops.finished.connect(drops.queue_free)

# A little puff of the floor's own dust from a step on dry ground (ParticleBurst.dust).
func _dust_puff(floor_id: int, at: Vector2) -> void:
	var tile := GridMover.floor_type(floor_id)
	var scene := _effects_parent()
	if tile == null or tile.atlas_texture == null or scene == null or not SoundPlayer.on_screen(self, at):
		return
	ParticleBurst.dust(scene, at, TileType.plain(tile.atlas_texture).resource_path)

# The floor's step sounds (its "footsteps" folder), taken in turn.
func _play_step(floor_id: int, at: Vector2, wet: bool) -> void:
	if not _steps.has(floor_id):
		var tile := GridMover.floor_type(floor_id)
		_steps[floor_id] = SoundPlayer.numbered(SFX_ROOT + tile.footsteps + "/step") if tile and tile.footsteps != "" else []
	var steps: Array = _steps[floor_id]
	if steps.is_empty():
		return
	_play(steps[_step % steps.size()], at, 0.0 if wet else DRY_QUIETER_DB)
	_step += 1

func _play(path: String, at: Vector2, quieter := 0.0) -> void:
	var team := "protagonist" if _body.is_in_group("protagonist") else ""
	var peer := int(str(_body.name)) if team != "" else 0
	var db := CombatSounds.who_db(_body, team, peer, false) - QUIETER_DB - quieter
	SoundPlayer.play(_body, path, {"at": at, "volume_db": db, "jitter": 0.08})

## A flat ring on the liquid, drawn in whole pixels, growing and fading (Wading._ring).
class Ripple extends Node2D:
	var colour := Color.WHITE
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
			draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2.ONE), Color(colour, alpha * near))
