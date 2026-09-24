# Cathedral: the stress test

The cathedral is not a hand-designed biome. It exists to push generation,
rendering and enemy pathing harder than any other biome. It is the dungeon's
room set blown up to three times the size and dressed as a church: carpets,
pillars and pews.

For the room file format see [../README.md](../README.md). For how the
generator places rooms and what each room kind means, see the dungeon's guide
([../dungeon/README.md](../dungeon/README.md)). Every cathedral room is a
copy of a dungeon room, so the dungeon's piece list is also this one.

## How the rooms are made

Rebuilt 2026-09-24 by a script, from the 43 rooms in `../dungeon/`:

1. **Scaled 3x.** Every inside tile becomes a 3x3 block. The outer wall stays
   1 thick. `Dungeon_Combat_Hall_12x10` becomes `Cathedral_Combat_Hall_32x26`.
2. **Doors widen.** 1-wide dungeon doors become 3 wide, and 2-wide doors
   become 5 wide (one cell of the 6 is walled off). `wood_fold` doors fit 3
   to 5.
   - A doorway the dungeon left open (no `door`) gets `"door": "none"`.
   - `"any"` stays `"any"`.
   - `"wood"` is dropped, so the biome's `default_door` applies.
3. **Spawns triple.** Each dungeon spawn cell becomes 3 cells in the same
   3x3 block. Mazes, entrances and peaceful rooms have none, like the dungeon.
4. **Chests move with their block.**

Then the decoration:

| Room kind | Carpet | Shape |
|---|---|---|
| Boss | `floor_carpet_crimson` | Big rug in the middle |
| Treasure | `floor_carpet_gold` | Rug |
| Peaceful | `floor_carpet_violet` | Rug |
| Barracks, kill zone | `floor_carpet_verdigris` | Rug |
| Corridor | `floor_carpet_indigo` | Runner |
| Entrance, combat, side room | `floor_carpet_crimson` | Runner |
| Maze | none | Bare stone |

- **Runners** are 3 wide and go from each door to the middle of the room,
  keeping straight where they can.
- **Rugs** are a runner plus a rectangle in the middle, kept 2 tiles off the
  walls.
- Carpet only replaces smooth stone, never wood planks, dirt or grass.
- **Pillars** (`wall_smooth_stone`) line the walls of big rooms (250+ floor
  tiles), 3 tiles in. They are never placed in front of a door.
- **Pews** (`wall_wood_plank`) fill big rooms that have a runner. Boss rooms
  get none, to keep the arena open. Pews are rows across the runner, broken
  into benches with gaps. If any pew would cut the room in two, all of that
  room's pews are removed.

**The pews are a stand-in.** They are walls, not objects. Replace them with
real pew objects once the object system exists. `defines.json` says so in
its `"_comment"`.

## `Cathedral_Boss_Nave_100x100`

Kept from the first cathedral, as the second boss option. It is the Dungeon
Maker's maximum size. It keeps its own floor layout: a wood-plank cross, a
dirt centre and four chapels. It gets a crimson rug and pillars, keeps its 46
torches and 2 chests, and has no spawns.

## Numbers

- 44 rooms, 257 spawn cells. The kill zone has 36 and each scaled boss room 24.
- Rooms average about 700 tiles (flesh: about 250).

## `defines.json`

- `room_count` 25 to 40. That's roughly 18,000 to 28,000 room tiles a dive.
- `tag_weights` are the dungeon's: `corridor` 0.8, `maze` 0.6, `killzone`
  0.5, `peaceful` 0.7.
- `monsters` are skeleton archer 3 and demonic hamster 1.
- `default_door` is `wood_fold`. TODO.md notes this was a temporary switch
  from `iron` for door testing.

## Changing it

Don't hand-edit these rooms. Change the dungeon room, then re-run the
script. The script lives outside the repo. If the team wants it kept, it
should be added under `.claude/tools/` first.
