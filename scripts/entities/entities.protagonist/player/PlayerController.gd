class_name PlayerController
extends CharacterBody2D

@onready var grid_mover: GridMover = $GridMover
@onready var animator: DirectionalAnimator = $DirectionalAnimator
@onready var stats: EntityStats = $EntityStats

## The worn gear, drawn on top of (or behind) $AnimatedSprite2D. See set_equipment().
var gear := GearLayers.new()

## Skins: the adventurer's look, purely cosmetic -- which sprite_frames to wear. Stats
## and actions are the same for every skin (ADVENTURER_DATA_PATH). Only the Human is left:
## gear (GearLayers) is drawn to fit its body, and the old knight and dwarf were temporary.
const SKINS := {
	"human": "res://resources/gfx/entities/entities.protagonist/human/human.json",
}
const DEFAULT_SKIN := "human"

## Stats/attack shared by every skin.
const ADVENTURER_DATA_PATH := "res://game/entities/entities.protagonist/adventurer.json"
const GHOST_DATA_PATH := "res://resources/gfx/entities/entities.protagonist/ghost/ghost.json"

const TILE_HOVER_DATA := {
	"texture": "res://resources/gfx/effects/TileHover.png",
	"frame_count": 2,
	"speed": 1.0,
}

## Hotbar slots 1-0 (index 0-9): the worn gear's actions, then the player's own
## (see _update_attacks). A slot past the end holds nothing, so number keys ignore
## it. active_slot is public so Hotbar can poll it to highlight the active slot.
signal attacks_changed
var _attacks: Array = []
var _own_actions: Array = []
var _worn: Dictionary = {}
var active_slot: int = 0
## Game time (GameTick.msec) the attacks can be used again, like the taunt's _taunt_ready_msec.
var _attack_ready_msec := 0
var _is_dead := false

func set_skin(skin_id: String) -> void:
	var data := JsonOnloading.load_dict(SKINS.get(skin_id, SKINS[DEFAULT_SKIN]))
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(data["sprite_frames"])

## worn: slot -> item id (NetworkSync.peer_equipment). Drawn, and its actions go on the hotbar.
func set_equipment(worn: Dictionary) -> void:
	_worn = worn
	viewer.light = ItemDatabase.light_of(worn)
	gear.set_equipment(worn)
	_update_attacks()

func _load_adventurer_data() -> void:
	var data := JsonOnloading.load_dict(ADVENTURER_DATA_PATH)
	stats.load_from_data(data)
	_own_actions = data.get("actions", [])
	_senses = data.get("senses", {})
	viewer.sight = sense_range("sight")
	viewer.touch = sense_range("touch")
	viewer.hearing = hearing_threshold()
	_update_attacks()

## adventurer.json "senses": sense -> {"range_tiles": n} (hearing: {"threshold_db": n}), or
## false for one it doesn't have.
var _senses := {}

## A sense's range in tiles; 0 when the adventurer doesn't have that sense.
func sense_range(sense: String) -> float:
	var entry = _senses.get(sense, false)
	return float(entry.get("range_tiles", 0.0)) if entry is Dictionary else 0.0

## The quietest sound this adventurer hears, in dB (like a minion's, SenseHearing); INF when deaf.
func hearing_threshold() -> float:
	var entry = _senses.get("hearing", false)
	return float(entry.get("threshold_db", SenseHearing.DEFAULT_THRESHOLD_DB)) if entry is Dictionary else INF

## What the map's light and vision know about this adventurer (cells never reads the player).
var viewer := Viewer.new()

## Gear actions come first, weapons before the other slots, then the player's own
## actions (adventurer.json: taunt, throw rock), cut to the 10 hotbar slots.
const WEAPON_SLOTS: Array[String] = ["main_hand", "off_hand"]

func _update_attacks() -> void:
	var entries: Array = []
	var slots := WEAPON_SLOTS + ItemDatabase.SLOTS.filter(func(slot): return not WEAPON_SLOTS.has(slot))
	for slot in slots:
		if _worn.has(slot):
			entries.append_array(ItemDatabase.get_item(_worn[slot]).get("actions", []))
	_attacks = ActionIndex.resolve(entries + _own_actions).slice(0, SLOT_ACTIONS.size())
	if not _slot_usable(active_slot):
		active_slot = 0
	attacks_changed.emit()

## The hotbar's actions in slot order (Hotbar shows their ids).
func hotbar_actions() -> Array:
	return _attacks

func _current_attack() -> Dictionary:
	return _attacks[active_slot] if active_slot < _attacks.size() else {}

## Debug god mode (DebugMenu), copied to every peer by NetworkSync so all of
## them agree this player can't be hurt.
var debug_god := false

func take_damage(amount: int, type: String = "") -> void:
	if debug_god:
		return
	stats.take_damage(amount, type)

