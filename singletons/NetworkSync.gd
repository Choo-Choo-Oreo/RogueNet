extends Node

# Temporary local test flag — flip by hand to simulate a dedicated host
# (no local player) without an actual dedicated-server build. Remove once
# real headless support exists.
var is_dedicated: bool = false

var peer_steam_ids: Dictionary = {}

var dungeon_seed: int = 0
var dungeon_biome: String = ""

# The peers in the mission that was started, known to every diver (the start message carries it).
# PlayerSpawner spawns just these, and positions and End Mission only go to them.
var dive_members: Array = []

func _ready() -> void:
	GameTick.tick_ended.connect(_send_minion_batch)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(func(id):
		if not is_host():
			return
		var left_name: String = peer_names.get(id, "")
		peer_steam_ids.erase(id)
		peer_names.erase(id)
		if left_name != "":
			_announce("%s left the game." % left_name)
		for peer_id in multiplayer.get_peers():
			receive_steam_ids.rpc_id(peer_id, peer_steam_ids)
			receive_player_names.rpc_id(peer_id, peer_names)
		# A dropped player leaves their missions the same way an explicit Leave does.
		for mission_id in missions.keys():
			if id in missions[mission_id]["members"]:
				_leave_mission(id, mission_id)
		var main_town := get_tree().current_scene
		if main_town and main_town.has_method("refresh_player_list"):
			main_town.refresh_player_list()
	)

## True in real multiplayer (hosting or joined). Singleplayer runs on an OfflineMultiplayerPeer,
## which does not count. The one check for "offline-only" things (debug tools, GameTick.speed).
func is_online() -> bool:
	if not is_inside_tree():  # a -s sim script can ask before autoloads join the tree
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and not peer is OfflineMultiplayerPeer

## True on the machine that decides: the host, or singleplayer (no peer, or the offline one).
func is_host() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()

## Runs one of this node's report_*/request_* rpcs on the host: straight away when this
## machine is the host, otherwise sent to it. The rpc finds who asked with _sender().
func ask_host(action: Callable, args: Array = []) -> void:
	if is_host():
		action.callv(args)
	else:
		callv("rpc_id", [1, action.get_method()] + args)

## Inside a report_*/request_* rpc: the peer that asked. 1 (the host) when ask_host ran it here.
func _sender() -> int:
	var id := multiplayer.get_remote_sender_id() if multiplayer.multiplayer_peer != null else 0
	return id if id != 0 else 1

## The name other players see: the Steam account's, never the character's (characters are
## swapped freely, the player stays the same). "Player" without Steam.
func account_name() -> String:
	return Steam.getPersonaName() if SteamManager.online else "Player"

## The node at `path` under the current scene ("Minions", "Player/3"), or null: none there, or
## no scene for a moment while the scene changes (packets keep arriving then).
func _in_scene(path: String) -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null(path) if scene != null else null

func _player(peer_id: int) -> Node:
	return _in_scene("Player/%d" % peer_id)

func _minion(minion_id: int) -> Node:
	return _in_scene("Minions/%d" % minion_id)

## Calls `method` on each spawned player in `by_peer` with that peer's value.
func _apply_to_players(by_peer: Dictionary, method: String) -> void:
	for peer_id in by_peer:
		var player := _player(peer_id)
		if player and player.has_method(method):
			player.call(method, by_peer[peer_id])

func reset_session() -> void:
	missions.clear()
	_countdowns.clear()
	dive_members.clear()
	peer_steam_ids.clear()
	peer_names.clear()
	peer_equipment.clear()
	dungeon_seed = 0
	dungeon_biome = ""

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

const MAX_CHAT_LENGTH := 200

# Chat goes through the host, which stamps the sender's name and sends the line to everyone.
func send_chat(text: String) -> void:
	ask_host(report_chat, [text])

@rpc("any_peer", "reliable")
func report_chat(text: String) -> void:
	if not is_host():
		return
	_broadcast_chat(_sender(), text)

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

# Same chat pipe as _broadcast_chat, but for system lines (mission countdown) that aren't from a player.
func _announce(text: String) -> void:
	receive_chat(text)
	for peer_id in multiplayer.get_peers():
		receive_chat.rpc_id(peer_id, text)

