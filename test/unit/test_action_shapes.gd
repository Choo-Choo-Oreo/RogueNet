extends GutTest

## Example test: copy this file to start a new one. It checks ActionShapes, the code that
## turns an action's "shape" JSON into the list of tiles it covers. Nothing here needs a
## scene or the game running, which makes it the easiest kind of test to write.
##
## Each function starting with `test_` is one test. It sets something up, calls the code,
## then asserts (checks) the result. Name a test after what it proves.

func test_circle_radius_1_covers_the_four_sides_of_a_one_tile_body() -> void:
	var tiles := ActionShapes.cells({"type": "circle", "radius": 1}, Vector2i(5, 5), 1, Vector2i(9, 9))
	assert_eq(tiles.size(), 4, "radius 1 is the four sides, no corners")
	for expected in [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 4), Vector2i(5, 6)]:
		assert_has(tiles, expected)

func test_circle_radius_1_5_adds_the_corners() -> void:
	var tiles := ActionShapes.cells({"type": "circle", "radius": 1.5}, Vector2i(5, 5), 1, Vector2i(9, 9))
	assert_eq(tiles.size(), 8)
	assert_has(tiles, Vector2i(4, 4))

func test_circle_never_includes_the_bodys_own_tiles() -> void:
	var tiles := ActionShapes.cells({"type": "circle", "radius": 2}, Vector2i(0, 0), 2, Vector2i(9, 9))
	for own in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		assert_does_not_have(tiles, own)

func test_circle_around_a_two_by_two_body_has_two_tiles_per_side() -> void:
	var tiles := ActionShapes.cells({"type": "circle", "radius": 1}, Vector2i(0, 0), 2, Vector2i(9, 9))
	assert_eq(tiles.size(), 8)

func test_line_runs_toward_the_target_along_its_main_axis() -> void:
	var tiles := ActionShapes.cells({"type": "line", "length": 3, "width": 1}, Vector2i(0, 0), 1, Vector2i(10, 0))
	assert_eq(tiles.size(), 3)
	for expected in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]:
		assert_has(tiles, expected)

func test_line_toward_a_target_on_the_left_runs_left() -> void:
	var tiles := ActionShapes.cells({"type": "line", "length": 2, "width": 1}, Vector2i(5, 5), 1, Vector2i(0, 5))
	assert_has(tiles, Vector2i(4, 5))
	assert_has(tiles, Vector2i(3, 5))

func test_unknown_shape_gives_no_tiles() -> void:
	var tiles := ActionShapes.cells({"type": "banana"}, Vector2i(0, 0), 1, Vector2i(1, 1))
	assert_eq(tiles.size(), 0)
