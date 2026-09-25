class_name ParticleBurst
extends Node2D

## Cosmetic bits that fly out, land and fade: blood when a creature dies (blood()), rubble
## when a wall breaks (rubble()). Nothing here touches game state, so there is no network
## message: every peer already runs the death (EntityStats) and the wall change
## (TileDestruction.apply) itself and spawns its own copy. The random spread may differ
## between peers, which is fine for looks.
##
## Art: resources/gfx/effects/effects.particles/, played at FPS. The rubble sheet is drawn in
## 8 template greys (16, 48, ... 240); each is swapped for the broken wall's own colours, so
## the chunks match the wall they came from.
##
## The floor is flat, so "up" is faked: each piece has a height above its spot on the
## floor, is drawn that many pixels higher, and gravity pulls the height back to 0.

const BLOOD_AIR := preload("res://resources/gfx/effects/effects.particles/Blood_Air.png")
const BLOOD_GROUND := preload("res://resources/gfx/effects/effects.particles/Blood_Ground.png")
const RUBBLE_PATH := "res://resources/gfx/effects/effects.particles/Rubble_Particles.png"
## 8x8 cells, 4 tumble frames per row: bone, stone, goo, wisp (hit_spray).
const CHIPS := preload("res://resources/gfx/effects/effects.particles/Hit_Chips.png")
const CHIP_ROW := {"bone": 0, "stone": 1, "metal": 1, "organic": 2, "ethereal": 3}
const RUBBLE_GRID := Vector2i(5, 6)  # columns, rows of 8x8 cells

const FPS := 10.0
const GRAVITY := 400.0     # px/s^2
const FLOOR_Z := 50        # above every floor (sort_order 1-8), below walls (100)
const AIR_Z := 1100        # above bodies (1000), below the LightMap overlay (2000)
const STAIN_SECONDS := 8.0 # how long blood stays on the floor before fading
const RUBBLE_SECONDS := 3.0

static var _rubble_by_wall := {}  # wall atlas path -> recoloured rubble sheet

class Piece:
	var sprite: Sprite2D
	var ground: Vector2          # its spot on the floor, relative to the burst
	var velocity: Vector2        # across the floor, px/s
	var height := 0.0            # above the floor, px
	var rise := 0.0              # upward speed, px/s
	var bounce := 0.0            # share of the fall speed kept when it hits the floor
	var air_frames: Array = []   # looped while flying
	var land_frames: Array = []  # played once on landing, the last one then held
	var landed_z := FLOOR_Z
	var linger := 0.0            # seconds after landing before it starts to fade
	var fade := 0.0
	var landed := false
	var time := 0.0              # since it was thrown, or since it landed

var _pieces: Array[Piece] = []

## Blood on every tile a dead body covered: one tile for a normal creature, four for a 2x2
## boss. Each tile gets a splash that stays as a stain, plus droplets thrown outward.
static func blood(body: Node) -> void:
	if not body is Node2D or not body.is_inside_tree():
		return
	var tile_size: float = body.grid_mover.tile_size if "grid_mover" in body else 16.0
	var footprint: int = body.get_meta("footprint", 1)
	var burst := _spawn(body.get_tree().current_scene, (body as Node2D).global_position)
	for y in footprint:
		for x in footprint:
			var centre := (Vector2(x, y) + Vector2(0.5, 0.5)) * tile_size
			var stain := burst._add(BLOOD_GROUND, Vector2i(6, 2), centre + _jitter(3.0))
			stain.land_frames = [6, 7, 8, 9]  # second row: a drop landing and spreading
			stain.linger = STAIN_SECONDS
			stain.fade = 2.0
			for i in 3:
				var drop := burst._add(BLOOD_AIR, Vector2i(8, 1), centre)
				drop.air_frames = [randi() % 4]
				_throw(drop, Vector2(20, 55), Vector2(60, 110))

## A small spray on every hit that doesn't kill (HitFeedback): two drops of blood from flesh,
## or two chips of whatever else the body is made of (CombatSounds.material). Nothing stays on
## the floor; the killing blow's blood() is the big one.
static func hit_spray(body: Node, material: String) -> void:
	if not body is Node2D or not body.is_inside_tree():
		return
	var size: float = body.get_meta("footprint", 1) * 16.0
	var burst := _spawn(body.get_tree().current_scene, (body as Node2D).global_position + Vector2(size, size) / 2.0)
	for i in 2:
		var bit: Piece
		if CHIP_ROW.has(material):
			var row: int = CHIP_ROW[material]
			bit = burst._add(CHIPS, Vector2i(4, 4), Vector2.ZERO)
			bit.air_frames = [row * 4, row * 4 + 1, row * 4 + 2, row * 4 + 3]
			bit.bounce = 0.3
		else:
			bit = burst._add(BLOOD_AIR, Vector2i(8, 1), Vector2.ZERO)
			bit.air_frames = [randi() % 4]
		bit.linger = 0.3
		bit.fade = 0.3
		_throw(bit, Vector2(20, 45), Vector2(40, 80))

