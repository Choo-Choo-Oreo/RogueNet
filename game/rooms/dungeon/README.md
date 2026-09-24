# Dungeon biome: how to make rooms

Built masonry: smooth stone floors, cobble brick walls. The dungeon is made
of wide, walkable corridors and open rooms. Small side rooms hang off the
main path through 1-wide doors.

This file covers the dungeon's own rules. For the full room file format (every
key, connectors, `free`, per-connector `door`, `favored_enemy`), see
[../README.md](../README.md).

## How the generator uses your room

Knowing this makes most of the rules below make sense.

- **A room is a puzzle piece.** Its connectors are the doorways. Two rooms join
  only where a connector faces another connector of the **same width**. A
  2-wide door never joins a 1-wide door, unless one of them is marked `free`.
- **The dungeon is a tree.** It starts at the entrance and adds rooms outward.
  Branches never loop back, so every connector that doesn't get a neighbour
  becomes a wall.
- **Rooms are rotated for you.** Draw each room once. The generator tries all
  four turns, except for the entrance and boss, which are never rotated.
- **Each room reserves its whole rectangle**, including its outer wall ring,
  even the parts that are solid wall. A big room with lots of dead wall
  wastes space the generator could have used.
- **Special rooms are placed last.** The boss goes on the deepest leftover
  doorway. A treasure room (tag `treasure`) goes on any leftover doorway that
  fits. Neither is ever picked as a random room.
- **Monsters come from `defines.json`**, not from the room. A room only
  marks *where* monsters may appear (`spawn_cells`). A spawn cell that is lit
  for the player when the dungeon loads doesn't spawn anything.

## Dungeon rules

1. **Corridors are 2 wide.** Corridors, bends and junctions have a 2-wide
   walkway.
2. **Two door sizes.**
   - **Wide (2 tiles):** corridors, junctions, the entrance, the boss, combat
     rooms and mazes built with 2-wide paths.
   - **Narrow (1 tile):** small rooms, side rooms, treasure rooms, and mazes
     built with 1-wide paths.
3. **Doors sit dead centre on their wall.** That makes the room line up the
   same way in every rotation.
   - A wide door needs an **even** wall length. For example, a 12-wide room
     has its door on cells 5 and 6.
   - A narrow door needs an **odd** wall length. For example, a 7-wide room
     has its door on cell 3.
   - One exception is the `Corridor_Tap` pieces. They have even ends for wide
     doors and an odd side length (9) for the narrow side door.
4. **Symmetric rooms.** Mirror left-right where you can. Mazes and bends can't
   mirror, so they use rotational symmetry instead (they look the same turned
   180° or 90°) or diagonal symmetry.
5. **Every narrow room needs something to plug into.** Narrow doors only join
   narrow doors. When you add narrow rooms, make sure the "Narrow links" pieces
   below still cover them.
6. **Nothing unreachable.** Every floor tile must be reachable from every
   door, with no sealed-off pockets.
7. **Fair in any rotation.** Don't design around a specific neighbour, and
   don't put spawn cells right next to a door where they would hit the player
   before the room is even on screen.

## Doors

The dungeon's `default_door` is `"none"`, so a doorway is open unless some
room asks for a door.

- **Entrance:** its four connectors say `"door": "wood"`, so the doorways out
  of the entrance always get wood doors.
- **Combat rooms** (`Combat_*`): every connector is `"door": "wood"`.
- **Every 1-wide (narrow) connector**, in any room, is `"door": "wood"`.
  Narrow doorways always get a door.
- **Corridor pieces:** their 2-wide connectors say `"door": "any"`, meaning
  they take whatever the room on the other side asks for. A corridor joining
  a combat room gets wood, and a corridor joining another corridor stays
  open. `"any"` is also what you get when `door` is left out. It's written
  here so the intent is visible.
- **Other rooms' wide doorways** (mazes, peaceful, barracks, kill zone,
  boss, Side DeadEnd) don't set `door`, so they are open unless the room on
  the other side asks for a door.
- **To give a room doors**, set `"door": "wood"` (or `"iron"`, `"iron_sink"`)
  on its connectors. If both sides of a doorway name a type, the deeper room
  wins.

## Sizes: inside vs. grid

When we talk about a room's size, we usually mean the **inside**, the part you
walk on. The file's `width`/`height` is the **grid**, which adds a 1-tile
wall ring all the way around: **grid = inside + 2**.

The entrance is 10×10 inside, so it's 12×12 in the file and named
`Dungeon_Entrance_12x12`. File names always use the grid size.

## Room file checklist

- File name `Dungeon_<Name>_<W>x<H>.json`, where W×H is the **grid** size.
  `id` is the file name without `.json`.
