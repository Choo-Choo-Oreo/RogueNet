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
- [✓] Re-host shows the old client twice: `NetworkSync.reset_session()` now exists and is called from `PauseMenu.gd`, `MainTown.gd`, `MainMenu.gd`, `LobbyMenu.gd` and `_on_server_disconnected`. Orea confirmed the new pause-menu flow works; the re-host retest itself (host, queue, start, main menu, host again, client rejoins shows once) hasn't been done
- [✓] Ghost player / soft-lock when the host starts a mission with a player not in it (2026-09-21, retested once by Orea; the log then showed a town client still receiving dungeon spawn, despawn and End Mission RPCs, so the fix was widened, untested): the `MultiplayerSpawner` in `Dungeon.tscn` is removed (it announced every spawn to every connected peer). `receive_start_mission(seed, members)` now carries the party, every diver's `PlayerSpawner` spawns those players locally (`NetworkSync.dive_members`), `_relay_position` only goes to divers, and End Mission is `NetworkSync.end_mission()` → `receive_return_to_town` for divers only (the RPC on the dungeon's PauseMenu node is gone). Both players need the same version (the start RPC changed signature). Known: a diver who disconnects before the dungeon loads still gets spawned on the other clients (clients only see the host as a peer)
- [✓] Hard seam between two players' lights: `normal_lit.gdshader` picked the nearest light, which flips at the halfway point; now the lights' shading is added (untested)
- [✓] Movement input: the newest key press now wins (`PlayerController.gd` keeps `_held`, oldest to newest; before, a fixed right/left/up/down priority ignored a new key while an older one was held). Reported by Orea 2026-09-21; untested
- [✓] Town chat: the UI existed in `MainTown.tscn` but nothing sent or received messages. Now `NetworkSync.send_chat` → host stamps the name and broadcasts (`receive_chat`), `MainTown.add_chat_line` shows it; Enter or Send. Written 2026-09-21, untested; chat only works in the town (the log clears on scene change), no history
- [✓] Host-only "End Mission" button in the pause menu (`PauseMenu.gd` / `PauseMenu.tscn`): sends everyone back to the town, panel resizes to fit; confirmed working by Orea
- [✓] Other players' lights, shared vision (decided 2026-09-21: a ranger can use a frontliner's eyes to see farther; untested): `LightMap.gd` keeps one `Light` (window, flood, texture) per player, `light_smooth.gdshader` takes the brightest of local + up to 3 others (`other_map_1..3`), `normal_lit.gdshader` blends the lights (`other_lights`): sum of each light's shading divided by max(1, sum of reaches). Nearest-light and strongest-light both left a hard seam where two lights meet, plain adding doubled the flesh sparkle; the blend is smooth everywhere (untested). Limit of 4 players lit, each extra light costs about one flood + paint per cell moved. Halo (glow-only) version was tried and dropped; `light_halo.gdshader` is unused and can be deleted; `light_steps.gdshaderinc` is still used by `light_smooth`
- [✓] Start-dive crash: `receive_mission_members` now returns early when the town panels don't exist (untested); also audit item 2
- [✓] `receive_position` crash when ending a mission (`current_scene` null during the scene change, seen 2026-09-21): all `receive_*` in `NetworkSync.gd` now check `current_scene` (untested)
- [✗] Netcode decision (`CLAUDE.md` networking line still says "note here once decided")
- [✗] Dungeon instancing (only the basic part: every member loads the dungeon scene with one shared seed; no per-party instance hosted by the party lead)
- [✗] Persistent town (research only)
- [✗] Lobby and menu backlog (`PanelLobby` still in `MainMenu.tscn`, line 102)
- [✗] Optional boss-player role (only `mouse.gd`, in an "antagonist" folder)

