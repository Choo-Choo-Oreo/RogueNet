# Minions

One JSON file per minion. The file name minus `.json` is the minion's **id**,
used everywhere else (biome `monsters` tables, `favored_minion` in rooms, the
debug spawn tool). The full field-by-field format, with an example, is in the
root `README.md` under "Minions". Sprite PNGs and their animation JSON live
under `resources/gfx/entities/entities.antagonist/minions/<id>/`, not here.

Minions are found by scanning this folder **and every folder under it**, so a
new minion is just a new JSON dropped anywhere in here (for example a species
folder). The id is the file name, so it must be **unique across all of these
folders**; if two files share a name the first one found is used and a warning
is printed. Files that are not `.json` (this README) are ignored. A file under a
folder called `bosses` is a boss; everything else is a minion. There is no
`"boss"` field: the folder decides, so to make a minion a boss, move its JSON
into `bosses/`.

This file is the reference for what exists. Keep it in step when a minion is
added, renamed or retagged.

## Tags

Each minion has `"tags"`: what kind of creature it is. A tag has a main category
and an optional secondary one after a dot (`undead.skeleton`, `beast.rodent`).
A minion carries its most specific tag, and it also counts as the main
category. Rooms use tags to favor kinds of minion (`favored_minion`, see
`game/rooms/README.md`), and the dynamic monster scaling design can reuse them
later. The full list, what each means, and how to add one is in
[`game/TAGS.md`](../../TAGS.md). Reuse an existing tag before making a new one.

| Main | Secondary | Meaning |
|---|---|---|
| `beast` | plain, `beast.rodent`, `beast.canine`, `beast.insect` | Wild animals and animal-like vermin. |
| `humanoid` | none yet | People-sized folk with tools or magic that are not giants: goblins, orcs, witches. |
| `giant` | none yet | Huge humanoid brutes (ogres, yetis). |
| `undead` | `undead.skeleton`, `undead.ghostly`, `undead.ghoul` | Dead things that still move. |
| `demon` | none yet | Infernal or corrupted. Added on top of the creature's own tag; a creature that is only a demon (the imp) carries it alone. |
| `construct` | none yet | Made things that move: mimics, gargoyles. |
| `ooze` | none yet | Slimes and other blobs. |
| `plant` | none yet | Walking plants and fungi. |
| `elemental` | none yet | Living fire and the like. |

A creature's tags describe what it is, never which biome it lives in or how
strong it is.

