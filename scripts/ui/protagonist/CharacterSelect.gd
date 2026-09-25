extends Control

## The Characters screen, Terraria style. Opens from Singleplayer / Multiplayer on the main menu
## and from Swap Characters in town. Two sides: Adventurers (the heroes saved on this machine,
## ProtagonistSave: make one, delete one, pick one to play) and Wardens (the antagonist side, a
## placeholder until that role is built). Picking sets PlayerInventory's hero (loading its items,
## remembered for the next start) and emits `picked`; whoever opened the screen decides what's next.
## Built in code, like the inventory windows. Only the "human" look exists so far, so
## there is no look picker yet: a new hero gets ProtagonistSave's default.

signal picked(hero: Dictionary)

const NAME_MAX_LENGTH := 24

## Opened from the town's Swap Characters (set before adding it): one "Back to Town" button,
## which plays the selected adventurer, instead of Play and Back.
var in_town := false

var _saves := ProtagonistSave.new()
var _heroes: Array[Dictionary] = []
var _list: ItemList
var _name_edit: LineEdit
var _new_button: Button
var _play_button: Button
var _delete_button: Button
var _message: Label
var _confirm_delete: ConfirmationDialog

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var title := Label.new()
	title.text = "Characters"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	page.add_child(title)

	var sides := HBoxContainer.new()
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sides.add_theme_constant_override("separation", 30)
	page.add_child(sides)
	var column := _side(sides, "Adventurers")
	var warden := _side(sides, "Wardens")
	var later := Label.new()
	later.text = "Coming later: play as the dungeon's boss against the party."
	later.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warden.add_child(later)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(_i): _update_buttons())
	_list.item_activated.connect(func(_i): _play())
	column.add_child(_list)

	var new_row := HBoxContainer.new()
	column.add_child(new_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "New character's name"
	_name_edit.max_length = NAME_MAX_LENGTH
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(_t): _update_buttons())
	_name_edit.text_submitted.connect(func(_t): _create())
	new_row.add_child(_name_edit)
	_new_button = _button(new_row, "Create", _create)
	_delete_button = _button(new_row, "Delete", func(): _confirm_delete.popup_centered())

	_message = Label.new()
	column.add_child(_message)

	# The ways off this screen, centred under both halves.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	page.add_child(buttons)
	if in_town:
		_play_button = _button(buttons, "Back to Town", _back_to_town)
	else:
		_play_button = _button(buttons, "Play", _play)
		_button(buttons, "Back", _close)

	_confirm_delete = ConfirmationDialog.new()
	_confirm_delete.confirmed.connect(_delete)
	add_child(_confirm_delete)

	_refresh()

## One half of the screen with its heading.
func _side(parent: Control, heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	var label := Label.new()
	label.text = heading
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	column.add_child(label)
	return column

## Shown above the list, e.g. why the screen opened ("Pick a character first").
func set_message(text: String) -> void:
	_message.text = text

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

## Rebuilds the list from the files, keeping `select_id` (or the playing hero) selected.
func _refresh(select_id := "") -> void:
	if select_id == "":
		select_id = PlayerInventory.hero.get("id", "")
	_heroes = _saves.list()
	_list.clear()
	for hero in _heroes:
		var index := _list.add_item("%s   (%s, %s)" % [hero["name"], hero["skin"], hero["difficulty"]])
		if hero["id"] == select_id:
			_list.select(index)
	_update_buttons()

func _selected() -> Dictionary:
	var picked_items := _list.get_selected_items()
	return _heroes[picked_items[0]] if not picked_items.is_empty() else {}

func _update_buttons() -> void:
	var hero := _selected()
	_new_button.disabled = _name_edit.text.strip_edges() == ""
	# The town can be gone back to with nothing selected, as long as someone is still being played.
	_play_button.disabled = hero.is_empty() and (not in_town or PlayerInventory.hero.is_empty())
	_delete_button.disabled = hero.is_empty()
	if not hero.is_empty():
		_confirm_delete.dialog_text = "Delete %s for good? Their items go with them." % hero["name"]

func _create() -> void:
	if _name_edit.text.strip_edges() == "":
		return
	var hero := _saves.create(_name_edit.text)
	if _saves.save(hero) != OK:
		set_message("Could not save %s." % hero["name"])
		return
	_name_edit.clear()
	set_message("")
	_refresh(hero["id"])

func _play() -> void:
	var hero := _selected()
	if hero.is_empty():
		return
	PlayerInventory.use_hero(hero)
	picked.emit(hero)
	_close()

## Plays the selected adventurer if it is a different one, then closes.
func _back_to_town() -> void:
	var hero := _selected()
	if hero.is_empty() or hero["id"] == PlayerInventory.hero.get("id", ""):
		_close()
	else:
		_play()

func _delete() -> void:
	var hero := _selected()
	if hero.is_empty():
		return
	# Let go of it first: use_hero saves the hero it leaves, which would write the file back.
	if PlayerInventory.hero.get("id", "") == hero["id"]:
		PlayerInventory.use_hero({})
	_saves.delete(hero["id"])
	_refresh()

## Same as SettingsMenu's Back: hide the main menu's panel and go.
func _close() -> void:
	get_parent().hide()
	queue_free()
