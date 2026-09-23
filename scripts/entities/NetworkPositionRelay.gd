class_name NetworkPositionRelay
extends Node

## Reports the parent's position to the host every frame, for anything other
## peers need to see move -- players, and antagonist when human-piloted.
## Relies on multiplayer authority being set (with the default recursive=true)
## on an ancestor, so this node inherits it.

@onready var _body: Node2D = get_parent()

func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if not _is_connected():
		return
	if multiplayer.is_server():
		NetworkSync._relay_position(1, _body.global_position)
	else:
		NetworkSync.report_position.rpc_id(1, _body.global_position)

func _is_connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
