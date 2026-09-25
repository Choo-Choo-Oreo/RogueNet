class_name MenuWeapon
extends Control

## The weapon that hovers to the right of the main-menu scroll under the mouse,
## pointing at it as if about to attack. Each new scroll gets a random sword or
## staff (the items' own inventory icons). strike() plays the attack on a scroll:
## a sword swings through it and cuts it in half, a staff throws a fireball that
## burns it (see MenuScrollButton).

## Which items can show up, by how they attack. The icons are drawn pointing up-right;
## mirrored, they point up-left at the scroll.
const WEAPONS := {
	"sword": ["heavy_iron_longsword", "militia_rusty_sword", "magma_lava_blade", "hamster_carrot_sword"],
	"staff": ["arcane_staff", "apprentice_crooked_staff", "sporecaller_glowcap_staff", "starforged_staff", "necromancer_bone_wand"],
}
const PX := MenuScrollButton.PX
const ICON_SIZE := 16
## From the icon's top-left corner to its tip, once mirrored (art pixels).
const TIP := Vector2(1, 1)
## How far past the scroll's strike point the tip hovers (art pixels).
const AIM_GAP := Vector2(4, 0)
const FIREBALL_TEX := preload(MenuScrollButton.ART + "Fireball.png")
const FIREBALL_SIZE := Vector2i(10, 8)
const FIREBALL_FRAMES := 4

var _sprite: TextureRect
var _fireball: TextureRect
var _target: MenuScrollButton
var _kind := ""
var _item := ""
var _time := 0.0
var _striking := false
## Only one fade at a time: a fade-out still running after a fade-in would hide the weapon again.
var _fade_tween: Tween
var _move_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = MenuScrollButton._add(MenuScrollButton._texture_rect(ItemDatabase.icon(WEAPONS["sword"][0])), self)
	_sprite.size = Vector2.ONE * ICON_SIZE * PX
	_sprite.flip_h = true
	_sprite.pivot_offset = _sprite.size / 2.0
	_fireball = MenuScrollButton._add(MenuScrollButton._texture_rect(
			MenuScrollButton._region(FIREBALL_TEX, Rect2(Vector2.ZERO, FIREBALL_SIZE))), self)
	_fireball.pivot_offset = _fireball.size / 2.0
	_fireball.visible = false
	modulate.a = 0.0

## Moves to point at `button`, with a newly rolled weapon.
func aim_at(button: MenuScrollButton) -> void:
	if _striking or button.destroyed:
		return
	var first := modulate.a == 0.0
	if button != _target or first:
		_roll_weapon()
	_target = button
	if _move_tween:
		_move_tween.kill()
	var tween := create_tween().set_parallel()
	_move_tween = tween
	if first:
		_sprite.position = _rest_position() + Vector2(6, 0) * PX
		_sprite.scale = Vector2.ONE * 0.6
	tween.tween_property(_sprite, "position", _rest_position(), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
	_fade(1.0, 0.1)

## The mouse left `button`: fade out unless it has already moved on to another one.
func lose_aim(button: MenuScrollButton) -> void:
	if _striking or button != _target:
		return
	_target = null
	_fade(0.0, 0.15)

func _fade(alpha: float, seconds: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, seconds)

func _roll_weapon() -> void:
	var previous := _item
	while _item == previous:
		_kind = WEAPONS.keys().pick_random()
		_item = WEAPONS[_kind].pick_random()
	_sprite.texture = ItemDatabase.icon(_item)

## Where the sprite's top-left sits so the tip points at the target's strike point.
func _rest_position() -> Vector2:
	if _target == null:
		return _sprite.position
	return _target.strike_point() - global_position + (AIM_GAP - TIP) * PX

func _process(delta: float) -> void:
	_time += delta
	if _striking or _target == null:
		return
	# a slow bob, in whole art pixels so the sprite never lands between them
	_sprite.position.y = _rest_position().y + roundf(sin(_time * 3.0)) * PX

## Attacks `button` with the current weapon and returns when the scroll is gone.
func strike(button: MenuScrollButton) -> void:
	if button != _target or modulate.a < 1.0:
		aim_at(button)
		await get_tree().create_timer(0.12).timeout
	_striking = true
	if _kind == "sword":
		await _swing(button)
	else:
		await _cast(button)
	_striking = false
	_target = null
	_fade(0.0, 0.15)

func _swing(button: MenuScrollButton) -> void:
	var rest := _rest_position()
	var wind_up := create_tween().set_parallel()
	wind_up.tween_property(_sprite, "position", rest + Vector2(5, -7) * PX, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wind_up.tween_property(_sprite, "rotation", 0.5, 0.12)
	await wind_up.finished
	var across := button.global_position.x - global_position.x + 10 * PX
	var swing := create_tween().set_parallel()
	swing.tween_property(_sprite, "position", Vector2(across, rest.y + 2 * PX), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.tween_property(_sprite, "rotation", -1.1, 0.14)
	button.cut()   # runs alongside the swing; waited for below
	await swing.finished
	var back := create_tween().set_parallel()
	back.tween_property(_sprite, "position", rest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.tween_property(_sprite, "rotation", 0.0, 0.25)
	if button.effect_running:
		await button.effect_finished

func _cast(button: MenuScrollButton) -> void:
	var rest := _rest_position()
	var tip := rest + TIP * PX - _fireball.size / 2.0
	_fireball.position = tip
	_fireball.scale = Vector2.ZERO
	_fireball.visible = true
	# charge: the fireball grows on the tip while the staff shakes
	var charge := create_tween().set_parallel()
	charge.tween_property(_fireball, "scale", Vector2.ONE, 0.3)
	for i in 6:
		charge.tween_property(_sprite, "position:x", rest.x + (PX if i % 2 == 0 else -PX), 0.05).set_delay(i * 0.05)
	await _animate_fireball(0.3)
	_sprite.position = rest
	var target := button.strike_point() - global_position - _fireball.size / 2.0
	var fly := create_tween()
	fly.tween_property(_fireball, "position", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	create_tween().tween_property(_sprite, "position", rest + Vector2(2, 0) * PX, 0.08)
	await _animate_fireball(0.16)
	_fireball.visible = false
	create_tween().tween_property(_sprite, "position", rest, 0.2)
	await button.burn()

## Flickers the fireball's frames for `seconds`.
func _animate_fireball(seconds: float) -> void:
	var elapsed := 0.0
	var frame := 0
	while elapsed < seconds:
		(_fireball.texture as AtlasTexture).region.position.x = frame * FIREBALL_SIZE.x
		frame = (frame + 1) % FIREBALL_FRAMES
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
