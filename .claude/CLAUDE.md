# Project: RogueNet

## Purpose of this file
Instructions for Claude Code when working in this repository. This file is
shared via git with the whole team — don't put personal preferences here.
If you want personal, non-shared settings later, create a `CLAUDE.local.md`
in the repo root and add it to `.gitignore`.

## What this project is
- Multiplayer, procedurally-generated dungeon-crawler RPG with roguelite
  elements: leveling, loot rarity, skill trees. Crafting is wanted later,
  once the basics are done; don't build it before then.
- A "town" map serves as the menu-hub. No persistent always-on world —
  players queue up ("dive") solo or in a party into turn/action-based
  dungeon runs.
- Networking model: local-or-server, similar to Terraria — not strictly
  server-authoritative. Exact Linux/Windows hosting implications aren't
  worked out yet; don't assume a specific netcode approach until this is
  settled.
- Optional lobby feature (deferred, low priority): instead of joining the
  party for a dive, a player can opt to play a "boss"/antagonist role
  against the rest of the party. Bot-controlled by default when no one
  opts in. This is confirmed as wanted but intentionally **not** a
  near-term priority — get core systems working first. Treat it as
  droppable/postponable unless someone says otherwise.
- Engine: Godot, using the **.NET-enabled build** (the version that
  supports C#). This is about keeping the option open, not a commitment
  to writing in C# — most of the team doesn't know C# beyond a crude
  level, so GDScript is likely to be the more common scripting language
  in practice. Don't assume code should be written in C# unless asked.

## How Claude should behave here
The main point of this project is for the team to **learn**, not to have
Claude build the game for them. Most of the team is new to programming.

- **Default mode: teach, don't implement.** When someone reports a bug or
  asks how something works, explain the cause and talk through the fix
  conceptually first. Only write or edit code when explicitly asked
  ("go ahead and implement it," "just fix it," etc.).
- **Exception for the technical lead** (repo owner): can ask Claude to
  implement directly for scoped bug fixes or small tasks. Even then,
  Claude should flag when a request looks like it's growing into a whole
  feature and check before building it out.
- **"Teach, don't implement" applies even to mechanical work**, like
  porting/translating an existing script from another language (e.g. a
  third-party C# reference implementation being converted to GDScript).
  Don't assume that because the logic already exists elsewhere, writing
  the `.gd` version doesn't count as "the code" — it still does. Only
  write it directly when explicitly told to (see exception above); don't
  infer permission from the task being low-judgment or reference-driven.
- **Never implement a whole feature or system unprompted.** Break broad
  requests into smaller pieces and confirm scope before writing
  significant code.
- For genuine "how does Godot do X" questions (not "what's wrong with my
  code"), point to the official docs:
  https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html

## No duplication
Duplicated code and duplicated data are a recurring problem here, and an LLM's
default is to add a fix next to what exists instead of looking for it. Do the
looking, every time:
- **Before adding code or data, search for something that already does it**
  and reuse or generalise it. Say what you found. One definition, referenced
  by id; a user of it overrides only what differs.
- **Do not store what can be derived** from something already stored (a flag
  the folder already tells you, a `kind` the keys imply, a count you can take).
- **Nothing is "for players" or "for minions" unless it truly differs.** Split
  by team only where behaviour differs; shared logic goes in the shared parent
  (see `docs/STRUCTURE.md`).
- **When touching a feature, also look for the same logic or data elsewhere**
  and report any copies, even ones outside the task; do not silently add a
  third.

## Folder layout
The layout, the rules behind it and what is still to move are in
[docs/STRUCTURE.md](../docs/STRUCTURE.md). Every folder under `game/` gets its own
README (what its files do, the format, what can and cannot happen).

## Adding game content
See [README.md](../README.md) for the data-driven content formats
(minions, rooms, biome config, tiles, doors, items, actions) — most new content goes in
`game/`/`resources/` as JSON + art, not code.

## Tech stack
- Godot Engine, .NET-enabled build (supports C#, but the team mostly
  works in GDScript in practice — see note above). The technical lead
  personally wants to build C# skills through this project, but that's
  not a team-wide commitment.
- Build command: _(fill in once established)_
- Test command: `godot --headless -s res://addons/gut/gut_cmdln.gd` (GUT; first run `godot --headless --import`; see `test/README.md`)
- Networking: Steam lobby through `SteamMultiplayerPeer` (GodotSteam), with
  the host as peer 1 running a listen server; singleplayer uses
  `OfflineMultiplayerPeer`. There is no ENet code. Minion spawning, AI, damage
  and doors are host-authoritative (see `singletons/NetworkSync.gd`). The
  lobby/Steam layer came from a downloaded template rather than being
  hand-written, so don't assume the team understands it well. Still
  undecided: a dedicated server (Steam has no headless peer), a persistent
  town, and late join -- see `TODO.md` and `TOWN_PERSISTENCE_RESEARCH.md`.

## Known team context
@.claude/memory/team-context.md