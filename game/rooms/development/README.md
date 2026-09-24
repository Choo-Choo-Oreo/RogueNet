# Development: a test map

Not a real biome: a place to try creatures and AI. Pick "development" in the location picker.
It always builds the same thing, whatever the seed: `room_count` is 1, and the one big room
is an **entrance** room, which is never rotated and is where you start. Everything else the
generator needs (a boss room and a treasure room, so it does not retry) is a 5x5 stub on
either end of the hub. No minion spawns from a table (`monsters` is empty); every creature is
pinned to a spawn cell in a test cell.

## The layout

A long central corridor (the hub, lit by torches) with test cells in a row above and a row
below. Every cell has its own wooden door onto the hub, so nothing wakes until you open it.
Door widths are 2 (3 for the swarm), so the Minotaur fits. Teleport with the debug tools to
reach a far cell.

| Cells | What they are for |
|---|---|
| `minion_<id>` (14) | One of each creature alone in a plain room, to see it on its own. |
| `bug1_spawn_fit` | The Minotaur pinned in a 1-wide nook it cannot stand in, and a rat beside a hole in the floor. |
| `bug1_no_room_for_boss` | The Minotaur pinned in the middle of a sealed 17-long 1-wide corridor, with no 2x2 spot within 6 tiles: it must be skipped, never spawned inside the walls. |
| `bug1_hole_band` | A chasm across the room with a bridge at one side and a rat on each side: nobody may walk on the holes. |
| `bug2_two_wide_gap`, `bug2_one_wide_gap` | A rat and the Minotaur chasing you through a 2-wide gap, then a 1-wide one (the flow field is shared between body sizes). |
| `bug6_boss_blocks_gap` | An unbreakable (bedrock) wall with a 1-wide gap on your row; the Minotaur stands in front of it and the rats are behind it. It must step aside so the rats get through. |
| `bug3_smash_plain`, `bug3_smash_door`, `bug3_smash_pillar` | Wall smash: a solid wall, a closed door in the way, and pillars with a way round. |
| `bug4_corridor_archer`, `bug4_open_archer` | An archer with rats queued behind it, in a 1-wide corridor and in the open. |
| `bug5_boss_crowd` | The Minotaur idling among rats (boss zone flicker). |
| `terrain_lava`, `terrain_water`, `terrain_acid` | A hazard band with a stone way round; a wolf, rat or hound must route around it, a flyer may cross. |
| `doors_widths` | Minotaur, archer, rat and wraith behind 1, 2 and 3 wide wooden doors. |
| `swarm_rats` | About 60 rats in one room, for performance. |
| `manual_*` (4) | For you to try by hand, things the headless sim cannot judge; see below. |

## Manual cells and the Test Lab

Run `test/lab/TestLab.tscn` (right-click it in the editor, Run). It loads this biome with seed 1 and
puts a panel over the game: the cell you are at, what it is, what to try, what counts as a bug, a
live readout of the creatures, and a button that copies a bug report. The text for every cell is
`NOTES` in `generate_hub.py`, beside the cell it describes. The `manual_*` cells are the ones only
you can judge; the sim does not check them.

## These are regression tests

`test/sim/dev_sim.gd` plays these cells without a window and checks what is written down for each
(`REACH`, `MAY_SKIP` and `ZONE_CHANGES_MAX` in `generate_hub.py`; every cell also fails if a creature
stands on a wall, void or no-floor tile). **Never delete a cell after its bug is fixed.** It stays
as the check that the bug does not come back. See `test/sim/README.md`.

## Changing it

The hub file is generated: edit `generate_hub.py` (each cell is a few lines of text; `#` wall,
`.` floor, `L` lava, `~` water, `A` acid, a space is a hole in the floor, and a letter is a
creature pinned to that tile) and run it from the repo root:

```
python game/rooms/development/generate_hub.py
```

It deletes and rewrites the `Development_*.json` files. The Dungeon Maker can open the result
too, but a saved edit there would be overwritten the next time the script runs.
