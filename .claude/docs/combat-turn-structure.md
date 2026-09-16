# Combat Turn Structure — Party/Monster Phases

**Status: draft.** Written at the end of a design discussion session as a
place to pick up from. Same convention as `design-goals.md` and
`dungeon-assembly-plan.md` — reference material, not a rules file.

## The decision

Combat is neither real-time nor strict single-actor alternating turns.
The shape is:

1. **Party phase** — every party member submits their action for the
   round at the same time (this is where player coordination happens).
2. The party phase resolves fully; positions/results are locked in.
3. **Monster phase** — monsters act based on the party's now-final state
   from step 2.
4. Repeat.

This is still accurately covered by `design-goals.md`'s existing
"turn/action-based dives" pillar — no change needed there. This doc just
records the specific shape now that it's been worked out.

## Why not real-time

Real-time (TomeNet-style) is the usual way multiplayer roguelikes dodge
lockstep problems, but that's specifically because those games are
persistent shared worlds with no natural sync point. RogueNet's dives are
instanced and party-scoped, so that constraint doesn't apply — there's
already a clean sync point (the phase boundary).

Separately: the current movement prototype (`scripts/tim.gd`,
`mouse.gd`) *looks* real-time because movement tweens smoothly between
tiles, but the underlying logic is already tile-locked — one tile per
input, gated until the tween finishes; the enemy acts once per a 1.2s
`Timer`, not per frame. No hitbox/`Area2D`-based damage exists anywhere;
`Health.gd` is a plain `take_damage(amount)` call. The smooth slide is
animation polish, unrelated to whether the decision loop is real-time.

## Why not full WEGO (simultaneous party *and* monsters together)

Resolving both sides in the same window creates real ambiguity — e.g.
does a fleeing player escape a monster's attack this tick or not — that
needs explicit tie-break rules (speed/initiative) to answer. Sequencing
party-phase-then-monster-phase removes that ambiguity for free: monsters
always act against the party's already-resolved final position.

## What that trade gives up, and how to get it back later

Strict sequencing removes the "nobody knows what anyone else will do"
tension that made simultaneous resolution interesting in the first place
(the Diplomacy comparison). If that's wanted later — most likely relevant
to the deferred antagonist/boss-lobby role in `design-goals.md` — the
standard fix without reintroducing full simultaneous resolution is a
**telegraph**: an attacker announces a target during its phase, but it
doesn't resolve until the party's *next* phase, giving them one more
window to react. This is how most turn-based tactics games fake
real-time dodge tension without actual simultaneity.

## Within-phase conflicts

The party phase is simultaneous only *among teammates*, not against
monsters — so the only conflict-resolution needed is the ordinary case of
two players choosing the same tile, not cross-side simultaneity. Small,
well-understood problem; not yet designed.

## Open, not yet decided

- Exact rule when two party members' actions collide (e.g. both move to
  the same tile).
- Whether a phase ends when everyone's submitted, or on a timer.
- Whether monster targeting happens instantly on phase-resolve, or is
  itself a decide-then-resolve step (relevant if telegraphs get added).
