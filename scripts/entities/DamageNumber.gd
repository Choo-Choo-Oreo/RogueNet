class_name DamageNumber
extends Node2D

## A small pixel number that pops off a creature when it is hit and drifts up while it fades.
## Hits that land on the same creature while its number is still fresh (MERGE_SECONDS) add into
## that number instead of stacking a new one, so a crowd doesn't fill the screen with digits.
## Art: resources/gfx/ui/hud/damage_digits.png, ten 5x7 white digits with a dark outline; the
## colour comes from `modulate`.

const DIGITS := preload("res://resources/gfx/ui/hud/damage_digits.png")
const DIGIT_SIZE := Vector2i(5, 7)
const SPACING := 4           # digits overlap by their shared outline column
const LIFE := 0.7            # seconds on screen
const RISE := 12.0           # pixels drifted up over LIFE
const MERGE_SECONDS := 0.3
const Z := 1150              # over bodies (1000) and particles (1100), under LightMap (2000)

const HURT := Color(1.0, 0.35, 0.3)
const DEALT := Color(1, 1, 1)
const BLOCKED := Color(0.6, 0.6, 0.65)

var total := 0
var _age := 0.0
var _start := Vector2.ZERO

## Shows `amount` over `body`, or adds it to `existing` if that one is still fresh. Returns the
## number now showing, for the caller to pass back as `existing` next time.
static func show_on(body: Node2D, amount: int, color: Color, existing: DamageNumber) -> DamageNumber:
	if is_instance_valid(existing) and existing._age < MERGE_SECONDS:
		existing.add(amount)
		return existing
	var scene := body.get_tree().current_scene
	if scene == null:
		return null
	var number := DamageNumber.new()
	number.modulate = color
	number.z_index = Z
	scene.add_child(number)
	var size: float = body.get_meta("footprint", 1) * 16.0
	number._start = body.global_position + Vector2(size / 2.0 + randf_range(-3, 3), -2.0)
	number.global_position = number._start
	number.add(amount)
	return number

func add(amount: int) -> void:
	total += amount
	_age = 0.0
	for child in get_children():
		child.queue_free()
	var text := str(total)
	var width := text.length() * SPACING + 1
	for i in text.length():
		var digit := Sprite2D.new()
		digit.texture = DIGITS
		digit.hframes = 10
		digit.frame = int(text[i])
		digit.centered = false
		digit.position = Vector2(i * SPACING - width / 2.0, -DIGIT_SIZE.y)
		add_child(digit)
	# A little pop: starts big and settles.
	scale = Vector2(1.6, 1.6)

func _process(delta: float) -> void:
	_age += delta
	scale = scale.lerp(Vector2.ONE, minf(1.0, delta * 18.0))
	var t := _age / LIFE
	global_position = (_start - Vector2(0, RISE * t)).round()
	modulate.a = 1.0 if t < 0.6 else maxf(0.0, 1.0 - (t - 0.6) / 0.4)
	if _age >= LIFE:
		queue_free()
