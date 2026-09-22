extends Node

enum SessionMode { SINGLEPLAYER, HOST, CLIENT }
var session_mode: SessionMode = SessionMode.SINGLEPLAYER

# Temporary local test flag — flip by hand to simulate a dedicated host
# (no local player) without an actual dedicated-server build. Remove once
# real headless support exists.
var is_dedicated: bool = false

var peer_steam_ids: Dictionary = {}

var dungeon_seed: int = 0

# The peers in the mission that was started, known to every diver (the start message carries it).
# PlayerSpawner spawns just these, and positions and End Mission only go to them.
var dive_members: Array = []

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(func(id):
		if not multiplayer.is_server():
			return
		peer_steam_ids.erase(id)
		peer_names.erase(id)
		for peer_id in multiplayer.get_peers():
			receive_steam_ids.rpc_id(peer_id, peer_steam_ids)
			receive_player_names.rpc_id(peer_id, peer_names)
		var main_town := get_tree().current_scene
		if main_town and main_town.has_method("refresh_player_list"):
			main_town.refresh_player_list()
	)

func reset_session() -> void:
	missions.clear()
	dive_members.clear()
	peer_steam_ids.clear()
	peer_names.clear()
	dungeon_seed = 0

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

const MAX_CHAT_LENGTH := 200

# Chat goes through the host, which stamps the sender's name and sends the line to everyone.
func send_chat(text: String) -> void:
	if multiplayer.is_server():
		_broadcast_chat(1, text)
	else:
		report_chat.rpc_id(1, text)

@rpc("any_peer", "reliable")
func report_chat(text: String) -> void:
	if not multiplayer.is_server():
		return
	_broadcast_chat(multiplayer.get_remote_sender_id(), text)

func _broadcast_chat(sender_id: int, text: String) -> void:
	var line := "%s: %s" % [peer_names.get(sender_id, str(sender_id)), text.substr(0, MAX_CHAT_LENGTH)]
	receive_chat(line)
	for peer_id in multiplayer.get_peers():
		receive_chat.rpc_id(peer_id, line)

@rpc("authority", "reliable")
func receive_chat(line: String) -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("add_chat_line"):
		scene.add_chat_line(line)

@rpc("authority", "reliable")
func receive_steam_ids(ids: Dictionary) -> void:
	peer_steam_ids = ids

