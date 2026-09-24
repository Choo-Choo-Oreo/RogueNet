# Catacomb: how to make rooms

Burial galleries and crypts, the undead's own biome. Every room is a
**feature**, a place you could name: an ossuary, a columbarium, a charnel
pit, a family tomb. Every feature also comes **Desecrated**: the same room
after graverobbers got in, with sarcophagi smashed, niches broken open and
the tomb carpet torn up. Minions come as **garrisons**: skeleton archers
standing in lines, with wraiths and the rest spread through the niches.

This file covers the catacomb's own rules. For the full room file format
(every key, connectors, `free`, per-connector `door`, `favored_minion`,
per-cell `minion`), see [../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Brick | `wall_cobble_brick` | Outer walls, the thick inner walls the niches are cut into, mausolea, the Columbarium's urn pillar. |
| Stone | `wall_smooth_stone` | Sarcophagi, bone stacks, altars, slabs, pillars, the pit rail. |
| Rubble | `wall_rough_cave` | Only in Desecrated rooms: smashed sarcophagi and bone stacks, cracked brick around broken niches. |
| Stone floor | `floor_smooth_stone` | Halls, chapels, tombs. |
| Dirt | `floor_dirt` | Galleries and processionals, burial halls, pits, the cloister yard, dirt spilled by graverobbers. |
| Violet carpet | `floor_carpet_violet` | Only in tombs, the treasure rooms, the Royal Crypt runner and the Crypt Labyrinth's heart. |

- **Built, not natural.** Rooms are straight and mostly symmetric, like the
  dungeon and the sewer. Desecrated is what breaks them up.
- **Niches.** Most rooms have a wall 2 tiles thick. Burial niches are cut
  1 deep into the inner layer, every other tile, never beside an opening.
  A niche is a dead-end floor tile, the same tile as the floor in front of
  it.
- **Openings carry the floor just inside them,** like the sewer's, so a
  dirt gallery stays dirt through its opening.
- **Desecrated keeps the room's size and openings.** It only turns walls
  into other walls and floor into other floor, so nothing gets cut off.

## Catacomb rules

1. **Every size is odd,** so openings can be centred.
2. **One opening width per room:** 3 (processionals and rooms) or 1
   (galleries, side pockets, mazes).
3. **Openings are centred on their wall.**
4. **Doors: iron on the tombs, the treasure rooms and both boss crypts**
   (`"door": "iron"`). Every other connector is `"door": "any"`, and
   `default_door` is `"none"`, so ordinary joins stay open.
5. **Every connector is `"free": true`,** so 3- and 1-wide pieces can join
   each other.
6. **Nothing unreachable.** Every floor tile connects to the openings.

Every room sets `"base_floor": "floor_smooth_stone"`.

## Minions: garrisons

Every spawn cell spawns one minion, unless the cell is lit (torches in the
chapels, the stairs, the lodge and the Bone Chapel keep spawns away). A room
has two kinds of cell:

- **Archer lines.** Cells 2 apart in a straight row, as far from the
  openings as they fit: the end of a gallery, the back of a hall. Each has
  `"minion": "skeleton_archer"`, so an archer always stands there.
- **Niche cells.** Spread thin (4+ tiles apart), in niches first. They have
  no `minion`, so they roll from the biome's `monsters` table, nudged by the
  room's `favored_minion`.

| Kind | Archer lines | Line length | Niche cells |
|---|---|---|---|
| Feature (combat) | 1 | 3 | 3 |
| Kill zone | 3 | 3 | 4 |
| Barracks | 2 | 4 | 3 |
| Boss | 2 | 3 | 4 |
| Tomb | none | | 4 |
| Maze | 1 | 2 | 2 |
| Treasure (guarded) | 1 | 2 | 1 |
| Side pocket | none | | 2 |
| Entrance, processional, gallery, peaceful | none | | none |

Desecrated rooms get 2 extra niche cells.

**Favoured minions:**

- Tombs favour `undead.ghostly` (wraiths), weight 3.
- Barracks, the Ossuary and the Great Ossuary favour `undead.skeleton`,
  weight 3.

The 80 rooms have 312 spawn cells between them: 132 fixed archers and 180
rolled from the table.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Processional (3 wide), gallery (1 wide) | `corridor` | `corridor` |
| Feature, side pocket, tomb | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Peaceful | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Barracks | `normal` | `barracks` |
| Treasure | `normal` | `treasure` (guarded: has spawns) |
| Boss | `boss` | `combat` |

### `defines.json`

- `room_count` 30 to 45.
- `default_door` `"none"`.
- `tag_weights` are the same as cave, flesh, forest and sewer:
  - `corridor` 0.7
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7
- `monsters`: wraith 3, skeleton archer 2, rat 1 (a rare scavenger). The
  archer lines add more archers on top of the table.
- `music`: Groovy.

## Current piece set (2026-09-24)

80 rooms: each feature below, plus `<Feature>_Desecrated`. Sizes are in the
file names (grid size = inside + 2).

- **Entrance:** Crypt Stairs (a stairwell down from the north), Mausoleum
  Gate (pillared hall with torches).
- **Processionals, 3 wide:** Processional, Processional Short, Processional
  Bend, Processional Junction, Processional Crossing. Niches both sides.
- **Galleries, 1 wide:** Gallery, Gallery Short, Gallery Bend, Gallery
  Fork, Gallery Cross. Niches both sides.
- **Features (combat):**
  - Ossuary (walls of stacked bones, an aisle down the middle).
  - Burial Hall (rows of sarcophagi on dirt).
  - Columbarium (a central urn pillar, niched on every face).
  - Bone Chapel (pillars, an altar with candles).
  - Embalming Room (stone slabs), Charnel Pit (a dirt pit behind a stone rail).
  - Cloister (an arcade around a dirt yard), Hypogeum (a cross-shaped chamber).
- **Kill zone:** Necropolis Crossroads (four niched mausolea around a
  crossing).
- **Peaceful:** Mourners Chapel, Caretakers Lodge. Both lit.
- **Mazes, 1 wide:** Catacomb Warren (dirt), Bone Stacks (walls of bones),
  Crypt Labyrinth (a small carpeted tomb at its heart).
- **Side pockets, 1 wide:** Loculus, Arcosolium, Cubiculum, Ossuary Nook,
  Grave Niche.
- **Tombs, iron:** Family Tomb (rows of sarcophagi on carpet), Noble Tomb
  (one big sarcophagus on a runner), Priests Tomb (altar and sarcophagus).
- **Barracks:** Bone Garrison (long niched walls), Guard Crypt (pillar
  rows).
- **Treasure, iron:** Grave Goods Vault, Reliquary. Chest on carpet.
- **Boss, iron:** Royal Crypt (a carpet runner up to a royal sarcophagus on
  a dais), Great Ossuary (bone pillars around a pit). The generator picks
  one of the four each run.

## Adding a new room, step by step

1. **Pick the feature and sketch it** as a text grid: `#` brick, `O` stone,
   `.` stone floor, `,` dirt, `v` violet carpet (tombs only), `D` openings.
   Pick an odd inside size, then add 2 for the grid.
2. **Keep it built.** Straight walls, and symmetric where it makes sense.
3. **Cut niches** every other tile into any wall 2 thick, not beside an
   opening.
4. **Check the openings.** Are they all one width? Are they centred? Give
   each opening cell the floor tile just inside it.
5. **Set the connectors.** Use `"door": "iron"` for a tomb, treasure or
   boss room, otherwise `"any"`. Always add `"free": true`.
6. **Add the garrison** using the table above. Give archer-line cells
   `"minion": "skeleton_archer"`.
7. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or
   by copying a similar room's JSON.
8. **Load a catacomb dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
9. **Add it to the piece list above.**