## Every minion

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
| `goblin` | humanoid | 8 | 2 Physical | open | |
| `bee` | beast.insect | 3 | 2 Physical | none | Flies. |
| `ant` | beast.insect | 6 | 2 Physical | none | |
| `mimic` | construct | 14 | 4 Physical | none | Hops; the lid snaps open mid-hop. |
| `slime` | ooze | 10 | 2 Physical | none | Hops (squash and stretch). |
| `octopus` | beast | 8 | 2 Physical | none | |
| `toad` | beast | 7 | 2 Physical | none | Hops. |
| `imp` | demon | 5 | 2 Entropia, ranged (4 tiles) | none | Flies. |
| `orc` | humanoid | 16 | 4 Physical.Bludgeoning | open | |
| `skeleton_warrior` | undead.skeleton | 10 | 3 Physical | open | No black outline, to match the skeleton archer. |
| `mushroom` | plant | 6 | 2 Physical.Bludgeoning | none | |
| `moth` | beast.insect | 3 | 1 Physical | none | Flies. |
| `owl` | beast | 5 | 2 Physical | none | Flies. |
| `crab` | beast | 9 | 2 Physical | none | Walks sideways: moving left or right it still faces the camera. |
| `beetle` | beast.insect | 10 | 3 Physical.Bludgeoning | none | |
| `dragonfly` | beast.insect | 3 | 1 Physical | none | Flies. |
| `fire_spirit` | elemental | 6 | 2 Entropia, ranged (4 tiles) | none | Flies. Flickers. Uses entropia_bolt until a fire damage type exists. |
| `witch` | humanoid | 8 | 2 Entropia, ranged (4 tiles) | open | |
| `cat` | beast | 5 | 2 Physical | none | |
| `gargoyle` | construct | 14 | 3 Physical | none | Flies. Flies on the imp's wing flap, in stone. |
| `mandrake` | plant | 5 | 1 Physical | none | |
| `snake` | beast | 6 | 3 Physical | none | |
| `butterfly` | beast.insect | 2 | 1 Physical | none | Flies. |
| `ghost` | undead.ghostly | 5 | 2 Perditio | phase | Flies. Passes through closed doors like the wraith. |
| `penguin` | beast | 7 | 2 Physical | none | Waddles. No cold biome yet, so no biome table lists it. |
| `turtle` | beast | 16 | 3 Physical | none | Very slow (2 tiles/s), tough. |
| `spiderling` | beast | 5 | 2 Physical | none | |
| `yeti` | giant | 22 | 5 Physical.Bludgeoning | open | No cold biome yet, so no biome table lists it. |
| `mantis` | beast.insect | 8 | 3 Physical | none | |
| `scorpion` | beast | 9 | 3 Perditio | none | |
| `eagle` | beast | 6 | 2 Physical | none | Flies. Flies on the owl's wing flap. |
| `clam` | beast | 12 | 4 Physical | none | Hops; the shell snaps open mid-hop. |
| `zombie` | undead.ghoul | 12 | 3 Physical | open | |
| `lizardman` | humanoid | 11 | 3 Physical | open | |
| `minotaur` | beast | 60 | 6 Physical.Bludgeoning | open | Boss (lives in `bosses/`, first pass): picked through a boss room's `favored_antagonist` (same matching as `favored_minion`). Slow (3 tiles/s). `size_tiles: 3`: a 3x3 body (48x48 hitbox). Its position is its top-left tile; walls, doors, occupancy and pathing check every tile of the body, so it does not fit through a door or gap narrower than 3. First pass, untested. Not in any biome table: spawn it with `"minion": "minotaur"` on a boss room's spawn cell, or from the debug spawn tool. 8-direction walk art, 48x48, 8 frames at 10 fps (2026-09-24). |
| `dragon` | beast | 250 | 12 Physical.Piercing bite, 10 Physical.Bludgeoning | none | Boss, the ultimate one. `size_tiles: 7` (112x112), so it only fits big boss rooms. Slow (1.5 tiles/s). 8-direction walk art, crimson and gold, 8 frames at 10 fps. Stats are a first guess, untested. |
| `spider` | beast | 120 | 8 Physical.Piercing | none | Boss. `size_tiles: 5` (80x80). 3.5 tiles/s. 8-direction walk art, 8 frames at 10 fps. Stats are a first guess, untested. |
| `ogre` | giant | 90 | 8 Physical.Bludgeoning | open | Boss. `size_tiles: 4` (64x64). Slow (2.5 tiles/s); smashes walls like the minotaur. 8-direction walk art, 8 frames at 10 fps. Stats are a first guess, untested. |

The rows from `goblin` to `lizardman` were added on 2026-09-24. Each has 4-direction walk art
(4 frames, 16x16, `.aseprite` next to each PNG) under
`resources/gfx/entities/entities.antagonist/minions/<species>/`. Their stats and attacks are a
first guess, untested.

Attack types are damage type ids from `game/damage_types.json`. `doors` is
`none` (cannot open doors), `open` (can open them), or `phase` (passes through
closed ones).

## Where each minion spawns

A biome's `monsters` table in `game/rooms/<biome>/defines.json` says which
minions spawn there and how often (relative weights). A minion that no biome
lists never appears in a normal dive; it can still be spawned from the debug
menu. A room's `favored_minion` only boosts minions that are in that table.

## Adding a minion

1. Copy a similar minion's JSON, rename it (the file name is the id, lower
   case with underscores, subject first: `wolf_hellhound`, not `hellhound_wolf`).
2. Give it `tags`, using existing ones from `game/TAGS.md`.
3. Add its sprites under `resources/gfx/entities/entities.antagonist/minions/<species>/` (or `bosses/`).
4. Add it to a biome's `monsters` table so it actually spawns.
5. Add a row to the table above and to the "every minion" table in
   `game/TAGS.md`.
