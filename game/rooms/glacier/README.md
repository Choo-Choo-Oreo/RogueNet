# Glacier: how to make rooms

Added 2026-09-26.

A frozen valley under a glacier. Open snowfields broken by crevasses, ice
caves, frozen lakes and a palace of ice. Wide and bright: fights happen at range, and the ice is
the terrain to watch. Water (under the ice) slows you down; there's always a way round on
snow or gravel.

The rooms are made by script (see *Regenerating* below), not by hand. Hand-made rooms are
welcome too; follow the rules below.

## The look

| Tile | Used for |
|---|---|
| `wall_ice` | ice walls, seracs, the palace |
| `wall_rough_cave` | rock, moraine |
| `floor_snow` | the main floor |
| `floor_ice` | frozen lakes, slick paths |
| `floor_water` | meltwater, hot springs (difficult terrain) |
| `floor_gravel` | moraine, fords |

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

No doors: it is outdoors.

## Minions

Wolf packs on the snow, penguin colonies (a whole flock in one room), yetis alone or in
pairs in their dens, owls and echo bats in the ice caves. The dens (`Penguin_Colony`,
`Wolf_Hollow`, `Yeti_Den`) are one minion each.

Most rooms pin a mix that suits them (the `minion` on each spawn cell). Cells without one
are rolled from `monsters` in `defines.json`.

## `defines.json`

| key | value |
|---|---|
| `room_count` | 25-38 |
| `tag_weights` | `corridor` 0.5, `maze` 0.6, `killzone` 0.5, `peaceful` 0.7, `vast` 0.35 |
| `monsters` | wolf 3, penguin 2, yeti 2, owl 1, bat_echo 1, eagle 1, ghost 0.5 |
| `music` | `The-Lone-Forest.mp3` |
| `ambience` | `cave.mp3` (a placeholder until the biome gets its own) |

## Current piece set (2026-09-26)

44 rooms. The sizes are the grid size.

- **Entrances:** Base Camp 21×21, Ice Gate 19×25.
- **Tunnels and crawls:** Crevice Crawl 3×11, Crevice Crawl Kinked 5×15, Ice Tunnel Bend 9×9, Ice Tunnel Cross 11×11, Ice Tunnel Fork 11×9, Ice Tunnel Long 5×19, Ice Tunnel Loop 13×15, Ice Tunnel Serpent 13×19, Ice Tunnel Short 5×9.
- **Combat:** Crevasse Field 31×25, Frozen Cleft 7×11, Frozen Lake 35×29, Frozen Waterfall 27×23, Glacier Expanse 71×71 (vast), Glacier Tongue 45×19, Ice Cave 29×25, Ice Grotto 11×7, Ice Palace 61×61 (vast), Ice Pillar Hall 25×33, Moraine Ridges 33×23, Penguin Colony 29×23, Serac Field 27×27, Snow Hollow 9×9, Standing Stones 25×25, Wolf Hollow 25×21, Yeti Den 27×23.
- **Kill zones:** Avalanche Chute 15×45, Ice Bridge 35×25.
- **Peaceful:** Abandoned Camp 21×17, Frozen Shrine 15×15, Hot Spring 17×17.
- **Mazes:** Maze Braided 23×23, Maze Coil 17×17, Maze Hub 25×25, Maze Switchback 21×25, Maze Tangle 25×19, Maze Uturn 19×17.
- **Treasure:** Crevasse Cache 15×15, Frozen Hoard 11×11, Lost Expedition 17×13.
- **Boss:** Frozen Throat 41×41, Glacier Heart 99×99.

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

The rooms are written by `.claude/tools/room_maps/glacier.py` (run from that folder:
`python glacier.py` checks every room, `python glacier.py --write` writes them). Editing the
JSON by hand is fine, but a later `--write` overwrites it.
