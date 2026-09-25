extends GutTest

## The sound lava makes by itself near the player (LiquidAmbience): its files, and how loud
## it is from where the player stands.

var _lava_id: int
var _floor: TileMapLayer
var _ambience: LiquidAmbience

func before_each() -> void:
	_lava_id = GridMover._tile_ids().get_id("floor_lava")
	# a floor layer with one plain tile under the lava's id
	var atlas := TileSetAtlasSource.new()
	atlas.texture = PlaceholderTexture2D.new()
	atlas.texture.size = Vector2(16, 16)
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	var tiles := TileSet.new()
	tiles.add_source(atlas, _lava_id)
	_floor = TileMapLayer.new()
	_floor.tile_set = tiles
	add_child_autofree(_floor)
	_ambience = LiquidAmbience.new()
	add_child_autofree(_ambience)
	_ambience.setup(Wading.liquid_folders())

func _lava(from: Vector2i, size: int) -> void:
	for y in size:
		for x in size:
			_floor.set_cell(from + Vector2i(x, y), _lava_id, Vector2i.ZERO)

func _loudness_at(tile: Vector2i) -> float:
	_ambience.hear(_floor, tile, LiquidAmbience.LOOK_EVERY)
	return _ambience._sounding["lava"].target

func test_lava_has_a_loop_that_loops_and_bubbles() -> void:
	var loop: AudioStreamWAV = load(Wading.SFX_ROOT + "lava/loop.wav")
	assert_ne(loop.loop_mode, AudioStreamWAV.LOOP_DISABLED, "loop.wav must be imported looping")
	assert_eq(LiquidAmbience.pop_paths("lava").size(), 3)

func test_standing_in_a_pool_is_louder_than_near_it() -> void:
	_lava(Vector2i(0, 0), 5)
	var inside := _loudness_at(Vector2i(2, 2))
	var beside := _loudness_at(Vector2i(7, 2))
	var far := _loudness_at(Vector2i(10, 2))
	assert_eq(inside, 1.0, "in the middle of a pool: full")
	assert_between(beside, 0.01, 0.99)
	assert_lt(far, beside)
	assert_eq(_loudness_at(Vector2i(30, 2)), 0.0, "out of reach: silent")

func test_a_lone_tile_is_quieter_than_a_pool() -> void:
	_lava(Vector2i(0, 0), 1)
	var lone := _loudness_at(Vector2i(0, 0))
	assert_almost_eq(lone, LiquidAmbience.PER_TILE, 0.001)
	_lava(Vector2i(-2, -2), 5)
	assert_gt(_loudness_at(Vector2i(0, 0)), lone)

func test_pops_only_come_from_lava_close_by() -> void:
	_lava(Vector2i(0, 0), 1)
	_loudness_at(Vector2i(LiquidAmbience.POP_REACH + 1, 0))
	assert_eq(_ambience._sounding["lava"].near.size(), 0)
	_loudness_at(Vector2i(LiquidAmbience.POP_REACH, 0))
	assert_eq(_ambience._sounding["lava"].near.size(), 1)