## Swaps to the ghost skin and stops the player from attacking -- movement
## stays on, since a ghost that can still drift around to watch the rest of
## the party fits the usual sense of "ghost" better than freezing in place.
## Each step into a new tile is a noise minions can hear (Sound, SenseHearing). Only the
## player's own machine reports it; a ghost or a debug-unseen player is silent.
const FOOTSTEP_DB := 30.0

func _on_stepped(tile: Vector2i) -> void:
	if not is_multiplayer_authority() or stats.is_ghost or DebugState.unseen:
		return
	NetworkSync.report_noise((Vector2(tile) + Vector2(0.5, 0.5)) * grid_mover.tile_size, FOOTSTEP_DB)

func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	stats.is_ghost = true
	viewer.ghost = true
	grid_mover.become_ghost()
	# Above every other entity (players/minions sit at 1000), but below
	# LightMap's own overlay sprites (2000/2001) so it doesn't fight lighting.
	z_index = 1500
	gear.hidden = true
	var ghost_data := JsonOnloading.load_dict(GHOST_DATA_PATH)
	$AnimatedSprite2D.sprite_frames = SpriteFramesLoader.build(ghost_data["sprite_frames"])

func _on_touch_area_body_entered(body: Node2D) -> void:
	if not stats.is_ghost and body is MinionController:
		body.senses.touch.notify_enter()

func _on_touch_area_body_exited(body: Node2D) -> void:
	if not stats.is_ghost and body is MinionController:
		body.senses.touch.notify_exit()

func _ready() -> void:
	set_multiplayer_authority(int(str(name)))
	add_to_group("protagonist")
	viewer.is_local = is_multiplayer_authority()
	Viewer.register(viewer)
	gear.name = "GearLayers"
	add_child(gear)
	gear.setup($AnimatedSprite2D)
	_load_adventurer_data()
	stats.died.connect(_on_died)
	grid_mover.stepped.connect(_on_stepped)
	$TileHoverHighlight.sprite_frames = SpriteFramesLoader.build({
		"frame_size": [16, 16],
		"animations": {"Play": TILE_HOVER_DATA},
	})
	$TileHoverHighlight.play("Play")
	$TileHoverHighlight.visible = false

func _exit_tree() -> void:
	Viewer.unregister(viewer)

func _process(delta: float) -> void:
	viewer.position = global_position
	if is_multiplayer_authority():
		if grid_mover.is_moving:
			animator.animate_moving(grid_mover.facing_direction)
		else:
			animator.animate_idle()
		_update_tile_hover()
		if _attack_held:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("attack"):
				_try_attack()
			else:
				_attack_held = false
		# Debug "unseen": your own sprite goes see-through as the reminder.
		$AnimatedSprite2D.modulate.a = 0.4 if DebugState.unseen else 1.0
	else:
		visible = not stats.is_ghost or Viewer.local_is_ghost()
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
		Vector2i((aim_position() / grid_mover.tile_size).floor()) if ranged
		else _melee_target_tile(own_tile)
	)
	var valid: bool = not _is_dead and not grid_mover.is_tile_blocked(tile)
	$TileHoverHighlight.visible = valid
	if valid:
		$TileHoverHighlight.global_position = Vector2(tile) * grid_mover.tile_size + Vector2(8, 8)

## The 8 tiles ringing the player, ordered by angle starting from due east
## (matches Vector2.angle()'s 0 = +x, increasing clockwise since y is down).
## Last direction the left stick pointed, scaled by how far it was pushed.
var _stick_aim := Vector2.RIGHT

## Where the player aims, in world space: the mouse, or on a controller the left
## stick, reaching as far as the current attack's range_tiles (see ThrowVerb).
## The stick's last direction is kept after it lets go, so aim doesn't jump to
## wherever the unused mouse cursor sits. Also used by MouseFollowCamera.
func aim_position() -> Vector2:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick != Vector2.ZERO:
		_stick_aim = stick
	if not InputDevice.using_pad:
		return get_global_mouse_position()
	var reach: float = _current_attack().get("range_tiles", 6.0) * grid_mover.tile_size
	return global_position + Vector2(8, 8) + _stick_aim * reach

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
	var to_mouse := aim_position() - (global_position + Vector2(8, 8))
	if to_mouse.length() < 0.001:
		return own_tile + ADJACENT_OFFSETS[0]
	var index := int(round(fposmod(to_mouse.angle(), TAU) / (PI / 4.0))) % 8
	return own_tile + ADJACENT_OFFSETS[index]

## WASD or the right stick (project.godot). Not the ui_* actions: those are the
## left stick, which aims in play and moves the focus in menus.
const MOVE_ACTIONS := {
	"move_right": Vector2.RIGHT,
	"move_left": Vector2.LEFT,
	"move_up": Vector2.UP,
	"move_down": Vector2.DOWN,
}

# Left mouse held down since a press that started as an attack: _process repeats
# the attack as its cooldown allows.
var _attack_held := false

# The movement keys currently held, oldest first. One horizontal and one vertical
# key together walk diagonally; two keys on the same axis (left + right) go
# whichever way was pressed last.
var _held: Array = []

