# Tiles

One JSON per tile: its name, `atlas_texture` and `normal_texture`, `category` (wall or
floor), draw `sort_order`, `specular_color` and `marker_color`. Tiles are also listed in
`game/tile_registry.json`. Names are subject first: `wall_forest`, `floor_water`. `barrier_*`
tiles cannot be broken. Liquid floors (water, lava, acid) may also set `see_through`, how
much of a wading body shows below the surface. `variant_weights` says how often each 64x64
set in the art is picked when there are several (see the root README). Floors may set
`footsteps`, the sound folder their steps play from. The full format is in the root `README.md` under "Tiles".
