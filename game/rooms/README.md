# Room design briefs

Each biome folder has a `README.md` with the design philosophy for its rooms:
what walking through it should feel like, how tight the corridors are, how open
the rooms are, and what kinds of rooms are still missing. Read it before drawing
a room for that biome. `BIOMES.md` is the technical side (what the assembler
needs, tags, tile rules).

Written 2026-09-22 from Orea's brief. Scale: everyone is one tile and moves one
tile per step, dives are 5 to 8 players, and a fight can be a dozen or two
dozen minions. Nobody walks through anybody, so 1-wide is single file.

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
  - `entrance`: where the dive starts. A biome needs at least one; with several, one is picked at random per dungeon (same seed, same pick). The only role that is never rotated.
  - `boss`: placed on the deepest dead end after the layout is built. Several are allowed: one is picked at random per dungeon, and if it does not fit anywhere the others are tried. Rotated like a normal room, so draw it once.
  - `corridor`: a connecting passage. Also used as filler when the boss needs a longer path.
  - `normal`: everything else.
- `tags`: free-text labels, all lower case. What they do:
  - The biome's `tag_weights` (in `defines.json`) can make a tag's rooms more or less likely to be picked (`maze` and `corridor` are down-weighted).
  - `treasure` takes a room out of the random pool. It is placed on a leftover dead end at the end. Treasure rooms can have `spawn_cells` if the loot should be guarded.
  - Other tags (`combat`, `peaceful`, `stone`, `brick`, `wood`, ...) describe the room and are not read by code yet.
  - `vast` marks the big set pieces (60+ tiles a side, up to the 100x100 maximum). It is only read through `tag_weights`: biomes that have them set it to 0.35, so a dive meets about one.
  - Room tags are not minion tags. Minion tags live in `game/TAGS.md`.

### Weights: rooms first, corridors second

A dive should feel like rooms joined by passages, not passages with the odd
room. So when setting a biome's `tag_weights`, keep real rooms (combat,
barracks, peaceful, working rooms) as the main share of picks.

- **Keep `corridor` below 1.0.** Corridor pieces have `corridor` as both role
  and tag, so the weight counts twice: 0.7 gives 0.49 per piece.
- **Check the share, not just the number.** Add up weight × piece count for
  each kind. Corridors should be roughly a quarter of the total. Adding more
  corridor pieces raises their share even when the weight stays the same.
