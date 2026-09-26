# Dungeon Generation Tracker

Ideas from the 2026-09-26 generation audit (130 dungeons: 13 biomes x seeds 1000-1009,
built with the real `DungeonAssembler` and `DoorPlacer`, one review agent per biome) plus
Orea's direction. Mark items as they land. Nothing here is built yet.

Connector format, door types and door runtime live in `CONNECTORS_TRACKER.md`; this
tracker is about how rooms are CHOSEN and ARRANGED. Where an item reopens something there,
it says so instead of repeating it.

Status key: [ ] todo, [x] done, [~] built / needs playtest, [-] on hold

## Orea's direction (the design goal)

- Connections should be logical: a room is next to another for a reason, not because it
  was the first thing that fit.
- Layouts should have intent. Playing the same biome over and over, a player should build
  an intuition for how THAT biome is put together and how it differs from the others:
  "in the sewer the mains run straight and the crawls come off them", "in the catacomb the
  tombs are off the galleries and the boss is at the end of the processional". Every run
  is different, but recognisably the same kind of place.
- Dungeon seed 1009 was fun (a long committed road, boss and treasure far apart in
  opposite directions, an outline that is not a plus). 1002 felt natural (reads as a
  building: central hall, packed rooms, one antechamber before the boss). Keep both
  feelings on purpose; do not keep the bug that made 1009.
- Dives end by walking back out alive (see the dive end condition), so the return trip is
  part of the design, not dead time.

## Current state (found in the audit)

What already holds in all 130 maps: every room reachable, no blocked joints, no overlaps,
boss and treasure always present, no route forced across lava or acid.

How the generator works today (all in `scripts/dungeon/DungeonAssembler.gd`):
- Growth is breadth-first (`open_connectors.pop_front()`), so maps fill a ring around the
  entrance: plus shapes, max depth only 3-7 hops even with 40 rooms.
- `_join_shifts` tries the centred position first; with centred doors on odd-sized rooms,
  every child lines up on its parent's axis: straight spines.
- Rooms are packed flush (a rect just must not overlap), so neighbours share walls, often
  with sealed doors facing each other.
- Every room has one parent: the layout is always a tree, and `RoomGraph` assumes that.
- Nothing about a room's neighbours is chosen: the first room in the weighted shuffle that
  fits geometrically wins. That is the missing "intent".

Numbers from the audit:

| Problem | How often |
|---|---|
| Treasure hangs directly off the entrance | 64 / 130 (49%) |
| Same treasure room every time | 9-10 of 10 in every biome |
| One-door rooms never placed | e.g. sewer 27 of 111 room files, void 13, flesh 10, all of catacomb's tombs |
| Boss at depth <= 1 | 3 / 130 (mine 1005, manor 1009, acid 1007) |
| Room count far over `room_count.max` | 5 / 130 (dungeon 1009: 120 rooms vs 30) |
| Unintended iron doors | manor: 63 of 306 doors |

Full write-up: `GENERATION_CRITIQUE.md` and the per-biome reviews (currently in the session
scratchpad; say if they should be copied into `docs/`).

## S tier -- bugs, do first

- [ ] Boss rotations are one boss. `boss_ids` holds every rotation (`Pit`, `Pit#r1`...) and
  each is tried against every dead end before the next rotation gets a turn, extending
  corridors each time. Try all rotations of the picked boss at each dead end, then move
  shallower (acid, catacomb, dungeon reviews)
- [ ] Boss corridor extension rolls back: a chain that does not end in the boss is removed,
  extension rooms count against `room_count`, corridors are picked by weighted random
  (bends and forks included, not the alphabetically first), and the chain does not always
  continue from `locked_connectors[0]`. Skip stubs whose width no boss door can match (mine).
  Causes the 120-room dungeon 1009, cave 1002's straight shafts, mine 1002's staircases
- [ ] The entrance's sealed doors are never a boss or treasure spot
  (`_seal_random_entrance_doors` output is depth 0 and nearly always has free space)
- [ ] Treasure placement is random and deep: random among treasure rooms, a dead end at
  mid-to-deep walking distance, off the boss route. Today `_place_any_locked` walks
  placements from index 0 and ids in sorted order with no RNG. Replaces the open
  `TODO.md` line on treasure file-name order