## Rubble from one broken wall tile. `centre` is the tile's centre in global pixels and
## `wall_atlas` the wall's texture path (from its game/tiles JSON), which gives the colours.
static func rubble(scene: Node, centre: Vector2, wall_atlas: String) -> void:
	var sheet := _rubble_sheet(wall_atlas)
	var burst := _spawn(scene, centre)
	var puff := burst._add(sheet, RUBBLE_GRID, Vector2.ZERO)
	puff.land_frames = [25, 26, 27, 28, 29]  # bottom row: dust puff
	puff.landed_z = AIR_Z
	puff.linger = 0.5
	for i in 3:
		var row := randi() % 4  # rows 1-4: chunks, big to small, 4 tumble frames each
		var chunk := burst._add(sheet, RUBBLE_GRID, _jitter(4.0))
		chunk.air_frames = [row * 5, row * 5 + 1, row * 5 + 2, row * 5 + 3]
		chunk.bounce = 0.35
		chunk.linger = RUBBLE_SECONDS
		chunk.fade = 1.0
		_throw(chunk, Vector2(15, 45), Vector2(70, 120))
	for i in 3:
		var pebble := burst._add(sheet, RUBBLE_GRID, _jitter(4.0))
		pebble.air_frames = [20 + randi() % 5]  # row 5: single pebbles
		pebble.bounce = 0.3
		pebble.linger = RUBBLE_SECONDS
		pebble.fade = 1.0
		_throw(pebble, Vector2(25, 65), Vector2(50, 100))

static func _spawn(scene: Node, at: Vector2) -> ParticleBurst:
	var burst := ParticleBurst.new()
	scene.add_child(burst)
	burst.global_position = at
	return burst

static func _jitter(radius: float) -> Vector2:
	return Vector2(randf_range(-radius, radius), randf_range(-radius, radius))

## Sends a piece off in a random direction: `speed` and `rise` are (min, max) ranges.
static func _throw(piece: Piece, speed: Vector2, rise: Vector2) -> void:
	piece.velocity = Vector2.from_angle(randf() * TAU) * randf_range(speed.x, speed.y)
	piece.rise = randf_range(rise.x, rise.y)
	piece.height = 4.0

func _add(texture: Texture2D, grid: Vector2i, at: Vector2) -> Piece:
	var piece := Piece.new()
	piece.sprite = Sprite2D.new()
	piece.sprite.texture = texture
	piece.sprite.hframes = grid.x
	piece.sprite.vframes = grid.y
	piece.sprite.z_index = AIR_Z
	piece.ground = at
	add_child(piece.sprite)
	_pieces.append(piece)
	return piece

func _process(delta: float) -> void:
	for piece in _pieces:
		_step(piece, delta)
	_pieces = _pieces.filter(func(piece: Piece) -> bool: return piece.sprite != null)
	if _pieces.is_empty():
		queue_free()

func _step(piece: Piece, delta: float) -> void:
	piece.time += delta
	if not piece.landed:
		piece.ground += piece.velocity * delta
		piece.rise -= GRAVITY * delta
		piece.height += piece.rise * delta
		if piece.height <= 0.0:
			_hit_floor(piece)
		elif not piece.air_frames.is_empty():
			piece.sprite.frame = piece.air_frames[int(piece.time * FPS) % piece.air_frames.size()]
	if piece.landed:
		if not piece.land_frames.is_empty():
			piece.sprite.frame = piece.land_frames[mini(int(piece.time * FPS), piece.land_frames.size() - 1)]
		if piece.time >= piece.linger + piece.fade:
			piece.sprite.queue_free()
			piece.sprite = null
			return
		if piece.time > piece.linger:
			piece.sprite.modulate.a = 1.0 - (piece.time - piece.linger) / piece.fade
	piece.sprite.position = piece.ground + Vector2(0.0, -piece.height)

## Bounces while it still falls fast enough, otherwise stays on the floor.
func _hit_floor(piece: Piece) -> void:
	piece.height = 0.0
	if piece.bounce > 0.0 and piece.rise < -60.0:
		piece.rise = -piece.rise * piece.bounce
		piece.velocity *= 0.5
		return
	piece.landed = true
	piece.time = 0.0
	piece.sprite.z_index = piece.landed_z

## The rubble sheet in one wall's colours, made once per wall and kept. Template grey i
## (i * 32 + 16) becomes the wall's colour at the same place in its dark-to-light order;
## a wall with fewer than 8 colours shares them out. Unknown wall: the greys stay.
static func _rubble_sheet(wall_atlas: String) -> Texture2D:
	if _rubble_by_wall.has(wall_atlas):
		return _rubble_by_wall[wall_atlas]
	var image := _image_of(load(RUBBLE_PATH))
	var palette := _wall_palette(wall_atlas)
	if not palette.is_empty():
		for y in image.get_height():
			for x in image.get_width():
				var colour := image.get_pixel(x, y)
				if colour.a > 0.0:
					var grey := clampi(floori(colour.r8 / 32.0), 0, 7)
					image.set_pixel(x, y, palette[floori(grey * palette.size() / 8.0)])
	var sheet := ImageTexture.create_from_image(image)
	_rubble_by_wall[wall_atlas] = sheet
	return sheet

## A wall texture's colours, darkest first. Black is left out: it is the unseen top of the
## wall, not the stone (the tile colour limit does not count it either).
static func _wall_palette(wall_atlas: String) -> Array[Color]:
	var palette: Array[Color] = []
	var texture: Texture2D = load(wall_atlas) if ResourceLoader.exists(wall_atlas) else null
	if texture == null:
		return palette
	var image := _image_of(texture)
	var seen := {}
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.a >= 1.0 and colour != Color.BLACK:
				seen[colour] = true
	palette.assign(seen.keys())
	palette.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	return palette

static func _image_of(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image
