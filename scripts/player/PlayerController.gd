extends CharacterBody2D

@export var tile_size := 16
@export var move_time := 0.2

@onready var wall_data: TileMapLayer = get_tree().current_scene.find_child("WallData", true, false)
@onready var floor_data: TileMapLayer = get_tree().current_scene.find_child("FloorData", true, false)

@onready var _open_door_source_id: int = load("res://resources/tiles/tile_type_registry.tres").get_id("wall_door_open")
@onready var _void_source_id: int = load("res://resources/tiles/tile_type_registry.tres").get_id("floor_void")

@export var camera_mouse_weight := 0.3
@export var camera_max_offset := 96.0

var _last_anim_position := Vector2.ZERO
var _facing_direction := Vector2.DOWN
var _anim_idle_time := 0.0

func _process(delta: float) -> void:
	_update_facing_animation(delta)
	if not is_multiplayer_authority():
		return
	# The connection drops a moment before the scene changes when a player leaves; skip sending then.
	if _is_connected():
		if multiplayer.is_server():
			NetworkSync._relay_position(1, global_position)
		else:
			NetworkSync.report_position.rpc_id(1, global_position)
	var mouse_world := get_global_mouse_position()
	var to_mouse := (mouse_world - global_position) * camera_mouse_weight
	if to_mouse.length() > camera_max_offset:
		to_mouse = to_mouse.normalized() * camera_max_offset
	$Camera2D.position = to_mouse

func _is_connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _update_facing_animation(delta: float) -> void:
	if is_multiplayer_authority():
		if not is_moving:
			$AnimatedSprite2D.stop()
			return
		if abs(_facing_direction.x) > abs(_facing_direction.y):
			$AnimatedSprite2D.play("Side")
			$AnimatedSprite2D.flip_h = _facing_direction.x < 0
		else:
			$AnimatedSprite2D.play("Back" if _facing_direction.y < 0 else "Front")
		return
	var delta_pos := global_position - _last_anim_position
	_last_anim_position = global_position
	if delta_pos.length() < 0.5:
		_anim_idle_time += delta
		if _anim_idle_time > 0.15:
			$AnimatedSprite2D.stop()
		return
	_anim_idle_time = 0.0
	if abs(delta_pos.x) > abs(delta_pos.y):
		$AnimatedSprite2D.play("Side")
		$AnimatedSprite2D.flip_h = delta_pos.x < 0
	else:
		$AnimatedSprite2D.play("Back" if delta_pos.y < 0 else "Front")

func _ready() -> void:
	_build_floor_speeds()
	set_multiplayer_authority(int(str(name)))
	if is_multiplayer_authority():
		$Camera2D.enabled = true

func _floor_source_at(target_global: Vector2) -> int:
	if floor_data == null:
		return -1
	var cell: Vector2i = floor_data.local_to_map(floor_data.to_local(target_global))
	return floor_data.get_cell_source_id(cell)

var _floor_speed := {}

func _build_floor_speeds() -> void:
	var registry: TileTypeRegistry = load("res://resources/tiles/tile_type_registry.tres")
	var dir := DirAccess.open("res://resources/tiles/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var tile := load("res://resources/tiles/" + file_name) as TileType
		if tile != null and tile.category == TileType.Category.FLOOR:
			_floor_speed[registry.get_id(tile.tile_name)] = tile.move_speed()

func _is_blocked(target_global: Vector2) -> bool:
	if wall_data == null:
		return false
	var cell: Vector2i = wall_data.local_to_map(wall_data.to_local(target_global))
	var source_id := wall_data.get_cell_source_id(cell)
	if source_id != -1 and source_id != _open_door_source_id:
		return true
	return _floor_source_at(target_global) == _void_source_id

var is_moving := false

func _move_one_tile(direction: Vector2) -> void:
	var target_global := global_position + direction * tile_size
	if _is_blocked(target_global):
		return
	_facing_direction = direction
	is_moving = true

	var step_time: float = move_time / _floor_speed.get(_floor_source_at(target_global), 1.0)

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global, step_time)
	tween.finished.connect(func(): is_moving = false)

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
	if is_moving:
		return
	if not _held.is_empty():
		_move_one_tile(MOVE_ACTIONS[_held.back()])
