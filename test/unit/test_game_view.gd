extends GutTest

## GameView's smooth camera: the picture is shifted by the camera's leftover fraction, which must
## stay within the hidden border, or a blank strip shows at the edge.

func test_leftover_is_zero_on_a_whole_pixel() -> void:
	assert_eq(GameView.leftover(Vector2(10, -4)), Vector2.ZERO)

func test_leftover_matches_the_viewport_rounding() -> void:
	assert_almost_eq(GameView.leftover(Vector2(10.3, 0)).x, 0.3, 0.0001)
	assert_almost_eq(GameView.leftover(Vector2(10.7, 0)).x, -0.3, 0.0001)
	assert_almost_eq(GameView.leftover(Vector2(-2.3, 0)).x, -0.3, 0.0001)

func test_shift_stays_inside_the_border() -> void:
	for i in 200:
		var centre := Vector2(i * 0.137 - 13.0, i * -0.291 + 7.0)
		var offset := GameView.leftover(centre)
		assert_true(absf(offset.x) <= 0.5 and absf(offset.y) <= 0.5, "leftover %s at %s" % [offset, centre])
		if absf(offset.x) > 0.5 or absf(offset.y) > 0.5:
			return
