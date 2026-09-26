extends Control

const JOIN_TIMEOUT := 15.0
const ERROR_SECONDS := 5.0

var _toast: PanelContainer
var _toast_label: Label
var _toast_id := 0
var _joining := false

func _ready():
	multiplayer.connection_failed.connect(_on_connection_failed)
	_build_toast()
	_show_own_id()

## Errors show as a toast (a small pop-up that dismisses itself) on the right of the
## lobby, not in the output panel. Built in code so no scene wiring is needed.
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pinned to the right edge, vertically centred, whatever the window size: a full-height
	# column on the right centres it (a container, so it lands on whole UI pixels).
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = -230.0
	column.offset_right = -20.0
	_toast.custom_minimum_size.y = 40
	_toast_label = Label.new()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_toast_label.theme_type_variation = &"MenuHeading"
	_toast.add_child(_toast_label)
	column.add_child(_toast)
	add_child(column)

## seconds = 0 keeps the toast up until the next one replaces it (used while joining).
func _show_error(text: String, color := Color(1.0, 0.45, 0.4), seconds := ERROR_SECONDS) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast_id += 1
	var my_id := _toast_id
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
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

## Your Steam ID goes in the read-only box so the Copy button (and you) can use it.
func _show_own_id() -> void:
	if SteamManager.online:
		$HSplitContainer/ConnectPanel/YourIdRow/YourIdField.text = str(Steam.getSteamID())

func _on_copy_id_button_pressed():
	var id_text: String = $HSplitContainer/ConnectPanel/YourIdRow/YourIdField.text
	if id_text.is_empty():
		_show_error("No Steam ID to copy. Start Steam and go online first.")
		return
	DisplayServer.clipboard_set(id_text)
	_show_error("Copied your Steam ID: " + id_text, Color(0.5, 1.0, 0.5))

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
	NetworkSync.reset_session()
	NetworkSync.peer_steam_ids[1] = Steam.getSteamID()
	NetworkSync.peer_names[1] = NetworkSync.account_name()
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
	_show_error("Joining %s ..." % host_steam_id, Color(0.8, 0.85, 1.0), 0.0)

	await get_tree().create_timer(JOIN_TIMEOUT).timeout
	if is_instance_valid(self) and _joining:
		_fail_join("Join timed out. The host did not answer.")

func _on_connected_to_server():
	_joining = false
	NetworkSync.report_player_name.rpc_id(1, NetworkSync.account_name())
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _on_back_pressed() -> void:
	get_parent().hide()
	queue_free()
