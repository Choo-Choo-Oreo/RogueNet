# Void: how to make rooms

Floating ruins over the abyss: the necrotic biome. Broken stone platforms
and bridges hang in nothing, and the rooms are islands joined by their
bridges. The abyss is **Perditio**, the necrotic branch of the magic system
(see `game/damage_types.json`): the irreversible null under everything.
Whatever falls into it is gone for good, and nothing here is ever rebuilt.
Most rooms also come **Crumbling**: the same room after the null has eaten
further in. The dead haunt the ruins: wraiths drift over the platforms, and
echo bats cling to the very edge of the drop.

This file covers the Void's own rules. For the full room file format (every
key, connectors, `free`, per-connector `door`, `favored_minion`,
`antagonist_spawns`, per-cell `minion`), see [../README.md](../README.md).
The dungeon's guide ([../dungeon/README.md](../dungeon/README.md)) explains
how the generator places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| The abyss | none (`null` floor and wall) | Everything that isn't a platform, the room's outer ring included. The game fills it with `floor_void`. |
| Stone | `floor_smooth_stone` | Platforms and bridges. |
| Rubble and rot | `floor_dirt` | Crumbled stone along the edges, and rot round the holes of the Rotted Floor. |
| Ruined walls | `wall_cobble_brick` | Stubs of old masonry: the Null Gate's back wall, hall walls, the Fallen Tower, vault walls. |
| Pillars and headstones | `wall_smooth_stone` | Posts on the bridge landings, colonnades, standing stones, the Headstone Field. |

- **The abyss is real.** A void cell can't be walked into, and minions
  route round it. It also blocks sight like a wall, so you can't see across
  a gap (for now).
- **Rooms are islands.** There is no outer wall: the ring is abyss except
  for the openings, and each opening is a bridge of its width leading in.
  Two joined rooms' bridges meet end to end. An opening the generator
  doesn't use is sealed with a wall tile, which hangs in the void like a
  broken-off pillar.
- **Built, but broken.** The ruins were built straight and mostly
  symmetric, then broke: bites out of the edges, rubble, holes.
- **Openings carry the floor just inside them.**
- **Crumbling keeps the room's size and openings.** Edge tiles fall away,
  bridges thin, and a few new holes open. A tile only falls if everything
  else stays connected, so the room never splits and a vault or boss
  platform is never cut off. A room gets no Crumbling version when it would
  barely change: the five ledges.

Room names follow the three strands of Perditio: **Ruina** (collapse: the
Ruined Span, Sunken Hall, Fallen Tower, Stair to Nothing, Throne of Ruin),
**Torpor** (stillness: the Torpor Shrine, Still Terrace) and **Virulentia**
(rot: the Rotted Floor). The rest are the dead's: barrows, tombs, graves and
headstones.

## Void rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room:** 3 (bridges and most rooms) or 1 (ledges,
   side pockets, the Span Maze, treasure).
3. **Openings are centred on their wall.**
4. **No doors.** Every connector is `"door": "none"`, and `default_door` is
   `"none"`.
5. **Every connector is `"free": true`,** so 3- and 1-wide pieces can join
   each other.
6. **Nothing unreachable.** Every floor tile connects to the openings.
7. **The ring is abyss.** Outer ring cells are `null` in both arrays,
   except the openings.

Every room sets `"base_floor": "floor_smooth_stone"`.

## Minions: the dead

Every spawn cell spawns one minion. There are three kinds of cell:

- **Wraith packs.** Loose groups (cells 2 apart) on the platforms, as far
  from the openings as they fit. Each has `"minion": "wraith"`.
- **Echo bats.** Single cells on the very edge of the abyss, or tucked
  against walls. Each has `"minion": "bat_echo"`.
- **Rolled cells.** Spread out, with no `minion`, so they roll from the
  biome's `monsters` table.

