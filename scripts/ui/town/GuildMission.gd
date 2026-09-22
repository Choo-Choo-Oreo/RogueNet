extends Control

@onready var member_list: ItemList = $HSplitContainer/MemberListPanel/MemberList
@onready var start_button: Button = $HSplitContainer/ActionPanel/StartButton
@onready var ready_button: Button = $HSplitContainer/ActionPanel/ReadyButton
@onready var back_button: Button = $HSplitContainer/ActionPanel/BackButton
@onready var leave_button: Button = $HSplitContainer/ActionPanel/LeaveButton

var current_mission_id: int = -1
var current_creator_id: int = -1
var _is_ready: bool = false

func _ready() -> void:
	back_button.visible = not NetworkSync.is_dedicated
	leave_button.visible = NetworkSync.is_dedicated

func set_members(mission_id: int, members: Array, ready_states: Dictionary, creator_id: int) -> void:
	current_mission_id = mission_id
	current_creator_id = creator_id
	var am_creator := multiplayer.get_unique_id() == creator_id
	start_button.visible = am_creator
	ready_button.visible = not am_creator
	member_list.clear()
	for peer_id in members:
		var player_name: String = NetworkSync.peer_names.get(peer_id, "Player %d" % peer_id)
		if peer_id == creator_id:
			player_name += " (Leader)"
		elif ready_states.get(peer_id, false):
			player_name += " (Ready)"
		member_list.add_item(player_name)
	if not am_creator:
		_is_ready = ready_states.get(multiplayer.get_unique_id(), false)
		ready_button.text = "Unready" if _is_ready else "Ready"

func _on_start_button_pressed() -> void:
	if multiplayer.is_server():
		NetworkSync._start_mission(1, current_mission_id)
	else:
		NetworkSync.report_start_mission.rpc_id(1, current_mission_id)

func _on_ready_button_pressed() -> void:
	_is_ready = not _is_ready
	ready_button.text = "Unready" if _is_ready else "Ready"
	if multiplayer.is_server():
		NetworkSync._set_ready(1, current_mission_id, _is_ready)
	else:
		NetworkSync.report_set_ready.rpc_id(1, current_mission_id, _is_ready)

func _on_back_button_pressed() -> void:
	if multiplayer.get_unique_id() == current_creator_id:
		if multiplayer.is_server():
			NetworkSync._cancel_countdown(current_mission_id, "Mission start cancelled.")
		else:
			NetworkSync.report_cancel_countdown.rpc_id(1, current_mission_id)
	get_tree().current_scene.get_node_or_null("PanelMission").hide()
	if not NetworkSync.is_dedicated:
		get_tree().current_scene.get_node_or_null("PanelMain").show()
	else:
		get_tree().current_scene.get_node_or_null("PanelGuild").show()

func _on_leave_button_pressed() -> void:
	if multiplayer.is_server():
		NetworkSync._leave_mission(1, current_mission_id)
	else:
		NetworkSync.report_leave_mission.rpc_id(1, current_mission_id)
	get_tree().current_scene.get_node_or_null("PanelMission").hide()
	get_tree().current_scene.get_node_or_null("PanelGuild").show()