@rpc("any_peer", "unreliable_ordered")
func report_position(pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	receive_position(sender_id, pos)
	_relay_position(sender_id, pos)

func _relay_position(sender_id: int, pos: Vector2) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id == sender_id:
			continue
		# Players still in the town have no dungeon to move anyone in.
		if not dive_members.is_empty() and peer_id not in dive_members:
			continue
		receive_position.rpc_id(peer_id, sender_id, pos)

@rpc("authority", "unreliable_ordered")
func receive_position(player_id: int, pos: Vector2) -> void:
	# current_scene is null for a moment while the scene changes, and packets keep arriving.
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player/" + str(player_id))
	if player:
		player.global_position = pos

var missions: Dictionary = {}

const SHARED_MISSION_ID := 0

@rpc("any_peer", "reliable")
func report_join_shared_party() -> void:
	if not multiplayer.is_server():
		return
	_join_shared_party(multiplayer.get_remote_sender_id())

func _join_shared_party(peer_id: int) -> void:
	if not missions.has(SHARED_MISSION_ID):
		missions[SHARED_MISSION_ID] = {"creator_id": 1, "privacy": "public", "password": "", "members": []}
		receive_mission_created(SHARED_MISSION_ID, 1, "public")
		for other_id in multiplayer.get_peers():
			receive_mission_created.rpc_id(other_id, SHARED_MISSION_ID, 1, "public")
	_join_mission(peer_id, SHARED_MISSION_ID, "")

@rpc("authority", "reliable")
func receive_mission_created(mission_id: int, creator_id: int, privacy: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guild_town := scene.get_node_or_null("PanelGuild/GuildTown")
	if guild_town:
		guild_town.add_mission(mission_id, creator_id, privacy)

@rpc("any_peer", "reliable")
func report_create_mission(privacy: String, password: String) -> void:
	if not multiplayer.is_server():
		return
	_create_mission(multiplayer.get_remote_sender_id(), privacy, password)

func _create_mission(creator_id: int, privacy: String, password: String) -> void:
	var mission_id := creator_id
	missions[mission_id] = {"creator_id": creator_id, "privacy": privacy, "password": password, "members": [creator_id]}
	receive_mission_created(mission_id, creator_id, privacy)
	for peer_id in multiplayer.get_peers():
		receive_mission_created.rpc_id(peer_id, mission_id, creator_id, privacy)
	_broadcast_members(mission_id)
var peer_names: Dictionary = {}

@rpc("any_peer", "reliable")
func report_player_name(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	peer_names[sender_id] = player_name
	for peer_id in multiplayer.get_peers():
		receive_player_names.rpc_id(peer_id, peer_names)
	receive_player_names(peer_names)
	_send_existing_missions(sender_id)

func _send_existing_missions(peer_id: int) -> void:
	for mission_id in missions:
		var mission: Dictionary = missions[mission_id]
		receive_mission_created.rpc_id(peer_id, mission_id, mission["creator_id"], mission["privacy"])

@rpc("authority", "reliable")
func receive_player_names(names: Dictionary) -> void:
	peer_names = names
	var main_town := get_tree().current_scene
	if main_town and main_town.has_method("refresh_player_list"):
		main_town.refresh_player_list()

@rpc("any_peer", "reliable")
func report_join_mission(mission_id: int, password: String) -> void:
	if not multiplayer.is_server():
		return
	_join_mission(multiplayer.get_remote_sender_id(), mission_id, password)

func _join_mission(peer_id: int, mission_id: int, password: String) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	# Joining a mission that already started would leave that player waiting in a panel for a dive
	# they are not part of, so tell them instead (through the town chat).
	if mission.get("started", false):
		var notice := "The mission has already started."
		if peer_id == 1:
			receive_chat(notice)
		else:
			receive_chat.rpc_id(peer_id, notice)
		return
	if mission["privacy"] == "password" and mission["password"] != password:
		if peer_id == 1:
			receive_join_rejected(mission_id)
		else:
			receive_join_rejected.rpc_id(peer_id, mission_id)
		print("Player %d failed to join mission %d: wrong password" % [peer_id, mission_id])
		return
	var members: Array = mission["members"]
	if peer_id not in members:
		members.append(peer_id)
	print("Player %d joined mission %d" % [peer_id, mission_id])
	_broadcast_members(mission_id)

@rpc("authority", "reliable")
func receive_join_rejected(_mission_id: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guild_town := scene.get_node_or_null("PanelGuild/GuildTown")
	if guild_town:
		guild_town.show_join_error("Incorrect password.")

@rpc("any_peer", "reliable")
func report_start_mission(mission_id: int) -> void:
	if not multiplayer.is_server():
		return
	_start_mission(multiplayer.get_remote_sender_id(), mission_id)

func _start_mission(peer_id: int, mission_id: int) -> void:
	if not missions.has(mission_id):
		return
	if peer_id != missions[mission_id]["creator_id"]:
		return
	var members: Array = missions[mission_id]["members"]
	var mission_seed := randi()
	missions[mission_id]["started"] = true
	for member_id in members:
		if member_id == 1:
			receive_start_mission(mission_seed, members)
		else:
			receive_start_mission.rpc_id(member_id, mission_seed, members)

@rpc("authority", "reliable")
func receive_start_mission(mission_seed: int, members: Array) -> void:
	dungeon_seed = mission_seed
	dive_members = members.duplicate()
	get_tree().change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

# Host only: sends the divers (not the players in the town) back to the town.
func end_mission() -> void:
	if not multiplayer.is_server():
		return
	var divers := dive_members.duplicate()
	# End each mission properly (not just clear the list) so every player's mission list and panel
	# is told, including anyone still in the town.
	for mission_id in missions.keys():
		_end_mission(mission_id)
	for peer_id in divers:
		if peer_id == 1:
			receive_return_to_town()
		else:
			receive_return_to_town.rpc_id(peer_id)

@rpc("authority", "reliable")
func receive_return_to_town() -> void:
	dive_members.clear()
	get_tree().change_scene_to_file("res://scenes/ui/town/MainTown.tscn")

func _broadcast_members(mission_id: int) -> void:
	var members: Array = missions[mission_id]["members"]
	for peer_id in members:
		if peer_id == 1:
			receive_mission_members(mission_id, members)
		else:
			receive_mission_members.rpc_id(peer_id, mission_id, members)

@rpc("authority", "reliable")
func receive_mission_members(mission_id: int, members: Array) -> void:
	var main_town := get_tree().current_scene
	# Not in the town (for example already in the dungeon): nothing to update.
	if main_town == null or main_town.get_node_or_null("PanelMission") == null:
		return
	var mission_screen := main_town.get_node_or_null("PanelMission/GuildMission")
	if mission_screen:
		mission_screen.set_members(mission_id, members)
	main_town.get_node_or_null("PanelMain").hide()
	main_town.get_node_or_null("PanelGuild").hide()
	main_town.get_node_or_null("PanelMission").show()

@rpc("any_peer", "reliable")
func report_leave_mission(mission_id: int) -> void:
	if not multiplayer.is_server():
		return
	_leave_mission(multiplayer.get_remote_sender_id(), mission_id)

func _leave_mission(peer_id: int, mission_id: int) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	if peer_id == mission["creator_id"]:
		_end_mission(mission_id)
		return
	var members: Array = mission["members"]
	members.erase(peer_id)
	_broadcast_members(mission_id)

func _end_mission(mission_id: int) -> void:
	missions.erase(mission_id)
	receive_mission_ended(mission_id)
	for peer_id in multiplayer.get_peers():
		receive_mission_ended.rpc_id(peer_id, mission_id)

@rpc("authority", "reliable")
func receive_mission_ended(mission_id: int) -> void:
	var main_town := get_tree().current_scene
	if main_town == null:
		return
	var guild_town := main_town.get_node_or_null("PanelGuild/GuildTown")
	if guild_town:
		guild_town.remove_mission(mission_id)
	var mission_screen := main_town.get_node_or_null("PanelMission/GuildMission")
	if mission_screen and mission_screen.current_mission_id == mission_id:
		main_town.get_node_or_null("PanelMission").hide()
		main_town.get_node_or_null("PanelGuild" if is_dedicated else "PanelMain").show()
