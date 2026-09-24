# Enemies

One JSON file per enemy. The file name minus `.json` is the enemy's **id**,
used everywhere else (biome `monsters` tables, `favored_enemy` in rooms, the
debug spawn tool). The full field-by-field format, with an example, is in the
root `README.md` under "Enemies". Sprite PNGs and their animation JSON live
under `resources/gfx/entities/entities.enemies/<id>/`, not here.

This file is the reference for what exists. Keep it in step when an enemy is
added, renamed or retagged.

## Tags

Each enemy has `"tags"`: what kind of creature it is. A tag has a main category
and an optional secondary one after a dot (`undead.skeleton`, `beast.rodent`).
An enemy carries its most specific tag, and it also counts as the main
category. Rooms use tags to favor kinds of enemy (`favored_enemy`, see
`game/rooms/README.md`), and the dynamic monster scaling design can reuse them
later. The full list, what each means, and how to add one is in
[`game/TAGS.md`](../../TAGS.md). Reuse an existing tag before making a new one.

| Main | Secondary | Meaning |
|---|---|---|
| `beast` | plain, `beast.rodent`, `beast.canine` | Wild animals and animal-like vermin. |
| `undead` | `undead.skeleton`, `undead.ghostly`, `undead.ghoul` (reserved) | Dead things that still move. |
| `demon` | none yet | Infernal or corrupted. Added on top of the creature's own tag. |

A creature's tags describe what it is, never which biome it lives in or how
strong it is.

## Every enemy

| Id | Tags | Health | Attack | Doors | Notes |
|---|---|---|---|---|---|
| `bat` | beast | 3 | 1 Physical | none | Fast (7.5 tiles/s). Wings animate continuously. |
| `bat_echo` | beast | 3 | 1 Physical | none | Bat with a `senses` override. |
| `hamster` | beast.rodent | 4 | 1 Physical | none | |
| `hamster_flying` | beast.rodent | 4 | 1 Physical | none | Wings animate continuously. |
| `hamster_demonic` | beast.rodent, demon | 8 | 2 Entropia, ranged (4 tiles) | none | |
| `leech` | beast | 5 | 1 Physical | none | Slow (2.5 tiles/s). |
| `leech_flesh` | beast | 6 | 1 Physical | none | Coloured to hide against flesh floors and walls. Meant to hunt by taste and touch; taste is not built, so today it is touch-only. |
| `rat` | beast.rodent | 5 | 1 Physical | none | Uses the default move speed. |
| `rat_blind` | beast.rodent | 5 | 1 Physical | none | Sight switched off. |
| `rat_toothless` | beast.rodent | 5 | 1 Physical | none | Sight range overridden (see its file). |
| `skeleton_archer` | undead.skeleton | 7 | 2 Physical, ranged (4 tiles) | open | Can open doors. |
| `wolf` | beast.canine | 10 | 3 Physical | none | |
| `wolf_hellhound` | beast.canine, demon | 9 | 3 Physical | none | Meant to track by smell; smell is not built yet. |
| `wraith` | undead.ghostly | 6 | 2 Perditio | phase | Passes through closed doors without opening them. Meant to see through walls at short range; not built yet. |
| `minotaur` | beast | 60 | 6 Physical.Bludgeoning | open | Boss (`"boss": true`, first pass): picked through a boss room's `favored_antagonist` (same matching as `favored_enemy`). Slow (3 tiles/s). `size_tiles: 2`: a 2x2 body (32x32 hitbox). Its position is its top-left tile; walls, doors, occupancy and pathing check all four tiles, so it does not fit through a 1-wide door or gap. First pass, untested. Not in any biome table: spawn it with `"enemy": "minotaur"` on a boss room's spawn cell, or from the debug spawn tool. Art is a placeholder. |

Attack types are damage type ids from `game/damage_types.json`. `doors` is
`none` (cannot open doors), `open` (can open them), or `phase` (passes through
closed ones).

## Where each enemy spawns

A biome's `monsters` table in `game/rooms/<biome>/defines.json` says which
enemies spawn there and how often (relative weights). An enemy that no biome
lists never appears in a normal dive; it can still be spawned from the debug
menu. A room's `favored_enemy` only boosts enemies that are in that table.

## Adding an enemy

1. Copy a similar enemy's JSON, rename it (the file name is the id, lower
   case with underscores, subject first: `wolf_hellhound`, not `hellhound_wolf`).
2. Give it `tags`, using existing ones from `game/TAGS.md`.
3. Add its sprites under `resources/gfx/entities/entities.enemies/<id>/`.
4. Add it to a biome's `monsters` table so it actually spawns.
5. Add a row to the table above and to the "every enemy" table in
   `game/TAGS.md`.
