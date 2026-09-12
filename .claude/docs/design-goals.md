# RogueNet — Goals & Design Notes

This is reference material, not a rules file. Claude won't load this
automatically every session the way it loads `CLAUDE.md` — read it when
you need the fuller picture behind a decision, or point Claude to it
directly ("check `.claude/docs/design-goals.md`").

## Why this project exists
The primary goal is for the team to learn — programming, game design,
working with an engine, and working together on a shared codebase.
Shipping a finished game is a secondary goal. If a choice trades off
"the team learns something" against "the game ships faster," lean toward
the former unless the technical lead says otherwise for a specific task.

## Core design pillars
- **Roguelite-light dungeon crawler.** Procedurally generated dungeon
  runs, leveling, loot rarity, skill trees. No crafting — deliberately
  cut to keep scope manageable.
- **Town hub, not an open world.** The "town" map is a menu-equivalent —
  a place to prep, party up, and launch a dive. There's no persistent
  always-on world to maintain.
- **Turn/action-based dives.** Once a party enters a dungeon, combat and
  progression happen there; the hub itself isn't where gameplay happens.
- **Local-or-server networking, Terraria-style.** Not strictly
  server-authoritative. This keeps hosting simple for a friend group
  without dedicated infrastructure, at the cost of some netcode purity.
  Linux vs. Windows hosting differences aren't resolved yet — don't
  assume a specific implementation until this is nailed down.

## Confirmed-but-deferred features
- **Antagonist/"boss" lobby role.** Instead of joining the party for a
  dive, a player can opt to play as the dungeon's antagonist. Bot-
  controlled by default if no one opts in. The team wants this, and the
  technical lead has agreed to it — but it's explicitly *not* a near-term
  priority. Treat it as safe to postpone or scope down further unless
  someone says the priority has changed.

## Open tensions (not yet resolved — don't assume an answer)
- **Roguelite-light vs. narrative-heavy.** The technical lead prefers a
  tighter, more mechanical roguelite loop. Other teammates want to lean
  more into story/RPG elements. This hasn't been decided either way.
- **Hosting model specifics.** "Local-or-server, like Terraria" is the
  direction, but exact implementation (how a host exposes a game, what
  changes between Linux and Windows hosts) is still open.

## Team shape
- 3–5 friends. Most have little to no prior coding experience.
- The technical lead (repo owner) has the most experience and owns core
  systems; other teammates are expected to own content/text areas.
- One teammate tends to overscope projects — the technical lead manages
  this by keeping their own scope tight rather than trying to control
  the other person's ambitions directly.

## How to use this alongside CLAUDE.md
`CLAUDE.md` has the compact, always-loaded rules (behavior, tech stack,
current status). This file is for the "why" behind those rules and for
things that are true but don't need to be re-read every session. If the
two ever conflict, `CLAUDE.md` wins — update this file to match rather
than the other way around.
