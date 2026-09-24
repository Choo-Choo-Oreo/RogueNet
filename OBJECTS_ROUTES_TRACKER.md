# Objects, Overlays, Routes & Ceilings Tracker

Ideas from the 2026-09-24 design session (Orea's direction + 3 independent
agent reviews: data format and placement, routes and forced movement,
interaction / loot / destructibles / lighting), merged and ranked. Mark items
as they land. Nothing here is built yet. Sister files: CONNECTORS_TRACKER.md
(connectors and doors), AGGRO_AI_TRACKER.md, SURROUND_AI_TRACKER.md.

Status key: [ ] todo, [x] done, [~] built / needs playtest, [-] on hold

Agent tags: (a1) data format and placement, (a2) routes and movement,
(a3) interaction, loot, lighting. Facts were read from the code, not run;
guesses are marked as guesses.

## Orea's direction (the design goal)

- Objects are a FIELD OF DEFINING SPECIFICS: one manifest per object type, with
  properties (light, interact, destructible, loot, blocking, layers), in the
  spirit of the boss-door layer folders (`<parent>.<family>`). New content is a
  data file, not code.
- Placement modes: a torch can be mounted ON A WALL. There are many light
  sources, not only torches (e.g. a pulsing green bulb for flesh).
- Overlays sit above the floor and below actors. Two kinds: tile-bound (embers,
  acid bubbles, today, visual only) and placed (tracks, conveyors, decals).
- Routes: ONE concept for tracks and conveyors (cells with a direction; a hub
  and branches; junctions with switches; a carrier setting: auto = conveyor,
  vehicle = minecart, maybe manual). Routes hang off a HUB room worth going to
  (not necessarily the boss room). If the hub does not generate, no routes
  generate. Routes cross room connectors and are generated, not only authored.
- Actors = players, monsters, bosses: one `actor` group holding both existing
  groups.
- Ceilings: naturally about 35% transparent, drawn above everything (in
  practice: above actors, below the darkness). 2.0 idea: several floors, the
  ceiling fades to 100% before you climb. Not now.
- Free-standing doors (in a room, not on a connector) are wanted by a teammate.
- Chests are the loot source; destructibles are wanted.
- Steampunk biome (lifts, pistons, vents, moving floors) is not made yet;
  the only requirement now is expandability.

## Decisions made (Orea, 2026-09-24)

