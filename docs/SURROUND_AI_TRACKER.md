# Surround AI / Crowd Movement Tracker

Ideas from the 2026-09-23 design session (3 independent agent reviews + Orea's
own notes), ranked by implementation value. Mark items as they land.

Roles context (from Orea's old role list): Shield = tank (holds the front),
Sword = damage (next to the tank), Healer, Support (buff/debuff), Utility
(craft, post-1.0), Leader (coordinator). Roles are skill-unlock ideas, not
classes. A tank only works if bodies are solid, hence the S-tier blocking fixes.

Status key: [ ] todo, [x] done, [~] partly / needs testing

## S tier -- do first

- [x] Tile reservation so two creatures can't claim the same tile (all 3 agents) -- in GridMover.move_one_tile, playtested 2026-09-23
- [x] Living enemies block the player; ghosts pass through everything (Orea + agent 3) -- same check in move_one_tile, playtested 2026-09-23 (ghost pass-through not explicitly tested yet)
- [x] Forward slide: a rat with someone behind it shifts sideways to open a spot (Orea) -- playtested; per-rat 1.5-2.5s slide cooldown added to stop pairs swapping back and forth

- [ ] Multi-tile (2x2) enemies, promoted from C on 2026-09-23 (Orea) because boss AI depends on it. Occupancy only indexes the top-left tile, reservation holds one tile, and pathing / flow fields treat every body as 1 tile, so a 2x2 enemy can clip corridors and overlap others. Plan: size-aware GridMover.is_tile_blocked / is_tile_occupied (tile arg = top-left anchor), all footprint tiles in the occupancy index + reservation, FlowField keyed by target + size, re-centre sprite/collision by size, big enemies skip surround/slide and use a footprint-edge range check, spawning needs a free NxN area, plus a test map with 2-wide corridors. Build AFTER aggro lock stage 1. Unknown: how player attacks hit a big body. Orea's dev-room test (all 14 enemy types) showed no problems for 1x1 enemies

## A tier

- [x] One distance flood + 16 angular sectors; rats step toward the emptiest sector, then sidestep (agent 2) -- playtested 2026-09-23, crowd encircles the player. Replaced SurroundSlots (deleted); the forward-slide step was kept. Known: ~2 rats don't settle into a spot (unexplained, watch for it)
- [x] Cache a failed slot claim -- moot, slot claiming removed
- [x] Rebuild path fields only when the player changes tile; share one flood across slots -- one shared flood per target now, rebuilt only on tile change
- [~] Waiting rats skip the full AI tick (re-think every ~6 frames); relay enemy state only on change + 1s heartbeat (agent 3) -- built, needs playtest

B through F tiers are on hold (Orea, 2026-09-23).

## B tier

- [ ] Ring assignment with a stable per-rat angle, outer rings open as inner ones fill (agent 1)
- [ ] Bolt ring 2/3 slots onto the current slot system (agent 3)
- [ ] Reuse one alertness icon per enemy instead of one per state change; likely the boss-room node spike, unconfirmed (agent 3)
- [ ] Threat-based targeting so a tank can draw aggro instead of nearest-player (Orea's roles idea) -- parked until skills exist
- [ ] Alternate path-field neighbor order / 8-direction steps to remove row/column bias (agent 3)

## C tier

- [ ] Attack tokens: only N rats attack, the rest wait (agent 1)
- [ ] Separate "new leader" rule (Orea) -- redundant once sideways flow + forward slide exist

## D / F tier -- not recommended

- [ ] Potential fields / influence maps (D)
- [ ] Reynolds-style separation steering (D)
- [ ] Physics colliders / RVO avoidance (F)
- [ ] Optimal (Hungarian) rat-to-slot assignment (F)

## Observed playtest problems (2026-09-23)

- Crowd forms rectangular columns/blocks instead of a rounded multi-layer swarm
- Rats sometimes stack on one tile
- Player can walk over rats
- Boss-room run: fps ~150 -> ~55-80, process ~25ms, node count spike