- [ ] Manor door fallback: a 3-wide `wood_fold` opening joined to a 1-wide passage falls
  back to the first type by name that fits (`iron`). Step down within the tier
  (`wood_fold` -> `wood`), or let the narrow side's choice win (`DoorPlacer._fit`)
- [ ] Corridor weight applied once: `_room_weight` multiplies the role weight by every tag
  weight, and corridor rooms have role `corridor` AND tag `corridor`, so a written 0.7 is
  really 0.49 (dungeon: 0.64)

## A tier -- intent (Orea's direction)

- [ ] Critical path first. Grow the entrance-to-boss path as a depth-first chain, with a
  target length in WALKING TILES (per biome, in `defines.json`), then fill branches
  breadth-first off it. The boss is placed at the end of that path, not "the deepest dead
  end that fits". Fixes shallow maps, plus shapes, and the 99-468 tile boss spread in
  cathedral (ruins, cathedral, forest reviews)
- [ ] Biome layout grammar: one small `layout` block per biome's `defines.json` that says
  what shape the biome makes, so each biome is recognisable run after run. Candidate
  shapes, to be decided per biome (open question 1):
  - spine and ribs: a straight main line with side branches (sewer mains, mine shaft)
  - processional: one long approach, rooms hung off it (catacomb, cathedral)
  - hub and wings: a central hall with wings of different purpose (manor, dungeon 1002)
  - winding: a path that keeps turning, few straight runs (cave, forest, flesh, acid)
  - islands: clusters joined by bridges (void)
- [ ] Zones by depth: rooms say which part of the dive they belong in (`zone`: outer /
  middle / inner, or a depth range). The generator only places a room in its zone. Gives
  the "the deeper you go, the more X" read players can learn. Also fixes ruins, where
  Overgrown and Reclaimed are mixed 50:50 at every depth instead of the forest taking over
  deeper in
- [ ] Connection rules: a room can say what it connects to (`connects_to` / `never_next_to`
  by tag or role). For example: side rooms only off corridors or galleries; a sewer crawl
  never opens into a main's water channel; a boss has an antechamber; tombs hang off
  galleries; kitchen next to the dining hall. Rooms that fit geometrically but break a rule
  are skipped
- [ ] Every branch ends in something: a dead end is capped with a one-door room (pocket,
  tomb, closet, side cell) or the treasure, never a corridor running into a sealed wall.
  Replace the "one-door rooms last" rule in `avoid_dead_ends` with a lower weight plus
  "cap leftover dead ends before sealing". Brings back the unused rooms
- [ ] Boss doors actually appear (added 2026-09-26). Drawing is built: `DoorManager._boss_layers`
  draws frame (by wall), leaves (by tier) and overlay (above creatures) from
  `resources/gfx/doors/doors.boss/`, and the `dungeon` door type exists
  (`game/doors/dungeon.json`, 4-5 wide). It never shows because:
  - no boss room connector asks for `door: "dungeon"` (they say `any`, `none` or `iron`);
  - boss connectors are 2 or 3 wide in 11 of 13 biomes, and the art is W4 / W5 only;
  - sewer's 5-wide boss connectors are `free`, so the joint shrinks to the smaller room's width;
  - cathedral's are 5-wide and exact, but `any`, so the biome's `wood_fold` wins.
  Plan: a 4-5 wide boss connector asking for `dungeon`, joined only to a room with a matching
  exact connector. That is the boss antechamber from the connection-rules item and the
  signposting item: the widest door in the dive, always in front of the boss. Leaves are
  always `wood` today (the tier comes from `dungeon.json` `"tier"`), so bronze / silver /
  gold never show: open question 7. Gate behaviour (lock on entry, open when the boss
  dies) is "boss gate" (B, on hold) in `CONNECTORS_TRACKER.md`: open question 8
- [ ] Entrance exits on purpose: how many of the entrance's doors stay open is a biome
  setting, not `_seal_random_entrance_doors` chance. One open exit gave forest 1009 and
  dungeon 1007 their single-snake maps by accident

## B tier

- [ ] Loops with a purpose. After growth, open some sealed door pairs that face each other
  or shared walls (ruins can show them as fallen walls). Priority: a return shortcut from
  the boss side back toward the entrance, because the dive ends by walking out.
  `RoomGraph` must accept more than one neighbour per room (today it is a tree). Gives
  flanking, regrouping, and fewer chokepoints for AI chases. Open question 3
