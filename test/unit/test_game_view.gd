extends GutTest

## GameView's smooth camera: the camera offset is rounded to whole pixels and the picture shifted
## by the rest, which must stay within the 1 px hidden border or a blank strip shows at the edge.

func test_snap_rounds_to_whole_pixels() -> void:
	assert_eq(GameView.snap(Vector2(10.3, -4.7))[0], Vector2(10, -5))
	assert_eq(GameView.snap(Vector2(10, -4))[1], Vector2.ZERO)

func test_snapped_plus_leftover_is_the_real_offset() -> void:
	var origin := Vector2(161.37, -90.62)
	var split := GameView.snap(origin)
	assert_almost_eq(split[0] + split[1], origin, Vector2(0.0001, 0.0001))

func test_leftover_stays_inside_the_border() -> void:
	for i in 200:
		var origin := Vector2(i * 0.137 - 13.0, i * -0.291 + 7.0)
		var leftover: Vector2 = GameView.snap(origin)[1]
		assert_true(absf(leftover.x) <= 0.5 and absf(leftover.y) <= 0.5, "leftover %s at %s" % [leftover, origin])
		if absf(leftover.x) > 0.5 or absf(leftover.y) > 0.5:
			return
