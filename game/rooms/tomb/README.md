# Tomb: how to make rooms

Added 2026-09-26.

A desert necropolis half buried in sand. Sandstone halls, hypostyle
forests of columns, a buried city and a pyramid. The dead guard it; the desert has moved in.
Sand floors, brick and cobble where the builders laid it, water only at the oasis and the canal.

The rooms are made by script (see *Regenerating* below), not by hand. Hand-made rooms are
welcome too; follow the rules below.

## The look

| Tile | Used for |
|---|---|
| `wall_sandstone` | the main walls, columns |
| `wall_smooth_stone` | sarcophagi, obelisks, the sphinx |
| `wall_brick` | mud-brick houses in the city |
| `floor_sand` | the main floor, drifts |
| `floor_brick` | processional floors |
| `floor_cobblestone` | plazas |
| `floor_water` | oasis, canal (difficult terrain) |
| `floor_gravel` | rubble |
| `floor_grass` | oasis banks |

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

No doors, except iron on treasure rooms and the boss.

## Minions

Scorpions and snakes in the sand, beetle swarms, skeleton warriors and archers guarding
the halls (archers in lines across the `Hypostyle_Hall`), zombies in the burial rooms,
lizardmen on the plazas, and mimics in the `False_Tomb`. The nests (`Scorpion_Nest`,
`Scarab_Swarm`, `Snake_Pit`) are one minion each.

Most rooms pin a mix that suits them (the `minion` on each spawn cell). Cells without one
are rolled from `monsters` in `defines.json`.

## `defines.json`

| key | value |
|---|---|
| `room_count` | 25-38 |
| `tag_weights` | `corridor` 0.6, `maze` 0.6, `killzone` 0.5, `peaceful` 0.7, `vast` 0.35 |
| `monsters` | scorpion 3, snake 2, skeleton_warrior 2, skeleton_archer 2, beetle 2, zombie 1, lizardman 1, ghost 0.5, mimic 0.3 |
| `music` | `Groovy.mp3` |
| `ambience` | `ruins.mp3` (a placeholder until the biome gets its own) |

## Current piece set (2026-09-26)

44 rooms. The sizes are the grid size.

- **Entrances:** Dune Hollow 23×21, Sunken Stair 21×23.
- **Tunnels and crawls:** Passage Bend 9×9, Passage Cross 11×11, Passage Fork 11×9, Passage Long 5×19, Passage Loop 13×15, Passage Serpent 13×19, Passage Short 5×9, Shaft 3×11, Shaft Kinked 5×15.
- **Combat:** Burial Niche 9×9, Buried Temple 29×25, Canal Of The Dead 31×23, Canopic Closet 11×7, Collapsed Gallery 37×17, Guard Barracks 25×21, Hall Of Kings 19×39, Hypostyle Hall 33×33, Necropolis 81×81 (vast), Obelisk Plaza 29×29, Pyramid Interior 63×63 (vast), Robbers Hole 7×11, Sand Drowned Court 31×31, Sarcophagus Chamber 23×27, Scarab Swarm 23×23, Scorpion Nest 25×23, Snake Pit 25×25.
- **Kill zones:** Arrow Gallery 13×43, Sphinx Court 37×33.
- **Peaceful:** Embalmers Workshop 17×13, Oasis 25×21, Shrine Of The Sun 15×15.
- **Mazes:** Maze Braided 23×23, Maze Coil 17×17, Maze Hub 25×25, Maze Switchback 21×25, Maze Tangle 25×19, Maze Uturn 19×17.
- **Treasure:** Buried Chest 15×13, False Tomb 17×15, Pharaoh Vault 11×13.
- **Boss:** Buried City 91×91, Throne Of Sand 45×45.

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

The rooms are written by `.claude/tools/room_maps/tomb.py` (run from that folder:
`python tomb.py` checks every room, `python tomb.py --write` writes them). Editing the
JSON by hand is fine, but a later `--write` overwrites it.
