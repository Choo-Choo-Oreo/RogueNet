extends GutTest

## Props (scripts/dungeon/Props.gd): a picture in resources/gfx/objects/props/ is a prop named
## by its file, drawn where a room places it, and turns with its room.

func test_every_prop_picture_is_a_prop_by_its_lower_case_name() -> void:
	assert_true(Props.is_prop("barrel"))
	assert_true(Props.is_prop("crate"))
	assert_false(Props.is_prop("torch"), "a torch is an object, not a prop")
	for id in Props.textures():
		assert_eq(id, id.to_lower())
		assert_true(ResourceLoader.exists(Props.textures()[id]), id)

func test_a_placed_prop_is_drawn_at_its_room_offset() -> void:
	var room := {"objects": [
		{"type": "barrel", "position": {"x": 24.0, "y": 40.0}, "rotation": 0.0},
		{"type": "torch", "position": {"x": 8.0, "y": 8.0}, "rotation": 0.0},
	]}
	var placement := DungeonAssembler.Placement.new()
	placement.room_id = "r"
	placement.offset = Vector2i(10, 2)
	var props: Props = autofree(Props.new())
	props.build({"r": room}, [placement])
	assert_eq(props.get_child_count(), 1, "only the prop, not the torch")
	var sprite: Sprite2D = props.get_child(0)
	assert_eq(sprite.position, Vector2(10 * 16 + 24, 2 * 16 + 40))
	assert_eq(sprite.texture, load(Props.textures()["barrel"]))

func test_a_turned_room_takes_its_props_with_it() -> void:
	var room := {
		"id": "r", "width": 3, "height": 2,
		"floor": [[null, null, null], [null, null, null]],
		"walls": [[null, null, null], [null, null, null]],
		"connectors": [],
		# the middle of the bottom-left cell
		"objects": [{"type": "crate", "position": {"x": 8.0, "y": 24.0}, "rotation": 0.0}],
	}
	var turned := DungeonAssembler.rotate_room(room, 1)
	# a quarter turn clockwise: the bottom-left cell becomes the top-left one
	assert_eq(turned["objects"][0]["position"], {"x": 8.0, "y": 8.0})
	assert_eq(DungeonAssembler.rotate_room(room, 4)["objects"][0]["position"], {"x": 8.0, "y": 24.0}, "four turns: back where it was")
