# Biomes

Added 2026-09-21.

Design briefs (what each biome should feel like to walk through) are in
`README.md` here and in each biome folder's `README.md`. This file is the
technical side.

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

That was the starting set. `dungeon/` and `mine/` were redesigned on
2026-09-24 and now have much larger sets: two entrances, two bosses, several
treasure rooms and 8 or 24 mazes. `flesh/` was redesigned the same day as
84 rooms, one per organ plus a mutant of each, `forest/` as 78 rooms,
one per landmark plus an Overgrown variant, and `cave/` as 76 rooms, one per
formation plus a Deep variant. `sewer/` was added the same day as 111 rooms,
one per feature plus a Flooded and a Collapsed variant, and `catacomb/` as
80 rooms, one per feature plus a Desecrated variant, and `volcano/` as
64 rooms, one per feature plus an Erupting variant, and `manor/` as
63 rooms, one per named room plus a Haunted variant, and `ruins/` as
86 rooms, every dungeon room overgrown by the forest in two stages, and `acid/` as
67 rooms, one per feature plus a Flooded variant. Each folder's own `README.md`
lists every piece.

| Folder | Walls | Floors | Idea |
|---|---|---|---|
| `dungeon/` | `wall_cobble_brick` | smooth stone | Built masonry. 2-wide corridors and open rooms, with small side rooms off 1-wide doors. |
| `cave/` | `wall_rough_cave` rock, `wall_smooth_cave` flowstone and crystal | dirt, moss (grass), smooth cave, water, lava | Natural caves by formation: one room per feature (stalactite hall, underground lake, magma pool, geode), plus a Deep variant of each. No doors. Tight tunnels, and enemies come in bat swarms. |
| `mine/` | `wall_rough_cave` rock with `wall_wood_plank` timber supports | dirt, wood plank walkways | A mine shaft. Plank tracks run door to door. Timber frames doorways and props up long tunnels. Includes `Mine_Cabin_Cavern_17x13`, a big cavern with a cabin in the middle. |
| `flesh/` | `wall_flesh` | flesh, smooth stone, acid | Inside a body: one room per organ, plus a mutant of each (extra lobes, doubled parts). Lopsided, never symmetric. Flesh floor slows movement, so stone strips act as fast lanes. Very dense with enemies. |
| `forest/` | `wall_forest` trees, `wall_rough_cave` rocks, `wall_wood_plank` timber | dirt, grass, water, wood planks | Woods by landmark: one room per forest feature (pond, fallen giant, wolf den), plus an Overgrown variant of each. No doors. Trails wind between openings, and enemies come in wolf packs. |
| `sewer/` | `wall_cobble_brick` brick, `wall_smooth_stone` pillars and tank walls, `wall_rough_cave` rubble | smooth stone walkways, water, acid, dirt (silt), wood planks | Built sewers by feature: one room per feature (cistern, sluice gates, pump room, rat nest), plus a Flooded and a Collapsed variant of each. Symmetric brickwork, 5-wide mains with a water channel between two ledges, 1-wide crawls. Iron doors on side rooms, cisterns and treasure. Enemies come in rat swarms, with leeches in the water. |
| `catacomb/` | `wall_cobble_brick` brick, `wall_smooth_stone` sarcophagi, bone stacks and altars, `wall_rough_cave` rubble | smooth stone, dirt, violet carpet (tombs only) | Burial galleries by feature: one room per feature (ossuary, columbarium, charnel pit, family tomb), plus a Desecrated variant of each. Burial niches cut every other tile into thick walls. 3-wide processionals and 1-wide galleries. Iron doors on tombs, treasure and boss crypts. Undead garrisons: skeleton archers pinned in lines, wraiths and the rest in the niches. |
| `volcano/` | `wall_rough_cave` basalt, `wall_smooth_cave` obsidian | dirt (ash), smooth cave (cooled crust), lava | Volcanic features: one room per feature (lava river, caldera, cinder cone, fumarole vents, magma chamber), plus an Erupting variant with more lava. Every lava room has a crust path between its openings: the fast way through. No doors. Demon packs: hellhounds in tight packs on the ground, demonic hamster swarms over the lava. |
| `manor/` | `wall_cobble_brick` outer walls, `wall_wood_plank` partitions and furniture, `wall_smooth_stone` hearths, busts and stairs, `wall_forest` potted trees | wood planks, smooth stone, all five carpets (one colour per room), dirt, grass, water | A great house by named room: dining hall, ballroom, study, kitchen, grand library. One carpet colour per room, furniture as wall stand-ins, plus a Haunted variant (furniture overturned, carpet torn, walls broken through). 3-wide hallways and 1-wide servants' passages. Wood doors on rooms (bi-fold on 3-wide), iron on the strongroom and bosses. A haunting: rolled cells (mostly wraiths), rat nests in the service rooms, bat roosts in the attic and gallery. |
| `ruins/` | `wall_cobble_brick` brick, `wall_forest` trees growing through it | smooth stone, grass, dirt, water | The dungeon reclaimed by the forest: every dungeon room, made by script, in two stages. Overgrown (grass breaking through, some trees in the walls, a few walls fallen in) and Reclaimed (mostly grass, walls half trees, more fallen in, pools). Same shapes and openings as the dungeon. No doors. Dungeon and forest enemies mixed: Overgrown rooms lean undead (skeleton archers, wraiths), Reclaimed rooms lean beasts (wolf packs, rats, bats), bats in the corners, a rare hellhound. |
| `acid/` | `wall_rough_cave` rock, `wall_smooth_cave` etched stone and crystal | dirt, grass (moss), smooth cave (dry stone), acid | Caves eaten by acid: one room per feature (acid lake, dripping gallery, stepping stones, corroded chasm, moss garden), plus a Flooded variant where the acid rises and scorches the moss. Every acid room has a dry stone path between its openings: the fast way through. No doors. Leeches pinned in the acid, blind rat packs on the dry floor, bats rolled. |

