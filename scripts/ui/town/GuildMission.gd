extends Control

@onready var member_list: ItemList = $HSplitContainer/MemberListPanel/MemberList

var current_mission_id: int = -1

func set_members(mission_id: int, members: Array) -> void:
	current_mission_id = mission_id
	member_list.clear()
	for peer_id in members:
		var player_name: String = NetworkSync.peer_names.get(peer_id, "Player %d" % peer_id)
		member_list.add_item(player_name)

func _on_start_button_pressed() -> void:
	if multiplayer.is_server():
		NetworkSync._start_mission(current_mission_id)
	else:
		NetworkSync.report_start_mission.rpc_id(1, current_mission_id)

func _on_back_button_pressed() -> void:
	get_tree().current_scene.get_node_or_null("PanelMission").hide()
	get_tree().current_scene.get_node_or_null("PanelGuild").show()

func _on_leave_button_pressed() -> void:
	if multiplayer.is_server():
		NetworkSync._leave_mission(1, current_mission_id)
	else:
		NetworkSync.report_leave_mission.rpc_id(1, current_mission_id)
	get_tree().current_scene.get_node_or_null("PanelMission").hide()
	get_tree().current_scene.get_node_or_null("PanelGuild").show()
