class_name GearEffects
extends Node2D

## A full-set bonus (game/sets/<set>.json, see its README) drawn around a body:
## an "aura" that stays under its feet, a "trail" left on each tile it walks
## onto, and "particles" that drift off it. A single worn item can carry a bonus
## of its own in the same format (a legendary ring's particles), shown alongside.
## Which set is complete comes from the worn gear, which is already synced to
## every peer, so every peer draws the same effects without any networking of
## their own. GearLayers owns it and adds it to the body sprite, so it sits on
## the body's tile centre and moves with it.

## Floors are z 1-10 and walls z 100: ground effects go between the two.
const GROUND_Z := 20
## Particles go in front of (or, with "behind", under) the body and all its gear.
const PARTICLE_Z := 20
const TILE := 16

var _sources: Array[String] = []   # the set, then each worn item with a bonus
var _active := true
var _aura: AnimatedSprite2D
var _particles: Array[CPUParticles2D] = []
var _trail: Dictionary = {}         # the set's "trail" block, {} for none
var _trail_frames: SpriteFrames
var _decals: Node2D                 # world-space parent of the trail decals
var _decal_on: Dictionary = {}      # tile -> the decal on it, so a tile has one at most
var _tile := Vector2i.MAX           # the tile the body was last on

func _ready() -> void:
	# top_level: decals stay where they were left instead of following the body.
	_decals = Node2D.new()
	_decals.name = "Trail"
	_decals.top_level = true
	_decals.z_as_relative = false
	_decals.z_index = GROUND_Z
	add_child(_decals)

## worn: slot -> item id, the same dictionary GearLayers gets.
## The set's bonus comes first; one aura and one trail at most (the first found),
## but every bonus's particles show.
func set_equipment(worn: Dictionary) -> void:
	var sources: Array[String] = []
	var bonuses: Array[Dictionary] = []
	var set_id := ItemDatabase.full_set(worn)
	if set_id != "":
		sources.append(set_id)
		bonuses.append(ItemDatabase.set_bonus(set_id))
	for slot in ItemDatabase.SLOTS:
		var item_bonus := ItemDatabase.item_bonus(worn.get(slot, ""))
		if not item_bonus.is_empty():
			sources.append(worn[slot])
			bonuses.append(item_bonus)
	if sources == _sources:
		return
	_sources = sources
	for old: Node in [_aura] + _particles:
		if old != null:
			remove_child(old)   # now, so the new ones can take the same names
			old.queue_free()
	_aura = null
	_particles.clear()
	_trail = {}
	for i in bonuses.size():
		var bonus := bonuses[i]
		if bonus.has("aura") and _aura == null:
			_aura = _make_aura(bonus["aura"])
		if bonus.has("particles"):
			var p := _make_particles(bonus["particles"])
			p.name = "Particles_" + sources[i]
			_particles.append(p)
		if bonus.has("trail") and _trail.is_empty():
			_trail = bonus["trail"]
	_trail_frames = _frames(_trail) if not _trail.is_empty() else null
	# Decals already left keep fading out on their own.

## Off while the gear is hidden (the ghost) or the body has no gear sheet.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	visible = on
	for p in _particles:
		p.emitting = on

func _process(_delta: float) -> void:
	if _trail.is_empty() or not _active:
		return
	# This node sits on the body's centre, so flooring it gives the body's tile.
	# A body sliding between tiles counts as on the new one from halfway across.
	var tile := Vector2i((global_position / TILE).floor())
	if tile == _tile:
		return
	var step := Vector2.ZERO if _tile == Vector2i.MAX else Vector2(tile - _tile)
	_tile = tile
	_leave_decal(tile, step)

func _leave_decal(tile: Vector2i, step: Vector2) -> void:
	var old: Node = _decal_on.get(tile)
	if is_instance_valid(old):
		old.queue_free()
	var decal := AnimatedSprite2D.new()
	decal.sprite_frames = _trail_frames
	decal.position = Vector2(tile * TILE) + Vector2(TILE, TILE) / 2.0
	# The art is drawn walking up; turn it to the step, in quarter turns so pixels stay square.
	if _trail.get("rotate", false) and step != Vector2.ZERO:
		decal.rotation = snappedf(step.angle(), PI / 2.0) + PI / 2.0
	_decals.add_child(decal)
	decal.play("Play")
	_decal_on[tile] = decal
	var tween := decal.create_tween()
	tween.tween_interval(_trail.get("lifetime", 2.0))
	tween.tween_property(decal, "modulate:a", 0.0, _trail.get("fade", 1.0))
	tween.tween_callback(func() -> void:
		if _decal_on.get(tile) == decal:
			_decal_on.erase(tile)
		decal.queue_free())

func _make_aura(data: Dictionary) -> AnimatedSprite2D:
	var aura := AnimatedSprite2D.new()
	aura.name = "Aura"
	aura.sprite_frames = _frames(data)
	aura.position = SpriteFramesLoader.vector_from_array(data.get("offset", [0, 0]))
	aura.z_as_relative = false
	aura.z_index = GROUND_Z
	add_child(aura)
	aura.play("Play")
	return aura

func _make_particles(data: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Particles"
	p.local_coords = false   # left behind in the world as the body walks on
	p.amount = data.get("amount", 8)
	p.lifetime = data.get("lifetime", 1.0)
	p.position = SpriteFramesLoader.vector_from_array(data.get("offset", [0, 0]))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = SpriteFramesLoader.vector_from_array(data.get("area", [4, 4])) / 2.0
	p.direction = SpriteFramesLoader.vector_from_array(data.get("direction", [0, -1]))
	p.spread = data.get("spread", 30.0)
	p.gravity = SpriteFramesLoader.vector_from_array(data.get("gravity", [0, 0]))
	var speed := SpriteFramesLoader.vector_from_array(data.get("speed", [2, 6]))
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	var size := SpriteFramesLoader.vector_from_array(data.get("size", [1, 1]))
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	p.color_ramp = _fade_ramp(data.get("colors", ["ffffff"]))
	p.z_index = -PARTICLE_Z if data.get("behind", false) else PARTICLE_Z
	p.emitting = _active
	add_child(p)
	return p

## The colours spread evenly over a particle's life, then a fade to nothing.
static func _fade_ramp(hexes: Array) -> Gradient:
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for i in hexes.size():
		colors.append(Color(hexes[i]))
		offsets.append(0.8 * i / max(hexes.size() - 1, 1))
	var last := colors[colors.size() - 1]
	colors.append(Color(last, 0.0))
	offsets.append(1.0)
	var ramp := Gradient.new()
	ramp.offsets = offsets
	ramp.colors = colors
	return ramp

## One animation, "Play", in the same format as an attack "effect" block plus frame_size.
static func _frames(data: Dictionary) -> SpriteFrames:
	return SpriteFramesLoader.build({"frame_size": data.get("frame_size", [TILE, TILE]), "animations": {"Play": data}})
