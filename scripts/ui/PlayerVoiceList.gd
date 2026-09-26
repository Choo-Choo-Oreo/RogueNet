class_name PlayerVoiceList
extends VBoxContainer

## The other players, one row each: their Steam name (with "(talking)" while they talk), Mute, and
## their voice volume for us (0 to VoiceChat.MAX_PLAYER_VOLUME, kept by Steam ID). The town's
## player list and the pause menu's Voices box are both this. refresh() rebuilds it; talking
## only changes the names, so a player typing a volume isn't interrupted.
## `with_me`: also lists this player (the town does, as who is here), without the voice controls.

@export var with_me := true

func _ready() -> void:
	VoiceChat.speaking_changed.connect(_on_speaking_changed)
	refresh()

func refresh() -> void:
	# Voice (VoiceChat.speaking_changed) can call this while the list is out of the tree.
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)  # now, so the new rows can take their names
		child.queue_free()
	for peer_id in NetworkSync.peer_names:
		var me: bool = peer_id == VoiceChat.my_id()
		if me and not with_me:
			continue
		var row := HBoxContainer.new()
		row.name = str(peer_id)
		var label := Label.new()
		label.name = "Name"
		row.add_child(label)
		if not me:
			var mute := CheckBox.new()
			mute.text = "Mute"
			mute.button_pressed = VoiceChat.is_muted(peer_id)
			mute.toggled.connect(func(on: bool): VoiceChat.set_muted(peer_id, on))
			row.add_child(mute)
			var volume := SpinBox.new()
			volume.max_value = VoiceChat.MAX_PLAYER_VOLUME
			volume.step = 0.05
			volume.value = VoiceChat.player_volume(peer_id)
			volume.tooltip_text = "Their voice volume (1 = as sent)"
			volume.value_changed.connect(func(v: float): VoiceChat.set_player_volume(peer_id, v))
			row.add_child(volume)
		add_child(row)
		_show_talking(peer_id)

## True when there is someone besides this player to list.
func has_others() -> bool:
	return NetworkSync.peer_names.size() > 1

func _on_speaking_changed(peer_id: int, _speaking: bool) -> void:
	if not is_inside_tree():
		return
	if has_node(str(peer_id)):
		_show_talking(peer_id)
	elif peer_id != VoiceChat.my_id() or with_me:
		refresh()

func _show_talking(peer_id: int) -> void:
	var label: Label = get_node(str(peer_id)).get_node("Name")
	label.text = NetworkSync.peer_names.get(peer_id, "?") + ("  (talking)" if VoiceChat.is_speaking(peer_id) else "")
