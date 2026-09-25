extends GutTest

## Sound.flood: how much of a sound's budget is spent reaching each tile. Open floor costs 1 per
## tile (1.41 diagonally), a wall 3, and a cell the sound cannot enter (INF) is never reached.
## The maps here are made up with a small muffle function, no scene needed.

func _open(_cell: Vector2i) -> float:
	return 1.0

## A wall along the column x = 1, open floor everywhere else.
func _wall_at_x1(cell: Vector2i) -> float:
	return 3.0 if cell.x == 1 else 1.0

## Like _wall_at_x1, but the column is outside the map instead of a wall: sound cannot cross it.
func _void_at_x1(cell: Vector2i) -> float:
	return INF if cell.x == 1 else 1.0

func test_open_floor_costs_one_per_tile() -> void:
	var costs := Sound.flood(Vector2i.ZERO, 10.0, _open)
	assert_almost_eq(costs[Vector2i(3, 0)], 3.0, 0.001)
	assert_almost_eq(costs[Vector2i(2, 2)], 2.0 * Sound.DIAGONAL, 0.001, "diagonals cost 1.41")

func test_nothing_past_the_budget() -> void:
	var costs := Sound.flood(Vector2i.ZERO, 3.0, _open)
	assert_true(costs.has(Vector2i(3, 0)), "exactly the budget is still heard")
	assert_false(costs.has(Vector2i(4, 0)))

func test_a_wall_costs_three() -> void:
	var costs := Sound.flood(Vector2i.ZERO, 10.0, _wall_at_x1)
	assert_almost_eq(costs[Vector2i(2, 0)], 4.0, 0.001, "wall 3 + floor 1")

func test_a_footstep_does_not_carry_through_a_wall() -> void:
	# The plain-rat case: 2 tiles away in a straight line, but 1 + 3 through the wall > 3.
	var costs := Sound.flood(Vector2i.ZERO, 3.0, _wall_at_x1)
	assert_false(costs.has(Vector2i(2, 0)))

func test_sound_never_enters_outside_the_map() -> void:
	var costs := Sound.flood(Vector2i.ZERO, 6.0, _void_at_x1)
	assert_false(costs.has(Vector2i(1, 0)))
	assert_false(costs.has(Vector2i(2, 0)))
