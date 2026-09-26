# Tiles

One JSON per tile: its name, `atlas_texture` and `normal_texture`, `category` (wall or
floor), draw `sort_order`, `specular_color` and `marker_color`. Tiles are also listed in
`game/tile_registry.json`. Sound: a wall's `muffle` (dB lost per tile, wood 20 to bedrock 60),
a floor's `footsteps` material (how loud a step on it is, `game/sounds.json`). Names are subject first: `wall_forest`, `floor_water`. `barrier_*`
tiles cannot be broken. The full format is in the root `README.md` under "Tiles".