## `cathedral/` is a stress test, not a designed biome

Added 2026-09-21 to see how generation and rendering hold up at size.
Rebuilt 2026-09-24: it is now the current 43 `dungeon/` rooms with their
interiors scaled 3x (outer wall still 1 thick, doors 3 or 5 wide), redecorated
with carpets, pillars and pews, plus `Cathedral_Boss_Nave_100x100`, which is
the Dungeon Maker's maximum size. Rooms average about 700 tiles (flesh: about
250), so a 25-40 room dive is roughly 18,000-28,000 room tiles, the biggest
biome again. See `cathedral/README.md`. Because it is a folder in `game/rooms/`,
`pick_biome()` will choose it like any other biome. Add it to
`IGNORED_FOLDERS` in `DungeonAssembler.gd` when the test is over.

## Maze pieces

The assembler grows a dungeon as a tree: it never joins two branches back
together. So the maze feel has to come from the pieces themselves. Each
biome started with the same ten kinds, drawn differently per biome
(`dungeon/` and `mine/` have since replaced theirs, see their READMEs):

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
and `load_rooms(biome)`. Every subfolder of `game/rooms/` that is not in `IGNORED_FOLDERS` counts
as a biome. `fallback/` holds exactly one room per kind the assembler can
ask for: `Entrance_15x15`, `Boss_Vault_11x11`, `Treasure_Vault_5x5`,
`Corridor_3x9` and `Brick_Arena_9x9` (normal). Trimmed to that on
2026-09-22; the other legacy rooms are in git history if needed.
The biome is picked from the dungeon seed, so every peer picks the same one.

`DungeonPainter.gd` calls
`load_rooms(pick_biome(seed))` (the F5 debug draws in `scripts/debug/` read its result from `DebugState`). `fallback/` is in `IGNORED_FOLDERS`, so it is
never picked as a biome; it only fills in room kinds a biome is missing.

## Dungeon Maker and biomes

Updated 2026-09-21. The Dungeon Maker now:

- builds its tile list from the tiles the renderer has, so a new TileType
  `.tres` in `resources/tiles/` shows up without compiling `tile_palette.json`;
- has Role and Biome folder dropdowns, writes both into the JSON, and saves
  into `game/rooms/<biome>/`. Opening a room sets the biome from its folder;
- lists rooms, known tags and "Validate All" across every folder here.

Still hard-coded in `DungeonMaker.gd`: the object types (`torch`, `chest`)
and the enemy types (`mouse`).