## Networking audit (2026-09-21): verify first, then decide
Found by reading the code, nothing was playtested. For each item: first check it's a real problem, then decide the fix. Items 1 and 2 of the audit are covered above (reset_session done; late Guild click is the start-dive crash).
- [✗] Disconnect leaves the peer in `missions[x]["members"]`; a dead peer gets `rpc_id` calls and a creator who leaves orphans the mission. Verify: join a mission, close the client, then start or click Guild on the host and watch for errors. Fix idea: erase the peer from every mission on `peer_disconnected`, and reassign or delete the mission if the creator left
- [✗] `PlayerSpawner` spawns everyone connected, not just the mission party (ghost avatars for players still in town, spawner errors on clients without `/root/Dungeon`). Verify: host and two clients, only two dive, look at the third's screen. Fix idea: spawn only for mission members (part of the "who is in this dive" pass)
- [✓] The dive needs the host in it: confirmed by Orea 2026-09-21 (a mission won't start without the host). Rule for now: the host always leads and is always in the dive (only the creator can start, and in shared-party mode the creator is the host). Still open for `is_dedicated`, where a client can create a mission, and for the party-lead-hosts vision; decide with the netcode decision
- [✗] No "I'm loaded" handshake between scene change and spawn (and `_send_existing_missions` can hit a client that hasn't loaded GuildTown yet). Verify: test with a slow client or a big dungeon. Fix idea: client tells the server once its scene is ready, then the server spawns and sends state
- [✗] `receive_mission_members` also force-shows `PanelMission` for every member on any join or leave; Back in shared-party mode never leaves the mission. Verify: join a mission, press Back, have someone else join. Fix idea: split into a data update and a UI update
- [✓] Singleplayer now uses `OfflineMultiplayerPeer` (`MainMenu.gd`) and `SteamManager` only touches Steam when it is running (`SteamManager.online`); Host and Join print a message and stop when Steam is off (Singleplayer confirmed working by Orea 2026-09-21; the Host/Join message is console-only, no on-screen text yet). Singleplayer without Steam crashed on `initRelayNetworkAccess` before
- [✗] Join has no failure path: `connection_failed` only prints, the peer isn't nulled, the one-shot `connected_to_server` stays attached, a second Join double-connects, Back mid-connect frees the menu anyway. Verify: join a wrong or offline host ID twice. Fix idea: null the peer and disconnect the signal on failure, disable Join while connecting
- [✗] Edge case, seen 2026-09-21: host's Steam was in Offline mode, so the client's join sat at "connecting" forever with no message, and Host still printed "Hosting". Needed a Steam restart. Fix idea: check `Steam.loggedOn()` (and that Steam is running) in `SteamManager` and before Host / Join / Singleplayer, and show a message in the menu; add a join timeout (about 15 s) that nulls the peer and says "couldn't reach host". Also disable Join while connecting (the second press gave `ERR_CANT_CREATE`, error 20)
- [✗] Dead code: `report_steam_id` never called (so `peer_steam_ids` only holds the host); `report_move_state` / `receive_move_state` never called and reference a missing `apply_move_animation`; `is_dedicated` isn't synced; dedicated mode `mission_id = creator_id` overwrites a second mission. Verify: grep for callers; decide keep or delete
- [✗] Position streamed every frame (`PlayerController.gd` 23-26), relayed to every peer including ones in town. Tested 2026-09-21 with the profiler: `NetworkSync` showed 7241 in / 3287 out (16-18 B each), and Orea reports the traffic slows a lot when nobody is moving, which the code doesn't explain (it sends every frame while the player is the authority; `project.godot` has no low-processor or FPS cap). Cause unknown (window focus throttling? the profiler's own sampling?), so low priority; still relayed to peers in town. Fix idea: one reliable "moving to tile X" per step (movement is tile-based). Also feeds the other-players'-lights work
- [✗] Trust: positions, names and the privacy string are unvalidated. Decide as part of the netcode decision (fits the Terraria-style model, but should be a conscious choice)
- [✗] `receive_*` functions call `get_tree().current_scene.get_node_or_null(...)` without a null check on `current_scene` (null briefly during scene changes; `receive_player_names` already guards). Verify: spam Guild during a scene change. Fix: one shared guard
- [✗] Root cause of several items above: `NetworkSync` reaches into the scene tree by hard-coded path and pushes UI changes. Bigger fix: `NetworkSync` holds the state and emits signals, scenes read it in `_ready` and subscribe. Revisit with the netcode decision
- [✗] Export bug (not networking): `_build_floor_speeds` (`PlayerController.gd` line 72), `TileInitialize.gd` line 35 and `CompileTilePalette.gd` line 16 filter with `ends_with(".tres")`; in exported builds files become `.tres.remap`, so floor speeds fall to 1.0 and tile loading may break. Verify: export a test build. Fix idea: strip a trailing `.remap` before checking or loading

## Debug controls
- [✗] F4: Debug Settings (bool, opens a menu)
- [✗] F5: Debug Overlay (bool, on/off)
- Note: F5 is already bound to `debug_dungeon_layout` in the input map (`project.godot`, used by `DungeonDebugView.gd` to print a layout to the console); rebind one of them or the two will fire together
