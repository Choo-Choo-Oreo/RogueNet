# Connectors & Doors Tracker

Ideas from the 2026-09-23 design session (Orea's direction + 3 independent
agent reviews: data format, assembly / free connections, doors), merged and
ranked. Mark items as they land. Nothing here is built yet.

Status key: [ ] todo, [x] done, [~] built / needs playtest, [-] on hold

## Orea's direction (the design goal)

- A connector is OPENING GEOMETRY only: a run of cells on a room edge defined by
  two endpoints (A x,y and B x,y) instead of a width field.
- Doors are a separate, original concept, not wall tiles. A door is an optional
  thing placed in a connector: it can be off entirely. Biomes decide: cathedral
  feels open, forest and flesh (a door in the middle of a vein makes no sense)
  have none, dungeon has lots.
- "Free connection": a connector can join a connector of ANY width (forest: 1
  opening naturally into 3) instead of requiring an exact match.
- Wider openings everywhere, so big rooms (cathedral) stop having tiny doors.
- Doors today: painted once as a wall_door tile, no hitbox of their own, never
  open / close / lock. Objects (chests, torches) are a separate open problem:
  they exist only in the editor JSON, nothing places them in the game and room
  rotation doesn't move them.
- README / room docs get rewritten after the format is decided (the "doorways
  are 1 wide in every biome" rule in game/rooms/README.md and
  game/rooms/dungeon/README.md will change).

## Current state (found while researching)

- Connector = one `{position:{x,y}}`; that cell in `walls` is also `wall_door`.
- Sealed / suppressed / locked connector bookkeeping, `door_cell`, and the queue
  in DungeonAssembler are all keyed by a single Vector2i -- that key has to
  change to a run / connector index.
- `_connector_dir` infers the side from position only (corner cells are
  ambiguous); `_rotate_connectors` is also reused for spawn cells.
- No reader-side check of the `format` field; DungeonMaker writes `format: 1`.
- DungeonMaker's flip only flips tiles, not connectors.
- The door-agent did not read the door code in detail: its "code touched" lists
  are starting points, verify before building.

## S tier -- do first

- [x] Endpoint schema `{a:{x,y}, b:{x,y}}`, inclusive, normalized (A <= B), both on ONE edge, corners rejected; width-1 = A equals B. New Connector helper: cells(), dir, width (agent 1) -- checked in code 2026-09-24 (`Connector.make/cells/width`); all 383 room files parse: 871 connectors, 0 problems
- [x] Explicit side derived from the endpoints (removes the corner ambiguity in `_connector_dir`) (agent 1) -- checked in code 2026-09-24 (`Connector.dir`)
- [x] Rotation / flip transform both endpoints then re-normalize; spawn cells stop sharing the connector rotate function; unit-check all 4 rotations against old width-1 output (agents 1, 2) -- rotation confirmed (`Connector.rotate`, `rotate_room`; the sim reproduces all 4 turns). The editor Flip still leaves connectors alone: still open, see A tier
- [x] Validator with clear errors, shared by loader, editor and a check script (not on an edge, corner, out of bounds, overlapping runs) (agent 1) -- checked in code 2026-09-24 (`Connector.validate`, run on every room load; a script check of all 383 rooms found 0 problems)
- [x] Migration: one-shot converter turns every `{position}` into `{a, b}` (merging adjacent wall_door cells into runs later); loader keeps accepting the legacy form with a warning; `format` bumped to 2 with an upgrader (agent 1) -- all 383 rooms are format 2, 0 legacy connectors; the format-1 loader shim is still there
- [x] One width-matching helper `_match_runs(run_from, run_cand, mode)` used by `_try_place` and `_fit_room_at` (agent 2) -- built as `_join_shifts` + `_joint_cells`, used by `_try_place` and `_fit_room_at` (a different name from the plan)
- [x] `free` flag on a connector (join any width) vs exact-match; legacy connectors default to exact so old seeds behave the same (Orea + agent 2) -- 555 of 871 connectors are free; cathedral and dungeon stay exact by choice
- [x] Free-mode alignment order: center first, then start, end, random -- fixed order from the seeded rng so seeds stay deterministic (agent 2) -- centre, start, end, no rng; the generator sim reproduces it
- [x] Painter seals / opens every cell of a run, not one cell (agent 2) -- `DungeonPainter` opens joint cells and seals the rest per cell, locked runs whole
- [x] Doors decoupled from walls: a `DoorPlacer` pass after assembly outputs door records (cell, orient, type, state, id); connectors stay geometry only (agent 3) -- `DoorPlacer` + `DoorRegistry` + `DoorManager`; playtested by Orea 2026-09-23/24
- [x] Unused-connector sealing becomes its own step with a per-biome cap tile (wall, foliage, flesh...); a used connector with no door stays plain open floor (agent 3) -- still open: the painter seals with the room's own `dominant_wall_tile`; there is no per-biome cap tile. The only S item left -- built 2026-09-24: `defines.json` `seal_tile` (optional) caps unused / unmatched runs, falling back to the room's `dominant_wall_tile`. No biome sets it yet: which cap tile each biome wants (e.g. forest foliage) is Orea's art call. Not run in Godot
- [x] Doors on/off: `defines.json` `doors: {density, types}` per biome (0 = none), overridable by room tag and per-connector `door` field ("none" / "auto" / type) (Orea + agent 3) -- changed: `defines.json` now has a `default_door` ("none" or a type) instead of `doors: {density, types}`, plus the per-connector `door` field (745 connectors set)
- [x] Door state is host-authoritative with a tiny sync (request -> host validates -> broadcast), full door list in the dungeon snapshot for late joiners (agent 3) -- `request_door_open` -> `set_door` -> `receive_door_state`; the full-list snapshot for late joiners is not needed yet (joins are refused once a mission starts)
- [x] Door blocking through a runtime DoorRegistry (cell -> door state) asked by GridMover / LightMap, not painted tiles or physics bodies (agent 3) -- asked by `GridMover` and `LightMap`

