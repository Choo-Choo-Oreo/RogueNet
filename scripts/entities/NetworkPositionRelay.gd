class_name NetworkPositionRelay
extends Node

## Reports the parent's position to the host once per game tick (GameTick) while it moves,
## plus a heartbeat, for anything other peers need to see move -- players, and antagonist
## when human-piloted. Receivers glide between positions (GridMover.follow_network).
## Relies on multiplayer authority being set (with the default recursive=true)
## on an ancestor, so this node inherits it.

@onready var _body: Node2D = get_parent()

const HEARTBEAT_TICKS := 20
var _sent_position := Vector2.INF
var _sent_tick := 0

func _ready() -> void:
	GameTick.ticked.connect(_on_tick)

func _on_tick(tick: int) -> void:
	if not is_inside_tree():  # leaving with a scene change, not freed yet
		return
	if not is_multiplayer_authority():
		return
	if not _is_connected():
		return
	if _body.global_position == _sent_position and tick - _sent_tick < HEARTBEAT_TICKS:
		return
	_sent_position = _body.global_position
	_sent_tick = tick
	if multiplayer.is_server():
		NetworkSync._relay_position(1, _body.global_position)
	else:
		NetworkSync.report_position.rpc_id(1, _body.global_position)

func _is_connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
