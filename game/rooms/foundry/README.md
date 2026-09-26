# Foundry: how to make rooms

Added 2026-09-26.

A dwarven-scale forge in the deep. Lava channels, casting floors,
conveyors, rail yards, slag heaps and a great crucible. Metal-plate floors, iron walls, and lava
that kills: every lava room has a grated walkway or a crust bridge between its openings.

The rooms are made by script (see *Regenerating* below), not by hand. Hand-made rooms are
welcome too; follow the rules below.

## The look

| Tile | Used for |
|---|---|
| `wall_iron` | machinery, the main walls |
| `wall_brick` | furnaces, chimneys |
| `wall_mine_ore` | ore heaps, the bunkers |
| `wall_smooth_stone` | moulds, anvils |
| `floor_metal_plate` | the main floor |
| `floor_grate` | walkways over lava and water |
| `floor_lava` | channels and pools (severe) |
| `floor_lava_crust` | cooling crust (severe) |
| `floor_cobblestone` | yards |
| `floor_gravel` | slag |
| `floor_water` | quench pools |

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

No doors on 3-wide openings; iron on 1-wide ones, treasure and the boss.

## Minions

Goblin crews and orcs working the floor, fire spirits (on the lava as well as off
it), imps, gargoyles watching the gallery, slimes in the drains, rats, the odd mimic.
`Goblin_Bunks`, `Orc_Mess` and `Spirit_Forge` are one crew each.

Most rooms pin a mix that suits them (the `minion` on each spawn cell). Cells without one
are rolled from `monsters` in `defines.json`.

## `defines.json`

| key | value |
|---|---|
| `room_count` | 25-38 |
| `tag_weights` | `corridor` 0.5, `maze` 0.6, `killzone` 0.5, `peaceful` 0.7, `vast` 0.35 |
| `monsters` | goblin 3, fire_spirit 3, orc 2, imp 2, gargoyle 1, slime 1, rat 1, mimic 0.3 |
| `music` | `Groovy.mp3` |
| `ambience` | `volcano.mp3` (a placeholder until the biome gets its own) |

## Current piece set (2026-09-26)

44 rooms. The sizes are the grid size.

- **Entrances:** Gatehouse 19×23, Loading Dock 23×21.
- **Tunnels and crawls:** Duct 3×11, Duct Kinked 5×15, Gantry Bend 9×9, Gantry Cross 11×11, Gantry Fork 11×9, Gantry Long 5×19, Gantry Loop 13×15, Gantry Serpent 13×19, Gantry Short 5×9.
- **Combat:** Anvil Row 31×19, Bellows Hall 29×23, Boiler Closet 7×11, Casting Floor 33×27, Coal Bunker 27×23, Coal Hole 11×7, Conveyor Lines 33×25, Goblin Bunks 27×21, Great Forge 81×81 (vast), Orc Mess 23×21, Pipe Works 27×27, Quench Pools 29×23, Rail Yard 61×61 (vast), Slag Heaps 31×25, Smelter 29×29, Spirit Forge 21×21, Tool Store 9×9.
- **Kill zones:** Crucible Bridge 35×27, Gargoyle Gallery 15×45.
- **Peaceful:** Cooling Cistern 17×17, Foremans Office 15×13, Pattern Shop 19×15.
- **Mazes:** Maze Braided 23×23, Maze Coil 17×17, Maze Hub 25×25, Maze Switchback 21×25, Maze Tangle 25×19, Maze Uturn 19×17.
- **Treasure:** Crate Hoard 15×13, Ingot Island 15×15, Strongroom 11×11.
- **Boss:** Crucible 45×45, Heart Of The Forge 97×97.

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

The rooms are written by `.claude/tools/room_maps/foundry.py` (run from that folder:
`python foundry.py` checks every room, `python foundry.py --write` writes them). Editing the
JSON by hand is fine, but a later `--write` overwrites it.