## A tier

- [x] Leftover cells of the wider side default to wall; optional per-connector "open remainder" later (agent 2) -- the painter seals cells outside the joint; the optional "open remainder" stays a later idea
- [-] Reserve the whole joint strip in `occupied` so later rooms can't misalign (agent 2) -- moot: the two rooms sit directly adjacent and both rects are already in `occupied`, so nothing can land in the joint
- [x] RoomGraph edges carry the joint cells (and door type); next_waypoint returns the nearest joint cell instead of always the centre (agent 2) -- built 2026-09-24: `Placement.joint_world` (all joint cells on the child's side), edges carry `cells`, `next_waypoint` returns the joint cell nearest the caller (door type not carried; no locked doors yet). Not run in Godot
- [-] Seed-drift guard: `connection_mode` (free / exact) in defines plus a candidate-order salt so old seeds still reproduce in exact mode (agent 2) -- dropped: every room file was rewritten, so old seeds already differ
- [~] Door types: archway (no block), wooden, locked / key, one `DoorDef` table in JSON (agent 3) -- the `DoorDef` table is `game/doors/*.json` (wood, wood_fold, iron, iron_sink, dungeon; `none` = archway); locked / key is not built (needs items)
- [x] Vision hook: closed doors block light and line of sight; door change marks the light / FOV region dirty (agent 3) -- closed solid doors block light and sight (`LightMap._is_blocked` asks `DoorRegistry.blocks_sight`)
- [~] Enemy pathing: closed unlocked doors passable with small cost, enemies open them on contact (host only); locked doors count as walls, flow field rebuilt on lock changes; RoomGraph edges avoid locked doors (agent 3) -- enemy JSON `doors: none | open | phase` and the door-open predicate work, and a door change clears the FlowField; there are no locked doors, so avoiding them in `RoomGraph` is not needed yet
- [~] DungeonMaker: two-click endpoint tool (click A, click B, snaps to the clicked edge), run bars in the list, drag ends, hover, flip transforms connectors; undo stores the whole connector (agent 1) -- flip now mirrors connectors (`_flipped_connectors`, undoable; not run in Godot). Still open: two-click endpoint tool, run bars, drag ends, `door` field. Bigger UI piece, needs scene changes
- [x] Stable door ids derived from the dungeon seed so clients and host agree without shipping coordinates (agent 3) -- ids are list positions from a deterministic `DoorPlacer`, identical on every peer

## B tier

- [-] Secret doors (render as wall until found), boss gate (locks on room entry, unlocks when cleared), "cracked open" see-through-but-blocked state (bars / portcullis) (agent 3) -- on hold
- [x] Door as its own node (Door.tscn) ONLY as a visual layer over the registry, for open / close animation (agent 3 -- pure node-physics version rejected) -- in effect built: `DoorManager` draws sprites over the registry, the registry stays the source of truth
- [-] Best-fit offset search (score every offset) instead of centre-first (agent 2) -- on hold; the fixed centre / start / end order is enough
- [-] Objects pass: real in-game instances, rotate with the room, tile snapping decision (Orea, separate from connectors) -- moved to OBJECTS_ROUTES_TRACKER.md

## C tier -- later / needs other systems

- [-] One-way doors (agent 3) -- on hold
- [-] Flare / funnel tiles for wide-to-narrow joints (agent 2) -- on hold
- [-] 2x2 boss clearance: per-edge `joint_width`, boss route requires width >= 2 (ties to the multi-tile item in SURROUND_AI_TRACKER.md) (agent 2) -- on hold; ties to the multi-tile item in SURROUND_AI_TRACKER.md

## D / F tier -- not recommended

- [-] Auto-widening 1-wide runs by carving into the neighbor wall: edits room data, breaks signature dedupe, can hit spawn cells (agent 2, D) -- not recommended, stays out
- [-] Doors as pure physics nodes with their own collision next to the grid: two blocking systems can disagree (agent 3, D) -- not recommended, stays out

## Confirmed 2026-09-24

Read against the code and a script check of every room file (not by running the game):
- All 383 room files are format 2 with 871 connectors: 0 problems (each run is on one edge, not a corner, in bounds, normalised, no overlaps). 586 are wider than 1, 555 are free, 745 carry a `door`.
- The whole S tier is confirmed except one item: a per-biome cap tile for unused connectors.
- Found and fixed: DungeonMaker's loader dropped each connector's `door` field, so saving any room from the editor would have stripped its door types. It now carries `door` along like `b` and `free`. Not run in Godot.
- Still open in A tier: reserve the whole joint strip in `occupied`, RoomGraph edges using the joint cells (`door_cell` is the middle joint cell), a `connection_mode` seed-drift guard (probably moot: every room file was rewritten, so old seeds already differ), and the editor tools (two-click endpoint tool, flip transforming connectors, and a field for a connector's `door`).
- B, C and D tiers are on hold ([-]) unless noted.

## Step 1 built 2026-09-23 (format only, needs a load / generate test)

- New scripts/dungeon/Connector.gd: make / upgrade / upgrade_room / a / b / cells / width / dir / rotate / validate.
- DungeonAssembler: rooms are upgraded + validated on load; rotation turns both endpoints; placement still uses each run's `a` cell, so width-1 behaviour is identical. Wider runs load but warn "assembler only joins width-1".
- All 139 room JSONs (407 connectors) rewritten to `{a, b}` with `format: 2` by a checked script (everything else in each file verified unchanged). Runtime shim still accepts format 1.
- DungeonPainter opens every cell of a run; DebugDraw (F5 debug view) draws runs; DungeonMaker reads format 1 and 2, keeps a wider run's `b` when re-saving, writes format 2, file check uses the shared validator. Editor still places single cells only.
- Rotation of a run is not "flip": editor Flip still leaves connectors alone (unchanged from before).
- Found: Flesh_Chambers_7x9 (3,5) and Mine_Cabin_Cavern_19x15 (12,7) have interior `wall_door` cells that are not connectors; the painter still turns them into open door tiles.
- Not done yet from S tier: flip transform in the editor, format upgrader versioning beyond the shim, everything from "width-matching helper" down.

## Step 2 built 2026-09-23 (width matching + free joins, needs a generate test)

- DungeonAssembler: `_join_shifts` (exact = equal widths only; free = either run has `"free": true`, tries centre, start-aligned, end-aligned shifts, no RNG), `_joint_cells` (shared cells, local to each room), used by `_try_place` and `_fit_room_at`. Width-1 joins produce the same offsets as before.
- Placement gets `joint_cells` (connector anchor -> the local cells that really join); `door_cell` is now the middle joint cell on the child side (same value for width 1).
- Painter: connector cells are handled per cell -- joint cells open (width 1 keeps its door tile, wider gaps are plain floor), cells outside the joint sealed with the room's wall tile, locked runs sealed whole. Existing interior `wall_door` cells still take the old path.
- To try it: in a room JSON make a connector `a`/`b` span several cells on one edge and add `"free": true`; the cells' wall tiles are overridden, floor is placed automatically.
- Not done: reserving the joint strip in `occupied` (A tier), RoomGraph using the joint cells, per-biome `connection_mode`, editor tool for runs.

## Option one built 2026-09-23, revised after Orea's per-biome decisions (needs a generate test)

- Free connections: cave, forest, flesh, mine, fallback = every connector `free`. Cathedral and dungeon = NO free, exact widths only.
- Widths: cathedral 3 nearly everywhere, 1 on Treasure_Vault, boss 5; new corridor rooms Cathedral_Boss_Approach_7x20 (3 -> 5) and Cathedral_Narrow_Passage_5x16 (3 -> 1). Dungeon 2 nearly everywhere, small rooms 1; new Dungeon_Corridor_Hub_5x13 (2,2 ends + four 1s), Dungeon_Corridor_4x9 and Dungeon_Hallway_7x4 replace the 3x9 / 7x3 (old files still on disk, pending deletion). Cave 1-3 (boss/entrance 5 N/S, 3 W/E). Forest like cave, capped at 3 except boss/entrance. Flesh mostly 1, up to 3. Mine 1 and 2 only. Fallback 1-5, all free.
- Interior non-connector `wall_door` cells removed (Flesh_Chambers_7x9, Mine_Cabin_Cavern_19x15); none left in any room.
- Global check (142 rooms): 0 problems.
- Known risk: exact biomes rely on width matches; fallback rooms cover gaps. Watch for missing boss/treasure in cathedral and dungeon.
- Outdated wording: "Doorways: 1 wide" in game/rooms/README.md, BIOMES.md (also names old dungeon Corridor/Hallway) and each biome README.

## Suggested build order

1. Format only (endpoint schema, side, rotation, validator, migration, format 2) with width 1 everywhere -- no gameplay change, proves the data model.
2. Width matching + free flag + alignment + painter runs, then RoomGraph joints.
3. Door decoupling (DoorPlacer, sealing step, defines toggle), then registry + sync, then vision and pathing hooks.
4. Editor tool last (biggest piece), or earlier if room authoring is blocked without it.
5. README / room docs rewrite from what actually got built.

## Open questions for Orea

- Should a free connection ever join two runs where only a partial overlap exists, or must the narrower run fit fully inside the wider one? (agents assume fully inside)
- Doors in play: do doors open on walk-into (auto) or need an interact key? Locked doors need a key item, which the game doesn't have yet.
- ~~Do wide openings (3+) ever get doors, or is that always an open arch?~~ Decided 2026-09-23: widths 1-2 get swinging wood or iron gates; widths 3-5 get a portcullis (iron rise-and-fade or iron sink), and since 2026-09-24 wood double doors are being added width by width as dedicated renders (3 approved as a swing door; the bi-fold on a rail, Orea's design, is its own `Wood_Fold` style for 3-5: the `wood` type uses it for 4 and 5 since 2026-09-24 because the 4-wide swing looked wonky, and the `wood_fold` type offers it as a second variant for 3-wide gaps; wood/iron frames 16x32; DoorPlacer emits `_2` names for the second middle piece on each side since 2026-09-24, so 5-wide doors address every cell). Boss-room door (`dungeon` type, `Dungeon_W4`/`W5`, 2026-09-24): placeholder only, flat red/blue sliding leaves 16px tall between 24px stone posts, 16 frames for a slow open, the lintel in a separate one-frame `Dungeon_W<n>_Overlay.png` at 50% alpha to draw above creatures (Orea renders that himself), 16x48 frames with `own_cell_row` 32 (DoorManager reads both since 2026-09-24). Same day the boss door was split into three layered atlases in `resources/gfx/doors/doors.boss/` (`_Frame` 1 frame, `_Leaves` 16 frames, `_Overlay` 1 frame at 50%, one manifest with `layers` + `draw_order`); Orea writes a separate boss-door manager for them. Frames done 2026-09-24: `frame_sets` in the manifest, one `<Set>_W<n>_Frame/_Overlay` pair per wall tileset (CobbleBrick, Flesh, Forest = logs, Marble, RoughCave, SmoothStone, WoodPlank), cut from the wall art, wall colours only. Leaves per tier go in the manifest's `leaf_sets` (keyed by tier, same geometry as the placeholder leaves, drawn per width, never scaled): `Wood/Iron/Bronze/Silver/Gold_W4/W5_Leaves` done 2026-09-24 (each metal a distinct design built on the tier below: iron grid over wood squares, bronze straps over iron plates, silver border + diamond bosses over bronze plates, gold border + X braces over silver plates); next: an emblem sprite on the lintel. The old combined `Dungeon_W4/W5` in `doors/` and `game/doors/dungeon.json` still point at each other and can go once his manager exists. Art is in `resources/gfx/doors/`: `Wood_W1` .. `Wood_W3`, `Wood_Fold_W3` .. `Wood_Fold_W5`, `Dungeon_W4` .. `Dungeon_W5` (one atlas per width, each 2+ door is its own render) and `Iron_W1-5`, `IronSink_W1-5` (one atlas for the whole range, the pieces repeat), each as `.png` + `.json` manifest (piece rows, selection rule, 16x16 tile split) + `_Normal.png`.
