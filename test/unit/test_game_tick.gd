extends GutTest

## GameTick: fixed ticks from uneven frame times, no catch-up burst after a long frame.

var _ticks: Array[int] = []
var _paused := false

func before_each() -> void:
	_ticks.clear()
	_paused = GameTick.paused
	GameTick.paused = true  # only the test's own advance() calls move time
	GameTick._carry = 0.0  # each test starts exactly on a tick
	GameTick.ticked.connect(_on_ticked)

func after_each() -> void:
	GameTick.ticked.disconnect(_on_ticked)
	GameTick.paused = _paused
	GameTick.speed = 1.0

func _on_ticked(tick: int) -> void:
	_ticks.append(tick)

func test_one_second_is_twenty_ticks_whatever_the_frame_times() -> void:
	var start := GameTick.tick
	for frame_time in [0.016, 0.033, 0.007, 0.1, 0.016]:
		GameTick.advance(frame_time)
	var frames_so_far := 0.172
	GameTick.advance(1.0 - frames_so_far + 0.0001)
	assert_eq(_ticks.size(), GameTick.TICKS_PER_SECOND)
	assert_eq(_ticks.back(), start + GameTick.TICKS_PER_SECOND, "ticks count up by one")

func test_leftover_time_waits_for_the_next_frame() -> void:
	GameTick.advance(GameTick.TICK_SECONDS * 0.6)
	assert_eq(_ticks.size(), 0)
	assert_almost_eq(GameTick.fraction(), 0.6, 0.001)
	GameTick.advance(GameTick.TICK_SECONDS * 0.6)
	assert_eq(_ticks.size(), 1)

func test_ticks_for_rounds_to_the_nearest_tick() -> void:
	assert_eq(GameTick.ticks_for(0.2), 4, "a normal step")
	assert_eq(GameTick.ticks_for(0.25), 5, "rough ground")
	assert_eq(GameTick.ticks_for(12.0), 240, "a taunt cooldown")

func test_speed_offline_scales_engine_time() -> void:
	GameTick.speed = 4.0
	assert_eq(Engine.time_scale, 4.0)
