# Player Death — Adventurer/Chump Demotion (working name)

**Status: core mechanic decided (hardcore mode).** Reference material,
same convention as the other docs in this folder — update in place as
things change rather than leaving stale entries.

## Terminology

Player characters are **adventurers**, not "heroes" — deliberate choice.
They're diving into a dungeon for loot and progression, not saving the
land. Don't use "hero" in docs, UI text, or code comments for this.

## The idea

When a player's adventurer dies, they don't get benched for the rest of
the dive. They come back as a **chump/soldier** — a static, level-one,
minimally-equipped fallback character. A meat shield: still playable,
still in the party, but with none of the gear, levels, or skills the
adventurer had built up.

## Why

Answers "permadeath is too harsh for a friend group" without removing
stakes entirely. Losing your adventurer still costs something real, but
it doesn't remove the player from the session or leave them sitting out.

## Decided — hardcore mode (the default)

- **Revive window.** A dead adventurer can be revived any time before the
  dive ends — i.e. before the party extracts (climbs back out). Revived
  in time, the adventurer is back.
- **Permanent loss.** If the dive ends and that adventurer was never
  revived, they're gone for good. The player has to build a brand-new
  adventurer from scratch for future dives — nothing carries over.
- **The chump itself has no revive.** Only the original adventurer can be
  revived, and only within that same before-extraction window. Once
  you're playing the chump, that's the floor for the rest of this dive —
  there's no second fallback under the chump.
- **Chump loot isn't personal.** Anything picked up while playing as the
  chump doesn't go to that player's own stash. It goes into a shared
  "general pool" the whole party draws from at the end of the dive.

## Deferred idea

A **softcore toggle** has been floated, specifically for single-player —
not built or specified further. Hardcore (above) is the confirmed mode
for party play; this is a maybe-later, not a commitment.

## Not yet touched

- What happens to a permanently-lost adventurer's own gear/stash (does it
  join the shared pool like chump loot, or is it just gone) — not
  specified yet.
- Whether/how this interacts with the deferred antagonist/boss-lobby role
  in `design-goals.md`.
- Party-balance implications of one member being reduced to a meat
  shield mid-run.
