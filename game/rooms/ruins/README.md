# Overgrown Ruins: how to make rooms

The dungeon, long abandoned, with the forest eating through it. The rooms
are **the dungeon's own rooms**, made by a script instead of drawn by hand
(the same way the cathedral was made), in **two stages**:

- **Overgrown:** the forest has broken in. Grass through the stone, some
  trees growing out of the walls, a few walls fallen in.
- **Reclaimed:** mostly forest. Grass almost everywhere, the walls half
  trees, more of them fallen in, water pooled in the low spots.

Enemies are **the dungeon's and the forest's, mixed**: the dungeon's
skeletons, wraiths and rats are still here, and the forest's wolves and
bats have moved in. The further the forest has taken a room, the more it
belongs to the beasts.

This file covers the ruins' own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_enemy`,
per-cell `enemy`), see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms and describes each room's shape, and all of that applies here
too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Brick | `wall_cobble_brick` | Whatever is left of the dungeon's walls. |
| Trees | `wall_forest` | Growing through the walls in patches, and lone saplings on the floor. |
| Stone | `floor_smooth_stone` | Whatever floor the grass hasn't reached. |
| Grass | `floor_grass` | Spreading over the stone in patches. |
| Dirt | `floor_dirt` | Round the edges of the grass, and where a wall fell in (Overgrown). |
| Water | `floor_water` | Pools in the low spots. Slow, never within 2 tiles of an opening. |

| | Grass | Trees in the walls | Walls fallen in | Water | Saplings |
|---|---|---|---|---|---|
| Overgrown | ~40% | ~20% | ~10% | a little | a few |
| Reclaimed | ~80% | about half | ~30% | more | three times as many |

- **The dungeon's shape stays.** Each room keeps its dungeon room's size,
  openings and chests. Opening widths are the dungeon's.
- **The outer wall never opens.** Where it isn't brick any more, it's
  trees. Only inner walls fall in, and never beside an opening.
- **Saplings never block.** A lone tree goes only where all 8 tiles round
  it are open.
- **Openings carry the floor just inside them.**
- Overgrown rooms set `"base_floor": "floor_smooth_stone"`, Reclaimed
  rooms `"floor_grass"`.

## Ruins rules

1. **Sizes and openings are the dungeon's** (so sizes can be even here).
2. **No doors.** Every connector is `"door": "none"`, and `default_door` is
   `"none"`: the doors rotted away. The one exception is iron, which doesn't
   rot: the Treasure Armory (both stages) and the Overgrown Treasure Hoard
   keep the dungeon vault's free-standing `iron` door (a `doors` entry). The
   Reclaimed Hoard has none: the wall it hung in has fallen.
3. **Every connector is `"free": true`,** so any widths can join.
4. **Nothing unreachable.** Every floor tile connects to the openings.

## Enemies: dungeon and forest

Every spawn cell spawns one enemy. The dungeon's own spawn cells and
favoured enemies are not kept. The biome's `monsters` table mixes both
biomes: wolf 3, rat 2, skeleton archer 2, wraith 2, bat 1, blind rat 1,
and a rare hellhound (0.5).

There are three kinds of cell:

- **Packs.** Tight clumps (members within 3 tiles, 2 apart) out in the
  open, as far from the openings as they fit.
  - In **Reclaimed** rooms they are wolf packs: `"enemy": "wolf"`.
  - In **Overgrown** rooms they have no `enemy` and roll from the table,
    one by one, so a pack there is a mixed band: more often skeletons
    and wraiths than wolves.
- **Bats.** Single cells tucked into corners (3+ walls or trees round
  them). Each has `"enemy": "bat"`.
- **Rolled cells.** Spread out, with no `enemy`, so they roll from the
  table.

Each room with spawns tilts the table with `favored_enemy`:

| Stage | `favored_enemy` | Rolled cells come out roughly |
|---|---|---|
| Overgrown | `undead`, weight 2 | half undead (skeleton archers, wraiths), half beasts |
| Reclaimed | `beast`, weight 2 | four in five beasts (wolves, rats, bats, hellhounds) |

| Kind | Packs | Pack size | Bats | Rolled |
|---|---|---|---|---|
| Combat | 1 | 3 | 1 | 1 |
| Kill zone | 2 | 4 | 2 | 1 |
| Barracks | 2 | 4 | 1 | none |
| Boss | 2 | 4 | 2 | 2 |
| Maze | 1 | 2 | 1 | none |
| Treasure (guarded) | 1 | 3 | none | none |
| Side room | none | | 1 | 1 |
| Entrance, corridor, peaceful | none | | none | none |

Reclaimed rooms that have rolled cells get 1 more. The 86 rooms have 259
spawn cells between them: 81 pinned wolves (Reclaimed packs), 52 pinned
bats, and 126 rolled (Overgrown packs plus the rolled cells).

## Roles and tags

Each room keeps its dungeon room's `role` and `tags`.

### `defines.json`

- `room_count` 30 to 45.
- `default_door` `"none"`.
- `tag_weights` are the same as the other new biomes:
  - `corridor` 0.7
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7
- `monsters`: wolf 3, rat 2, skeleton archer 2, wraith 2, bat 1, blind
  rat 1, hellhound 0.5. Reclaimed wolf packs and the bats are pinned on
  top of the table.
- `music`: The Lone Forest (the forest's track).

## Current piece set (2026-09-24)

86 rooms: every dungeon room as `Ruins_<Room>_Overgrown_<W>x<H>` and
`Ruins_<Room>_Reclaimed_<W>x<H>`. There is no plain version: the plain
room is the dungeon's. See [../dungeon/README.md](../dungeon/README.md)
for what each room is.

## Adding a new room

A ruins room is a dungeon room with the forest let in, so the easiest way
is to **make the dungeon room first**, then make its two stages from it:

1. **Copy the dungeon room's JSON** twice, as `..._Overgrown_` and
   `..._Reclaimed_`, and set `"biome": "ruins"` and the new `id`.
2. **Let the forest in.** Paint grass over the stone in patches, dirt round
   the edges, and a small pool or two away from the openings. Turn some
   brick into `wall_forest`, and remove a few inner wall tiles (never the
   outer wall, never beside an opening). Do more of all of it for
   Reclaimed.
3. **Add saplings** only where all 8 tiles round them are open.
4. **Set the connectors** to `"door": "none"`, `"free": true`.
5. **Add the spawns** using the table above, and set `favored_enemy`
   (`undead` for Overgrown, `beast` for Reclaimed, weight 2).
6. **Load a ruins dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
