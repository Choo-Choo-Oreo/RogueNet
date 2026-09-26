# Garden: how to make rooms

Added 2026-09-26.

An overgrown palace garden. Hedge mazes, rose gardens, a parterre the
size of a town, lily ponds, orchards and a greenhouse. The hedges are the walls, so it is a maze
biome at heart; the lawns between them are wide open.

The rooms are made by script (see *Regenerating* below), not by hand. Hand-made rooms are
welcome too; follow the rules below.

## The look

| Tile | Used for |
|---|---|
| `wall_forest` | hedges |
| `wall_mossy_stone` | garden walls, statues |
| `wall_stained_glass` | the greenhouse |
| `wall_smooth_stone` | fountains, plinths |
| `wall_brick` | sheds |
| `floor_grass` | the main floor |
| `floor_flowers` | beds |
| `floor_moss` | shade |
| `floor_leaves` | the orchard |
| `floor_cobblestone` | paths |
| `floor_mossy_cobblestone` | old paths |
| `floor_water` | ponds (difficult terrain) |

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

No doors on 3-wide openings; wood on 1-wide ones and treasure.

## Minions

Bees round the apiary, mantises in the thicket, toads in the marsh, mandrakes and
mushrooms in the beds, beetles, butterflies, dragonflies over the ponds, snakes, slimes.
`Apiary` and `Toad_Marsh` are one minion each (plus dragonflies over the marsh).

Most rooms pin a mix that suits them (the `minion` on each spawn cell). Cells without one
are rolled from `monsters` in `defines.json`.

## `defines.json`

| key | value |
|---|---|
| `room_count` | 25-38 |
| `tag_weights` | `corridor` 0.6, `maze` 0.6, `killzone` 0.5, `peaceful` 0.7, `vast` 0.35 |
| `monsters` | bee 3, mantis 2, toad 2, mandrake 2, mushroom 2, beetle 1, butterfly 1, dragonfly 1, snake 1, slime 0.5 |
| `music` | `The-Lone-Forest.mp3` |
| `ambience` | `forest.mp3` (a placeholder until the biome gets its own) |

## Current piece set (2026-09-26)

43 rooms. The sizes are the grid size.

- **Entrances:** Garden Gate 23×23, Terrace 25×19.
- **Tunnels and crawls:** Hedge Gap 3×11, Hedge Gap Kinked 5×15, Path Bend 9×9, Path Cross 11×11, Path Fork 11×9, Path Long 5×19, Path Loop 13×15, Path Serpent 13×19, Path Short 5×9.
- **Combat:** Apiary 25×21, Bird Bath 7×11, Compost Corner 11×7, Fountain Court 31×31, Greenhouse 29×21, Lily Pond 33×27, Mushroom Grotto 27×23, Orchard 33×27, Palace Parterre 81×81 (vast), Potting Shed 9×9, Rose Garden 31×29, Sunken Garden 29×29, Toad Marsh 25×21, Topiary Walk 19×41, Wild Meadow 31×25.
- **Kill zones:** Bramble Walk 13×45, Mantis Thicket 31×25.
- **Peaceful:** Gazebo 17×17, Herb Garden 15×19, Tea Lawn 19×15.
- **Mazes:** Great Hedge Maze 75×75 (vast), Hedge Maze Braided 23×23, Hedge Maze Coil 17×17, Hedge Maze Hub 25×25, Hedge Maze Switchback 21×25, Hedge Maze Tangle 25×19, Hedge Maze Uturn 19×17.
- **Treasure:** Hidden Arbor 13×13, Statue Garden 17×15, Wishing Well 13×15.
- **Boss:** Queens Bower 45×45, Wild Heart 91×91.

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

The rooms are written by `.claude/tools/room_maps/garden.py` (run from that folder:
`python garden.py` checks every room, `python garden.py --write` writes them). Editing the
JSON by hand is fine, but a later `--write` overwrites it.
