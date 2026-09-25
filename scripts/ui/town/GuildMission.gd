extends Control

@onready var member_list: ItemList = $HSplitContainer/MemberListPanel/MemberList
@onready var location_option: OptionButton = $HSplitContainer/ActionPanel/LocationOption
@onready var start_button: Button = $HSplitContainer/ActionPanel/StartButton
@onready var ready_button: Button = $HSplitContainer/ActionPanel/ReadyButton
@onready var back_button: Button = $HSplitContainer/ActionPanel/BackButton
@onready var leave_button: Button = $HSplitContainer/ActionPanel/LeaveButton

const RANDOM_LOCATION := ""

var current_mission_id: int = -1
var current_creator_id: int = -1
var _is_ready: bool = false

func _ready() -> void:
	back_button.visible = not NetworkSync.is_dedicated
	leave_button.visible = NetworkSync.is_dedicated
	location_option.clear()
	location_option.add_item("Random")
	location_option.set_item_metadata(0, RANDOM_LOCATION)
	for location in DungeonAssembler.list_biomes():
		location_option.add_item(location.capitalize())
		location_option.set_item_metadata(location_option.item_count - 1, location)

func _select_location_option(location: String) -> void:
	for i in location_option.item_count:
		if location_option.get_item_metadata(i) == location:
			location_option.select(i)
			return

func _on_location_option_item_selected(index: int) -> void:
	var location: String = location_option.get_item_metadata(index)
	NetworkSync.ask_host(NetworkSync.report_set_location, [current_mission_id, location])

func set_members(mission_id: int, members: Array, ready_states: Dictionary, creator_id: int, location: String) -> void:
	current_mission_id = mission_id
	current_creator_id = creator_id
	var am_creator := multiplayer.get_unique_id() == creator_id
	start_button.visible = am_creator
	ready_button.visible = not am_creator
	location_option.disabled = not am_creator
	_select_location_option(location)
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
	NetworkSync.ask_host(NetworkSync.report_start_mission, [current_mission_id])

func _on_ready_button_pressed() -> void:
	_is_ready = not _is_ready
	ready_button.text = "Unready" if _is_ready else "Ready"
	NetworkSync.ask_host(NetworkSync.report_set_ready, [current_mission_id, _is_ready])

func _on_back_button_pressed() -> void:
	if multiplayer.get_unique_id() == current_creator_id:
		NetworkSync.ask_host(NetworkSync.report_cancel_countdown, [current_mission_id])
	get_tree().current_scene.get_node_or_null("PanelMission").hide()
	if not NetworkSync.is_dedicated:
		get_tree().current_scene.get_node_or_null("PanelMain").show()
	else:
		get_tree().current_scene.get_node_or_null("PanelGuild").show()

func _on_leave_button_pressed() -> void:
	NetworkSync.ask_host(NetworkSync.report_leave_mission, [current_mission_id])
	get_tree().current_scene.get_node_or_null("PanelMission").hide()
	get_tree().current_scene.get_node_or_null("PanelGuild").show()
