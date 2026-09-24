# Forest biome: how to make rooms

Old woods with no doors anywhere. Every room is a **landmark**, a place
you could name: a pond, a fallen giant of a tree, a wolf den, a ring of
standing stones. Every landmark also comes **Overgrown**: the same place,
bigger and wilder, with a second pond, another fallen trunk or an extra
ring of mushrooms. Enemies come in **packs**, mostly wolves, so a fight
starts all at once rather than one enemy at a time.

This file covers the forest's own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_enemy`),
see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Trees | `wall_forest` | Outer walls, thickets, bramble, lone trees. |
| Rock | `wall_rough_cave` | Boulders, standing stones, the ravine sides, bat roosts. |
| Timber | `wall_wood_plank` | Anything built or fallen: the beaver dam, the hunter's shack, fallen trunks, the hollow tree's bark. |
| Dirt | `floor_dirt` | The normal floor, under the trees and along trails. |
| Grass | `floor_grass` | Open ground away from the trees. |
| Water | `floor_water` | Ponds, streams, marsh, bog. Slows movement but never blocks it. |
| Planks | `floor_wood_planks` | Log bridges and the shack floor. |

- **Nothing is straight or symmetric.** Edges are rough, streams wander and
  trees stand where they like. It's the same rule as flesh: natural, not
  built.
- **The landmark gives the shape.** A pond room is mostly the pond, and a
  ravine is a rock gash through the middle. If someone could look at the
  room and name the place, it's right.
- **Overgrown adds to the place, it doesn't replace it.** The same
  landmark, only more of it.
- **Trails.** A dirt trail winds from one opening to every other one, so
  the way through reads at a glance. Mazes and the Fairy Ring have none.
  Grass grows where the trees thin out.

## Forest rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room.** Trails are 3 wide and paths are 1 wide.
   A room's openings are all one width.
3. **Openings are centred on their wall, or in mirrored pairs.**
4. **No doors.** `default_door` is `"none"` and every connector has
   `"door": "none"` and `"free": true`, so forest rooms join whatever they
   touch, whatever the widths.
5. **Nothing unreachable.** Every floor tile connects to the openings, and
   there are no spawn cells right beside an opening.
6. **Lone trees never block a path.** A single tree only goes where all
   eight tiles around it are open.

Every room sets `"base_floor": "floor_dirt"`, so the ground under trees and
openings is dirt.

## Enemies: packs

Every spawn cell spawns one enemy (unless the cell is lit). In the forest,
spawn cells come in **packs**: a tight clump of cells (each within 3 tiles
of the pack's centre, 2 apart) with packs spread far apart and kept away
from the openings.

| Kind | Packs | Pack size |
|---|---|---|
| Landmark (combat) | 1, plus 1 more per 170 floor tiles | 4 |
| Kill zone | 3 | 4 |
| Barracks | 2 | 4 |
| Boss | 2 | 4 |
| Leech Bog | 2 | 3 |
| Maze | 1 | 3 |
| Treasure (guarded) | 1 | 3 |
| Side pocket | 1 | 2 |
| Entrance, trail, path, peaceful | none | |

The 74 rooms have 234 spawn cells between them. That's about the dungeon's
density, not flesh's.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Trail (3 wide), path (1 wide) | `corridor` | `corridor` |
| Landmark, side pocket | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Peaceful | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Barracks | `normal` | `barracks` |
| Leech Bog | `normal` | `combat`, `nest`, and `"favored_enemy": {"tag": "leech", "weight": 30}` |
| Treasure | `normal` | `treasure` (guarded: has spawns) |
| Boss | `boss` | `combat` |

### `defines.json`

- `room_count` 30 to 45.
- `default_door` `"none"`.
- `tag_weights` are the same as flesh:
  - `corridor` 0.7
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7
- `monsters` and `music` are unchanged: wolf 3, bat 1, rat 1, leech 0.1, and
  The Lone Forest.

## Current piece set (2026-09-24)

74 rooms: each landmark below, plus `<Landmark>_Overgrown`. Sizes are in
the file names (grid size = inside + 2).

- **Entrance:** Trailhead, Forest Edge.
- **Trails, 3 wide:** Trail, Trail Bend, Trail Fork, Stream Ford (a
  stream crosses it; Overgrown has two), Log Bridge (planks over water),
  Switchback.
- **Paths, 1 wide:** Deer Track, Root Tunnel, Bramble Squeeze.
- **Landmarks (combat):**
  - Glade, Pond, Marsh, Beaver Dam (timber dam holding back a pond).
  - Fallen Giant (fallen timber trunks with a gap to climb through; Overgrown has two, crossed).
  - Old Oak, Ravine (rock gash), Standing Stones (rock ring).
- **Kill zone:** Ambush Hollow.
- **Peaceful:** Sunlit Clearing, Fairy Ring (ring of trees with gaps;
  Overgrown has a second outer ring).
- **Mazes:** Bramble Thicket, Bog, Deadfall, Root Maze.
- **Side pockets, 1 wide:** Hollow Stump, Badger Sett, Rock Outcrop, Berry
  Thicket.
- **Barracks:** Wolf Den, Bat Roost (rock roosts around a small pool).
- **Leech Bog:** favours leeches.
- **Treasure:** Hunters Cache (timber shack, chest on the plank floor),
  Hollow Tree (chest inside a hollow timber trunk; Overgrown has two
  trunks, one empty).
- **Boss:** Ancient Grove (one huge oak; Overgrown has three), Wolf Lair
  (rock den with caves along the back wall). The generator picks one of
  the four each run.

## Adding a new room, step by step

1. **Pick the landmark and sketch it** as a text grid: `#` tree, `R` rock,
   `W` timber, `.` dirt, `,` grass, `~` water, `=` planks, `D` openings.
   Pick an odd inside size, then add 2 for the grid.
2. **Make it rough.** If you can fold it in half and it matches, break it
   up.
3. **Check the openings.** Are they all one width? Are they centred, or a
   mirrored pair?
4. **Set the connectors.** Give each one `"door": "none"` and
   `"free": true`.
5. **Draw a trail** of dirt between the openings, unless it's a maze.
6. **Add packs** using the table above.
7. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
8. **Load a forest dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
9. **Add it to the piece list above.**