@rpc("authority", "reliable")
func receive_steam_ids(ids: Dictionary) -> void:
	peer_steam_ids = ids

@rpc("any_peer", "unreliable_ordered")
func report_position(pos: Vector2) -> void:
	if not is_host():
		return
	var sender_id := _sender()
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
	var player := _player(player_id)
	if player:
		player.grid_mover.follow_network(pos)

var missions: Dictionary = {}

const SHARED_MISSION_ID := 0

@rpc("any_peer", "reliable")
func report_join_shared_party() -> void:
	if not is_host():
		return
	_join_shared_party(_sender())

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
	if not is_host():
		return
	_create_mission(_sender(), privacy, password)

func _create_mission(creator_id: int, privacy: String, password: String) -> void:
	var mission_id := creator_id
	missions[mission_id] = {"creator_id": creator_id, "privacy": privacy, "password": password, "members": [creator_id], "location": ""}
	receive_mission_created(mission_id, creator_id, privacy)
	for peer_id in multiplayer.get_peers():
		receive_mission_created.rpc_id(peer_id, mission_id, creator_id, privacy)
	_broadcast_members(mission_id)
var peer_names: Dictionary = {}

@rpc("any_peer", "reliable")
func report_player_name(player_name: String) -> void:
	if not is_host():
		return
	var sender_id := _sender()
	var is_new := not peer_names.has(sender_id)
	peer_names[sender_id] = player_name
	if is_new:
		_announce("%s joined the game." % player_name)
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

# peer_id -> skin id (only "human" today): the look each player's adventurer shows in the dungeon.
var peer_skins: Dictionary = {}

@rpc("any_peer", "reliable")
func report_skin(skin_id: String) -> void:
	if not is_host():
		return
	_set_skin(_sender(), skin_id)

func _set_skin(peer_id: int, skin_id: String) -> void:
	peer_skins[peer_id] = skin_id
	for other_id in multiplayer.get_peers():
		receive_skins.rpc_id(other_id, peer_skins)
	receive_skins(peer_skins)

@rpc("authority", "reliable")
func receive_skins(skins: Dictionary) -> void:
	peer_skins = skins
	_apply_to_players(peer_skins, "set_skin")

# peer_id -> {slot: item id}, the gear each player wears (see PlayerInventory.worn()).
# Same "tell the host, host tells everyone" route as peer_skins above.
var peer_equipment: Dictionary = {}

## Called by PlayerInventory whenever this machine's player changes what they wear.
func share_equipment(worn: Dictionary) -> void:
	ask_host(report_player_equipment, [worn])

@rpc("any_peer", "reliable")
func report_player_equipment(worn: Dictionary) -> void:
	if not is_host():
		return
	_set_equipment(_sender(), worn)

func _set_equipment(peer_id: int, worn: Dictionary) -> void:
	# Only item ids for the slot they claim, so a bad message can't put a sword on someone's head.
	var clean := {}
	for slot in worn:
		var item_id = worn[slot]
		if item_id is String and ItemDatabase.item_slot(item_id) == slot:
			clean[slot] = item_id
	peer_equipment[peer_id] = clean
	for other_id in multiplayer.get_peers():
		receive_player_equipment.rpc_id(other_id, peer_equipment)
	receive_player_equipment(peer_equipment)

@rpc("authority", "reliable")
func receive_player_equipment(equipment: Dictionary) -> void:
	peer_equipment = equipment
	_apply_to_players(peer_equipment, "set_equipment")

@rpc("any_peer", "reliable")
func report_join_mission(mission_id: int, password: String) -> void:
	if not is_host():
		return
	_join_mission(_sender(), mission_id, password)

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
		if peer_id != mission["creator_id"]:
			var ready_map: Dictionary = mission.get("ready", {})
			ready_map[peer_id] = false
			mission["ready"] = ready_map
		_cancel_countdown(mission_id, PARTY_CHANGED)
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
	if not is_host():
		return
	_start_mission(_sender(), mission_id)

const MISSION_COUNTDOWN_SECONDS := 10
const MISSION_COUNTDOWN_READY_SKIP := 3
const PARTY_CHANGED := "Countdown cancelled — the party changed."

