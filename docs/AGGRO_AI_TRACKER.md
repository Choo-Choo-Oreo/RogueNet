# Aggro / Target Lock AI Tracker

Ideas from the 2026-09-23 design session (3 independent agent reviews + Orea's
own notes), ranked by implementation value. Mark items as they land. Sister
file: SURROUND_AI_TRACKER.md (crowd movement).

Status key: [ ] todo, [x] done, [~] built / needs playtest, [-] on hold

## Design rules (agreed by Orea + all 3 agents)

- Aggro comes from ABILITIES (taunt) and crowd control, NOT from damage. A
  back-line player shooting constantly must not pull enemies off a tank who is
  only intermittently in sight. No WoW-style threat tables.
- An alerted enemy keeps its target instead of re-picking the nearest player
  every tick. The first pick when it wakes up is the nearest player, so a tank
  standing in front wins passively.
- All lock timers use real time (msec), not frame counts -- waiting enemies
  skip frames, so frame counts are uneven.
- The "blocked by a player" rule is a temporary attack override; it must not
  overwrite the stored target (or it flip-flops when the blocker steps aside).
- Being crowded by other enemies is NOT "unreachable". Only a real wall-based
  failed route search counts.
- Roles context: Shield = tank, Sword = damage next to the tank, Healer,
  Support (buff/debuff), Leader. Roles are skill unlocks, not classes.

## S tier -- do first

- [~] Target lock: while alerted, keep the same player; release when the alert window ends, the target dies / becomes a ghost / disconnects (freed node)
- [~] Cheap validity check (freed node, ghost) placed BEFORE the idle-skip and _stuck early returns in MinionController._process, so boxed-in / waiting enemies still notice a dead or ghost target (agent 2)
- [~] Taunt ("Rawr") in the empty 4th hotbar slot, host-side: enemies in radius switch to the caster for ~4s, alert window refreshed, caster stays their target after expiry (Orea + all 3)

## A tier

- [~] Release when the target is unreachable by walls for ~4s. Path solve returns OK / FAILED / DEFERRED; only FAILED starts the timer (budget exhaustion and the failed-search cooldown must not count) (Orea + agent 2)
- [~] Leash: drop the target when it is more than ~24 tiles away, so an enemy doesn't chase a fleeing player forever (agents 1, 3)
- [-] Retarget lockout (not built: nothing switches the lock except exempt events; the 5s avoid-after-drop covers re-lock loops): no new switch for ~1.5s after any switch, except death / ghost / freed / a fresh taunt (agents 1, 2)
- [~] Blocked by a player: enemy failed to move, a non-target player is on its next tile for ~1s -> attack that player as a temporary ~1.5s override, stored target untouched (Orea + agents 1, 2)
- [~] Ranged enemies already in range never start the unreachable / blocked timers; flying enemies skip the unreachable logic entirely (agents 1, 2)
- [~] Taunt cap: nearest ~24-40 enemies per cast so one cast can't spike 500 at once (agents 1, 3)
- [ ] Two-player check: per-target FlowField / SurroundSectors keys still behave when enemies split between two players (agent 2)

## B tier

- [ ] Taunt feedback: ring pulse on cast, tinted "!" icon on pulled enemies, floating "x7" count (agent 3)
- [~] Taunt cooldown / radius / duration as data fields for tuning. Starting point: radius ~6 (agents said 5 and 8), 4s, ~12s cooldown
- [ ] Diminishing returns: repeat taunt on the same enemy within 10s has 50% duration (agent 3)
- [ ] Bosses / elites take half taunt duration (never fully immune) (agent 3)
- [~] Post-taunt handling: enemy keeps the taunter as its sticky target until normal release rules drop it, no snap-back (agent 1)
- [x] DECIDED (Orea): the window keeps decaying while locked on an unseen target; seeing it again resets to 10s. Was: should the senses window keep decaying while an enemy is locked on an out-of-sight target? Agent 1 says pause decay, agent 2 says the decay is the intended release. Decide when building the lock

## C tier -- later / needs other systems

- [ ] Aggro telegraph: thin line from each pulled enemy to the tank
- [ ] Tank "aggro released" flash and ~1s enemy attack pause when the tank dies
- [ ] Damage reduction for the tank that scales with pulled enemies (capped)
- [ ] Projectiles hit the first body in their line, so a tank blocks shots
- [ ] Shove-past / swap places with an ally, to avoid corridor deadlocks now that bodies are solid
- [ ] Extra role skills: Hold the Line (Shield), Riposte Peel (Sword), Mark Target (Support), Sanctuary Ward (Healer/Support), Rally Call (Leader)

