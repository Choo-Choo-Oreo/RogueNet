class_name PlayerController
extends CharacterBody2D

@onready var grid_mover: GridMover = $GridMover
@onready var animator: DirectionalAnimator = $DirectionalAnimator
@onready var stats: EntityStats = $EntityStats

## Purely cosmetic -- which sprite_frames to wear. Knight/dwarf don't (yet)
## differ in stats or attack, so that data doesn't live in these files; see
## PLAYER_DATA_PATH.
const CHARACTERS := {
	"knight": "res://resources/gfx/players/player.protagonist/knight/knight.json",
	"dwarf": "res://resources/gfx/players/player.protagonist/dwarf/dwarf.json",
}
const DEFAULT_CHARACTER := "knight"

## Stats/attack shared by every character skin.
const PLAYER_DATA_PATH := "res://game/entities/entities.players/player.json"
const GHOST_DATA_PATH := "res://resources/gfx/players/player.protagonist/ghost/ghost.json"

const TILE_HOVER_DATA := {
	"texture": "res://resources/gfx/effects/TileHover.png",
	"frame_count": 2,
	"speed": 1.0,
}

## Hotbar slots 1-4 (index 0-3) -- an empty {} means the slot has nothing
## equipped, so number keys ignore it and it never fires. Public so Hotbar
## can poll it to highlight the active slot.
var _attacks: Array = []
var active_slot: int = 0
var _attack_timer := 0.0
var _is_dead := false

## True on this machine once its OWN player has died. A dead player's ghost
## (and its light, see LightMap) is only shown to other ghosts, never to the
## living. Static so LightMap can ask without holding a player reference.
static var local_is_ghost := false

func set_character(character_id: String) -> void:
	var data := JsonOnloading.load_dict(CHARACTERS.get(character_id, CHARACTERS[DEFAULT_CHARACTER]))
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])

func _load_player_data() -> void:
	var data := JsonOnloading.load_dict(PLAYER_DATA_PATH)
	stats.load_from_data(data)
	_attacks = data.get("attacks", [])

func _current_attack() -> Dictionary:
	return _attacks[active_slot] if active_slot < _attacks.size() else {}

func take_damage(amount: int, type: String = "") -> void:
	stats.take_damage(amount, type)

## Swaps to the ghost skin and stops the player from attacking -- movement
## stays on, since a ghost that can still drift around to watch the rest of
## the party fits the usual sense of "ghost" better than freezing in place.
func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	stats.is_ghost = true
	if is_multiplayer_authority():
		local_is_ghost = true
	# Above every other entity (players/enemies sit at 1000), but below
	# LightMap's own overlay sprites (2000/2001) so it doesn't fight lighting.
	z_index = 1500
	var ghost_data := JsonOnloading.load_dict(GHOST_DATA_PATH)
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(ghost_data["sprite_frames"])

func _on_touch_area_body_entered(body: Node2D) -> void:
	if not stats.is_ghost and body is EnemyController:
		body.senses.touch.notify_enter()

func _on_touch_area_body_exited(body: Node2D) -> void:
	if not stats.is_ghost and body is EnemyController:
		body.senses.touch.notify_exit()

func _ready() -> void:
	set_multiplayer_authority(int(str(name)))
	if is_multiplayer_authority():
		local_is_ghost = false
	add_to_group("protagonist")
	_load_player_data()
	stats.died.connect(_on_died)
	$TileHoverHighlight.sprite_frames = SpriteFramesLoader.build({
		"frame_size": [16, 16],
		"animations": {"Play": TILE_HOVER_DATA},
	})
	$TileHoverHighlight.play("Play")
	$TileHoverHighlight.visible = false

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if grid_mover.is_moving:
			animator.animate_moving(grid_mover.facing_direction)
		else:
			animator.animate_idle()
		_attack_timer = maxf(_attack_timer - delta, 0.0)
		_update_tile_hover()
	else:
		visible = not stats.is_ghost or local_is_ghost
		animator.animate_from_position(delta, global_position)