| Kind | Wraith packs | Pack size | Echo bats | Rolled |
|---|---|---|---|---|
| Combat | 1 | 3 | 2 | 1 |
| Kill zone | 2 | 4 | 4 | 2 |
| Wraith Hall | 3 | 4 | none | 1 |
| Echo Roost | none | | 7 | 1 |
| Boss | 2 | 4 | 3 | 1 |
| Maze | 1 | 3 | 1 | 1 |
| Treasure (guarded) | 1 | 2 | 1 | none |
| Side pocket | none | | 1 | 1 |
| Entrance, bridge, ledge, peaceful | none | | none | none |

**The boss.** Both boss rooms have one opening and an `antagonist_spawns`
entry: across the ring from the opening in The Maw, and in front of the
throne in the Throne of Ruin. They set `"favored_antagonist": { "tag":
"undead" }`, unlike the other biomes' `beast`. Today the Minotaur is the
only boss, so it still comes. When an undead boss is added, the Void will
pick it.

No room sets `favored_minion`. The 69 rooms have 272 spawn cells between
them: 146 wraiths, 84 echo bats and 42 rolled.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Bridge (3 wide), ledge (1 wide) | `corridor` | `corridor` |
| Combat, side pocket | `normal` | `combat` |
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
- `monsters`: wraith 3, echo bat 2, skeleton archer 1. The wraith packs and
  echo bats are pinned on top of the table.
- `music`: The Lone Forest (emptier than Groovy).

## Current piece set (2026-09-24)

69 rooms: each feature below, plus `<Feature>_Crumbling` where it changes
the room. Sizes are in the file names (grid size = inside + 2).

- **Entrance:** Null Gate (a platform before a ruined gate), Last Landing
  (a round landing with four posts).
- **Bridges, 3 wide:** Bridge (two landings with posts), Bridge Short,
  Bridge Bend, Bridge Fork, Bridge Cross, Ruined Span (the middle crumbled
  to a single span).
- **Ledges, 1 wide:** Ledge, Ledge Short, Ledge Bend, Ledge Fork, Ledge
  Cross. No Crumbling.
- **Combat:**
  - Hollow Plaza (a pillared plaza with a crack across it), Twin Barrows
    (two round islands joined by a bridge), Dead Colonnade (two rows of
    pillars, bites out of the edges).
  - Sunken Hall (a walled hall whose middle fell in), Grave Ring (a ring of
    standing stones round a hole), Fallen Tower (a broken round tower).
  - Drifting Tombs (three islands in a row), Stair to Nothing (stepped
    slabs down into the dark).
- **Kill zone:** Null Crossroads (a big island with a pillar ring, four
  bridges in, four outlying islands on 1-wide spans).
- **Peaceful:** Torpor Shrine (a small walled shrine), Still Terrace.
- **Mazes:** Span Maze (1-wide spans between small platforms), Rotted Floor
  (a floor rotted through with holes), Headstone Field (rows of headstones).
- **Side pockets, 1 wide:** Outcrop, Broken Balcony, Lone Pillar, Ledge
  Nook.
- **Barracks:** Wraith Hall (a long pillared hall), Echo Roost (a round
  walled roost).
- **Treasure:** Sealed Vault (a walled vault at the end of a 1-wide span),
  Reliquary (a round island with a chest between two pillars).
- **Boss:** The Maw (a ring platform round a huge hole), Throne of Ruin (a
  throne against a broken wall, holes torn in the floor). The generator
  picks one of the four each run.

## Adding a new room, step by step

1. **Pick the feature and sketch it** as a text grid: space for abyss, `.`
   stone, `,` rubble, `#` ruined wall, `O` pillar, `D` openings. Pick an
   odd inside size, then add 2 for the grid.
2. **Leave the ring as abyss,** apart from the openings, and run a bridge
   of the opening's width from each opening to the platform.
3. **Check the openings.** Are they all one width? Are they centred? Give
   each opening cell the floor tile just inside it.
4. **Set the connectors:** `"door": "none"`, `"free": true`.
5. **Add the spawns** using the table above. For a boss room, add
   `antagonist_spawns` and `"favored_antagonist": { "tag": "undead" }`.
6. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
7. **Load a void dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
8. **Add it to the piece list above.**
