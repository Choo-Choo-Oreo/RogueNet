# Acid Caverns: how to make rooms

Natural caves eaten away by acid. Every room is a **feature**, a place you
could name: an acid lake, a dripping gallery, a corroded chasm, a moss
garden. Most features also come **Flooded**: the same room with the acid
risen. Every room with acid is a "find the dry path" puzzle: a path of dry
stone runs between the openings, and wading through the acid is the slow
way. Enemies are **vermin**: leeches lurking in the acid, and packs of
blind rats on the dry floor.

This file covers the acid caverns' own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_enemy`,
per-cell `enemy`), see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Rock | `wall_rough_cave` | Outer walls, pinches in the tunnels, maze walls. |
| Etched stone | `wall_smooth_cave` | Columns and lumps worn smooth by the acid, crystals in the Crystal Seep, the Etched Geode's shell. |
| Dirt | `floor_dirt` | Most floor. |
| Moss | `floor_grass` | Patches on the damp dirt within 2 tiles of the acid. |
| Dry stone | `floor_smooth_cave` | The paths across the acid, islands, stepping stones, bridges, the rim around the acid. |
| Acid | `floor_acid` | Lakes, rivers, seeps, drips. Slow (0.5 speed), no damage yet, so it never cuts a room off. |

- **Natural, not built.** Rooms are rough and lopsided, like the cave.
- **Dry paths.** Each acid room has a dry stone path from its first opening
  to every other one, and to any island in the acid.
- **Drips never block.** A single acid drip goes only where all 8 tiles
  round it are open floor.
- **Never acid in an opening,** nor on the tile just inside it. Openings
  carry the floor just inside them.
- **Flooded keeps the room's size and openings.** Acid spreads onto the
  dirt next to it, and one or two new streams cut across the room. The
  moss next to the acid is burned back to dirt. Dry stone never floods, so
  islands and bridges survive. The least-acid route between the openings is
  kept, often narrowed to 1 tile. A room gets no Flooded version when it
  would barely change: the crawls, Dry Alcove and Moss Nook.

## Acid rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room:** 3 (passages and rooms) or 1 (crawls,
   side pockets, the Braided Seeps maze, treasure).
3. **Openings are centred on their wall.**
4. **No doors.** Every connector is `"door": "none"`, and `default_door` is
   `"none"`.
5. **Every connector is `"free": true`,** so 3- and 1-wide pieces can join
   each other.
6. **Nothing unreachable.** Every floor tile, acid included, connects to
   the openings.

Every room sets `"base_floor": "floor_dirt"`.

## Enemies: vermin

Every spawn cell spawns one enemy. There are three kinds of cell:

- **Leech groups.** Loose groups (cells 2 apart) in the acid, 3+ tiles from
  the openings. Each has `"enemy": "leech"`.
- **Blind rat packs.** Tight clumps (cells next to each other) on dirt, moss
  or dry stone, as far from the openings as they fit. Each has
  `"enemy": "rat_blind"`.
- **Rolled cells.** Single cells spread out on the dry floor, with no
  `enemy`, so they roll from the biome's `monsters` table (the only way a
  bat shows up).

| Kind | Rat packs | Pack size | Leech groups | Group size | Rolled |
|---|---|---|---|---|---|
| Feature (combat) | 1 | 3 | 1 | 3 | 1 |
| Kill zone | 2 | 4 | 2 | 3 | 2 |
| Leech Pool | none | | 3 | 4 | 1 |
| Rat Nest | 3 | 4 | none | | none |
| Boss | 2 | 4 | 2 | 3 | 1 |
| Maze | 1 | 3 | none | | 1 |
| Treasure (guarded) | 1 | 3 | none | | none |
| Side pocket | none | | none | | 2 |
| Entrance, passage, crawl, peaceful | none | | none | | none |

No room sets `favored_enemy`. The 67 rooms have 302 spawn cells between
them: 150 blind rats, 108 leeches and 44 rolled.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Passage (3 wide), crawl (1 wide) | `corridor` | `corridor` |
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
- `monsters`: blind rat 3, leech 2, bat 2. The rat packs and leech groups
  are pinned on top of the table.
- `music`: Groovy.

## Current piece set (2026-09-24)

67 rooms: each feature below, plus `<Feature>_Flooded` where it changes
the room. Sizes are in the file names (grid size = inside + 2). A feature
whose name starts with "Acid" drops it from the file name, so Acid Lake is
`Acid_Lake_<W>x<H>`, not `Acid_Acid_Lake_...`.

- **Entrance:** Acid Seep (a trickle of acid down a slope), Drip Hall
  (etched columns, drips from the ceiling).
- **Passages, 3 wide:** Tunnel, Tunnel Bend, Tunnel Fork, Sludge Channel
  (dry stone floor, acid along one wall), Stepping Stones (dry stones a
  step apart across a pool), Etched Passage (etched pinches, a few drips).
- **Crawls, 1 wide:** Crawl, Crawl Short, Crawl Bend, Crawl Fork, Crawl
  Cross. No Flooded.
- **Features (combat):**
  - Acid Lake (a dry island), Sludge River (two dry fords), Acid Falls
    (acid pouring from the north wall into a pool), Bubbling Pits (small
    acid pits with dry rims).
  - Dripping Gallery (a long hall of columns and drips), Etched Columns
    (acid pooled round the column bases).
  - Corroded Chasm (a wide acid crack with two stone bridges), Moss Garden
    (acid pools in thick moss).
- **Kill zone:** Acid Basin (an acid ring round a dry island, dry paths in
  from all four openings).
- **Peaceful:** Dry Grotto, Crystal Seep (crystals on dry stone).
- **Mazes:** Etched Maze, Braided Seeps (1 wide), Honeycomb.
- **Side pockets, 1 wide:** Drip Pocket, Dry Alcove, Moss Nook, Acid Sump.
  Dry Alcove and Moss Nook have no Flooded.
- **Barracks:** Leech Pool (an acid pool ringed with etched stone), Rat
  Nest (hollows round a pit).
- **Treasure:** Etched Geode (a chest in an etched stone shell), Acid
  Island Cache (a chest on an island). Chest on dry stone.
- **Boss:** Great Basin (dry islands in an acid lake), Acid Heart (a dry
  platform ringed by acid). The generator picks one of the four each run.

## Adding a new room, step by step

1. **Pick the feature and sketch it** as a text grid: `#` rock, `O` etched
   stone, `.` dirt, `,` moss, `=` dry stone, `^` acid, `D` openings. Pick
   an odd inside size, then add 2 for the grid.
2. **Lay a dry stone path** between the openings through any acid, and
   keep acid off the openings and the tiles just inside them.
3. **Check the openings.** Are they all one width? Are they centred? Give
   each opening cell the floor tile just inside it.
4. **Set the connectors:** `"door": "none"`, `"free": true`.
5. **Add the spawns** using the table above. Give leech cells
   `"enemy": "leech"` (in the acid) and rat cells `"enemy": "rat_blind"`.
6. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
7. **Load an acid dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
8. **Add it to the piece list above.**
