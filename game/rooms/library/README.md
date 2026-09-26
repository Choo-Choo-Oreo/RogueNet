# Library: how to make rooms

Added 2026-09-26.

An endless haunted library. Stacks you can get lost in, reading rooms,
a rotunda under a dome, an orrery, and a forbidden section. Bookshelves are the walls, so every
room is full of cover and sight lines are short. Each room has its own carpet colour.

The rooms are made by script (see *Regenerating* below), not by hand. Hand-made rooms are
welcome too; follow the rules below.

## The look

| Tile | Used for |
|---|---|
| `wall_bookshelf` | the stacks, the main walls |
| `wall_wood_plank` | desks, catalogues |
| `wall_stained_glass` | windows, the chapel |
| `wall_smooth_stone` | columns, the orrery |
| `wall_brick` | outer walls |
| `floor_parquet` | the main floor |
| `floor_carpet_*` | crimson, indigo, gold, verdigris: one per room |
| `floor_smooth_stone` | the atrium |

## Rules

- **Sizes are odd** (grid size), so 3-wide and 1-wide openings centre on a wall.
- **Openings are 3 wide (rooms, tunnels) or 1 wide (crawls, pockets, side rooms).** Every
  connector is `free`, so rooms of different widths can join.
- **No floor on the outer ring, no opening in a corner.** Each opening leads straight into floor,
  never into a hazard.
- **Every walkable cell is connected**, with a hazard-free path between every pair of openings.
- **No spawns in entrance or boss rooms.** A boss room has an antagonist spawn with a clear 7x7
  around it (room for the biggest bosses).
- **Treasure rooms hold at least one chest.** Corridors never dead-end, except the pockets and
  the coil maze, which do so on purpose and hold a reward.

## Doors

No doors on 3-wide openings; wood on 1-wide ones; iron on treasure and the boss.

## Minions

Ghosts and moths everywhere, wraiths in the forbidden section, rats in the archive,
witches, imps, the librarian's cat and owls, gargoyles on the galleries, mimics among the
chests. `Boss_Heart_Of_The_Archive` always gets the minotaur: a labyrinth of shelves has to.

Most rooms pin a mix that suits them (the `minion` on each spawn cell). Cells without one
are rolled from `monsters` in `defines.json`.

## `defines.json`

| key | value |
|---|---|
| `room_count` | 25-38 |
| `tag_weights` | `corridor` 0.5, `maze` 0.6, `killzone` 0.5, `peaceful` 0.7, `vast` 0.35 |
| `monsters` | ghost 3, moth 3, wraith 2, rat 2, owl 1, cat 1, imp 1, witch 1, gargoyle 1, mimic 0.5 |
| `music` | `Groovy.mp3` |
| `ambience` | `manor.mp3` (a placeholder until the biome gets its own) |

## Current piece set (2026-09-26)

42 rooms. The sizes are the grid size.

- **Entrances:** Atrium 25×25, Front Desk 23×21.
- **Tunnels and crawls:** Hallway Bend 9×9, Hallway Cross 11×11, Hallway Fork 11×9, Hallway Long 5×19, Hallway Loop 13×15, Hallway Serpent 13×19, Hallway Short 5×9, Servants Stair 3×11, Servants Stair Kinked 5×15.
- **Combat:** Bindery Nook 7×11, Book Closet 9×9, Card Catalogue 25×25, Endless Stacks 91×91 (vast), Fallen Shelves 31×25, Grand Atrium 63×63 (vast), Map Cupboard 11×7, Map Room 23×23, Moth Roost 25×21, Orrery 29×29, Rat Archive 23×19, Reading Room 29×21, Rotunda 33×33, Scriptorium 25×23, Stacks 33×29.
- **Kill zones:** Forbidden Section 27×27, Gallery Of Echoes 15×47.
- **Peaceful:** Chapel Of Silence 17×17, Librarians Study 15×13, Tea Room 19×15.
- **Mazes:** Maze Braided 23×23, Maze Coil 17×17, Maze Hub 25×25, Maze Switchback 21×25, Maze Tangle 25×19, Maze Uturn 19×17.
- **Treasure:** Curators Cabinet 17×15, Hidden Reading Nook 11×11, Restricted Vault 13×11.
- **Boss:** Great Reading Hall 75×75, Heart Of The Archive 49×49.

## Map design: what these rooms are built to do

The assembler builds a tree of rooms, so the variety has to come from the rooms themselves. Each
room was built to do at least one of these jobs:

- **Tension and release.** Fights come in waves. After a big combat room the player should find a
  corridor or a `peaceful` room (no spawns) to catch their breath. That's why every biome has
  peaceful rooms and short tunnels as well as big fights.
- **Loops inside rooms.** A tree has no loops, so the loops are built into the rooms: pillar
  halls, rings round a core, braided mazes, district blocks with several ways round each one.
  A loop lets a party split up, kite a minion round a pillar or flank a pack.
- **Landmarks.** Every big room has one thing you can steer by: a fountain, an obelisk, a
  rotunda, standing stones, the furnace. In a vast room it's how a player remembers where they
  are.
- **Chokepoints and killzones.** `killzone` rooms are long galleries or bridges with many spawns
  and little cover. The weight keeps them rare, so they spike the difficulty instead of setting it.
- **Cover and flanking lanes.** Big rooms are broken up with pillars, shelves, crates and
  hedges, so ranged minions can't cover the whole floor and melee players have a way in.
- **Dead ends pay out.** A dead end should hold something. Coil mazes end in a chest, treasure
  rooms have one door, and 1-wide pockets hide the small stuff.
- **Varied scale.** Rooms run from 3x11 crawls to 99x99 set pieces. Small, big, small again is
  more interesting than the same size every time.
- **A safe way through.** Every hazard room (water, lava, ice) has a hazard-free path between
  all its openings: grates, fords or bridges. The hazard is a shortcut or a detour, never a wall.
- **Vast rooms are rare.** Rooms tagged `vast` (60+ tiles a side) get weight 0.35, so a dive
  meets about one, sometimes none. The huge boss rooms (90+) and the medium boss rooms split the
  boss slot roughly half and half.


## Regenerating

The rooms are written by `.claude/tools/room_maps/library.py` (run from that folder:
`python library.py` checks every room, `python library.py --write` writes them). Editing the
JSON by hand is fine, but a later `--write` overwrites it.