# mission_id -> {"remaining": int, "accum": float}, server-side only.
var _countdowns: Dictionary = {}

func _start_mission(peer_id: int, mission_id: int) -> void:
	if not missions.has(mission_id):
		return
	if peer_id != missions[mission_id]["creator_id"]:
		return
	if _countdowns.has(mission_id):
		return
	# Nobody's waiting on anybody — solo dives count too, since there are no non-creator
	# members to be un-ready, so this also covers the singleplayer/solo-host case.
	if _all_non_creators_ready(mission_id):
		_launch_mission(mission_id)
		return
	_countdowns[mission_id] = {"remaining": MISSION_COUNTDOWN_SECONDS, "accum": 0.0}
	_announce("Mission starting in %d..." % MISSION_COUNTDOWN_SECONDS)

func _process(delta: float) -> void:
	# Check _countdowns first: multiplayer.is_server() logs an engine error if called with
	# no peer assigned (eg. after backing out to the main menu), and _process always runs.
	if _countdowns.is_empty() or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	for mission_id in _countdowns.keys():
		var countdown: Dictionary = _countdowns[mission_id]
		countdown["accum"] += delta
		if countdown["accum"] < 1.0:
			continue
		countdown["accum"] -= 1.0
		countdown["remaining"] -= 1
		if countdown["remaining"] <= 0:
			_countdowns.erase(mission_id)
			_launch_mission(mission_id)
		else:
			_announce("Mission starting in %d..." % countdown["remaining"])

func _cancel_countdown(mission_id: int, reason: String = "") -> void:
	if not _countdowns.erase(mission_id):
		return
	if reason != "":
		_announce(reason)

func _all_non_creators_ready(mission_id: int) -> bool:
	var mission: Dictionary = missions[mission_id]
	var ready_map: Dictionary = mission.get("ready", {})
	for member_id in mission["members"]:
		if member_id == mission["creator_id"]:
			continue
		if not ready_map.get(member_id, false):
			return false
	return true

@rpc("any_peer", "reliable")
func report_set_ready(mission_id: int, is_ready: bool) -> void:
	if not is_host():
		return
	_set_ready(_sender(), mission_id, is_ready)

func _set_ready(peer_id: int, mission_id: int, is_ready: bool) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	if peer_id == mission["creator_id"]:
		return
	var ready_map: Dictionary = mission.get("ready", {})
	ready_map[peer_id] = is_ready
	mission["ready"] = ready_map
	_broadcast_members(mission_id)
	if not _countdowns.has(mission_id) or not _all_non_creators_ready(mission_id):
		return
	var countdown: Dictionary = _countdowns[mission_id]
	if countdown["remaining"] > MISSION_COUNTDOWN_READY_SKIP:
		countdown["remaining"] = MISSION_COUNTDOWN_READY_SKIP
		_announce("Everyone's ready — mission starting in %d..." % MISSION_COUNTDOWN_READY_SKIP)

@rpc("any_peer", "reliable")
func report_cancel_countdown(mission_id: int) -> void:
	if not is_host():
		return
	var sender_id := _sender()
	if not missions.has(mission_id) or sender_id != missions[mission_id]["creator_id"]:
		return
	_cancel_countdown(mission_id, "Mission start cancelled.")

func _launch_mission(mission_id: int) -> void:
	if not missions.has(mission_id):
		return
	var members: Array = missions[mission_id]["members"]
	var mission_seed := randi()
	# Picked once, here, by the host — every diver gets told the result instead of
	# each independently re-picking from their own local game/rooms/ folder list,
	# which desyncs the moment one machine's folder set differs from another's.
	var chosen_location: String = missions[mission_id].get("location", "")
	var mission_biome := chosen_location if chosen_location != "" else DungeonAssembler.pick_biome(mission_seed)
	missions[mission_id]["started"] = true
	for member_id in members:
		if member_id == 1:
			receive_start_mission(mission_seed, mission_biome, members)
		else:
			receive_start_mission.rpc_id(member_id, mission_seed, mission_biome, members)

