# Sewer: how to make rooms

Built sewers under the town. Every room is a **feature**, a part of the
sewer you could name: a cistern, a set of sluice gates, a pump room, a rat
nest. Every feature also comes in two variants:

- **Flooded:** the same room with the water up one tile. Channels spill onto
  the walkways, and the deepest water has an acid slick.
- **Collapsed:** the same room with part of the vault fallen in. Rubble heaps
  lie against the walls, with dirt spilled around them.

Minions come in **rat swarms**, with leeches in the water.

This file covers the sewer's own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_minion`),
see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Brick | `wall_cobble_brick` | Outer walls and anything the builders walled off. |
| Stone | `wall_smooth_stone` | Pillars, buttresses, tank lips, weirs, gates, machinery, crates and benches. |
| Rubble | `wall_rough_cave` | Only in Collapsed rooms, plus the refuse mounds in the Rat Nest, Refuse Heap and Rat King's Throne. |
| Walkway | `floor_smooth_stone` | The normal floor: ledges beside the channels, room floors. |
| Water | `floor_water` | Channels, cisterns, sumps. Slows movement. |
| Acid | `floor_acid` | Settling tanks, the Grand Collector and Great Sump cores, the slick in Flooded rooms. Slows movement. |
| Silt | `floor_dirt` | Refuse, filter beds, dirt spilled by a collapse. |
| Planks | `floor_wood_planks` | Bridges over channels, decks, the smugglers' floor. |

- **Built, not natural.** Unlike cave, forest and flesh, sewer rooms are
  straight and mostly symmetric. The Collapsed variant is what breaks them
  up.
- **Mains are 5 wide:** a 3-wide water channel with a walkway ledge on each
  side. The channel runs straight through each opening, so mains line up
  with each other.
- **Openings carry the floor just inside them.** Each opening cell's `floor`
  is the tile one step in: water under the channel, stone under the ledges.
  Without it the painter would put `base_floor` (smooth stone) there and
  cut every channel off at the wall.
- **Crawls are 1 wide:** dry service passages with a little silt.
- **The variants keep the room's size and openings.** A Flooded or
  Collapsed room fits wherever its plain version fits.

## Sewer rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room:** 5 (mains, big rooms), 3 (small rooms:
   peaceful, treasure, barracks) or 1 (crawls, side rooms, mazes).
3. **Openings are centred on their wall.**
4. **Doors: iron on the side rooms, the treasure rooms, Cistern, Settling
   Tanks and Leech Cistern** (`"door": "iron"`). Every other connector is
   `"door": "any"`, and `default_door` is `"none"`, so ordinary joins stay
   open but an iron room still gets its door wherever it joins. Iron fits
   widths 1 to 5.
5. **Every connector is `"free": true`,** so 5-, 3- and 1-wide pieces can
   join each other.
6. **Nothing unreachable.** Every floor tile connects to the openings.
   Water and acid count as floor. A collapse is never allowed to cut a room
   in two or block an opening.

Every room sets `"base_floor": "floor_smooth_stone"`.

## Minions: rat swarms

