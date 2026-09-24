# Room design briefs

Each biome folder has a `README.md` with the design philosophy for its rooms:
what walking through it should feel like, how tight the corridors are, how open
the rooms are, and what kinds of rooms are still missing. Read it before drawing
a room for that biome. `BIOMES.md` is the technical side (what the assembler
needs, tags, tile rules).

Written 2026-09-22 from Orea's brief. Scale: everyone is one tile and moves one
tile per step, dives are 5 to 8 players, and a fight can be a dozen or two
dozen enemies. Nobody walks through anybody, so 1-wide is single file.

## Room JSON reference

For anyone (human or model) reading or writing a room file
`game/rooms/<biome>/<id>.json`. The file name minus `.json` is the room's `id`.
Everything is in **tiles** (16px each) unless stated. Keys marked *(optional)*
can be left out. Rooms are also edited with the Dungeon Maker tool, which
writes this same format. The tool is owned by someone else, so do not change it
just to add a field here.

### Identity and size

| Key | Required | What it does |
|---|---|---|
| `id` | yes | Must match the file name. Rotated copies made at load time get `#r1`, `#r2`, `#r3` appended; that is never written to disk. |
| `biome` | usually | The folder name (`dungeon`, `cave`, ...). Biome is decided by the folder; this only labels the file. |
| `format` | yes | `2` today. Old format 1 files still load and are upgraded in memory. |
| `width`, `height` | yes | Size of the room's rectangle. The generator reserves this whole rectangle, so two rooms never overlap, even in empty corners. |

### Role and tags

- `role` *(optional, default `"normal"`)*: one of
  - `entrance`: where the dive starts. A biome needs at least one; with several, one is picked at random per dungeon (same seed, same pick). Never rotated.
  - `boss`: placed on the deepest dead end after the layout is built. Several are allowed: one is picked at random per dungeon, and if it does not fit anywhere the others are tried. Never rotated.
  - `corridor`: a connecting passage. Also used as filler when the boss needs a longer path.
  - `normal`: everything else.
- `tags`: free-text labels, all lower case. What they do:
  - The biome's `tag_weights` (in `defines.json`) can make a tag's rooms more or less likely to be picked (`maze` and `corridor` are down-weighted).
  - `treasure` takes a room out of the random pool. It is placed on a leftover dead end at the end. Give treasure rooms no `spawn_cells`.
  - Other tags (`combat`, `peaceful`, `stone`, `brick`, `wood`, ...) describe the room and are not read by code yet.
  - Room tags are not enemy tags. Enemy tags live in `game/TAGS.md`.

### Tiles: `floor`, `walls`, `base_floor`

- `floor` and `walls` are 2D arrays indexed `[y][x]`, `height` rows of `width` cells. Each cell is a tile id from `game/tiles/` or `null`.
- A cell with a floor id is walkable. A cell with a wall id and no floor is a wall, drawn on top of the room's base floor tile so it never shows empty ground.
- `null` in both arrays is void, outside the room.
- The outer ring of the grid is normally the wall ring: floor `null`, wall set.
- `base_floor` *(optional)*: the floor tile put under wall cells. If left out, the room's most common floor tile is used. Set it when the walls should sit on something different from the interior.

### Connectors: how rooms join

`connectors` is the list of openings the generator may attach other rooms to.
Each one is a straight run of cells on the outer ring:

```json
{ "a": {"x": 1, "y": 0}, "b": {"x": 2, "y": 0}, "free": true, "door": "wood" }
```

- `a` and `b` are the first and last cell, both included. `a` is the top or left end. `a` equal to `b` is a 1-wide opening.
- A run must sit on one edge and must not include a corner.
- The direction it faces comes from the edge it is on (north edge faces north).
- Leave the connector cells' `walls` (and `floor`) as `null` so the wall opens. The painter fills the opening.
- Two connectors join only when they face each other with equal width, unless either has `"free": true` (`free` is optional, default false). Free joins any widths with at least one cell overlapping, centred first; leftover cells become wall.
- `door` *(optional, default `"any"`)*: what this opening wants.
  - a door type name from `game/doors/` (`"wood"`, `"iron"`, `"iron_sink"`): always gets that door
  - `"none"`: no door
  - `"any"` (or omitted): whatever the other side asks for, otherwise the biome's `default_door`
  - Doors never change what connects, only what is drawn in the opening.
- A room with one connector is a dead end. The generator saves those for the end of the layout.

### Spawns

- `spawn_cells` *(optional)*: `[{ "position": {"x": 3, "y": 4} }, ...]`, tile coordinates inside the room, on floor. Each is a place an enemy may spawn. What spawns comes from the biome's `monsters` table in `defines.json`, not from the room.
  - Leave them out of `entrance`, `boss` and `treasure` rooms.
  - Spread a handful around cover and corners instead of clustering them in the open.
- `favored_enemy` *(optional)*: nudges what spawns in this room's cells.
  - Written as `{ "tag": "beast.rodent", "weight": 3 }`, or a list of those. `weight` is optional (default 3).
  - Every enemy in the biome's `monsters` table that carries the tag (or has that id) gets its weight multiplied by `weight`.
  - It only boosts: enemies not in the biome table are never added.
  - Tags and their meanings are in `game/TAGS.md`.

### Objects

`objects` *(optional)*: decorations and props, one entry each:

```json
{ "type": "torch", "position": { "x": 40.0, "y": 40.0 }, "rotation": 0.0 }
```

- `type` must be a known object id. Today: `torch` (a light source) and `chest`.
- `position` is in **pixels** (not tiles): tile x 16 + 8 is the middle of a tile.
- `rotation` is the object's rotation (`0.0` in every current room).

### Rotation

For roles other than `entrance` and `boss`, the loader adds 90, 180 and 270
degree copies, so each room is drawn once and works facing any way. Connectors
follow the rotation. Do not rely on a fixed neighbour or a fixed orientation.

### Minimal example

A 3x3 closet with one 1-wide opening on the south edge:

```json
{
  "id": "Dungeon_Closet_3x3", "biome": "dungeon", "format": 2,
  "width": 3, "height": 3, "role": "normal", "tags": ["peaceful"],
  "floor": [[null, null, null], [null, "floor_smooth_stone", null], [null, null, null]],
  "walls": [["wall_smooth_stone", "wall_smooth_stone", "wall_smooth_stone"],
            ["wall_smooth_stone", null, "wall_smooth_stone"],
            ["wall_smooth_stone", null, "wall_smooth_stone"]],
  "connectors": [{ "a": {"x": 1, "y": 2}, "b": {"x": 1, "y": 2} }],
  "spawn_cells": [{ "position": {"x": 1, "y": 1} }],
  "objects": []
}
```

(The floor in the connector cell `(1,2)` is `null` too; the painter fills it.
Real rooms are bigger than this. It only shows the shape of the file.)