## Vector2i(pos / tile_size) truncates toward zero, which rounds the wrong
## way for a fractional position on the negative side of the origin (this
## dungeon spans both) -- floori() matches what TileMapLayer.local_to_map
## actually does, same fix DungeonMaker/LightMap already use.
func _to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / grid_mover.tile_size), floori(pos.y / grid_mover.tile_size))

## The tile the player's centre is over. Attacks are allowed mid-step, and
## global_position (the tile's top-left corner) would name the tile being left
## for the whole step instead of the one the player is mostly on.
func _own_tile() -> Vector2i:
	return _to_tile(global_position + Vector2(grid_mover.tile_size, grid_mover.tile_size) / 2.0)

## Always on (both melee and ranged), but hidden over a wall/void tile --
## nothing is ever a legal target there, same restriction _try_attack()
## itself enforces below.
func _update_tile_hover() -> void:
	var ranged: bool = _current_attack().get("target_mode", "melee") == "ranged"
	var own_tile := _own_tile()
	var tile := (
		Vector2i((get_global_mouse_position() / grid_mover.tile_size).floor()) if ranged
		else _melee_target_tile(own_tile)
	)
	var valid: bool = not _is_dead and not grid_mover.is_tile_blocked(tile)
	$TileHoverHighlight.visible = valid
	if valid:
		$TileHoverHighlight.global_position = Vector2(tile) * grid_mover.tile_size + Vector2(8, 8)

## The 8 tiles ringing the player, ordered by angle starting from due east
## (matches Vector2.angle()'s 0 = +x, increasing clockwise since y is down).
const ADJACENT_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]

## Melee doesn't require clicking exactly on an adjacent tile -- it takes
## whichever of the 8 surrounding tiles best matches the mouse's direction
## from the player, so clicking anywhere off to the left hits the one tile
## to the left instead of missing because the click landed further out.
func _melee_target_tile(own_tile: Vector2i) -> Vector2i:
	# Measured from the player's center, not global_position (their tile's
	# top-left corner) -- that 8px bias barely affects the angle at range,
	# but up close, where to_mouse itself might only be ~16-24px long, it's
	# enough to swing the angle into the wrong one of the 8 directions.
	var to_mouse := get_global_mouse_position() - (global_position + Vector2(8, 8))
	if to_mouse.length() < 0.001:
		return own_tile + ADJACENT_OFFSETS[0]
	var index := int(round(fposmod(to_mouse.angle(), TAU) / (PI / 4.0))) % 8
	return own_tile + ADJACENT_OFFSETS[index]

const MOVE_ACTIONS := {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN,
}

# The movement keys currently held, oldest first, so the newest press decides the direction.
var _held: Array = []

const SLOT_KEYS := {
	KEY_1: 0,
	KEY_2: 1,
	KEY_3: 2,
	KEY_4: 3,
}

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event is InputEventKey and event.pressed and SLOT_KEYS.has(event.keycode):
		var slot: int = SLOT_KEYS[event.keycode]
		if slot < _attacks.size() and not _attacks[slot].is_empty():
			active_slot = slot
	for action in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			_held.erase(action)
			_held.append(action)
		elif event.is_action_released(action):
			_held.erase(action)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_attack()