Every spawn cell spawns one minion (unless the cell is lit: torches in the
Lamp Room, Maintenance Room and Smugglers Den keep spawns away). Spawn
cells come in **swarms**: a dense clump of cells (each within 3 tiles of the
swarm's centre, 2 apart). Swarms are spread apart (6+ tiles) and kept away
from the openings.

| Kind | Swarms | Swarm size |
|---|---|---|
| Feature (combat) | 1, plus 1 more per 160 floor tiles | 5 |
| Kill zone | 3 | 5 |
| Barracks | 3 | 6 |
| Leech Cistern | 2 | 4 |
| Boss | 2 | 6 |
| Maze | 1 | 4 |
| Treasure (guarded) | 1 | 3 |
| Side room | 1 | 2 |
| Entrance, main, crawl, peaceful | none | |

Spawns can be in water only in the Leech Cistern and in Flooded rooms.

**Leeches:**

- The Leech Cistern favours leeches strongly (`{"tag": "leech", "weight": 30}`).
- Every other Flooded room favours them a little (`weight` 5).

The 111 rooms have 512 spawn cells between them.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Main (5 wide), crawl (1 wide) | `corridor` | `corridor` |
| Feature, side room | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Peaceful | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Barracks | `normal` | `barracks` |
| Leech Cistern | `normal` | `combat`, `nest` |
| Treasure | `normal` | `treasure` (guarded: has spawns) |
| Boss | `boss` | `combat` |

### `defines.json`

- `room_count` 30 to 45.
- `default_door` `"none"`.
- `tag_weights` are the same as cave, flesh and forest, plus `vast`:
  - `corridor` 0.7
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7
  - `vast` 0.35 (the 60+ tile set pieces; about one run in ten meets one)
- `monsters`: rat 3, blind rat 2, toothless rat 2, leech 1. Every minion but the
  leech is a `beast.rodent`.
- `music`: Groovy.

## Current piece set (2026-09-24)

111 rooms: each feature below, plus `<Feature>_Flooded` and
`<Feature>_Collapsed`. Sizes are in the file names (grid size = inside + 2).

- **Entrance:** Outflow (a channel runs into a pool at a grate), Manhole
  Shaft (a plank landing inside a stone ring, under the ladder).
- **Mains, 5 wide:** Main Line, Main Short, Main Bend, Main Junction, Main
  Crossing (plank bridges over each arm), Drop Weir (water spills through a
  notch in a stone weir into a plunge pool).
- **Crawls, 1 wide:** Service Crawl (with a niche halfway), Crawl Short,
  Crawl Bend, Crawl Fork, Crawl Cross.
- **Features (combat):**
  - Cistern (vault pillars standing in water, one plank walk). Iron.
  - Settling Tanks (three stone tanks, the middle one acid). Iron.
  - Overflow Chamber (inlets pour into a sunken overflow), Pump Room.
  - Sluice Gates (three gates across the channel, catwalks over them).
  - Confluence (four channels meet), Culvert Hall (three narrow culverts).
- **Kill zone:** Grand Collector (a big basin with an acid core).
- **Peaceful:** Maintenance Room (plank floor, workbenches), Lamp Room.
- **Mazes, 1 wide:** Storm Drains (grid of drains, water in some), Pipe
  Warren (with silt), Filter Beds (you cross through sand beds where
  walkways are blocked).
- **Side rooms, 1 wide, iron:** Outfall Pipe, Valve Room, Drain Pit, Storage
  Closet.
- **Barracks:** Rat Nest (refuse mounds), Refuse Heap (one big heap).
- **Leech Cistern:** a plank ring over the water. Iron.
- **Treasure, iron:** Smugglers Den (crates, a lit plank floor), Lost Cache
  (a chest on a stone island, rotten boards out to it).
- **Boss:** Rat Kings Throne (a plank dais and throne on the refuse), Great
  Sump (a sump with an acid core, crossed by plank bridges). The generator
  picks one of the six each run.

### Added 2026-09-26 (3 rooms, now 114)

These use `floor_brick`, `floor_grate`, `wall_brick` and `wall_iron`. Rules as above: odd
sizes, 5-wide mains with a 3-wide channel between ledges, rat swarms of five.

- **Great Cistern 71×71** (`combat`, `vast`): a cistern the size of a cathedral. Brick
  walkways on a grid over the water, grates at every crossing, brick piers standing in the
  pools, a dry brick island in the middle. Many ways round, so swarms can come from anywhere.
  Iron doors, like the other cisterns.
- **Grate Junction 25×25:** four mains meet over a grated sump.
- **Brick Culvert 13×31:** a brick culvert with a narrow channel and grated steps.

The rooms are written by `.claude/tools/room_maps/additions.py`.

## Adding a new room, step by step

1. **Pick the feature and sketch it** as a text grid: `#` brick, `O` stone,
   `R` rubble, `.` walkway, `~` water, `a` acid, `,` silt, `=` planks, `D`
   openings. Pick an odd inside size, then add 2 for the grid.
2. **Keep it built.** Straight walls, and symmetric where it makes sense.
3. **Check the openings.** Are they all one width? Are they centred? Give
   each opening cell the floor tile just inside it.
4. **Set the connectors.** Use `"door": "iron"` if it's a side room,
   cistern or treasure room, otherwise `"any"`. Always add `"free": true`.
5. **Add swarms** using the table above.
6. **Make the variants** if you want them: Flooded (water up one tile,
   an acid slick, `favored_minion` leech 5) and Collapsed (rubble off the
   walls, dirt around it, nothing cut off).
7. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
8. **Load a sewer dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
9. **Add it to the piece list above.**
