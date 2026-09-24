# Volcano: how to make rooms

Basalt caves and lava, the demons' own biome. Every room is a **feature**,
a place you could name: a lava river, a caldera, a cinder cone, a magma
chamber. Most features also come **Erupting**: the same room with more lava.
Every room with lava is a "find the stone path" puzzle: a path of cooled
crust runs between the openings, and wading through the lava is the slow
way. Enemies come as **demon packs**: hellhounds in tight packs on the
ground, and demonic hamsters swarming over the lava.

This file covers the volcano's own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_enemy`,
per-cell `enemy`), see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Basalt | `wall_rough_cave` | Outer walls, pinches in the tunnels, the cinder cone, maze walls. |
| Obsidian | `wall_smooth_cave` | Glassy lumps: the Obsidian Flow, the Basalt Columns, the Geode's shell, the Volcano Heart's pillars. |
| Ash | `floor_dirt` | Most floor. |
| Cooled crust | `floor_smooth_cave` | The paths across the lava, islands, fords, the rim around lava, old flows. |
| Lava | `floor_lava` | Rivers, lakes, fissures, vents. Slow (0.2 speed), but no damage, so it never cuts a room off. |

- **Natural, not built.** Rooms are rough and lopsided, like the cave.
- **Crust paths.** Each lava room has a crust path from its first opening
  to every other one, and to any island in the lava.
- **Never lava in an opening,** nor on the tile just inside it. Openings
  carry the floor just inside them: ash or crust.
- **Erupting keeps the room's size and openings.** Lava spreads onto the
  ash next to it, and one or two new streams cut across the room. Crust
  never melts, so islands and fords survive. The least-lava route between
  the openings is kept, often narrowed to 1 tile. A room gets no Erupting
  version when it would barely change: the 1-wide vents, Lava Tube and
  most side pockets.

## Volcano rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room:** 3 (tunnels and rooms) or 1 (vents, side
   pockets, the Braided Flows maze, treasure).
3. **Openings are centred on their wall.**
4. **No doors.** Every connector is `"door": "none"`, and `default_door` is
   `"none"`.
5. **Every connector is `"free": true`,** so 3- and 1-wide pieces can join
   each other.
6. **Nothing unreachable.** Every floor tile, lava included, connects to
   the openings.

Every room sets `"base_floor": "floor_dirt"`.

## Enemies: demon packs

Every spawn cell spawns one enemy. There are three kinds of cell:

- **Hellhound packs.** Tight clumps (cells next to each other) on ash or
  crust, as far from the openings as they fit. Each has
  `"enemy": "wolf_hellhound"`.
- **Hamster swarms.** Loose groups (cells 2 apart) over the lava. Each has
  `"enemy": "hamster_demonic"`: a flyer is the only thing that belongs out
  there. In a room with no lava, the swarm gathers on the ash instead.
- **Rolled cells.** Single cells spread out on the ground, with no
  `enemy`, so they roll from the biome's `monsters` table (the only way a
  bat shows up).

| Kind | Packs | Pack size | Swarms | Swarm size | Rolled |
|---|---|---|---|---|---|
| Feature (combat) | 1 | 3 | 1 | 3 | 1 |
| Kill zone | 2 | 4 | 2 | 4 | 2 |
| Hellhound Den | 3 | 4 | none | | none |
| Demon Roost | 1 | 3 | 3 | 4 | none |
| Boss | 2 | 4 | 2 | 4 | 1 |
| Maze | 1 | 3 | none | | 1 |
| Treasure (guarded) | 1 | 3 | none | | none |
| Side pocket | none | | none | | 2 |
| Entrance, tunnel, vent, peaceful | none | | none | | none |

No room sets `favored_enemy`. The 64 rooms have 311 spawn cells between
them: 156 hellhounds, 117 demonic hamsters and 38 rolled.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Tunnel (3 wide), vent (1 wide) | `corridor` | `corridor` |
| Feature, side pocket | `normal` | `combat` |
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
- `monsters`: hellhound 3, demonic hamster 3, bat 1. The packs and swarms
  are pinned on top of the table.
- `music`: Groovy.

## Current piece set (2026-09-24)

64 rooms: each feature below, plus `<Feature>_Erupting` where it changes
the room. Sizes are in the file names (grid size = inside + 2).

- **Entrance:** Caldera Rim (a ledge above a lava pool), Ash Slope.
- **Tunnels, 3 wide:** Basalt Tunnel, Tunnel Bend, Tunnel Fork, Lava Tube
  (glassy floor, lava along one wall, no Erupting), Crust Bridge (a crust
  ford across a flow), Fissure Walk (three cracks of lava across it).
- **Vents, 1 wide:** Vent Crawl, Vent Crawl Short, Vent Crawl Bend, Vent
  Crawl Fork, Vent Crawl Cross. No Erupting.
- **Features (combat):**
  - Lava River (two crust fords), Lava Lake (a crust island), Lava Falls
    (lava pouring from the north wall into a pool).
  - Fissure Field (short glowing cracks everywhere), Fumarole Vents (small
    lava vents with crust rims).
  - Obsidian Flow (glassy lumps on crust), Basalt Columns.
  - Cinder Cone (a basalt cone with a lava crater and one crack into it).
- **Kill zone:** Caldera Floor (a lava ring round a crust island, crust
  paths in from all four openings).
- **Peaceful:** Cooled Grotto, Obsidian Garden.
- **Mazes:** Basalt Maze, Braided Flows (1 wide), Cracked Crust.
- **Side pockets, 1 wide:** Vent, Ash Pit, Obsidian Nook, Magma Bubble. No
  Erupting.
- **Barracks:** Hellhound Den (sleeping hollows round a warm pit), Demon
  Roost (a lava pool ringed with obsidian).
- **Treasure:** Obsidian Geode (a chest in an obsidian shell), Lava Island
  Hoard (a chest on an island). Chest on crust.
- **Boss:** Magma Chamber (crust islands in a lava lake), Volcano Heart (a
  crust platform ringed by lava, with obsidian pillars). The generator
  picks one of the four each run.

## Adding a new room, step by step

1. **Pick the feature and sketch it** as a text grid: `#` basalt, `O`
   obsidian, `.` ash, `=` crust, `^` lava, `D` openings. Pick an odd inside
   size, then add 2 for the grid.
2. **Lay a crust path** between the openings through any lava, and keep
   lava off the openings and the tiles just inside them.
3. **Check the openings.** Are they all one width? Are they centred? Give
   each opening cell the floor tile just inside it.
4. **Set the connectors:** `"door": "none"`, `"free": true`.
5. **Add the spawns** using the table above. Give pack cells
   `"enemy": "wolf_hellhound"` and swarm cells `"enemy": "hamster_demonic"`.
6. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
7. **Load a volcano dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
8. **Add it to the piece list above.**
