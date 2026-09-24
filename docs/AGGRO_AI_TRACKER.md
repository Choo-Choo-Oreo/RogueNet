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

## Background

- Today: MinionController._process re-picks _nearest_player() every tick; the 10s alert window (MinionSenses.ACTIVE_ALERT_SECONDS) belongs to the enemy, not to any player; note_hit() doesn't record who hit it.
- Hotbar: Sword, Bow, Magic, and an empty 4th slot -- planned test bed for the taunt.
