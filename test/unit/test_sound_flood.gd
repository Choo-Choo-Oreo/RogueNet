extends GutTest

## SoundSpread.flood: how many dB a sound still has on each 8px quad. Open floor loses AIR_DB_PER_TILE
## per tile, half per quad (1.41x diagonally), a wall quad 17.5 (35 per tile), a turn beside a wall 3
## more, and a quad the sound cannot enter (INF) is never reached. The maps here are made up
## with a small loss function, no scene needed.

const AIR := SoundSpread.AIR_DB_PER_TILE / 2.0
const WALL := SoundSpread.WALL_DB_PER_TILE / 2.0

func _open(_quad: Vector2i) -> float:
	return AIR

## A one-tile wall (quad columns 2 and 3), open floor everywhere else.
func _wall_at_tile_1(quad: Vector2i) -> float:
	return WALL if quad.x == 2 or quad.x == 3 else AIR

## Like _wall_at_tile_1, but outside the map instead of a wall: sound cannot cross it.
func _void_at_tile_1(quad: Vector2i) -> float:
	return INF if quad.x == 2 or quad.x == 3 else AIR

## An L-shaped corridor one quad wide, walls all round: along y = 0 from x = 0 to 5, then up
## x = 5 to y = -5. A sound can only get round it by turning beside the wall.
func _corridor(quad: Vector2i) -> float:
	var along := quad.y == 0 and quad.x >= 0 and quad.x <= 5
	var up := quad.x == 5 and quad.y <= 0 and quad.y >= -5
	return AIR if along or up else WALL

func test_open_floor_loses_air_db_per_tile() -> void:
	var levels := SoundSpread.flood(Vector2i.ZERO, 30.0, 0.0, _open)
	assert_almost_eq(levels[Vector2i(6, 0)], 30.0 - 6.0 * AIR, 0.001, "3 tiles = 6 quads")
	assert_almost_eq(levels[Vector2i(2, 2)], 30.0 - 2.0 * AIR * SoundSpread.DIAGONAL, 0.001, "diagonals lose 1.41x")

func test_nothing_quieter_than_the_stop_level() -> void:
	var levels := SoundSpread.flood(Vector2i.ZERO, 30.0, 30.0 - 6.0 * AIR, _open)
	assert_true(levels.has(Vector2i(6, 0)), "exactly the stop level is still heard")
	assert_false(levels.has(Vector2i(7, 0)))

func test_a_wall_tile_takes_35_db() -> void:
	var levels := SoundSpread.flood(Vector2i(1, 0), 60.0, 0.0, _wall_at_tile_1)
	assert_almost_eq(levels[Vector2i(4, 0)], 60.0 - 2.0 * WALL - AIR, 0.001, "two wall quads, then floor")

func test_a_footstep_does_not_carry_through_a_wall() -> void:
	# A plain rat (27 dB) one tile past a wall from a footstep (30 dB).
	var levels := SoundSpread.flood(Vector2i(1, 0), PlayerController.FOOTSTEP_DB, 27.0, _wall_at_tile_1)
	assert_false(levels.has(Vector2i(4, 0)))

func test_sound_never_enters_outside_the_map() -> void:
	var levels := SoundSpread.flood(Vector2i(1, 0), 60.0, 0.0, _void_at_tile_1)
	assert_false(levels.has(Vector2i(2, 0)))
	assert_false(levels.has(Vector2i(4, 0)))

func test_bending_round_a_corner_costs_extra() -> void:
	var levels := SoundSpread.flood(Vector2i.ZERO, 60.0, 0.0, _corridor)
	# 4 quads right, cut the corner diagonally (two 45-degree turns), 2 quads up.
	assert_almost_eq(levels[Vector2i(5, -3)], 60.0 - AIR * (6.0 + SoundSpread.DIAGONAL) - SoundSpread.CORNER_DB, 0.001)
	assert_almost_eq(levels[Vector2i(5, 0)], 60.0 - 5.0 * AIR, 0.001, "no turn yet, no extra")

func test_turning_in_the_open_is_free() -> void:
	var levels := SoundSpread.flood(Vector2i.ZERO, 60.0, 0.0, _open)
	assert_almost_eq(levels[Vector2i(3, 1)], 60.0 - AIR * (SoundSpread.DIAGONAL + 2.0), 0.001)

func test_a_body_hears_its_loudest_quad() -> void:
	var levels := {Vector2i(2, 2): 10.0, Vector2i(3, 3): 12.0}
	assert_eq(SoundSpread.level_at(levels, Vector2i(1, 1)), 12.0)
	assert_eq(SoundSpread.level_at(levels, Vector2i(5, 5)), -INF, "never reached")

func test_stopping_at_a_listener_gives_the_same_level() -> void:
	var ears := SoundSpread.quads_of(Vector2i(3, 0))
	var whole := SoundSpread.flood(Vector2i.ZERO, 60.0, 0.0, _corridor)
	var early := SoundSpread.flood(Vector2i.ZERO, 60.0, 0.0, _corridor, ears)
	assert_almost_eq(SoundSpread.level_at(early, Vector2i(3, 0)), SoundSpread.level_at(whole, Vector2i(3, 0)), 0.001)
	assert_lt(early.size(), whole.size(), "stopped before flooding everything")