@rpc("authority", "reliable")
func receive_start_mission(mission_seed: int, mission_biome: String, members: Array) -> void:
	dungeon_seed = mission_seed
	dungeon_biome = mission_biome
	dive_members = members.duplicate()
	get_tree().change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

# Host only: sends the divers (not the players in the town) back to the town.
func end_mission() -> void:
	if not is_host():
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

# --- Minions: host decides identity/position and tells everyone else,
# same "one decider, everyone else is told" split as the dungeon seed above.

func broadcast_minion_spawns(spawns: Array) -> void:
	if spawns.is_empty():
		return
	for peer_id in multiplayer.get_peers():
		receive_spawn_minions.rpc_id(peer_id, spawns)

@rpc("authority", "reliable")
func receive_spawn_minions(spawns: Array) -> void:
	var minions_root := _in_scene("Minions")
	if minions_root == null:
		return
	for spawn in spawns:
		if minions_root.has_node(str(spawn["id"])):
			continue
		MinionSpawning.spawn_one(spawn["id"], spawn["type"], spawn["tile"], minions_root)

# Host relays every frame it moves an owned minion (unreliable, same as player
# position) -- clients never run minion AI at all, they only ever render
# whatever the host last told them.
# Host only: the minions whose position or state changed this tick, sent together when the
# tick ends (GameTick.tick_ended) instead of one message per minion. Split into messages of
# MINION_BATCH_SIZE so each stays around one network packet (13 bytes a minion).
const MINION_BATCH_SIZE := 64
var _batch_ids := PackedInt32Array()
var _batch_positions := PackedVector2Array()
var _batch_states := PackedByteArray()

func relay_minion_state(minion_id: int, pos: Vector2, state: int) -> void:
	if multiplayer.get_peers().is_empty():
		return
	_batch_ids.append(minion_id)
	_batch_positions.append(pos)
	_batch_states.append(state)

func _send_minion_batch(_tick: int) -> void:
	if _batch_ids.is_empty():
		return
	for start in range(0, _batch_ids.size(), MINION_BATCH_SIZE):
		var end := mini(start + MINION_BATCH_SIZE, _batch_ids.size())
		var ids := _batch_ids.slice(start, end)
		var positions := _batch_positions.slice(start, end)
		var states := _batch_states.slice(start, end)
		for peer_id in multiplayer.get_peers():
			receive_minion_states.rpc_id(peer_id, ids, positions, states)
	_batch_ids.clear()
	_batch_positions.clear()
	_batch_states.clear()

@rpc("authority", "unreliable_ordered")
func receive_minion_states(ids: PackedInt32Array, positions: PackedVector2Array, states: PackedByteArray) -> void:
	var minions := _in_scene("Minions")
	if minions == null:
		return
	for i in ids.size():
		var minion := minions.get_node_or_null(str(ids[i]))
		if minion and minion.has_method("receive_network_state"):
			minion.receive_network_state(positions[i], states[i])

# A client's attack reports the hit to the host (only the host may ever
# actually apply it); the host itself applies straight away. Either path
# lands on _resolve_minion_hit, which applies once and relays the same
# amount/type to every peer so each one's own EntityStats independently
# reaches the same health and fires its own died signal -- no separate
# despawn message needed, every peer just queue_frees itself once its own
# copy hits 0.
func report_minion_hit(minion_id: int, amount: int, type: String) -> void:
	ask_host(request_minion_hit, [minion_id, amount, type])

@rpc("any_peer", "reliable")
func request_minion_hit(minion_id: int, amount: int, type: String) -> void:
	if not is_host():
		return
	_resolve_minion_hit(minion_id, amount, type)

func _resolve_minion_hit(minion_id: int, amount: int, type: String) -> void:
	receive_minion_damage(minion_id, amount, type)
	for peer_id in multiplayer.get_peers():
		receive_minion_damage.rpc_id(peer_id, minion_id, amount, type)

@rpc("authority", "reliable")
func receive_minion_damage(minion_id: int, amount: int, type: String) -> void:
	var minion := _minion(minion_id)
	if minion and minion.has_method("take_damage"):
		minion.take_damage(amount, type)

