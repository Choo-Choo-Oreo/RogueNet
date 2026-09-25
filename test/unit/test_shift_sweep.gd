extends GutTest

## Shift+click sends one item between the bag and the storage; keeping Shift and the button
## held and sweeping across more slots sends each of them, once. Events are pushed in the
## viewport's own coordinates (the headless window is tiny and stretched).

var _saved_bag: Array[String]
var _saved_storage: Array[String]
var _slots: Array = []

func before_each() -> void:
	_saved_bag = PlayerInventory.bag.duplicate()
	_saved_storage = PlayerInventory.storage.duplicate()
	PlayerInventory.bag.fill("")
	PlayerInventory.storage.fill("")
	for i in 3:
		PlayerInventory.bag[i] = "ruby_ring"
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child_autofree(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(200, 200)
	layer.add_child(row)
	_slots.clear()
	for i in 3:
		var cell := ItemSlot.new(PlayerInventory.place(PlayerInventory.BAG, i))
		cell.shift_action = func(at: Dictionary): PlayerInventory.send_to(at, PlayerInventory.STORAGE)
		row.add_child(cell)
		_slots.append(cell)
	await wait_process_frames(2)

func after_each() -> void:
	PlayerInventory.bag = _saved_bag
	PlayerInventory.storage = _saved_storage

func _centre(i: int) -> Vector2:
	return _slots[i].get_global_rect().get_center()

func _button(i: int, pressed: bool, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = _centre(i)
	event.global_position = event.position
	get_viewport().push_input(event, true)

func _move(i: int, shift: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = _centre(i)
	event.global_position = event.position
	event.relative = Vector2(10, 0)
	get_viewport().push_input(event, true)

func _bag_left() -> int:
	return PlayerInventory.bag.count("ruby_ring")

func test_shift_click_sends_one() -> void:
	_button(0, true, true)
	_button(0, false, true)
	assert_eq(_bag_left(), 2)

func test_a_shift_sweep_sends_each_slot_it_crosses() -> void:
	_button(0, true, true)
	_move(1, true)
	_move(2, true)
	_move(1, true)
	_button(2, false, true)
	assert_eq(_bag_left(), 0)
	assert_eq(PlayerInventory.storage.count("ruby_ring"), 3)

func test_the_sweep_ends_on_release() -> void:
	_button(0, true, true)
	_button(0, false, true)
	_move(1, true)
	assert_eq(_bag_left(), 2, "moving after letting go sends nothing")

func test_without_shift_moving_sends_nothing() -> void:
	_button(0, true, true)
	_move(1, false)
	_move(2, false)
	_button(2, false, false)
	assert_eq(_bag_left(), 2)
