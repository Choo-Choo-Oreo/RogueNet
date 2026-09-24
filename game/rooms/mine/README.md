# Mine biome: how to make rooms

A working mine. Structure and order: straight shafts that turn at right
angles, a cart track down the middle, and rooms that are mazes with a
purpose. The maze comes from what the room is *for*, like ore galleries,
sidings and supports, not from decoration.

This file covers the mine's own rules. For the full room file format (every
key, connectors, `free`, per-connector `door`, `favored_enemy`), see
[../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Rock | `wall_rough_cave` | Outer walls, rubble, ore piles, maze walls. |
| Timber | `wall_wood_plank` | Door frames, supports along shafts, posts, dividers, cabins and stores. |
| Dirt | `floor_dirt` | The normal floor. |
| Planks | `floor_wood_planks` | The cart track, and cabin or storeroom floors. |

- **Timber frames every doorway.** The wall tile on each side of a door is
  timber, not rock.
- **Long shafts get supports:** a pair of timber tiles in the side walls every
  3 tiles.
- **Lone posts are timber.** In mazes, a wall post standing on its own, open on
  all four sides, is a timber prop.
- **The track** runs down the centre of shafts and working rooms, and follows
  the route between the two main doors in wide-door mazes. Planks stand in for
  a real rail tile. If one is added later, only the track cells should switch
  to it, not the cabin floors.

## Mine rules

1. **Every size is odd.** That keeps the track and every door exactly
   centred, in any rotation. The one exception is two doors on the same
   wall (U-turn, Wye, Crossover): they sit as a mirrored pair instead.
2. **Two door sizes.**
   - **Wide (3 tiles):** shafts, junctions, the entrance, the boss, working
     rooms, wide-door mazes. The track runs through the middle tile.
   - **Narrow (1 tile):** side rooms, most treasure rooms, crawlways,
     narrow-door mazes.
3. **Shafts are 3 wide inside:** dirt, track, dirt. They run straight and turn
   at right angles.
4. **Maze galleries are 3 wide too,** even in narrow-door mazes. Only the
   doorway is 1 wide. No 1-wide maze paths.
5. **Narrow rooms need something to plug into.** Narrow doors only join narrow
   doors, so keep the "Narrow links" pieces (the Shaft Taps and the Crawl
   pieces) in the set.
6. **Symmetric.** Mirror left-right where you can. Mazes use rotational
   symmetry: they look the same turned 180°.
7. **Nothing unreachable,** and no spawn cells right beside a door.

## Sizes: inside vs. grid

As in the dungeon, the file's `width`/`height` is the **grid**, which is the
inside plus a 1-tile wall ring: **grid = inside + 2**. File names use the grid
size, for example `Mine_Shaft_Short_5x7` is 3×5 inside.

## Doors

The mine's `default_door` is `"none"`, so doorways are open unless a room
asks for a door. Only a few rooms do:

- **`"wood_fold"`** (sliding timber doors) on the 3-wide connectors of the
  **entrances**, the **working rooms** and the **bunkhouses**. They suit a
  mine better than hinged house doors. `wood_fold` only has art for openings
  3 to 5 tiles wide.
- **`"wood"`** on the only 1-wide connectors that want a door: Entrance Cage's
  west and east doors. A folding door can't fill a 1-tile opening, so the game
  would swap in some other door type that fits.
- **`"any"`** on every other connector. It takes whatever the room on the
  other side asks for. A shaft joining a working room gets that room's
  folding door, and a shaft joining a maze stays open.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Shaft, bend, junction, narrow link | `corridor` | `corridor` |
| Working room | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Breather | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Side room / dead end | `normal` | `combat` |
| Bunkhouse | `normal` | `barracks` |
| Treasure | `normal` | `treasure` |
| Boss | `boss` | `combat` |

### `tag_weights` in `defines.json`

A room's chance is its role's weight multiplied by each of its tags' weights.
Anything not listed counts as 1.0.

| key | weight | effect |
|---|---|---|
| `corridor` | 0.7 | Shafts have this as both role and tag, so they end up at 0.7 × 0.7 = **0.49**. That makes about a quarter of random picks a shaft. At 1.2 (1.44) it was closer to 40%, and runs felt like all corridor. |
| `maze` | 0.4 | There are 24 mazes, almost half the set, so each one is kept rarer or they would crowd everything else out. |
| `killzone` | 0.5 | Rare spikes of difficulty. |
| `peaceful` | 0.7 | A breather now and then. |

## Current piece set (2026-09-24)

65 rooms. The sizes below are the grid size.

- **Entrance:** Lift 13×13 (four wide doors), Cage 13×13 (wide north and
  south doors, narrow west and east doors). The generator picks one at
  random each run.
- **Shafts:** Short 5×7, Medium 5×11, Long 5×15, Bend 7×7, Tee 9×9, Cart
  Junction 9×9, Jog 11×15 (S-curve), Bypass 11×13 (splits around a rock
  and rejoins), U-turn 11×9 (both doors on one wall), Wye 11×11 (one door
  forks into two side by side), Crossover 11×13 (two parallel shafts joined
  in the middle), Roundabout 13×13 (a loop round a rock, four doors).
- **Narrow links:** Shaft Tap 5×11 (one narrow side door), Shaft TapTwin 5×11
  (two narrow side doors), Crawlway 3×9, Crawl Bend 5×5, Crawl Fork 5×5.
- **Working rooms:** Ore Gallery 15×11, Timber Hall 13×13, Loading Bay 15×11,
  Switchyard 13×13, Collapsed Tunnel 11×11, Stope 15×15, Pillar Works 15×15.
- **Kill zone:** Killzone Chute 11×17 (12 spawns).
- **Peaceful:** Miners Rest 11×11, Cabin Cavern 17×13.
- **Mazes, wide doors (12):** Workings, Drifts, Switchback, Crosscut, Adit,
  Crossdrift, Winze, Levels, Longwall, Deep Drift, Hub, Great Workings.
- **Mazes, narrow doors (12):** Stalls, Zigzag, Crossing, Old Workings,
  Stopes, Pockets, Galleries, Burrows, Rat Run, Warrens, Tunnels, Honeycomb.
- **Side rooms:** Tool Store 7×7, Powder Store 7×9, Ore Pocket 7×7 (all
  narrow), Dead Drift 5×9 (wide).
- **Barracks:** Bunkhouse 13×15 (bunk pockets off a hall), Bunkhouse Cabins
  15×13 (four small cabins off a track aisle).
- **Treasure:** Stash 7×7, Strongbox 9×11 (both narrow), Ore Cache 11×13 and
  Cart Siding 13×11 (both wide, each guarded by 6 spawns).
- **Boss:** Excavation 17×17, Ore Heart 15×15. The generator picks one at
  random each run.

Every maze has spawns: 2 in the small ones and up to 7 in the biggest. They
sit in the dead ends farthest from the doors.

## Adding a new room, step by step

1. **Sketch it** as a text grid: `#` rock, `W` timber, `.` dirt, `=` track or
   planks, `D` doors. Pick an odd inside size, then add 2 for the grid.
2. **Check the doors.** Is each one centred? Is it 3 wide (main path) or 1 wide
   (side)? Are the frame tiles next to it timber?
3. **Check the track.** Does it line up with the middle tile of each wide door
   it passes through?
4. **Check it connects.** If it only has narrow doors, can a narrow link reach
   it?
5. **Set its doors.** If it's a working room, a bunkhouse or an entrance, use
   `"wood_fold"` on 3-wide doors and `"wood"` on 1-wide doors. Otherwise use
   `"any"`.
6. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or by
   copying a similar room's JSON.
7. **Load a mine dungeon** and watch the Godot output for `Room '<id>': ...`
   warnings.
8. **Add it to the piece list above.**
