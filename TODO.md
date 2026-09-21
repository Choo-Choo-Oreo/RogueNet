# RogueNet To-Do

Legend: ✓ done, ✗ not done. Statuses were checked against the files (not by
running the game), so anything about how it looks or plays is unconfirmed.

Last verified: 2026-09-21 (after commit `3f9aaa4`, plus uncommitted lighting, normal-map and flesh variant work; only the look of the light and flesh was seen in game by Orea).

## Small cleanups
- ✓ Unused `_pieces()` in `DualGridRender.gd` removed
- ✓ Stray `floor_flesh_normal.png~` deleted
- ✓ Dev scenes (`SilverTest`, `HubMPTest`) removed (only harmless `.godot/editor` cache files remain)
- ✓ Everything committed (working tree clean)
- ✗ Debug PNG swaps kept out of commits (can't tell which PNG changes were debug swaps; check `d4b0558`, which refreshed the smooth stone and cobble textures)

## Dungeon generation
- ✓ Random room rotation (rotate-and-expand in `DungeonAssembler.gd`)
- ✗ Boss room rotation (`with_rotations` skips `entrance` and `boss` roles)
- ✗ Object rotation (the rooms' `objects` list isn't rotated)
- ✓ Wood rooms in the pool (part of the dungeon biome)
- ✓ Floors under walls (`elif` in `DungeonPainter.gd`)
- ✗ Confirmed the `elif` fixed the tan strip at wall bases (not seen running)
- ✗ Dungeon Maker refresh batching (`_apply_tile` calls `refresh_all()` for every cell); left as is on purpose for now
- ✗ Dungeon Maker export keeping `role` and `biome` (re-saving a biome room drops both)
- ✓ Biome loading: `load_rooms(pick_biome(seed))` in `DungeonPainter.gd` and `DungeonDebugView.gd`, `IGNORED_FOLDERS := ["fallback"]`
- ✓ Fallback rooms: `_fill_from_fallback` fills missing room kinds from `game/rooms/fallback/`
- ✓ Wall tiles in `tile_type_registry.tres`: `wall_flesh`, `wall_rough_cave`, `wall_wood_plank` (ids 10-12)
- ✗ Same three walls still missing from `game/tile_palette.json` (run `CompileTilePalette` in the editor)

### Pinned (parked on purpose, revisit only if it comes up)
- ✗ Maze share: `maze`-tagged rooms are about 59% of each biome's growth pool; a cap or weight by tag would fix it
- ✗ `Mine_Cabin_Cavern_19x15`: about 8% of its floor is unreachable from its doors (may be intentional)

## Rendering and art
- ✓ Vision limit and walls blocking light: `LightMap.gd` (Minecraft-style flood fill from the local player, round, smooth to the pixel, stepped brightness) replaced the shadow/occluder attempt
- ✓ Normal-map shading driven by code: `normal_lit.gdshader` + `normal_lit_material.tres` on every DisplayLayer (set in `TileInitialize.gd`), `light_pos` fed by `LightMap.gd` (no `PointLight2D`)
- ✓ Light brightness follows the walked path around corners (`_cost` in `LightMap.gd`, `max(straight, walked - gap)` in `_paint`)
- ✗ Confirmed the round-circle fix (the `gap` subtraction in `_paint`; not tested in game yet)
- ✓ Palette-driven flesh normals (`.claude/tools/flesh_normals.py`: bone, veins, indent) and smooth-stone floor normals (`floor_smooth_stone_normals.py`)
- ✓ Flesh floor variants: `floor_flesh.png` is 192x64 (three sets side by side), `TileInitialize.gd` widens the atlas, `DualGridRender.gd` picks one per interior quarter with a position hash
- ✗ Variants for other materials (same layout: extra 64 px sets to the right, then re-run the normal script)
- ✗ Merge the normal-map tools into one shared script with a palette table per tileset (the old ones duplicate the same code)
- ✗ Specular / glare map (`#FFFFFF` vein glare is painted in; the shader doesn't read a specular map)
- ✗ Light steps and radius tuning (`light_radius`, `step_*` in `light_smooth.gdshader`)
- ✗ Other players' vision and party shared vision (LightMap only follows the local player)
- ✓ `wall_wood_plank`, `wall_rough_cave`, `wall_flesh` tile types and lit textures exist
- ✓ Normal maps for those three walls (`.claude/tools/wall_normals.py` lists them, PNGs exist)
- ✗ Normal maps for the void and the doors (no files)
- ✗ Flesh shine confirmed (`specular_color` is 0.75, effect not seen)
- ✗ Door look (your friend is fixing it later)

## Gameplay
- ✓ Flesh terrain tier (`terrain = 1` in `floor_flesh.tres`, code committed)
- ✗ `DIFFICULT` and `SEVERE` tried on real floors (flesh is the only floor with a terrain value)
- ✓ Health and damage component (`Health.gd`, health bar, death screen)
- ✗ Enemies beyond the mouse (only `mouse.gd` and `PlaceholderMouse.gd` found)
- ✗ Objects and spawners finished
- ✗ Loot, stats and skill tree data (no files found)

## Multiplayer and structure
- ✗ Start-dive crash: `receive_mission_members` in `NetworkSync.gd` calls `.hide()` on `get_node_or_null("PanelMain")` without a null check (line 211)
- ✗ Netcode decision (`CLAUDE.md` networking line still says "note here once decided")
- ✗ Dungeon instancing (only the basic part: every member loads the dungeon scene with one shared seed; no per-party instance hosted by the party lead)
- ✗ Persistent town (research only)
- ✗ Lobby and menu backlog (`PanelLobby` still in `MainMenu.tscn`, line 102)
- ✗ Optional boss-player role (only `mouse.gd`, in an "antagonist" folder)

## Debug controls
- ✗ F4: Debug Settings (bool, opens a menu)
- ✗ F5: Debug Overlay (bool, on/off)
- Note: F5 is already bound to `debug_dungeon_layout` in the input map (`project.godot`, used by `DungeonDebugView.gd` to print a layout to the console); rebind one of them or the two will fire together