- Chests BLOCK walking (you cannot walk over one; a mimic is planned for one day). So a chest is a `floor` object that registers in the blocker registry, and enemies and pathfinding must treat it as blocked. (Answers Q7)
- Wall placement stores the WALL CELL plus the face it hangs on. Cells are the data layer; tiles (the dual-grid mesh, visuals) sit under them and are derived from cell data, so an object reads what it needs from its cell instead of storing tile info. (Answers Q1; this is my reading of Orea's explanation, confirm when we build it)
- Belts: standing still on a belt moves you one tile every second in its direction; pressing a movement key overrides the push (input wins over forced movement). (Answers Q13)

## Current state (found while researching)

- Room JSON `objects` (pixel `position`, `rotation`, `type`) hold 148 torches
  and 39 chests (counted by parsing every room file; an agent's grep counted
  130 / 34, so recount before writing the migrator). Nothing reads them at
  runtime; DungeonMaker only draws marker icons (`DungeonMaker.gd:49-51`).
- `rotate_room` rotates floor, walls, connectors, spawn cells; NOT objects
  (`DungeonAssembler.gd:156-170`). DungeonMaker's flip also leaves objects alone.
- Doors are the pattern to copy: host-owned, ids are list positions identical
  on every peer (`DoorPlacer.gd:2-5`), `request_door_open` -> `set_door` ->
  `receive_door_state` (`NetworkSync.gd:488-514`), 300 ms ask cooldown, and
  `DoorRegistry._changed()` bumps a version and clears the FlowField.
- Enemy hits are the pattern for destructibles: report -> host -> every peer
  applies the damage to its own `EntityStats` (`NetworkSync.gd:450-477`). The
  attack path only loops the `antagonist` group (`PlayerController.gd` ~248).
- No interact key exists; Hotbar is placeholder text, no slot logic.
- Blocking is asked in several places, all door-aware and not object-aware:
  `is_tile_blocked`, `blocks_sight`, `blocks_shot` (`GridMover.gd`),
  `LightMap._is_blocked`, FlowField.
- Glow is baked once at load from tile types only; no pulse (glow rebake is
  still open in TODO.md).
- Draw order today: tiles 1-10 (`sort_order`), doors 101 and 1600 when behind
  (`DoorManager.gd:18,24`), actors 1000-1500, LightMap darkness 2000, glow
  tint 2001, debug 4000.
- Movement is a two-half tween per tile, destination reserved, released at
  finish (`GridMover.gd:216-235`). Players stream their own position, enemies
  are host-owned and relayed; remote bodies are set straight from the stream.
- Costs: FlowField and Pathfinding are direction-independent (terrain costs
  since 2026-09-24); a conveyor needs direction-dependent cost.
- Joining a started mission is refused today, so "late joiner" means
  reconnect or a future feature: design snapshots, do not build sync yet.

## Tiers below cover the whole plan

Foundation items (S) unblock everything else. Route foundations sit in A and
vehicles in B because objects unblock them.

## S tier -- do first

- [ ] `actor` group, additive: `add_to_group("actor")` where players and enemies already join their groups, and switch only the both-groups loop in `GridMover.gd` (~142) to `actor`; leave the ~20 single-group call sites alone and migrate lazily. Keep `DebugMenu` protagonist / antagonist counts as they are (a2, a3)
- [ ] One draw-order table (`DrawOrder.gd` constants: floor, overlay, object, door, actor, door-behind, ceiling ~1800, darkness 2000, glow 2001, debug 4000) plus a `layer` field on objects (floor / overlay / object / ceiling). Replace the magic z numbers in `DoorManager`, `PlayerController`, `LightMap`, `DebugDraw`. Cheap, and keeps 2.0 possible (a1, a2, a3)
- [ ] Object manifest `game/objects/<type>.json` + `ObjectType` / `ObjectRegistry` (mirrors `DoorRegistry`: runtime record with id, cell, state, hp; ids are list positions from the seed) + a validator shared by the loader, DungeonMaker and a check script (same pattern as the Connector validator) (a1, a3). Sketch (a1): id, layer, placement modes allowed, size, blocks {walk, sight, shot}, art (folder, frames, fps) or boss-door style layers, light {color, radius, pulse}, interact, loot, destructible, alpha, tags. Behaviours are optional properties
- [ ] Room placement schema, cell-based so rotation is an integer transform: `{type, mode: wall|floor|free, cell, face, quarter, rotation, overrides, id}`; `wall` mode stores the wall cell + the face it hangs on (decided); `mode` checked against the manifest's allowed modes; overrides limited to whitelisted manifest fields (a1)
- [ ] `rotate_room` transforms objects (helper like the connector one; check all four rotations; free-mode pixels rotate about the tile grid: verify), the `#rN` rotation signature includes objects, DungeonMaker flip transforms them too (a1, a3)
- [ ] One-time migrator for the existing 187 objects: pixel positions become `free` at first, torches near a wall cell are snapped to `wall` by a script that writes a REPORT for a human to review, `format` bumped with a legacy-load warning (a1)
- [ ] `ObjectSpawner` step in `DungeonPainter` between `_paint` and `_place_doors`: a deterministic geometry pass like `DoorPlacer` (no rng) (a1)

## A tier

- [ ] Generic object RPC pair `request_object_act(id, action)` / `receive_object_state(id, state)` modelled on `set_door`; host validates range, state and line of sight from the SENDER's own position, never the client's claim (a3)
- [ ] Shared interact key (default E, ideally in the input map): nearest interactable within about 1.5 tiles that passes `LineOfSight.clear`, prompt label, 300 ms ask cooldown copied from the door one. Not tied to the hotbar (a3)
- [ ] Chest: interact + loot. Host rolls ONCE at open time (not at generation), stores the result in the object, broadcasts opened + result. Stub table `game/loot/<name>.json` with weighted `{id, weight, min, max}` until items exist (a3)
- [ ] Blocker registry: `ObjectRegistry` answers `blocks_walk / sight / shot` per cell and every existing query (`GridMover` x3, `LightMap._is_blocked`, FlowField) goes through one shared check; on open or death call the same `_changed()` (version bump + `FlowField.clear`). Wall-mounted objects never register (a1, a3)
- [ ] Destructible hits through the host: copy the enemy trio (`report_object_hit` / `_resolve_object_hit` / `receive_object_damage`), add `hit_objects_at(tile)` beside `hit_enemies_at` so melee and arrows both work; objects own an `EntityStats`. Note `_try_attack` bails if the target tile is blocked, so blocking objects need an exemption (a3)
- [ ] Deterministic randomness rule: object id = list position from the seed; anything random for gameplay (loot, destruction) is rolled host-only and synced; purely visual randomness (pulse phase) derives from the seed on every peer. No `randomize()` in placement (a1, a3)
- [ ] Light-source family: objects register runtime glow sources `{position, color, radius, pulse, owner}` through `rebake_around` (the open glow-rebake item), not a full re-bake. Pulse is a shader uniform or tween, never a per-frame re-flood. Wall torches seed glow on the wall face (`_flood_glow` seeds look compatible: guess, verify) (a1, a3)
- [x] Free-standing doors: room-level `doors: [{cell, orient, type, lock}]`, `DoorPlacer.place_free` as a second entry point, cells transformed with the room offset and rotation, appended AFTER connector doors so their ids do not shift; must not count as connectors in the assembler; DungeonMaker door tool (a1, a3) -- BUILT 2026-09-24 (written, not run in Godot) with a simpler shape than planned: room `doors: [{cell, orient h|v, width, type}]`, `DoorPlacer.place_free` appended after the connector doors, rotation and flip transform them, painter clears their walls, Dungeon Maker tool. No `lock` field yet (needs keys/items)
- [ ] DungeonMaker: object palette built from the registry (removes the hard-coded dict), `mode` toggle, wall-snap to the nearest wall face, overrides inspector (a1)
- [ ] Forced-movement hook on `GridMover` (`forced_step(dir, speed_scale)`; a belt only pushes a body that is idle, one tile per second, and any movement input cancels it: decided) sharing the wall / void / door / occupancy / reservation checks of `move_one_tile`, run only on the body's own authority so a conveyor needs no new sync; flyers and ghosts skip it via `_ignores_terrain()` (a2)
- [ ] Route data model: static `RouteRegistry` (cells -> `{dir, route_id, carrier}`, nodes and edges for junctions, `hub_room`, `switch_state`); direction is data so later carriers reuse it (a2)

## B tier

- [ ] Route generation: a post-pass over the placements with its own rng (`seed ^ ROUTE_SALT`, taken from the USED seed after `generate_with_retry`, not the original); hub picked from rooms tagged `route_hub` (fallback boss or treasure); no hub means no routes; lay routes along tree paths from the hub to N leaves, door to door inside rooms; corridor rooms are the easy first target (a2)
- [ ] Connector flag `route: true` (forced `door: none` in v1, so cart-versus-door is avoided); check it works through locked or sealed connectors (a2)
- [ ] Minecart as a host-owned node: relay `receive_cart_state(id, pos, edge)` unreliably, board / leave / switch reliably; riders pinned to the cart on every peer while `riding_cart` is set; rider input gated; board via the shared interact key with host validation of adjacency and capacity (a2)
- [ ] Junction switches host-authoritative, toggled by interact, included in snapshots (a2)
- [ ] Direction-dependent cost: optional `edge_cost(from, step)` in `FlowField._build_weighted` (the flood runs outward from the target, so the real move is neighbor -> cell) and a directional A* (verify `_compute_cost` override in 4.7); keep costs at 1.0 or above (a2)
- [ ] Enemies do not board carts in v1; belts still drift them through the same `GridMover` hook (a2)
- [ ] Ceiling objects: `layer: ceiling`, alpha 0.35, z about 1800 (between actors and the darkness so it is lit like everything else); fade only when the local player stands inside its footprint or room (a1, a3)
- [ ] Placed overlays use the same manifest with `layer: overlay` in the same `objects` array (tracks, decals); tile-bound overlays stay as they are (a1)
- [ ] Biome `defines.json` `objects: {density, allow, deny}` with a `replace` map (flesh swaps torches for green bulbs) and a per-biome `routes` block (a1, a2)
- [ ] Treasure rarity from room tags and depth, multiplying loot weights like `EnemySpawning._favored_weights` (a3)
- [ ] Snapshot functions (`ObjectRegistry.snapshot()`, `DoorRegistry.snapshot()`) and a `receive_dungeon_state` RPC; unused until joins are allowed (a3, a2)
- [ ] Chest open animation from a frame counter, like `DoorManager` (a3)
- [ ] Cart end of line: buffer stop ejects riders on the last cell; capacity as a cart property; debug overlay for route cells and the hub (a2)

## C tier

- [ ] `manual` carrier (rider chooses at junctions) (a2)
- [ ] Lifts, pistons, steam vents, moving floors as new carriers on the same hook: the steampunk biome (a2)
- [ ] Room-authored route lanes in room JSON, rotated like connectors (a2)
- [ ] Random decoration scatter driven by tags and density, seed-derived (a1)
- [ ] Manifest inheritance (`"extends": "torch"`) and hot reload of manifests in the editor (a1)
- [ ] Levers, signs, cracked walls (wall-tile swap plus `FlowField.clear` plus a LightMap blocked-cache invalidate) as later `interact` / destructible types (a3)
- [ ] Multi-floor: stay with one dungeon instance per floor and stairs as an instance swap; only the `layer` field is added now (a1, a3)

## Risks and things to verify

- Rotation centre for free-mode pixel positions; the editor may add an offset, so check saved positions are room-local (a1)
- Are the 148 torches actually near walls? Run an audit script before the migrator (a1)
- Object ids as list positions break if peers build objects in different orders; any rng in placement must come from the seed (a1, a3)
- `LightMap._blocked_cache` is cleared only inside a flood or bake; a destroyed object needs a version bump like doors (a3)
- Belt versus input: DECIDED input wins. Implementation note: the belt tick must only fire when the body is idle and no movement key is held, and must not chain steps at `tween.finished` (a2)
- Remote copies must not run the forced-movement hook (guard on authority) or bodies move twice (a2)
- Remote bodies snap with no interpolation, so a fast cart looks choppy (guess) (a2)
- Riders share a cell with the cart: exempt them in the occupancy check or the cart's own steps are refused (a2)
- Group migration: nothing should treat `protagonist` and `antagonist` as one total by accident (a2)
- Verify `peer_disconnected` handling for players inside a dungeon (a mid-ride disconnect must dismount) (a2)
- The `dedicated-host` test flag may change who "the host" is when applying hits (a3)
- 150 animated lit objects plus a flood per light may be costly; measure with `PerfMonitor` (a1)
- Tall objects (statues) may need the doors' behind-layer trick or a y-sort (a1)

## Questions for Orea

Objects and placement
1. ANSWERED: wall cell plus face (cells are data, tiles are derived visuals).
2. Is an object always one cell, or do we need multi-cell footprints (machines, big chests)?
3. Migrator: auto-snap near-wall torches, or produce a report for you to approve? (Recommended: report.)
4. Overrides per placement: whitelist of manifest fields, or free-form?
5. Are lights purely visual, or do they later affect enemy sight (stealth)?
6. Must decorations be identical on every client (seed-derived), or is host-owned plus sync fine for everything that is not purely visual?

Interaction, loot, destructibles
7. ANSWERED: chests block walking (mimic planned). Blocker registry needed.
8. Do enemies open free doors and destroy barrels, or only players?
9. Chest rolls at open time (recommended) or at generation?
10. Interact key: fixed E or configurable in the input map?
11. Who owns the loot while no inventory exists: a chat line, or a floating pickup?
12. Which rooms may hold free doors: all rooms, or only tagged ones?

Routes and carts
13. ANSWERED: idle bodies are moved one tile per second; a movement key overrides the belt.
14. Should enemies ever ride carts or belts on purpose (ambush)?
15. Can riders attack, be hit, be targeted?
16. Does a cart run on demand (boarding starts it), on a schedule, or only when a switch is thrown?
17. Purely generated routes, or can hand-made rooms author lanes too?
18. Does the hub need a required tag or role, hold a reward, and should the whole route be visible from the start or revealed?
19. Is a dungeon with no route acceptable in every biome (a per-biome `routes` block)?

Ceilings
20. Does a ceiling fade only when you stand under it (per object or per room), or is it always 35%?