# Doors. Open/closed state is host-authoritative: anyone who bumps a door (a
# player, or a minion on the host) calls open_door; a client asks the host, the
# host applies it and tells everybody. Closing is the host's own timer
# (DoorManager) through set_door. Door ids are positions in DoorRegistry.doors,
# identical on every peer because the dungeon is built from the same seed.
var _door_asked_msec := {}
const DOOR_ASK_COOLDOWN_MSEC := 300

func open_door(id: int) -> void:
	# A held movement key bumps the door every physics tick until the answer
	# comes back, so don't ask more than once per cooldown (game time, so a sped-up game asks
	# as often per game second as a real one).
	var now := GameTick.msec()
	if now - _door_asked_msec.get(id, -DOOR_ASK_COOLDOWN_MSEC) < DOOR_ASK_COOLDOWN_MSEC:
		return
	_door_asked_msec[id] = now
	ask_host(request_door_open, [id])

@rpc("any_peer", "reliable")
func request_door_open(id: int) -> void:
	if is_host():
		set_door(id, true)

## Host / singleplayer: apply a door state and tell every other peer.
func set_door(id: int, open: bool) -> void:
	if not DoorRegistry.set_open(id, open):
		return
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		receive_door_state.rpc(id, open)

@rpc("authority", "reliable")
func receive_door_state(id: int, open: bool) -> void:
	DoorRegistry.set_open(id, open)

# Debug menu (DebugMenu.gd). God mode is a flag on the player node that every peer
# has to agree on (damage is applied on every peer), so it is copied like a
# state change: a client asks the host, the host applies it and tells the rest.
func set_god_mode(on: bool) -> void:
	var my_id := multiplayer.get_unique_id()
	_apply_god_mode(my_id, on)
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		receive_god_mode.rpc(my_id, on)
	else:
		report_god_mode.rpc_id(1, on)

@rpc("any_peer", "reliable")
func report_god_mode(on: bool) -> void:
	if not is_host():
		return
	var sender := _sender()
	_apply_god_mode(sender, on)
	receive_god_mode.rpc(sender, on)

@rpc("authority", "reliable")
func receive_god_mode(player_id: int, on: bool) -> void:
	_apply_god_mode(player_id, on)

func _apply_god_mode(player_id: int, on: bool) -> void:
	var player := _player(player_id)
	if player != null and "debug_god" in player:
		player.debug_god = on

## Minions are host-owned, so a client asks the host to place one.
func debug_spawn_minion(minion_id: String, tile: Vector2i) -> void:
	ask_host(request_debug_spawn, [minion_id, tile])

@rpc("any_peer", "reliable")
func request_debug_spawn(minion_id: String, tile: Vector2i) -> void:
	if is_host():
		_host_debug_spawn(minion_id, tile)

func _host_debug_spawn(minion_id: String, tile: Vector2i) -> void:
	var minions_root := _in_scene("Minions")
	if minions_root != null:
		MinionSpawning.spawn_debug(minion_id, tile, minions_root)

## Opening works from anywhere (every door asks the host); closing is host only.
func debug_all_doors(open: bool) -> void:
	if open:
		for door: DoorRegistry.Door in DoorRegistry.doors:
			if not door.is_open:
				ask_host(request_door_open, [door.id])
	elif is_host():
		for door: DoorRegistry.Door in DoorRegistry.doors:
			set_door(door.id, false)

# Cosmetic effects (sword swings, bites, arrows, magic) are only ever drawn by
# whoever's attack it is, so every one goes through play_effect / play_projectile:
# it plays locally, then tells everyone else to play the same thing. A client's
# effect goes to the host first (clients only talk to the host), which plays it,
# then forwards it to every other peer. The sender is never sent its own copy.
const ATTACK_EFFECT_SCENE := preload("res://scenes/entities/AttackEffect.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/ProjectileController.tscn")

func play_effect(pos: Vector2, data: Dictionary, direction: Vector2) -> void:
	_spawn_effect(pos, data, direction)
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_forward_effect(pos, data, direction, 1)
	else:
		request_effect.rpc_id(1, pos, data, direction)