## Melee (target_mode "melee", the default) always hits one of the 8 tiles
## adjacent to the player -- whichever _melee_target_tile() picks for the
## mouse's direction -- effect between the two. Ranged (target_mode
## "ranged") can hit any tile clicked instead, effect anchored on the
## target -- see AttackEffect.effect_position().
func _try_attack() -> void:
	var attack: Dictionary = _current_attack()
	if attack.get("kind", "") == "taunt":
		_try_taunt(attack)
		return
	var amount: int = attack.get("amount", 0)
	if _is_dead or _attack_timer > 0.0 or amount <= 0:
		return
	var own_tile := _own_tile()
	var ranged: bool = attack.get("target_mode", "melee") == "ranged"
	var target_tile: Vector2i
	if ranged:
		target_tile = Vector2i((get_global_mouse_position() / grid_mover.tile_size).floor())
		if target_tile == own_tile:
			return
	else:
		target_tile = _melee_target_tile(own_tile)
	if grid_mover.is_tile_blocked(target_tile):
		return
	_attack_timer = attack.get("interval", 0.5)
	var target_global := Vector2(target_tile) * grid_mover.tile_size
	var effect_data: Dictionary = attack.get("effect", {})
	var deal_damage := func():
		for enemy in get_tree().get_nodes_in_group("antagonist"):
			if _to_tile(enemy.global_position) == target_tile:
				# Enemies are host-owned (EnemySpawning.spawn_one) -- route
				# through NetworkSync so the host actually applies it and
				# tells every peer, instead of mutating this client's own
				# possibly-non-authoritative copy directly.
				NetworkSync.report_enemy_hit(int(str(enemy.name)), amount, attack.get("type", ""))
	if effect_data.has("attacker") or effect_data.has("target"):
		_play_bow_effect(effect_data, target_global, deal_damage)
		return
	if not effect_data.is_empty():
		NetworkSync.play_effect(
			AttackEffect.effect_position(global_position, target_global, effect_data),
			effect_data, target_global - global_position)
	deal_damage.call()

## Taunt slot ("kind": "taunt" in player.json): enemies within radius_tiles
## (nearest max_targets of them) are forced onto this player for `duration`
## seconds. Its own cooldown (`interval`) so it never locks out the attacks.
var _taunt_ready_msec := 0

func _try_taunt(attack: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if _is_dead or now < _taunt_ready_msec:
		return
	_taunt_ready_msec = now + int(attack.get("interval", 12.0) * 1000.0)
	NetworkSync.report_taunt(
		int(str(name)),
		attack.get("radius_tiles", 6.0),
		attack.get("duration", 4.0),
		attack.get("max_targets", 24))
	var effect_data: Dictionary = attack.get("effect", {})
	if not effect_data.is_empty():
		NetworkSync.play_effect(
			AttackEffect.effect_position(global_position, global_position, effect_data),
			effect_data, Vector2.RIGHT)

const PROJECTILE_SCENE := preload("res://scenes/entities/ProjectileController.tscn")

## Bow-style attack: the "attacker" effect plays on the player as the shot
## leaves (purely cosmetic), a real projectile (e.g. the arrow) flies from
## their center to the target tile's center at a fixed speed, and only on
## arrival does the "target" hit effect play and the damage land.
func _play_bow_effect(effect_data: Dictionary, target_global: Vector2, on_hit: Callable) -> void:
	var direction := target_global - global_position
	var attacker_data: Dictionary = effect_data.get("attacker", {})
	if not attacker_data.is_empty():
		NetworkSync.play_effect(
			AttackEffect.effect_position(global_position, target_global, attacker_data),
			attacker_data, direction)
	var projectile_texture: String = effect_data.get("projectile", "")
	if projectile_texture == "":
		_land_hit(effect_data, target_global, on_hit)
		return
	var projectile: ProjectileController = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	var center := Vector2(8, 8)
	projectile.global_position = global_position + center
	projectile.launch(projectile_texture, target_global + center, grid_mover.tile_size, func():
		_land_hit(effect_data, target_global, on_hit), grid_mover.is_position_blocked)
	NetworkSync.share_projectile(projectile_texture, global_position + center, target_global + center)

func _land_hit(effect_data: Dictionary, target_global: Vector2, on_hit: Callable) -> void:
	var target_data: Dictionary = effect_data.get("target", {})
	if not target_data.is_empty():
		NetworkSync.play_effect(
			AttackEffect.effect_position(global_position, target_global, target_data),
			target_data, target_global - global_position)
	on_hit.call()

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	# Drop keys that are no longer down (a release can be missed, for example when focus is lost).
	_held = _held.filter(func(action): return Input.is_action_pressed(action))
	if grid_mover.is_moving:
		return
	if not _held.is_empty():
		grid_mover.move_one_tile(MOVE_ACTIONS[_held.back()])
