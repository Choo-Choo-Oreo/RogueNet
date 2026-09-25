# World sound effects

Sounds the dungeon itself makes. Like the combat sounds, no JSON names a file: the file is
found by name, so adding or replacing a file is all it takes. All of them were synthesised
on 2026-09-25 (no licence to track) and are placeholders until someone picks better ones.

## Liquids: `water/`, `lava/`, `acid/`

Played by `scripts/entities/Wading.gd` when a creature on the ground walks through the floor of
the same name (`floor_water`, `floor_lava`, `floor_acid`), 10 dB quieter than its combat
sounds. Ghosts and fliers make none. Each folder has the same five files:

| File | When |
|---|---|
| `enter.wav` | stepping in from dry ground (or from another liquid) |
| `exit.wav` | stepping out |
| `step_1.wav` - `step_3.wav` | each step onto another tile of it, taken in turn |

A floor is a liquid because its folder has an `enter.wav`: a new liquid (`floor_tar`) only
needs a `tar/` folder. Every liquid also looks wet: bodies sink, and below the surface take the tile's
colour, with a pale rim, droplets and rings (`Wading.liquid_look`; how see-through it is
is the tile's `see_through`). Lava is a thick gloop with a sizzle, acid a fizz with bright bubbles.

## Doors: `doors/`

Played by `scripts/dungeon/DoorManager.gd` on every screen, at the door, when it starts to open
or close: `<door type>_open.wav` and `<door type>_close.wav`, else the type's first word
(`wood_fold` uses `wood_*`). A type with neither is silent. A sound may last as long as the
door takes to open, plus 0.4 s.

| Type | Open | Close |
|---|---|---|
| `wood`, `wood_fold` | latch click, creak | short creak, thud, latch |
| `iron` (a grate that lifts) | small clang, chain rattle, scrape | rattle, clang |
| `iron_sink` (bars that sink into the floor) | grinding rumble, thud | grinding rumble, clang |
| `dungeon` (the boss door) | boom, long stone slide, thud | long stone slide, heavy boom |
