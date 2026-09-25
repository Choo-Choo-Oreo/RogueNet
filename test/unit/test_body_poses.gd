extends GutTest

## DirectionalAnimator's poses: the whole body (and its worn gear) moves in whole pixels at
## 10 fps -- a lunge on attack, a topple on death, a breath and a blink while idle.

var _sprite: AnimatedSprite2D
var _animator: DirectionalAnimator
var _gear: GearLayers

func before_each() -> void:
	var data := JsonOnloading.load_dict(PlayerController.CHARACTERS["human"])
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AnimatedSprite2D"
	_sprite.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])
	var holder := Node2D.new()
	holder.add_child(_sprite)
	_animator = DirectionalAnimator.new()
	holder.add_child(_animator)
	_gear = GearLayers.new()
	holder.add_child(_gear)
	add_child_autofree(holder)
	_gear.setup(_sprite)
	_gear.set_equipment({"head": "heavy_iron_helm"})
	_animator.set_idle_life(data.get("idle", {}))
	_animator.animate_moving(Vector2.DOWN)

func _step(seconds: float) -> void:
	_animator._process(seconds)
	_gear._process(seconds)

func test_attack_lunges_toward_the_target_and_springs_back() -> void:
	_animator.play_attack(Vector2(3, 0))
	var seen := []
	for i in 4:
		_step(0.1)
		seen.append(_sprite.offset)
	assert_eq(seen[0], Vector2(2, 0), "second step: lunge 2px")
	assert_eq(_sprite.get_node("Gear_head").offset, _sprite.offset, "gear follows the body")
	_animator.play_attack(Vector2(-1, 1))
	_step(0.01)
	assert_eq(_sprite.offset, Vector2(1, -1), "first step pulls back, diagonals snap")
	for i in 5:
		_step(0.1)
	assert_eq(_sprite.offset, Vector2.ZERO)

func test_death_topples_into_its_own_tile_fades_and_waits_for_reset() -> void:
	watch_signals(_animator)
	_animator.play_death()
	_step(0.25)
	# half way over, the feet have only moved 2-3px (the pivot is half way up)
	var feet := Vector2(0, 8)
	assert_lt((_sprite.transform * (feet + _sprite.offset)).distance_to(feet), 3.5)
	for i in 20:
		_step(0.1)
	assert_signal_emitted(_animator, "pose_finished")
	assert_almost_eq(_sprite.rotation, PI / 2.0, 0.001)
	assert_eq(_sprite.modulate.a, 0.0)
	assert_eq(_sprite.offset, Vector2.ZERO, "lying flat: turned about the middle, inside its tile")
	_step(1.0)
	assert_almost_eq(_sprite.rotation, PI / 2.0, 0.001, "stays down until reset")
	_animator.reset_pose()
	assert_eq(_sprite.rotation, 0.0)
	assert_eq(_sprite.modulate.a, 1.0)
	assert_eq(_sprite.offset, Vector2.ZERO)

func test_idle_breathes_and_blinks_but_not_while_walking() -> void:
	_animator.animate_idle()
	_step(1.0)
	assert_eq(_sprite.offset, Vector2.ZERO)
	_step(0.6)
	assert_eq(_sprite.offset, Vector2(0, 1), "breath: 1px sink in the second half")
	_step(0.7)
	var blink: Sprite2D = _sprite.get_node("Blink")
	assert_true(blink.visible, "blinks at 2.2-2.4 s")
	assert_eq(blink.frame, 0, "the Front column")
	_animator.animate_moving(Vector2.UP)
	_step(0.01)
	assert_false(blink.visible)
	assert_eq(_sprite.offset, Vector2.ZERO)

func test_no_blink_from_behind() -> void:
	_animator.animate_moving(Vector2.UP)
	_animator.animate_idle()
	_step(2.3)
	assert_false(_sprite.get_node("Blink").visible)

func test_a_creature_without_idle_life_is_left_alone() -> void:
	_animator.set_idle_life({})
	await wait_process_frames(1)
	_sprite.offset = Vector2(3, 3)
	_animator.animate_idle()
	_step(2.0)
	assert_eq(_sprite.offset, Vector2(3, 3))
	assert_false(_sprite.has_node("Blink"))
