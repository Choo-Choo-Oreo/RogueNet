# Manor: how to make rooms

A great house gone bad, and its library. Every room is a **named room** of
the house: a dining hall, a ballroom, a study, a kitchen. Each has its own
carpet colour, and its furniture is drawn as walls. Most rooms also come
**Haunted**: the same room abandoned and wrong, with furniture overturned,
carpet torn up and a wall or two broken through. Enemies come as a
**haunting**: wraiths drifting through the rooms, rats nesting in the
service rooms, bats roosting under the roof.

This file covers the manor's own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_enemy`,
per-cell `enemy`), see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Brick | `wall_cobble_brick` | Outer walls. |
| Wood | `wall_wood_plank` | Furniture, shelves, beds, pews, crates and wine racks, the maze walls. |
| Stone | `wall_smooth_stone` | Hearths, busts on plinths, pillars, the grand stairs, ovens, the altar. |
| Potted trees | `wall_forest` | Only in the Conservatory. |
| Planks | `floor_wood_planks` | Most floor. |
| Stone floor | `floor_smooth_stone` | The foyer, kitchen, great hall, chapel, pantry, privy, strongroom, wine cellar, conservatory paths. |
| Dirt | `floor_dirt` | The servants' entrance, dust in the attic and wine cellar, the bat loft. |
| Grass, water | `floor_grass`, `floor_water` | The Conservatory's beds and fountain. |

**One carpet colour per room:**

| Carpet | Rooms |
|---|---|
| `floor_carpet_crimson` | Hallway runners, foyer, dining hall, master bedroom, great hall, parlour, Lords Chamber. |
| `floor_carpet_gold` | Ballroom, music room, nursery, strongroom. |
| `floor_carpet_indigo` | Library Stacks, Secret Room, Grand Library. |
| `floor_carpet_verdigris` | Study. |
| `floor_carpet_violet` | Portrait Gallery, chapel. |

- **Built, not natural.** Rooms are straight and mostly symmetric, like the
  dungeon and the catacomb.
- **Furniture is walls for now.** Tables, beds and shelves are
  `wall_wood_plank` stand-ins, the same as the cathedral pews, until there
  is an object system.
- **Openings carry the floor just inside them,** so a carpeted hallway
  stays carpeted through its opening.
- **Haunted keeps the room's size and openings.** About half the
  free-standing furniture is tipped over into a heap nearby. Carpet is torn
  up to the planks in a few clumps. One or two thin walls are broken
  through into hidden passages. A heap never cuts the room off. A room gets
  no Haunted version when there is nothing to haunt: the servants'
  entrance, the servants' passages, the Conservatory and most side
  pockets.

## Manor rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room:** 3 (hallways and most rooms) or 1
   (servants' passages, the servants' entrance, mazes, side pockets, the
   Secret Room).
3. **Openings are centred on their wall.**
4. **Doors:**
   - Rooms with 3-wide openings: `"door": "wood_fold"` (bi-fold).
   - Rooms with 1-wide openings: `"door": "wood"` (swing).
   - The Strongroom and both bosses: `"door": "iron"`.
   - Hallways and servants' passages: `"door": "any"`. `default_door` is
     `"none"`, so where two hallways meet the doorway stays open, and where
     a hallway meets a room the room's door wins.
5. **Every connector is `"free": true`,** so 3- and 1-wide pieces can join
   each other.
6. **Nothing unreachable.** Every floor tile connects to the openings.

Every room sets `"base_floor": "floor_wood_planks"`.

## Enemies: the haunting

Every spawn cell spawns one enemy, unless the cell is lit (torches in the
foyer, the servants' entrance, the kitchen hearth, the chapel and the
parlour keep spawns away). A room has two kinds of cell:

- **Nests.** A pinned group, as far from the openings as it fits:
  - Rats (`"enemy": "rat"`): a tight clump in the Kitchen, Wine Cellar,
    Pantry and Servants Quarters, and one rat in the Servants Passage and
    its Fork and Cross.
  - Bats (`"enemy": "bat"`): a loose roost in the Attic, Bat Loft and
    Portrait Gallery.
- **Rolled cells.** Spread 4+ tiles apart, with no `enemy`, so they roll
  from the biome's `monsters` table (mostly wraiths), nudged by the room's
  `favored_enemy`.

