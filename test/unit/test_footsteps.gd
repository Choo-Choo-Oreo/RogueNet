extends GutTest

## Steps on every floor (Wading): which sounds a floor's steps play (its "footsteps" folder),
## the dust they kick up, and the colours worked out from tile art (TileType.art_colours),
## which only read a tile's plain first set.

func _tile(tile_name: String) -> TileType:
	return GridMover.floor_type(GridMover._tile_ids().get_id(tile_name))

func test_a_floor_steps_in_its_own_folder_unless_it_shares_one() -> void:
	assert_eq(_tile("floor_water").footsteps, "water", "left out: the tile's own name")
	assert_eq(_tile("floor_dirt").footsteps, "dirt")
	assert_eq(_tile("floor_smooth_stone").footsteps, "stone")
	assert_eq(_tile("floor_smooth_cave").footsteps, "stone", "floors that sound alike share a folder")
	for colour in ["crimson", "gold", "indigo", "verdigris", "violet"]:
		assert_eq(_tile("floor_carpet_" + colour).footsteps, "carpet")

func test_numbered_takes_run_until_one_is_missing() -> void:
	assert_eq(SoundPlayer.numbered(Wading.SFX_ROOT + "water/step").size(), 3)
	assert_eq(SoundPlayer.numbered(Wading.SFX_ROOT + "lava/pop"), LiquidAmbience.pop_paths("lava"))
	assert_eq(SoundPlayer.numbered(Wading.SFX_ROOT + "nothing_here/step").size(), 0)

func test_dust_takes_the_floors_colours() -> void:
	# the dust puff is the rubble sheet's, recoloured to the floor's palette (lightest last)
	var stone: Color = ParticleBurst._tile_palette(_art_path("floor_smooth_stone")).back()
	var grass: Color = ParticleBurst._tile_palette(_art_path("floor_grass")).back()
	assert_almost_eq(stone.r, stone.b, 0.1, "stone dust is grey")
	assert_gt(grass.g, grass.r, "grass dust is green")

func _art_path(tile_name: String) -> String:
	return TileType.plain(_tile(tile_name).atlas_texture).resource_path

func test_only_the_plain_set_gives_a_tiles_colours() -> void:
	# wall_rough_cave's rarer sets have gold ore in them; its rubble must stay rock coloured
	var plain := TileType.art_colours(_wall_art("wall_rough_cave"))
	assert_false(plain.has(Color8(236, 200, 104)), "no ore in the plain set's colours")
	var rubble := ParticleBurst._tile_palette("res://resources/gfx/tileset/wall_rough_cave.png")
	assert_eq(rubble.size(), 6)
	assert_false(rubble.has(Color8(236, 200, 104)))

func _wall_art(tile_name: String) -> Texture2D:
	var tile := TileType.new()
	tile.load_from_file("res://game/tiles/" + tile_name + ".json")
	return tile.atlas_texture
