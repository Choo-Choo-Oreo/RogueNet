# Biomes

Added 2026-09-21.

A biome is one self-contained room pool. One dive should draw all its
rooms from one biome, so run A feels different from run B. Each biome is
a subfolder here and holds a full set the assembler can build a dungeon
from on its own:

- 1 `entrance`
- 1 `boss`
- 1 room tagged `"treasure"`
- 2 `corridor` rooms
- 5 `normal` rooms
- 10 maze pieces (`<Biome>_Maze_*`, role `normal`, tagged `"maze"`), see below

| Folder | Walls | Floors | Idea |
|---|---|---|---|
| `dungeon/` | `wall_cobble_brick`, `wall_smooth_stone`, `wall_wood_plank` | smooth stone, wood planks, a little dirt | Built masonry. Wood rooms are barracks and cabins inside it. |
| `cave/` | `wall_rough_cave` | dirt, grass patches | Thick irregular walls, few straight edges. |
| `mine/` | `wall_rough_cave` rock with `wall_wood_plank` timber supports | dirt, wood plank walkways | A mine shaft. Plank tracks run door to door. Timber frames doorways and props up long tunnels. Includes `Mine_Cabin_Cavern_19x15`, a big cavern with a cabin in the middle. |
| `flesh/` | `wall_flesh` | flesh, smooth stone | Flesh floor slows movement, so stone strips act as fast lanes. |

## `cathedral/` is a stress test, not a designed biome

Added 2026-09-21 to see how generation and rendering hold up at size. It is
the 20 `dungeon/` rooms with their interiors scaled 3x or 4x (outer wall
still 1 thick, doors still 1 wide), plus `Cathedral_Boss_Nave_100x100`, which
is the Dungeon Maker's maximum size. A dive here is about 25,000 room tiles
inside a roughly 240 x 256 tile box. Because it is a folder in `game/rooms/`,
`pick_biome()` will choose it like any other biome. Add it to
`IGNORED_FOLDERS` in `DungeonAssembler.gd` when the test is over.

## Maze pieces

The assembler grows a dungeon as a tree: it never joins two branches back
together. So the maze feel has to come from the pieces themselves. Each
biome has the same ten kinds, drawn differently per biome:

| Piece | Doors | What it does to the player |
|---|---|---|
| Tee / Fork | 3 | Narrow three-way split. The base pools had almost none. |
| Pinwheel / Cross / Crosscut | 4 | Doors are off-centre, so rooms beyond stop lining up on a grid. Has an inner loop. |
| Dogleg | 2 | Exit is offset from the entry, shifting everything after it sideways. |
| U-turn | 2 | Both doors on the same side. Sends the player back the way they were heading. |
| Spiral / Coil / Drift | 1 | A long dead end with a chest at the end of it. |
| Ring / Twin Loop | 3-4 | A loop around a solid core. The only loops in the game are inside rooms. |
| Labyrinth / Warren / Intestine / Workings | 3 | A real small maze with loops and stubs. |
| Switchback | 2 | Serpentine. Long walk, doors at opposite corners. |
| Hub | 5-6 | Many doors, some two to a side, and repeating pillars. |
| Deja vu | 4 | Looks the same from every door, with baffles blocking the view across. |

**Rule for any new piece: all floor must connect inside the room.** A room
whose doors don't all reach each other would cut off whole branches,
possibly the boss, because nothing loops back around.

## Rules for a biome room

- It lives in the biome's folder and has `"biome": "<folder name>"`.
- Its `id` starts with the biome name (`Cave_Hollow_11x9`), so it can
  never clash with a legacy room. The filename is the `id` plus `.json`.
- It uses that biome's walls and floors only.
- Everything else follows `scripts/dungeon/DUNGEON_CREATOR_README.md`.

## What is live right now

As of 2026-09-21 `DungeonAssembler` has `list_biomes()`, `pick_biome(seed)`
and `load_rooms(biome)`. Every subfolder of `game/rooms/` except `tmp` counts
as a biome, including `fallback/`, which holds the original legacy rooms.
The biome is picked from the dungeon seed, so every peer picks the same one.

`DungeonPainter.gd` and `DungeonDebugView.gd` still call `load_rooms()` with
no biome. That reads the top level of `game/rooms/`, which no longer has any
rooms in it. Until they pass `pick_biome(seed)` in, no dungeon generates.

## Known Dungeon Maker gaps

- Export (`_build_export_data()`) writes neither `role` nor `biome`.
  Re-exporting a room from the tool drops both fields.
- The recent-rooms list and "Validate All" only look at the top-level
  folder. The Open dialog can browse into a biome folder.