## D / F tier -- not recommended

- [ ] Permanent hard aggro (D)
- [ ] Full taunt immunity for bosses (D) -- leaves the tank with no job
- [ ] WoW-style threat tables with 110% / 130% overtake (F for now) -- needs tuning and UI the game doesn't have
- [ ] Switching target to whoever last hit the enemy (F) -- rejected by Orea, back-line ping-pong

## Done this session (needs playtest)

- [~] Alertness icon replaces the previous one instead of stacking (Investigate -> Attack no longer overlaps) -- MinionController._show_alertness
- [~] Development biome now rolls all 14 enemy types at equal weight (test/lab/development/defines.json), to stress-test the AI across speeds, ranged and flying

## Built 2026-09-23 (all [~] need playtest)

MinionController: _lock / _override / timers, force_target(); MinionSenses.forget(); NetworkSync.report_taunt; PlayerController._try_taunt; slot 4 in player.json (radius 6, 4s, 12s cooldown, cap 24). Flyers are cosmetic-only in this codebase (they path like walkers) so no flyer exemption was needed.

## Hearing built 2026-09-24 (needs playtest)

Investigate now walks to a marker (a spot), not the player: `Sound.gd` (host-side fan-out), `SenseHearing.hears`, `MinionSenses.hear` / `investigate_marker`, `MinionController.can_hear` / `hear_noise`. Only an Attack locks a target now (before, Investigate locked the nearest player too). Footsteps come from `GridMover.stepped` (PlayerController), rocks from `ThrowVerb`; `NetworkSync.report_noise` sends a client's noise to the host.

## Sound muffling, room packs, sense debug 2026-09-24 (needs playtest)

Sound: `Sound.make` pre-filters listeners by straight-line distance (never more than the path cost), then one Dijkstra flood (`Sound.flood`) out to the largest budget; a minion hears when the cheapest cost to any tile of its body is <= `SenseHearing.budget(loudness)` = `range_tiles * loudness`. Muffle per tile from `TileType.muffle` (JSON `muffle`, default wall 3 / floor 1), closed doors `Sound.DOOR_MUFFLE` 3, no-floor cells INF. Tile JSONs are now loaded once and shared (`TileType.by_id`, used by GridMover and Sound). Packs: `_is_packmate` = same pack id, same room, within `PACK_RADIUS_TILES`. Debug: five sense toggles plus `show-minion-inspector`; `LineOfSight.blocked_at` gives the blocking cell for the sight line.

## Pack and patrol built 2026-09-24 (needs playtest)

Pack: creature JSON `"pack": "wolf"` (wolf, wolf_hellhound); `MinionController._alert_pack` runs when a minion steps up an alert level and calls packmates within `PACK_RADIUS_TILES` (16): Investigate shares the marker (`join_pack_investigation`), Attack shares the player (`join_pack_attack`); `last_trigger "pack"` stops the alarm chaining. Cells `pack_investigate` and `pack_attack`.

Patrol: `_patrol_step` replaced the old jitter wander (whose radius check never passed because home was read while the minion was still at (0,0)). Random goals within 8 tiles of home, inside the room, half speed, 1.5-4 s rests, give up after 8 s; only while a player is in the same or an adjacent room (`RoomGraph.is_near_any`, re-checked every 0.5 s; otherwise it sleeps cheaply). Re-homes when an alert ends. Cell `patrol_wanders`; the other sim cells turn patrol off (`MinionController.patrol_enabled`) so walking creatures do not wander into the player's light. Herd (same day): the unalerted packmate with the lowest instance id nearby leads (`_pack_leader`); the others pick goals within `PACK_SPREAD_TILES` (3) of its goal and re-pick when it changes. Works for any creature with a `pack` id. Cell `patrol_herd` (the sim opens the cell door, so wolves may walk out into the lab's big room). Not built: patrol routes between rooms.

## Background

- Today: MinionController._process re-picks _nearest_player() every tick; the 10s alert window (MinionSenses.ACTIVE_ALERT_SECONDS) belongs to the enemy, not to any player; note_hit() doesn't record who hit it.
- Hotbar: Sword, Bow, Magic, and an empty 4th slot -- planned test bed for the taunt.
