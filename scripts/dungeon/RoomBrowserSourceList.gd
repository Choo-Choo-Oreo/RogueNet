extends ItemList

## Attached to RoomBrowserPopup/BrowserVBox/BrowserSplitRow/BrowserItemList so a
## thumbnail can be dragged onto BrowserFolderList to move that room's file.
## The room's path (relative to game/rooms/) is read from the item's metadata,
## which DungeonMaker.gd already fills in via _refresh_room_browser().

## Godot only calls _get_drag_data once the mouse has moved past its drag
## threshold while held down. DungeonMaker.gd listens for this to cancel the
## delayed "load on click" it schedules from item_selected (which fires on
## mouse-down, before a drag can be told apart from a click).
signal drag_started

func _get_drag_data(at_position: Vector2) -> Variant:
	var index := get_item_at_position(at_position, true)
	if index == -1:
		return null
	var room_file = get_item_metadata(index)
	if not (room_file is String):
		return null
	drag_started.emit()
	var preview := Label.new()
	preview.text = get_item_text(index)
	set_drag_preview(preview)
	return {"room_file": room_file}
