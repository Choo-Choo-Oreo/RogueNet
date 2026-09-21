# RogueNet To-Do

Legend: ✓ done, ✗ not done. Statuses were checked against the files (not by
running the game), so anything about how it looks or plays is unconfirmed.

Last verified: 2026-09-21 (after commit `a89638a`, "Introduce biomes and per-biome room loading").

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
- ✗ Wall tiles registered: `wall_flesh`, `wall_rough_cave`, `wall_wood_plank` missing from `tile_type_registry.tres` and `game/tile_palette.json` (run `CompileTilePalette` in the editor)

### Pinned (parked on purpose, revisit only if it comes up)
- ✗ Maze share: `maze`-tagged rooms are about 59% of each biome's growth pool; a cap or weight by tag would fix it
- ✗ `Mine_Cabin_Cavern_19x15`: about 8% of its floor is unreachable from its doors (may be intentional)

## Rendering and art
- ✗ Wall shadows: no `LightOccluder2D` anywhere (needs a `TileInitialize.gd` change)
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