- [ ] Signposting players can learn: consistent tells that point to the boss and treasure,
  e.g. the critical path is the widest route, iron doors only on vaults and bosses (needs
  the S-tier door fix), a boss antechamber, a landmark room halfway. Decide per biome
- [ ] Off-centre joints. `_join_shifts` always tries centred first; let free joints
  sometimes pick start / end or another shift from the seeded RNG. Reopens "best-fit offset
  search" (B, on hold) in `CONNECTORS_TRACKER.md`; the audit shows centring is the main
  reason maps look like a grid
- [ ] Draw fairness: weight the draw per room, not per rotation. `with_rotations` drops
  rotations that look the same, so a symmetric room is one entry and an asymmetric one up
  to four. Plus a per-map repeat limit per room id (sewer Confluence 33 times in 10 maps,
  forest Old_Oak 30, volcano 1003 Cinder_Cone 6 in one map)
- [ ] Mazes are not junctions on the critical path unless the biome wants it: 4-door mazes
  become hubs today and the party walks through them twice (manor 1000: three in a row)
- [ ] Spacing between rooms where the biome wants it (rock between caves, void between
  islands) instead of always flush: fewer "should connect" walls

## C tier -- content and later

- [ ] L- and T-shaped and off-centre door layouts on straight-through feature rooms (acid:
  26 of 42 are straight-through, volcano: 33 of 36). Room data, not code
- [ ] Cathedral: the 3-wide and 5-wide sets only meet through a few Tap and Entrance_Wings
  pieces because no connector is `free`. Cathedral is a stress test, so only if it matters
- [ ] Repeatable audit: keep the map audit (images + stats) as a script under `test/sim/`,
  reusing `DungeonPainter` instead of the scratch copy of its paint rules, so every change
  here can be checked against the criteria below. Needs Orea's OK to add a script. Ties to
  `AUTOMATED_TESTING_TRACKER.md`

## Acceptance criteria (measured with the audit, 10 seeds per biome)

Bugs:
- Room count within `room_count` in 100% of maps
- Treasure never attached to the entrance; boss never at depth <= 1
- Every treasure room of a biome appears at least once in 30 seeds
- No unintended iron doors (iron only where a connector or room asks for it)
- Still true: every room reachable, no blocked joints, no forced hazard on the boss route

Intent:
- Boss walking distance inside the biome's target window in every map
- Share of room files never used below a set limit (e.g. 10%), one-door rooms included
- No bare dead ends: every leaf is a room meant to be one, or the treasure
- Recognisable: shown grey silhouettes only (no floor colours), a player can tell which
  biome a map is from its shape. Orea's call, by eye
- Same biome, different seeds: different maps, same family (Orea's call, by eye)

## Suggested build order

1. S tier together: small, local changes in `_place_farthest` / `_place_any_locked` /
   `DoorPlacer._fit` / `_room_weight`; they remove the bugs without changing the feel.
2. Repeatable audit (C), so every step after this is measured, not guessed.
3. Critical path first, then the per-biome layout block (A): the biggest change in feel.
4. Zones and connection rules (A), one biome at a time, starting with the one whose
   grammar is clearest (sewer or catacomb).
5. Dead-end capping and entrance exits (A), then loops (B), then signposting (B).

## Open questions for Orea

1. Which layout shape does each biome get? (the list in A tier is a suggestion)
2. Target boss distance in walking tiles per biome, and should it scale with party size?
3. Loops: how many per map, and should the return shortcut be one-way (opens from the boss
   side only) so it can't skip the dive?
4. Should the 1009 "long road" be its own layout shape some biomes use, or a rare variant
   any biome can roll?
5. Same seed, same map is already true. Should a biome also have fixed landmarks (a room
   that is always there, like a sewer outfall), or only a fixed grammar?
6. Where should `zone` and `connects_to` live: on each room file, or as tag rules in the
   biome's `defines.json` (fewer places to edit, per the no-duplication rule)?
7. Boss door leaf tier (wood / iron / bronze / silver / gold): picked by what? The boss's
   difficulty, dive depth, the biome, or a field on the boss room?
8. Boss door behaviour: an ordinary door (opens on approach, closes after 2 s, as now), or a
   gate that locks behind the party when the fight starts and opens when the boss dies?
   And is it one boss door per biome style, or the same for every biome?
