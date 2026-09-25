extends GutTest

## A tile's art can hold several 64x64 sets stacked top to bottom; each 8x8 quarter of the floor
## picks one (DualGridRender._pick_variant), as often as the tile's variant_weights say.

const TILES_DIR := "res://game/tiles/"

func _picks(variants: int, weights: Array[float]) -> Array[int]:
	var render := DualGridRender.new()
	autofree(render)
	render._variants = variants
	render.variant_weights = weights
	var counts: Array[int] = []
	counts.resize(variants)
	for y in 100:
		for x in 100:
			counts[render._pick_variant(Vector2i(x, y))] += 1
	return counts

func _tile_types() -> Array[TileType]:
	var types: Array[TileType] = []
	for file in DirAccess.get_files_at(TILES_DIR):
		if file.ends_with(".json"):
			var tile := TileType.new()
			tile.load_from_file(TILES_DIR + file)
			types.append(tile)
	return types

func _art(tile: TileType) -> Image:
	var texture := tile.atlas_texture
	if texture is CanvasTexture:
		texture = texture.diffuse_texture
	return texture.get_image()

func test_without_weights_every_set_is_as_likely() -> void:
	for count in _picks(4, []):
		assert_between(count, 2000, 3000)

func test_weights_make_a_set_rare() -> void:
	var counts := _picks(5, [40.0, 1.0, 1.0, 1.5, 1.5])
	assert_between(counts[0] / 10000.0, 0.85, 0.93, "the clean set nearly everywhere")
	for i in range(1, 5):
		assert_gt(counts[i], 50, "set %d still turns up" % i)
		assert_lt(counts[i], 600, "set %d is rare" % i)

func test_sets_past_the_list_weigh_one() -> void:
	var counts := _picks(2, [3.0])
	assert_between(counts[1] / 10000.0, 0.2, 0.3)

func test_tiles_have_a_weight_for_every_set() -> void:
	var weighted := 0
	for tile in _tile_types():
		if tile.variant_weights.is_empty():
			continue
		weighted += 1
		var sets := int(_art(tile).get_height() / 64.0)
		assert_eq(tile.variant_weights.size(), sets, tile.tile_name + ": one weight per 64x64 set in its art")
	assert_gt(weighted, 0)

func test_every_set_keeps_the_first_sets_outline() -> void:
	# the renderer picks per quarter, so a set whose edges differ would leave holes and seams
	for tile in _tile_types():
		if tile.shape != TileType.Shape.DUAL_GRID or tile.atlas_texture == null:
			continue
		var art := _art(tile)
		if art.is_compressed():
			art.decompress()
		for s in range(1, int(art.get_height() / 64.0)):
			var same := true
			for y in 64:
				for x in art.get_width():
					if (art.get_pixel(x, y).a > 0.0) != (art.get_pixel(x, y + 64 * s).a > 0.0):
						same = false
			assert_true(same, "%s: set %d has the first set's outline" % [tile.tile_name, s])
