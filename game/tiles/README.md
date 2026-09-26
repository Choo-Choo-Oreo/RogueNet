# Tiles

One JSON per tile: its name, `atlas_texture` and `normal_texture`, `category` (wall or
floor), draw `sort_order`, `specular_color` and `marker_color`. Tiles are also listed in
`game/tile_registry.json`. Names are subject first: `wall_forest`, `floor_water`. `barrier_*`
tiles cannot be broken. Liquid floors (water, lava, acid) may also set `see_through`, how
much of a wading body shows below the surface. `variant_weights` says how often each 64x64
set in the art is picked when there are several (see the root README). Floors may set
`footsteps`, the sound folder their steps play from. Floors may also set `overlay_texture`
and `overlay_density`: a 64x64 sheet of 8 little animations (one per row, 8 frames of 8x8,
transparent) that play now and then on the floor's inner quarters, picked at random per
quarter (`resources/shaders/overlay_anim.gdshader`). `overlay_density` is the chance a quarter
plays one each cycle (0.1-0.2 looks alive without busy). One sheet can serve several floors
(`overlay_frost_glints` is on both snow and ice). Walls cannot have one. The full format is in the root `README.md` under "Tiles".
