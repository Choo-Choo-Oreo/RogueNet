# Cave: how to make rooms

Natural caves with no doors anywhere. Every room is a **formation**, a
feature you could name: a stalactite hall, an underground lake, a magma
pool, a geode. Every formation also comes **Deep**: the same place, bigger
and further in, with a second pool, more columns or two geodes instead of
one. Tunnels are tight and lumpy. Enemies come in **swarms**, mostly bats,
spread loosely through the bigger chambers.

This file covers the cave's own rules. For the full room file format (every
key, connectors, `free`, per-connector `door`, `favored_enemy`), see
[../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Rock | `wall_rough_cave` | Outer walls, stalagmites, boulders, rubble, pinches in tunnels. |
| Flowstone, crystal | `wall_smooth_stone` | Columns, rimstone lips, crystal clusters, the geode's shell. |
| Dirt | `floor_dirt` | The normal floor. |
| Moss | `floor_grass` | Only where there's light (the cave mouth, under the sinkhole) or damp (by water). |
| Smooth stone | `floor_smooth_stone` | Flowstone floors, the old lava tube's glassy floor, cooled crust around lava. |
| Water | `floor_water` | Lakes, streams, pools, sumps. Slows movement. |
| Lava | `floor_lava` | Lava tubes and magma rooms. Slows movement a lot (to a fifth of normal speed) but does no damage. |

- **Nothing is straight or symmetric.** Edges are rough and tunnels lumpy.
  Columns come in uneven sizes.
- **The formation gives the shape.** A lake room is mostly lake, and a
  chasm is a crack across the floor with stone bridges. If someone could
  look at the room and name the feature, it's right.
- **Deep adds to the place, it doesn't replace it.** The same formation,
  only more of it.
- **Tunnels are tight.** Passages are 3 wide at the openings, but rock
  bulges off the walls pinch them narrower inside. A pinch never cuts a
  tunnel off.

## Cave rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room.** Passages are 3 wide and crawlways 1
   wide. A room's openings are all one width.
3. **Openings are centred on their wall, or in mirrored pairs.**
4. **No doors.** `default_door` is `"none"` and every connector has
   `"door": "none"` and `"free": true`, so cave rooms join whatever they
   touch, whatever the widths.
5. **Nothing unreachable.** Every floor tile connects to the openings, and
   there are no spawn cells right beside an opening. Water and lava count
   as floor, since they slow you down but don't stop you.
6. **Lone stalagmites never block a path.** A single rock only goes where
   all eight tiles around it are open.

Every room sets `"base_floor": "floor_dirt"`.

## Enemies: swarms

Every spawn cell spawns one enemy (unless the cell is lit). In the cave,
spawn cells come in **swarms**: a loose cluster of cells (each within 4
tiles of the swarm's centre, 2 apart). Swarms are spread well apart (6+
tiles) and kept away from the openings. They're bigger and looser than
the forest's wolf packs, to fit bats.

| Kind | Swarms | Swarm size |
|---|---|---|
| Formation (combat) | 1, plus 1 more per 180 floor tiles | 5 |
| Kill zone | 3 | 5 |
| Barracks | 3 | 5 |
| Boss | 2 | 5 |
| Maze | 1 | 4 |
| Treasure (guarded) | 1 | 3 |
| Side pocket | 1 | 2 |
| Entrance, passage, crawlway, peaceful | none | |

The 74 rooms have 306 spawn cells between them.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Passage (3 wide), crawlway (1 wide) | `corridor` | `corridor` |
| Formation, side pocket | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Peaceful | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Barracks | `normal` | `barracks` |
| Treasure | `normal` | `treasure` (guarded: has spawns) |
| Boss | `boss` | `combat` |

### `defines.json`

- `room_count` 30 to 50 (unchanged).
- `default_door` `"none"`.
- `tag_weights` are the same as flesh and forest:
  - `corridor` 0.7
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7

  The old maze boost of 1.5 is gone. Only 8 of the 74 rooms are mazes now.
- `monsters` and `music` are unchanged: bat 3, blind rat 2, wolf 1, and
  Groovy.

## Current piece set (2026-09-24)

74 rooms: each formation below, plus `<Formation>_Deep`. Sizes are in the
file names (grid size = inside + 2).

- **Entrance:** Cave Mouth (moss where daylight gets in), Sinkhole (a moss
  circle under the hole in the roof; Deep adds rubble from the collapse).
- **Passages, 3 wide:** Tunnel, Tunnel Bend, Tunnel Fork, Lava Tube
  (smooth floor with lava along one wall; Deep has lava along both),
  Underground Stream, Rift (a zigzag crack).
- **Crawlways, 1 wide:** Crawlway, Squeeze, Crawlway Bend (a turn that loops
  around the room), Keyhole.
- **Formations (combat):**
  - Stalactite Hall (lone stalagmites), Column Hall (flowstone columns).
  - Underground Lake, Rimstone Pools (stepped pools behind stone lips).
  - Chasm (a crack across the floor with stone bridges), Magma Pool.
  - Rockfall (boulders), Flowstone Slope (smooth floor with a stream down it).
- **Kill zone:** Echo Chamber (a big dome with pillars around the edge).
- **Peaceful:** Crystal Grotto, Glowworm Grotto (moss around a pool).
- **Mazes:** Spongework, Boulder Choke, Braided Passages, Pillar Maze.
- **Side pockets, 1 wide:** Alcove, Pothole, Sump, Crevice.
- **Barracks:** Bat Roost (rock pillars to roost on), Rat Warren (burrows
  off a central chamber).
- **Treasure:** Geode (chest inside a crystal shell; Deep has two, one
  empty), Waterfall Grotto (chest behind a curtain of water).
- **Boss:** Great Cavern (columns and a pool), Magma Heart (a lava lake
  with stone islands). The generator picks one of the four each run.

## Adding a new room, step by step

1. **Pick the formation and sketch it** as a text grid: `#` rock, `O`
   flowstone/crystal, `.` dirt, `,` moss, `=` smooth stone, `~` water, `^`
   lava, `D` openings. Pick an odd inside size, then add 2 for the grid.
2. **Make it rough.** If you can fold it in half and it matches, break it
   up.
3. **Check the openings.** Are they all one width? Are they centred, or a
   mirrored pair?
4. **Set the connectors.** Give each one `"door": "none"` and
   `"free": true`.
5. **Add swarms** using the table above.
6. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
7. **Load a cave dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
8. **Add it to the piece list above.**
