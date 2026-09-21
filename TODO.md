# RogueNet To-Do

Legend: ✓ done, ✗ not done. Statuses were checked against the files (not by
running the game), so anything about how it looks or plays is unconfirmed.

Last verified: 2026-09-21 (after commit `3f9aaa4`, plus uncommitted lighting, normal-map and flesh variant work; only the look of the light and flesh was seen in game by Orea).

## Small cleanups
- [✓] Unused `_pieces()` in `DualGridRender.gd` removed
- [✓] Stray `floor_flesh_normal.png~` deleted
- [✓] Dev scenes (`SilverTest`, `HubMPTest`) removed (only harmless `.godot/editor` cache files remain)
- [✓] Everything committed (working tree clean)
- [✗] Debug PNG swaps kept out of commits (can't tell which PNG changes were debug swaps; check `d4b0558`, which refreshed the smooth stone and cobble textures)

## Dungeon generation
- [✓] Random room rotation (rotate-and-expand in `DungeonAssembler.gd`)
- [✗] Boss room rotation (`with_rotations` skips `entrance` and `boss` roles)
- [✗] Object rotation (the rooms' `objects` list isn't rotated)
- [✓] Wood rooms in the pool (part of the dungeon biome)
- [✓] Floors under walls (`elif` in `DungeonPainter.gd`)
- [✓] Tan strip at wall bases: Orea thinks later changes fixed it, so no longer tracked (not specifically checked)
- [✓] Dungeon Maker refresh batching (`_apply_tile` queues one deferred `refresh_all()` per frame instead of one per cell; not run in Godot yet)
- [✓] Dungeon Maker export keeping `role` and `biome` (Role and Biome folder dropdowns; saves into the biome folder; not run in Godot yet)
- [✓] Biome loading: `load_rooms(pick_biome(seed))` in `DungeonPainter.gd` and `DungeonDebugView.gd`, `IGNORED_FOLDERS := ["fallback"]`
- [✓] Fallback rooms: `_fill_from_fallback` fills missing room kinds from `game/rooms/fallback/`
- [✓] Wall tiles in `tile_type_registry.tres`: `wall_flesh`, `wall_rough_cave`, `wall_wood_plank` (ids 10-12)
- [✓] Dungeon Maker tile list builds itself from the `TileRenderer` children, so it no longer needs `game/tile_palette.json` (the file is still three walls behind, and nothing reads it now; not run in Godot yet)
- [✓] Dungeon Maker room list, known tags and "Validate All" look inside the biome folders

### Pinned (parked on purpose, revisit only if it comes up)
- [✗] Maze share: `maze`-tagged rooms are about 59% of each biome's growth pool; a cap or weight by tag would fix it
- [✗] `Mine_Cabin_Cavern_19x15`: about 8% of its floor is unreachable from its doors (may be intentional)

## Rendering and art
- [✓] Vision limit and walls blocking light: `LightMap.gd` (Minecraft-style flood fill from the local player, round, smooth to the pixel, stepped brightness) replaced the shadow/occluder attempt
- [✓] Normal-map shading driven by code: `normal_lit.gdshader` + `normal_lit_material.tres` on every DisplayLayer (set in `TileInitialize.gd`), `light_pos` fed by `LightMap.gd` (no `PointLight2D`)
- [✓] Light brightness follows the walked path around corners (`_cost` in `LightMap.gd`, `max(straight, walked - gap)` in `_paint`)
- [✓] Round light circle confirmed by Orea in game (the `gap` subtraction in `_paint`)
- [✓] Palette-driven flesh normals and smooth-stone floor normals (both in `.claude/tools/normal_maps.py`)
- [✓] Flesh floor variants: `floor_flesh.png` is 192x64 (three sets side by side), `TileInitialize.gd` widens the atlas, `DualGridRender.gd` picks one per interior quarter with a position hash
- [✓] Water and lava tile types, lit textures, normals and registry ids 13/14 (`floor_water`, `floor_lava`; terrain DIFFICULT / SEVERE and sort order 5 / 6 are placeholders)
- [✓] `game/rooms/liquid/` test biome: `Liquid_Pools_9x9`, `Liquid_Lava_Bridge_11x7`, `Liquid_Moat_9x9` (normal rooms only, rest from `fallback/`; generated and confirmed working by Orea)
- [✓] Glow light: lava lights and tints nearby stone (`_find_glow_sources`, `_flood_glow`, `_paint_glow` in `LightMap.gd`, `glow_tint.gdshader`); confirmed orange and cheap by Orea
- [✓] Glow stress test (no visible stutter after the bake): `Liquid_Boss_Lava_Lake_52x52` (1600 lava tiles) in the liquid biome; check for stutter when crossing cells near it
- [✓] Glow baked once at dungeon load (`LightMap.bake_glow`, whole-dungeon glow map, `light_smooth.gdshader` finds it by world position). Measured before: glow flood 56 ms (1,260 lava tiles in window), 29 ms after skipping interior seeds; now zero per move. Test room `Liquid_Maze_Checker_29x29` (360 lava tiles in 3x3 blocks)
- [✓] Tile overlays (`TileType.overlay_texture` / `overlay_density`, `overlay_anim.gdshader`): 64x64 sheet = 8 rows (animations) x 8 frames of 8x8 quads; each interior quad picks a row per cycle. Lava embers wired up (needs a look in game); untested on acid
- [✓] Acid tile set up (`floor_acid.tres`, id 15, sort 7, `DIFFICULT`, normal map via `normal_maps.py`, lit texture, bubbles overlay); test room `Liquid_Acid_Vats_11x9`. Needs a look in game (teal `#37946E` treated as the raised highlight; no glow yet, no damage yet)
- [✗] Glow rebake for changing sources (pickup-able wall torches, destroyed lava): `_scan_glow_sources(rect)` already takes any rectangle; needs `rebake_around(position, radius)` (clear box, reflood from overlapping sources) and an object-sourced entry in `_glow_sources`. Carried torches = live light, not baked
- [✗] Player flood + paint still run per 8px cell (about 6 ms + 5 ms in the debugger): flat arrays instead of dictionaries next
- [✓] `base_floor` room field (painter reads it, falls back to the dominant floor): set on all `liquid/` and `flesh/` rooms so doorways and wall floors aren't lava, water or stray stone
- [✗] Glow ideas: flicker (shader wobble on the radius), glowstone wall tile, glow radius/colour tuning
- [✓] Water and lava animation: `TileInitialize.gd` creates the first 8 columns and sets Godot tile animation (frames = image width / 64, 0.1 s each); confirmed working by Orea in game
- [✓] Water and lava art touch-up: calm water with a darker deep (`.claude/tools/liquid_touchup.py`), lava with a dark cooled crust and an uneven wave rolling in to the shore (`.claude/tools/lava_shore.py`, style A); normals rebuilt; new lava not seen in game yet
- [✗] Lava glow / ignore darkness (lava is lit and darkened like stone for now)
- [✗] Variants for other materials (same layout: extra 64 px sets to the right, then re-run the normal script)
- [✓] Normal-map tools merged into `.claude/tools/normal_maps.py` (one table of materials; `python normal_maps.py [name]`)
- [✓] Old normal-map scripts deleted (still in git history)
- [✗] `floor_dirt` / `floor_grass` normals were made with other settings than the script's defaults; a plain rebuild skips them
- [✗] Specular / glare map (`#FFFFFF` vein glare is painted in; the shader doesn't read a specular map)
- [✗] Light steps and radius tuning (`light_radius`, `step_*` in `light_smooth.gdshader`)
- [✗] Other players' vision and party shared vision (LightMap only follows the local player)
- [✓] `wall_wood_plank`, `wall_rough_cave`, `wall_flesh` tile types and lit textures exist
- [✓] Normal maps for those three walls (`.claude/tools/normal_maps.py` lists them, PNGs exist)
- [✗] Normal maps for the void and the doors (no files)
- [✗] Flesh shine confirmed (`specular_color` is 0.75, effect not seen)
- [✗] Door look (your friend is fixing it later)

## Gameplay
- [✓] Flesh terrain tier (`terrain = 1` in `floor_flesh.tres`, code committed)
- [✗] `DIFFICULT` and `SEVERE` tried on real floors (flesh is the only floor with a terrain value)
- [✓] Health and damage component (`Health.gd`, health bar, death screen)
- [✗] Enemies beyond the mouse (only `mouse.gd` and `PlaceholderMouse.gd` found)
- [✗] Objects and spawners finished
- [✗] Loot, stats and skill tree data (no files found)

## Multiplayer and structure
- [✗] Start-dive crash: `receive_mission_members` in `NetworkSync.gd` calls `.hide()` on `get_node_or_null("PanelMain")` without a null check (line 211)
- [✗] Netcode decision (`CLAUDE.md` networking line still says "note here once decided")
- [✗] Dungeon instancing (only the basic part: every member loads the dungeon scene with one shared seed; no per-party instance hosted by the party lead)
- [✗] Persistent town (research only)
- [✗] Lobby and menu backlog (`PanelLobby` still in `MainMenu.tscn`, line 102)
- [✗] Optional boss-player role (only `mouse.gd`, in an "antagonist" folder)

## Debug controls
- [✗] F4: Debug Settings (bool, opens a menu)
- [✗] F5: Debug Overlay (bool, on/off)
- Note: F5 is already bound to `debug_dungeon_layout` in the input map (`project.godot`, used by `DungeonDebugView.gd` to print a layout to the console); rebind one of them or the two will fire together
