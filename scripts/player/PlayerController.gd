extends CharacterBody2D

@onready var grid_mover: GridMover = $GridMover
@onready var animator: DirectionalAnimator = $DirectionalAnimator

const CHARACTERS := {
	"knight": "res://resources/gfx/players/knight/Knight.tres",
	"dwarf": "res://resources/gfx/players/dwarf/Dwarf.tres",
}
const DEFAULT_CHARACTER := "knight"

func set_character(character_id: String) -> void:
	$AnimatedSprite2D.sprite_frames = load(CHARACTERS.get(character_id, CHARACTERS[DEFAULT_CHARACTER]))

func _ready() -> void:
	set_multiplayer_authority(int(str(name)))

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if grid_mover.is_moving:
			animator.animate_moving(grid_mover.facing_direction)
		else:
			animator.animate_idle()
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
	for action in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			_held.erase(action)
			_held.append(action)
		elif event.is_action_released(action):
			_held.erase(action)

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	# Drop keys that are no longer down (a release can be missed, for example when focus is lost).
	_held = _held.filter(func(action): return Input.is_action_pressed(action))
	if grid_mover.is_moving:
		return
	if not _held.is_empty():
		grid_mover.move_one_tile(MOVE_ACTIONS[_held.back()])
