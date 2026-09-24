extends Control

const JOIN_TIMEOUT := 15.0
const ERROR_SECONDS := 5.0

var _toast: PanelContainer
var _toast_label: Label
var _toast_id := 0
var _joining := false

func _ready():
	multiplayer.peer_connected.connect(func(id): print ("Peer connected: ", id))
	multiplayer.connection_failed.connect(_on_connection_failed)
	_build_toast()

## Errors show as a toast (a small pop-up that dismisses itself) on the right of the
## lobby, not in the output panel. Built in code so no scene wiring is needed.
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pinned to the right edge, vertically centred, whatever the window size.
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.5
	_toast.anchor_bottom = 0.5
	_toast.offset_left = -460.0
	_toast.offset_right = -40.0
	_toast.offset_top = -40.0
	_toast.offset_bottom = 40.0
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label = Label.new()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast.add_child(_toast_label)
	add_child(_toast)

func _show_error(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast_id += 1
	var my_id := _toast_id
	await get_tree().create_timer(ERROR_SECONDS).timeout
	if my_id == _toast_id and is_instance_valid(_toast):
		_toast.visible = false

## A peer left over from an earlier host or join still owns the Steam listen
## socket, which makes the next create_host fail with ERR_CANT_CREATE.
func _close_old_peer() -> void:
	var old := multiplayer.multiplayer_peer
	if old is SteamMultiplayerPeer:
		old.close()
	multiplayer.multiplayer_peer = null

## Plain-language text for a failed create_host / create_client.
func _describe_error(action: String, error: int) -> String:
	if error == ERR_CANT_CREATE:
		return "Could not %s: Steam would not open the connection. Another copy of the game on this Steam account may be running, or a previous session is still open. Close it and try again." % action
	return "Could not %s (%s)." % [action, error_string(error)]

func _on_connection_failed() -> void:
	_fail_join("Could not reach that host. Check the Steam ID and that they are hosting.")

## Drops the half-open peer so Join can be pressed again.
func _fail_join(text: String) -> void:
	_joining = false
	multiplayer.multiplayer_peer = null
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	_show_error(text)

func _on_copy_id_button_pressed():
	pass

func _on_host_button_pressed():
	if not SteamManager.online:
		_show_error("Steam is not running or you are offline. Start Steam (and go online) to host.")
		return
	_close_old_peer()
	var peer = SteamMultiplayerPeer.new()
	var error = peer.create_host(0)

	if error != OK:
		_show_error(_describe_error("host", error))
		return

	multiplayer.multiplayer_peer = peer
	NetworkSync.session_mode = NetworkSync.SessionMode.HOST
	NetworkSync.reset_session()
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID()
	NetworkSync.peer_names[1] = Steam.getPersonaName()
	print("Hosting. My Steam ID: ", Steam.getSteamID())
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _on_join_button_pressed():
	if _joining:
		return
	if not SteamManager.online:
		_show_error("Steam is not running or you are offline. Start Steam (and go online) to join.")
		return
	var host_id_text = $HSplitContainer/ConnectPanel/LineEdit.text.strip_edges()
	if host_id_text.is_empty() or not host_id_text.is_valid_int():
		_show_error("Enter a valid host Steam ID before joining (digits only).")
		return
	if host_id_text.length() != 17:
		_show_error("A Steam ID is 17 digits long. Yours had %d. Copy it again from the host." % host_id_text.length())
		return
	if host_id_text.to_int() == Steam.getSteamID():
		_show_error("That is your own Steam ID. Paste the host's ID instead.")
		return
	_close_old_peer()
	var peer = SteamMultiplayerPeer.new()
	var host_steam_id = host_id_text.to_int()
	var error = peer.create_client(host_steam_id, 0)

	if error != OK:
		_show_error(_describe_error("join", error))
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	_joining = true
	print("Joining host: ", host_steam_id)

	await get_tree().create_timer(JOIN_TIMEOUT).timeout
	if is_instance_valid(self) and _joining:
		_fail_join("Join timed out. The host did not answer.")

func _on_connected_to_server():
	_joining = false
	NetworkSync.session_mode = NetworkSync.SessionMode.CLIENT
	NetworkSync.report_player_name.rpc_id(1, Steam.getPersonaName())
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _on_back_pressed() -> void:
	get_parent().hide()
	queue_free()