| Kind | Rolled cells |
|---|---|
| Room (combat) | 4 |
| Kill zone | 7 |
| Boss | 6 |
| Maze | 3 |
| Barracks | 3 |
| Treasure (guarded) | 2 |
| Side pocket | 2 |
| Entrance, hallway, servants' passage, peaceful | none |

Haunted rooms get 2 extra rolled cells. Nests are on top: 3 rats (4 in the
Servants Quarters, 1 in a passage), 3 bats (5 in the Bat Loft).

**Favoured enemies:**

- The rat-nest rooms favour `rat`, weight 3.
- The bat-roost rooms favour `bat`, weight 3.
- Library Stacks and the Grand Library favour `undead.ghostly` (wraiths),
  weight 2.

The 63 rooms have 231 spawn cells between them: 26 pinned rats, 22 pinned
bats and 183 rolled from the table.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Hallway (3 wide), servants' passage (1 wide) | `corridor` | `corridor` |
| Room, side pocket | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Peaceful | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Barracks | `normal` | `barracks` |
| Treasure | `normal` | `treasure` (guarded: has spawns) |
| Boss | `boss` | `combat` |

### `defines.json`

- `room_count` 30 to 45.
- `default_door` `"none"`.
- `tag_weights` are the same as the other biomes:
  - `corridor` 0.7
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7
- `monsters`: wraith 3, rat 2, bat 1. The nests add more rats and bats on
  top of the table. The manor will want its own enemies eventually.
- `music`: Groovy.

## Current piece set (2026-09-24)

63 rooms: each room below, plus `<Room>_Haunted` where it changes the room.
Sizes are in the file names (grid size = inside + 2).

- **Entrance:** Foyer (a grand staircase, a crimson runner, torches),
  Servants Entrance (a dirt mudroom with a boot bench, 1 wide, no Haunted).
- **Hallways, 3 wide:** Hallway, Hallway Short, Hallway Corner, Hallway
  Tee, Hallway Crossing. Crimson runners, side tables and busts.
- **Servants' passages, 1 wide:** Servants Passage, Short, Bend, Fork,
  Cross. No Haunted.
- **Rooms (combat):**
  - Dining Hall (a long table with chairs), Ballroom (a gold dance floor
    and a bandstand), Music Room (a piano, a harp, rows of chairs).
  - Study (a desk, shelves either side of the hearth), Portrait Gallery
    (busts on plinths, benches under the portraits).
  - Kitchen (the great hearth, a work table, ovens, barrels), Master
    Bedroom (a four-poster bed, wardrobes).
  - Conservatory (grass beds with potted trees, stone paths, a fountain,
    no Haunted).
- **Kill zone:** Great Hall (the grand stair, a carpet cross, pillars,
  banquet tables).
- **Peaceful:** Chapel (pews, an altar), Parlour (a sofa and armchairs by
  the hearth). Both lit.
- **Mazes, 1 wide:** Library Stacks (bookshelf aisles on indigo), Attic
  (crates and rafters, dust), Wine Cellar (wine racks on stone and dirt).
- **Side pockets, 1 wide:** Closet, Pantry, Linen Room, Privy, Nursery.
  Only the Nursery has a Haunted version.
- **Barracks:** Servants Quarters (cots along both walls), Bat Loft (posts
  under the rafters).
- **Treasure:** Strongroom (iron, a chest on gold), Secret Room (1 wide,
  a chest among the shelves on indigo).
- **Boss, iron:** Grand Library (the stacks either side of an indigo nave),
  Lords Chamber (a great bed at the end of a crimson runner). The
  generator picks one of the four each run.

## Adding a new room, step by step

1. **Pick the room and sketch it** as a text grid: `#` brick, `B` wood,
   `O` stone, `=` planks, `.` stone floor, a carpet letter, `D` openings.
   Pick an odd inside size, then add 2 for the grid.
2. **Pick one carpet colour** for the room.
3. **Keep it built.** Straight walls, and symmetric where it makes sense.
4. **Check the openings.** Are they all one width? Are they centred? Give
   each opening cell the floor tile just inside it.
5. **Set the connectors.** Use `"wood_fold"` for a 3-wide room, `"wood"`
   for a 1-wide room, `"iron"` for a vault or boss, and `"any"` for a
   hallway or passage. Always add `"free": true`.
6. **Add the spawns** using the table above. Give nest cells
   `"enemy": "rat"` or `"enemy": "bat"`.
7. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
8. **Load a manor dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
9. **Add it to the piece list above.**
