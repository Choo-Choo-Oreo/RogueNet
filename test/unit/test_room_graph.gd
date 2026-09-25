extends GutTest

## RoomGraph decides which rooms count as "near a player" for patrol: the player's own room and
## the rooms joined to it by a door, not the rooms beyond those. Three rooms in a row here:
## A (0..9) - B (10..19) - C (20..29), each 10 x 10.

class FakePlacement:
	var room_id := "r"
	var offset := Vector2i.ZERO
	var parent_index := -1
	var door_cell := Vector2i.ZERO
	var joint_world: Array[Vector2i] = []

var _graph: RoomGraph

func before_each() -> void:
	var placements: Array = []
	for i in 3:
		var p := FakePlacement.new()
		p.offset = Vector2i(i * 10, 0)
		p.parent_index = i - 1
		p.door_cell = Vector2i(i * 10, 5)
		placements.append(p)
	RoomGraph.build({"r": {"width": 10, "height": 10}}, placements)
	_graph = RoomGraph.current

func after_each() -> void:
	RoomGraph.current = null

func test_a_cell_is_in_its_own_room_and_the_neighbours() -> void:
	assert_eq(_graph.rooms_near(Vector2i(5, 5)), [0, 1] as Array[int], "the end room touches one neighbour")
	assert_eq(_graph.rooms_near(Vector2i(15, 5)).size(), 3, "the middle room touches both")

func test_a_cell_outside_every_room_is_near_nothing() -> void:
	assert_true(_graph.rooms_near(Vector2i(50, 50)).is_empty())

func test_same_room_and_next_room_count_but_two_rooms_away_does_not() -> void:
	var player: Array[Vector2i] = [Vector2i(5, 5)]
	assert_true(_graph.is_near_any(Vector2i(2, 2), player), "same room")
	assert_true(_graph.is_near_any(Vector2i(12, 2), player), "next room")
	assert_false(_graph.is_near_any(Vector2i(25, 2), player), "two rooms away")

func test_any_one_player_is_enough() -> void:
	var players: Array[Vector2i] = [Vector2i(5, 5), Vector2i(25, 5)]
	assert_true(_graph.is_near_any(Vector2i(22, 2), players))

func test_room_rect_is_the_rooms_rectangle() -> void:
	assert_eq(_graph.room_rect(Vector2i(13, 4)), Rect2i(10, 0, 10, 10))
	assert_false(_graph.room_rect(Vector2i(99, 99)).has_area())
