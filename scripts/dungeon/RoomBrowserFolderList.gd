extends ItemList

## Attached to RoomBrowserPopup/BrowserVBox/BrowserSplitRow/BrowserFolderPanel/BrowserFolderList
## so a room thumbnail dragged from BrowserItemList (see RoomBrowserSourceList.gd)
## can be dropped here to move that room's file into the target folder.
## DungeonMaker.gd connects to room_dropped and performs the actual move.

signal room_dropped(room_file: String, target_folder: String)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("room_file")

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("room_file"):
		return
	var index := get_item_at_position(at_position, true)
	if index == -1:
		return
	var target_folder := "" if index == 0 else get_item_text(index)
	room_dropped.emit(data["room_file"], target_folder)