- **For corridor variety, add different shapes rather than raising the weight.**
  Some examples are S-curves, loops around a pillar, U-turns and forks (see the
  mine's shafts).
- The generator also adds corridors on its own to stretch the path to the
  boss, so a real dive will show a few more than the weights suggest.

Example: in the mine, `corridor` at 1.2 (1.44 per piece) made about 40% of
picks a shaft. Runs felt like all corridor. At 0.7 it's about 25%.

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
- Leave the connector cells' `walls` as `null` so the wall opens.
- The floor under an opening is the connector cell's `floor` value if it has one, otherwise `base_floor` (or the most common floor). Most rooms leave it `null`. The sewer sets it so water channels run out through the gap.
- Two connectors join only when they face each other with equal width, unless either has `"free": true` (`free` is optional, default false). Free joins any widths with at least one cell overlapping, centred first; leftover cells become wall.
- `door` *(optional, default `"any"`)*: what this opening wants.
  - a door type name from `game/doors/` (`"wood"`, `"iron"`, `"iron_sink"`): always gets that door
  - `"none"`: no door
  - `"any"` (or omitted): whatever the other side asks for, otherwise the biome's `default_door`
  - Doors never change what connects, only what is drawn in the opening.
- A room with one connector is a dead end. The generator saves those for the end of the layout.

### Spawns

- `spawn_cells` *(optional)*: `[{ "position": {"x": 3, "y": 4} }, ...]`, tile coordinates inside the room, on floor. Each is a place a minion may spawn. What spawns comes from the biome's `monsters` table in `defines.json`, not from the room.
  - A cell can pin its minion with `"minion"`: `{ "position": {"x": 3, "y": 4}, "minion": "skeleton_archer" }` always spawns that minion id (from `game/entities/entities.antagonist/`), skipping the table and `favored_minion`. The catacomb uses it to stand archers in lines.
  - Leave them out of `entrance`, `boss` and `treasure` rooms.
  - Spread a handful around cover and corners instead of clustering them in the open.
  - A spawn cell may name its minion: `{ "position": {...}, "minion": "rat" }` (any id from `game/entities/entities.antagonist/`). That cell then always spawns it instead of rolling the table. The Dungeon Maker's minion spawner sets this.
- `antagonist_spawns` *(optional, boss rooms)*: where the room's boss appears, one entry per boss: `{ "position": {"x","y"} }`. Always spawns (not hidden by the fog). Which boss comes is the room's `favored_antagonist`, written exactly like `favored_minion` (`{ "tag": "beast", "weight": 3 }`, weight optional): every minion with `"boss": true` in its json is a candidate, and the ones matching the tag are boosted, so it is the same rule and the same code as `favored_minion`. Today every boss room says `beast` except the Void's, which say `undead` (no undead boss exists yet, so it is still the Minotaur everywhere); a new boss kind only needs a `"boss": true` minion with its own tag. An entry with `"minion": "minotaur"` forces that one. The Dungeon Maker keeps both fields but has no tool for them, and its flip does not move the spawn.
- `favored_minion` *(optional)*: nudges what spawns in this room's cells.
  - Written as `{ "tag": "beast.rodent", "weight": 3 }`, or a list of those. `weight` is optional (default 3).
  - Every minion in the biome's `monsters` table that carries the tag (or has that id) gets its weight multiplied by `weight`.
  - It only boosts: minions not in the biome table are never added.
  - Tags and their meanings are in `game/TAGS.md`.

### Free-standing doors: `doors`

`doors` *(optional)*: doors inside a room that are not on a connector (a door across a corridor, a vault door). Each entry:

```json
{ "cell": { "x": 4, "y": 3 }, "orient": "h", "width": 2, "type": "iron" }
```

- `orient`: `"h"` blocks north-south, `"v"` blocks east-west.
- `cell` is the first cell of the run. For `"h"` it is the south cell of the leftmost column; the barrier lies between it and the cell above, and the door covers `width` cells to the right. For `"v"` it is the west cell of the top row; the barrier lies between it and the cell to its east, and the door covers `width` rows down (both the west and the east cell of each row).
- `type` is a door type from `game/doors/`, or `"any"` for the biome's `default_door` (`"none"` = no door). A type that does not fit `width` is swapped for one that does, with a warning.
- The painter removes any wall on the door's cells and lays floor there, so the room can leave them as they are. Use a 1-thick wall for `"h"` and a 2-thick one for `"v"`.
- They rotate with the room. They are added after every connector door, so those door ids do not change.
- The Dungeon Maker places them: the connector section's tool picker, "free-standing door".
- Status (2026-09-24): confirmed working in play by Orea (placement, drawing, opening and rotation). These rooms use them:
  - Vault doors (`iron`), sealing the chest end: `Dungeon_Treasure_Armory`, `Dungeon_Treasure_Hoard`, `Mine_Treasure_Strongbox`, `Mine_Treasure_Ore_Cache`, and their ruins versions where the vault wall still stands (`Ruins_Treasure_Armory_Overgrown`, `Ruins_Treasure_Armory_Reclaimed`, `Ruins_Treasure_Hoard_Overgrown`: iron doesn't rot).
  - The hut door (`wood`) in `Forest_Hunters_Cache`, plus a 2-wide fence gate in its Overgrown version.
  - Air doors (`wood`, 3 wide) across the tunnels of `Mine_Maze_Hub` and `Mine_Maze_Narrow_Honeycomb`.
  - Sluice gates (`iron_sink`, 5 wide) across the whole main in `Sewer_Main_Line` and `Sewer_Main_Short` and their variants.
  - Only minions with `"doors": "open"` or `"phase"` (skeleton archer, minotaur, wraith) get through, so these doors hold rats, wolves and the rest back.

### Objects

`objects` *(optional)*: decorations and props, one entry each:

```json
{ "type": "torch", "position": { "x": 40.0, "y": 40.0 }, "rotation": 0.0 }
```

- `type` must be a known object id: `torch` (a light source), `chest`, `sign`, or a prop.
  A prop is any picture in `resources/gfx/objects/props/`, named by its file in lower case
  (`Barrel.png` is `barrel`). Props are drawn in a live dive (`scripts/dungeon/Props.gd`),
  cosmetic only: nothing bumps into one. The other types are not drawn in a dive yet.
  A room the assembler turns takes its objects with it; the pictures stay upright.
- `position` is in **pixels** (not tiles): tile x 16 + 8 is the middle of a tile.
- `rotation` is the object's rotation (`0.0` in every current room).

### Rotation

For every role except `entrance`, the loader adds 90, 180 and 270
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

(The floor in the connector cell `(1,2)` is `null` too, so the painter fills it with `base_floor`.
Real rooms are bigger than this. It only shows the shape of the file.)
