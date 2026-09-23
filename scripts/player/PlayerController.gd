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

const ATTACK_EFFECT_SCENE := preload("res://scenes/entities/AttackEffect.tscn")

var _attack_amount: int = 0
var _attack_type: String = ""
var _attack_interval: float = 0.5
var _attack_effect: Dictionary = {}
var _attack_timer := 0.0
var _is_dead := false

func set_character(character_id: String) -> void:
	var data := JsonOnloading.load_dict(CHARACTERS.get(character_id, CHARACTERS[DEFAULT_CHARACTER]))
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])

func _load_player_data() -> void:
	var data := JsonOnloading.load_dict(PLAYER_DATA_PATH)
	stats.load_from_data(data)
	var attack_data: Dictionary = data.get("attack", {})
	_attack_amount = attack_data.get("amount", 0)
	_attack_type = attack_data.get("type", "")
	_attack_interval = attack_data.get("interval", 0.5)
	_attack_effect = attack_data.get("effect", {})

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
	add_to_group("protagonist")
	_load_player_data()
	stats.died.connect(_on_died)

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if grid_mover.is_moving:
			animator.animate_moving(grid_mover.facing_direction)
		else:
			animator.animate_idle()
		_attack_timer = maxf(_attack_timer - delta, 0.0)
	else:
		animator.animate_from_position(delta, global_position)

const MOVE_ACTIONS := {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN,
}

# The movement keys currently held, oldest first, so the newest press decides the direction.
var _held: Array = []

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	for action in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			_held.erase(action)
			_held.append(action)
		elif event.is_action_released(action):
			_held.erase(action)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_attack()

## Click a tile adjacent to (including diagonal to) the player to attack it --
## a 16x16 effect spawns at the midpoint between the player's tile and the
## clicked tile, and whatever occupies that tile takes damage. Inert (no
## effect, no cooldown) until the character's JSON supplies an "attack" block.
func _try_attack() -> void:
	if _is_dead or grid_mover.is_moving or _attack_timer > 0.0 or _attack_amount <= 0:
		return
	var own_tile := Vector2i(global_position / grid_mover.tile_size)
	var target_tile := Vector2i((get_global_mouse_position() / grid_mover.tile_size).floor())
	var offset := target_tile - own_tile
	if offset == Vector2i.ZERO or absi(offset.x) > 1 or absi(offset.y) > 1:
		return
	_attack_timer = _attack_interval
	var target_global := Vector2(target_tile) * grid_mover.tile_size
	if not _attack_effect.is_empty():
		var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = AttackEffect.effect_position(global_position, target_global, _attack_effect)
		effect.play(_attack_effect, target_global - global_position)
	for enemy in get_tree().get_nodes_in_group("antagonist"):
		if Vector2i(enemy.global_position / grid_mover.tile_size) == target_tile:
			enemy.take_damage(_attack_amount, _attack_type)

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	# Drop keys that are no longer down (a release can be missed, for example when focus is lost).
	_held = _held.filter(func(action): return Input.is_action_pressed(action))
	if grid_mover.is_moving:
		return
	if not _held.is_empty():
		grid_mover.move_one_tile(MOVE_ACTIONS[_held.back()])