## The step the held keys ask for: one of the 8 directions, or zero.
func _held_direction() -> Vector2:
	var direction := Vector2.ZERO
	for action in _held:
		var step: Vector2 = MOVE_ACTIONS[action]
		if step.x != 0.0:
			direction.x = step.x
		else:
			direction.y = step.y
	return direction

## Input actions for hotbar slots 1..10 (keys 1-9 and 0, see project.godot).
const SLOT_ACTIONS := ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
	"hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_0"]

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	for slot in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[slot]) and _slot_usable(slot):
			active_slot = slot
	# The mouse wheel is also hotbar_prev/next: not while it scrolls a menu or zooms the free cam.
	var wheel_busy := event is InputEventMouseButton and (_attack_blocked() or DebugState.free_cam)
	if not wheel_busy and event.is_action_pressed("hotbar_prev"):
		_step_slot(-1)
	elif not wheel_busy and event.is_action_pressed("hotbar_next"):
		_step_slot(1)
	for action in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			_held.erase(action)
			_held.append(action)
		elif event.is_action_released(action):
			_held.erase(action)
	# Space and RT ("attack" in project.godot) swing the same as the left mouse button.
	var attack_pressed: bool = event.is_action_pressed("attack") or (event is InputEventMouseButton
		and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if attack_pressed:
		# Holding the button keeps swinging (see _process); a press that starts on
		# the debug menu or a click tool never turns into a held attack.
		_attack_held = not _attack_blocked()
		_try_attack()

func _slot_usable(slot: int) -> bool:
	return slot < _attacks.size() and not _attacks[slot].is_empty()

## LB/RB: the next slot that holds an attack, wrapping around the 10 slots.
func _step_slot(step: int) -> void:
	for i in range(1, SLOT_ACTIONS.size()):
		var slot := posmod(active_slot + step * i, SLOT_ACTIONS.size())
		if _slot_usable(slot):
			active_slot = slot
			return

## A click on a menu (the debug menu, the open inventory) is not an attack.
func _attack_blocked() -> bool:
	return DebugState.blocks_attack() or InventoryPanel.mouse_over_open_panel(get_viewport())

## Melee (target_mode "melee", the default) always hits one of the 8 tiles
## adjacent to the player -- whichever _melee_target_tile() picks for the
## mouse's direction -- effect between the two. Ranged (target_mode
## "ranged") can hit any tile clicked instead, effect anchored on the
## target -- see AttackEffect.effect_position().
func _try_attack() -> void:
	if _attack_blocked():
		return
	var attack: Dictionary = _current_attack()
	if attack.get("verb", "") == "taunt":
		_try_taunt(attack)
		return
	if _is_dead or GameTick.msec() < _attack_ready_msec or attack.is_empty():
		return
	var own_tile := _own_tile()
	var ranged: bool = attack.get("target_mode", "melee") == "ranged"
	var target_tile: Vector2i
	if ranged:
		target_tile = Vector2i((aim_position() / grid_mover.tile_size).floor())
		if target_tile == own_tile:
			return
	else:
		target_tile = _melee_target_tile(own_tile)
	# A thrown rock may be aimed at a wall (ThrowVerb lands it in front).
	if attack.get("verb", "") != "throw" and grid_mover.is_tile_blocked(target_tile):
		return
	_attack_ready_msec = GameTick.msec() + int(attack.get("interval", 0.5) * 1000.0)
	var target_global := Vector2(target_tile) * grid_mover.tile_size
	if not ActionRunner.perform(self, target_global, attack):
		_attack_ready_msec = 0

## Taunt slot (an action whose verb is "taunt", see TauntVerb). Its own cooldown
## (`interval`) so it never locks out the attacks.
var _taunt_ready_msec := 0

func _try_taunt(attack: Dictionary) -> void:
	var now := GameTick.msec()
	if _is_dead or now < _taunt_ready_msec:
		return
	_taunt_ready_msec = now + int(attack.get("interval", 12.0) * 1000.0)
	ActionRunner.perform(self, global_position, attack)

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	# Drop keys that are no longer down (a release can be missed, for example when focus is lost).
	_held = _held.filter(func(action): return Input.is_action_pressed(action))
	# Debug free cam: the move keys fly the camera instead, so stand still.
	if DebugState.free_cam:
		_held.clear()
		return
	if grid_mover.is_moving or _held.is_empty():
		return
	var direction := _held_direction()
	if direction.x == 0.0 or direction.y == 0.0:
		grid_mover.move_one_tile(direction)
		return
	# Diagonal. If it is refused (a wall corner, a doorway, someone standing
	# there), slide along the key pressed last, then the other one, so holding
	# two keys against a wall still walks along it.
	if grid_mover.move_one_tile(direction):
		return
	var newest: Vector2 = MOVE_ACTIONS[_held.back()]
	if not grid_mover.move_one_tile(newest):
		grid_mover.move_one_tile(direction - newest)
