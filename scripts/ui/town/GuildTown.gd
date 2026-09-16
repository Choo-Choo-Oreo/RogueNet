extends Control

@onready var privacy_option: OptionButton = $HSplitContainer/CreatePanel/PrivacyOption
@onready var password_field: LineEdit = $HSplitContainer/CreatePanel/PasswordField
@onready var mission_list: ItemList = $HSplitContainer/MissionListPanel/MissionList
@onready var join_password_field: LineEdit = $HSplitContainer/MissionListPanel/JoinPasswordField

func _ready() -> void:
	privacy_option.add_item("Public", 0)
	privacy_option.add_item("Password", 1)

func _on_create_button_pressed() -> void:
	var privacy := "public" if privacy_option.selected == 0 else "password"
	if multiplayer.is_server():
		NetworkSync._create_mission(1, privacy, password_field.text)
	else:
		NetworkSync.report_create_mission.rpc_id(1, privacy, password_field.text)

var mission_items: Dictionary = {}

func add_mission(mission_id: int, creator_id: int, privacy: String) -> void:
	var creator_name: String = NetworkSync.peer_names.get(creator_id, "Player %d" % creator_id)
	var label := "%s's Mission (%s)" % [creator_name, privacy]
	if mission_items.has(mission_id):
		mission_list.set_item_text(mission_items[mission_id], label)
	else:
		var idx := mission_list.add_item(label)
		mission_list.set_item_metadata(idx, mission_id)
		mission_items[mission_id] = idx

func _on_join_button_pressed() -> void:
	var selected := mission_list.get_selected_items()
	if selected.is_empty():
		return
	var mission_id: int = mission_list.get_item_metadata(selected[0])
	var password := join_password_field.text
	if multiplayer.is_server():
		NetworkSync._join_mission(1, mission_id, password)
	else:
		NetworkSync.report_join_mission.rpc_id(1, mission_id, password)

func remove_mission(mission_id: int) -> void:
	if not mission_items.has(mission_id):
		return
	var idx: int = mission_items[mission_id]
	mission_list.remove_item(idx)
	mission_items.erase(mission_id)
	for key in mission_items.keys():
		if mission_items[key] > idx:
			mission_items[key] -= 1