- `biome` is `"dungeon"` and `format` is `2`.
- `floor` and `walls` are rows (`[y][x]`) of tile ids or `null`.
  - Floor tiles: `floor_smooth_stone`. Wall tiles: `wall_cobble_brick`.
  - Solid cells have a wall and `null` floor. Walkable cells have floor and
    `null` wall.
  - **Door cells** on the outer ring are `null` in **both** grids.
- `connectors`: one `{"a": {x, y}, "b": {x, y}}` per doorway, covering its
  cells from end to end. For a narrow door, `a` and `b` are the same cell.
- `spawn_cells`: `{"position": {x, y}}` in **tile** coordinates, on floor.
- `objects` are in **pixels**: tile × 16 + 8 for the centre of a tile.
- `role`: `entrance`, `boss`, `corridor` or `normal`.
- `tags`: pick from the list below.

## Roles and tags

| Kind | role | tags | Notes |
|---|---|---|---|
| Entrance | `entrance` | *(none)* | Only one per biome. Not rotated. No spawns. |
| Corridor, bend, junction, narrow link | `corridor` | `corridor` | Also used to stretch a path so the boss fits. |
| Combat room | `normal` | `combat` | The bread and butter. |
| Kill zone | `normal` | `killzone` | Many spawns, a hard fight. Kept rarer. |
| Breather | `normal` | `peaceful` | No spawns. |
| Maze | `normal` | `maze` | 2-wide paths with wide doors, or 1-wide paths with narrow doors. |
| Side room / dead end | `normal` | `combat` | Usually one narrow door. |
| Barracks | `normal` | `barracks` | A hall with pockets off it. Favors `undead.skeleton` (weight 3). |
| Treasure | `normal` | `treasure` | Never random. Placed on a leftover doorway. |
| Boss | `boss` | `combat` | Not rotated. Placed on the deepest doorway. |

### How often each kind shows up (`defines.json` → `tag_weights`)

A room's chance is its **role's** weight multiplied by each of its **tags'**
weights. Anything not listed counts as 1.0.

| key | weight | effect |
|---|---|---|
| `corridor` | 0.8 | Corridor pieces have this as both role and tag, so they end up at 0.8 × 0.8 = **0.64**. |
| `maze` | 0.6 | Mazes are fun, but not every other room. |
| `killzone` | 0.5 | Rare spikes of difficulty. |
| `peaceful` | 0.7 | A breather now and then. |

Lower weight means less often, but never impossible.

## Current piece set (2026-09-24)

40 rooms. The sizes below are the grid size.

- **Entrance:** Entrance 12×12 (four wide doors), Entrance Wings 12×12 (wide
  doors north and south, plus two narrow doors each on the west and east
  walls). The Wings' narrow doors can't be centred on the even 12-tile walls,
  so they sit as a mirrored pair, 3 tiles in from each end.
- **Corridors:** Corridor Short 4×6, Medium 4×10 and Long 4×14, Bend 6×6,
  Junction T 8×8, Crossroads 10×10.
- **Narrow links:** Corridor Tap 4×9 (wide corridor, one narrow side door),
  Corridor TapTwin 4×9 (two narrow side doors), Passage Narrow 3×7, Passage
  Bend 5×5, Passage Fork 5×5.
- **Combat:** Hall 12×10, Pillars 14×14, Divide 14×10, Ring 14×14, Cross
  14×14, Gallery 8×16, Octagon 12×12.
- **Kill zone:** Killzone 10×14 (12 spawns).
- **Peaceful:** Shrine 8×8, Garden 10×10.
- **Mazes, wide doors:** Switchback 12×10, Pinwheel 12×12, Rings 12×12,
  Labyrinth 16×16.
- **Mazes, narrow doors:** Narrow Serpent 11×9, Narrow Rings 9×9, Narrow
  Warren 11×11, Narrow Crooked 7×11.
- **Side rooms:** Closet 5×5, Storeroom 7×7, Cells 9×7 (all narrow), DeadEnd
  6×8 (wide).
- **Barracks:** Barracks 12×12.
- **Treasure:** Vault 7×7, Hoard 9×11 (both narrow).
- **Boss:** Throne 18×18, Pit 16×16 (8 minion spawns each).

## Adding a new room, step by step

1. **Sketch it first.** Use graph paper or a text grid with `#` for wall,
   `.` for floor and `D` for doors. Decide the inside size, then add 2 for
   the grid.
2. **Check the door rule.** Is each door centred? Is the wall even for a wide
   door and odd for a narrow one?
3. **Check it connects to something.** If it only has narrow doors, is there a
   narrow link that can reach it?
4. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or by
   hand, copying a similar room's JSON as a starting point.
5. **Check it in the game.** Load a dungeon and watch the Godot output for
   `Room '<id>': ...` warnings. The assembler checks connectors on load and
   reports anything off the edge, in a corner or overlapping.
6. **Add it to the piece list above** so the next person knows it exists.