func _spawn_effect(pos: Vector2, data: Dictionary, direction: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	CombatSounds.on_effect(scene, pos, data)
	if not data.has("texture"):
		return  # a sound with no picture (AttackEffect.play_attack)
	var effect: AttackEffect = ATTACK_EFFECT_SCENE.instantiate()
	scene.add_child(effect)
	effect.global_position = pos
	effect.play(data, direction)

func _forward_effect(pos: Vector2, data: Dictionary, direction: Vector2, skip_id: int) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id != skip_id:
			receive_effect.rpc_id(peer_id, pos, data, direction)

@rpc("any_peer", "unreliable")
func request_effect(pos: Vector2, data: Dictionary, direction: Vector2) -> void:
	if not is_host():
		return
	_spawn_effect(pos, data, direction)
	_forward_effect(pos, data, direction, _sender())

@rpc("authority", "unreliable")
func receive_effect(pos: Vector2, data: Dictionary, direction: Vector2) -> void:
	_spawn_effect(pos, data, direction)

## Visual-only copy of a projectile on every other peer -- the shooter's own
## projectile is the one whose arrival applies damage and plays the hit effect
## (which is shared separately), so the copy just flies and vanishes.
func share_projectile(texture_path: String, from: Vector2, to: Vector2) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_forward_projectile(texture_path, from, to, 1)
	else:
		request_projectile.rpc_id(1, texture_path, from, to)

func _forward_projectile(texture_path: String, from: Vector2, to: Vector2, skip_id: int) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id != skip_id:
			receive_projectile.rpc_id(peer_id, texture_path, from, to)

@rpc("any_peer", "unreliable")
func request_projectile(texture_path: String, from: Vector2, to: Vector2) -> void:
	if not is_host():
		return
	_spawn_projectile_copy(texture_path, from, to)
	_forward_projectile(texture_path, from, to, _sender())

@rpc("authority", "unreliable")
func receive_projectile(texture_path: String, from: Vector2, to: Vector2) -> void:
	_spawn_projectile_copy(texture_path, from, to)

func _spawn_projectile_copy(texture_path: String, from: Vector2, to: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var projectile: ProjectileController = PROJECTILE_SCENE.instantiate()
	scene.add_child(projectile)
	projectile.global_position = from
	# Stops at walls like the real one, using whichever local player's map check.
	var blocked := func(_pos: Vector2) -> bool: return false
	var local_player := PlayerLookup.find_local(get_tree())
	if local_player != null and local_player.get("grid_mover") != null:
		blocked = local_player.grid_mover.is_position_blocked
	projectile.launch(texture_path, to, 16.0, func(): pass, blocked)

# Taunt ("Rawr", hotbar slot 4): minion AI only runs on the host, so a client's
# cast is just a request to the host, which forces the nearest minions in
# radius onto the caster. Clients need no reply -- they never run minion AI.
func report_taunt(player_id: int, radius_tiles: float, duration: float, max_targets: int) -> void:
	ask_host(request_taunt, [player_id, radius_tiles, duration, max_targets])

@rpc("any_peer", "reliable")
func request_taunt(player_id: int, radius_tiles: float, duration: float, max_targets: int) -> void:
	if not is_host():
		return
	_resolve_taunt(player_id, radius_tiles, duration, max_targets)

func _resolve_taunt(player_id: int, radius_tiles: float, duration: float, max_targets: int) -> void:
	var player := _player(player_id)
	if player == null or player.stats.is_ghost:
		return
	var radius_px := radius_tiles * 16.0
	var in_range: Array = []
	for minion in get_tree().get_nodes_in_group("antagonist"):
		var dist: float = minion.global_position.distance_to(player.global_position)
		if dist <= radius_px and minion.has_method("force_target"):
			in_range.append([dist, minion])
	# Nearest first, capped so one cast can't yank hundreds of minions at once.
	in_range.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(in_range.size(), max_targets):
		in_range[i][1].force_target(player, duration)

# Noise (footsteps, a landing rock): like a taunt, minion AI only runs on the host, so a
# client's noise is a request to it. Sound.make tells every minion that can hear the spot.
func report_noise(position: Vector2, db: float) -> void:
	ask_host(request_noise, [position, db])

@rpc("any_peer", "unreliable")
func request_noise(position: Vector2, db: float) -> void:
	if is_host():
		Sound.make(get_tree(), position, db)

# Minion-on-player damage only ever originates on the host (only the host ever
# runs minion AI/attacks), so this is a straight broadcast, no any_peer report
# step needed the way minion hits have one.
func relay_player_hit(player_id: int, amount: int, type: String) -> void:
	receive_player_damage(player_id, amount, type)
	for peer_id in multiplayer.get_peers():
		receive_player_damage.rpc_id(peer_id, player_id, amount, type)

@rpc("authority", "reliable")
func receive_player_damage(player_id: int, amount: int, type: String) -> void:
	var player := _player(player_id)
	if player and player.has_method("take_damage"):
		player.take_damage(amount, type)

## Host only (an ability the host's AI fires, see MinionController._ability_destroy_tiles).
## Breaks the walls among `cells`: the host decides which fall and what shows under and
## around them (TileDestruction.plan), then every peer applies that same list -- no peer
## rolls its own dice, so the maps cannot drift apart. Returns how many cells changed
## (0 = nothing there was breakable, nothing was sent). A peer that joins later does not
## get earlier changes, the same as doors.
func destroy_tiles(cells: Array[Vector2i]) -> int:
	if not is_host():
		return 0
	var changes := TileDestruction.plan(cells, get_tree().current_scene)
	if changes.is_empty():
		return 0
	receive_tile_changes(changes)
	for peer_id in multiplayer.get_peers():
		receive_tile_changes.rpc_id(peer_id, changes)
	return changes.size()

@rpc("authority", "reliable")
func receive_tile_changes(changes: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null:
		TileDestruction.apply(changes, scene)

func _broadcast_members(mission_id: int) -> void:
	var mission: Dictionary = missions[mission_id]
	var members: Array = mission["members"]
	var ready_states: Dictionary = mission.get("ready", {})
	var creator_id: int = mission["creator_id"]
	var location: String = mission.get("location", "")
	for peer_id in members:
		if peer_id == 1:
			receive_mission_members(mission_id, members, ready_states, creator_id, location)
		else:
			receive_mission_members.rpc_id(peer_id, mission_id, members, ready_states, creator_id, location)

@rpc("authority", "reliable")
func receive_mission_members(mission_id: int, members: Array, ready_states: Dictionary, creator_id: int, location: String) -> void:
	var main_town := get_tree().current_scene
	# Not in the town (for example already in the dungeon): nothing to update.
	if main_town == null or main_town.get_node_or_null("PanelMission") == null:
		return
	var mission_screen := main_town.get_node_or_null("PanelMission/GuildMission")
	if mission_screen:
		mission_screen.set_members(mission_id, members, ready_states, creator_id, location)
	main_town.get_node_or_null("PanelMain").hide()
	main_town.get_node_or_null("PanelGuild").hide()
	main_town.get_node_or_null("PanelMission").show()

@rpc("any_peer", "reliable")
func report_leave_mission(mission_id: int) -> void:
	if not is_host():
		return
	_leave_mission(_sender(), mission_id)

func _leave_mission(peer_id: int, mission_id: int) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	if peer_id == mission["creator_id"]:
		_end_mission(mission_id)
		return
	var members: Array = mission["members"]
	members.erase(peer_id)
	mission.get("ready", {}).erase(peer_id)
	_cancel_countdown(mission_id, PARTY_CHANGED)
	_broadcast_members(mission_id)

@rpc("any_peer", "reliable")
func report_set_location(mission_id: int, location: String) -> void:
	if not is_host():
		return
	_set_location(_sender(), mission_id, location)

func _set_location(peer_id: int, mission_id: int, location: String) -> void:
	if not missions.has(mission_id):
		return
	var mission: Dictionary = missions[mission_id]
	if peer_id != mission["creator_id"]:
		return
	# "" means Random; anything else must be a real folder under game/rooms/.
	if location != "" and not DungeonAssembler.list_biomes().has(location):
		return
	mission["location"] = location
	_broadcast_members(mission_id)

func _end_mission(mission_id: int) -> void:
	_countdowns.erase(mission_id)
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
