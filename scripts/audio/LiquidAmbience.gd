class_name LiquidAmbience
extends Node

## The sound a liquid makes by itself (lava bubbling and sizzling): heard near it and standing
## in it, whether or not anyone moves. Only for the player on this machine, so it's sound only
## and needs no networking. Wading makes one for its body and calls hear() with the body's tile.
## A liquid (see Wading) has one when its sfx folder has these files:
## - loop.wav: a seamless loop (its import must loop). Every tile of the liquid near the player
##   adds to it, the near ones far more, so it swells walking up to a pool and is loudest
##   standing in a big one; a lone tile stays quiet.
## - pop_1.wav, pop_2.wav...: now and then one of these from a random tile of it nearby (a
##   bubble bursting), heard from that tile. Oftener the more of the liquid is around.
## A liquid with neither is silent until someone walks through it.

## How far away a liquid is heard, in tiles.
const REACH := 8
## How much one tile adds (the player's own tile; further ones add less), out of 1 (full).
const PER_TILE := 0.35
## The loop at full, and how fast it follows a change (1 = silent to full in a second).
const LOOP_DB := -9.0
const FADE_PER_SECOND := 2.5
## Pops: from tiles this close, this loud, this long apart next to plenty of the liquid.
const POP_REACH := 5
const POP_DB := -8.0
const POP_EVERY := Vector2(0.4, 1.4)
## Seconds between looks at the tiles around the player.
const LOOK_EVERY := 0.2

## Sfx folder -> {"loop": AudioStreamPlayer or null, "pops": [paths], "level": 0..1 now,
## "target": 0..1 it's heading to, "near": [tile centres within POP_REACH], "pop_left": s}.
var _sounding := {}
var _liquids := {}
var _look_left := 0.0

## `liquids` is Wading's floor tile id -> sfx folder.
func setup(liquids: Dictionary) -> void:
	_liquids = liquids
	for folder: String in liquids.values():
		var loop_path := Wading.SFX_ROOT + folder + "/loop.wav"
		var pops := pop_paths(folder)
		if not ResourceLoader.exists(loop_path) and pops.is_empty():
			continue
		var loop: AudioStreamPlayer = null
		if ResourceLoader.exists(loop_path):
			loop = AudioStreamPlayer.new()
			loop.stream = load(loop_path)
			loop.bus = "SFX"
			add_child(loop)
		_sounding[folder] = {"loop": loop, "pops": pops, "level": 0.0, "target": 0.0, "near": [], "pop_left": 0.0}

## pop_1.wav, pop_2.wav... in the liquid's folder, until one is missing.
static func pop_paths(folder: String) -> Array[String]:
	return SoundPlayer.numbered(Wading.SFX_ROOT + folder + "/pop")

## Called every frame with the tile the player is over.
func hear(floor_data: TileMapLayer, tile: Vector2i, delta: float) -> void:
	if _sounding.is_empty():
		return
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = LOOK_EVERY
		_look(floor_data, tile)
	for folder: String in _sounding:
		var sound: Dictionary = _sounding[folder]
		sound.level = move_toward(sound.level, sound.target, FADE_PER_SECOND * delta)
		_play_loop(sound)
		sound.pop_left -= delta
		if sound.pop_left <= 0.0 and not sound.near.is_empty() and not sound.pops.is_empty():
			# more of the liquid around, more pops
			sound.pop_left = randf_range(POP_EVERY.x, POP_EVERY.y) / maxf(sound.target, 0.3)
			SoundPlayer.play(self, sound.pops.pick_random(), {
				"at": sound.near.pick_random(), "volume_db": POP_DB, "jitter": 0.15, "max_voices": 4})

## How loud each liquid should be from here: every tile of it within REACH adds to it, the
## near ones far more, up to 1.
func _look(floor_data: TileMapLayer, tile: Vector2i) -> void:
	var loudness := {}
	for sound: Dictionary in _sounding.values():
		sound.near = []
	var tile_size := Vector2(floor_data.tile_set.tile_size)
	for dy in range(-REACH, REACH + 1):
		for dx in range(-REACH, REACH + 1):
			var distance := Vector2(dx, dy).length()
			if distance > REACH:
				continue
			var folder: String = _liquids.get(floor_data.get_cell_source_id(tile + Vector2i(dx, dy)), "")
			if not _sounding.has(folder):
				continue
			loudness[folder] = loudness.get(folder, 0.0) + PER_TILE * pow(1.0 - distance / (REACH + 1), 3.0)
			if distance <= POP_REACH:
				var centre := floor_data.to_global(floor_data.map_to_local(tile + Vector2i(dx, dy)))
				_sounding[folder].near.append(centre)
	for folder: String in _sounding:
		_sounding[folder].target = minf(loudness.get(folder, 0.0), 1.0)

func _play_loop(sound: Dictionary) -> void:
	var loop: AudioStreamPlayer = sound.loop
	if loop == null:
		return
	if sound.level <= 0.0:
		if loop.playing:
			loop.stop()
		return
	loop.volume_db = LOOP_DB + linear_to_db(sound.level)
	if not loop.playing:
		# start somewhere in the loop, so two visits don't begin the same way
		loop.play(randf() * loop.stream.get_length())
