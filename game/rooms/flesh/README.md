# Flesh biome: how to make rooms

Inside something alive, and something wrong with it. Every room is an organ,
and every organ also comes as a **mutant**: the same organ with an extra lobe,
a doubled part or a strange growth. Two hearts, a four-lobed brain, a womb with
two horns. The place should feel big, knotted and crawling with minions. It's
meant to be a slog.

This file covers flesh's own rules. For the full room file format (every
key, connectors, `free`, per-connector `door`, `favored_minion`), see
[../README.md](../README.md). The dungeon's guide
([../dungeon/README.md](../dungeon/README.md)) explains how the generator
places rooms, and all of that applies here too.

## The look

| Material | Tile | Where it goes |
|---|---|---|
| Flesh | `wall_flesh` | Every wall: outer walls, lumps, folds, septa. |
| Flesh floor | `floor_flesh` | The normal floor. Slows movement. |
| Smooth stone | `floor_smooth_stone` | Fast lanes: the tongue, airways in the lungs, ducts. |
| Acid | `floor_acid` | Stomach acid, bile, urine, cysts. |

- **Nothing is straight or symmetric.** Outlines are lopsided and wobbly.
  Lumps come in uneven sizes. Walls inside a room (septa, fissures, fibres)
  wander, and stone lanes wind. The first draft of this set used mirrored
  shapes, straight crosses and square pools, and it was thrown out for
  looking too clean.
- **Shape comes from the organ.** Lungs are two lobes with fissures. The
  heart has four chambers joined by valve gaps. The cochlea is a spiral. If
  someone could look at the room and name the organ, it's right.
- **Mutants stay recognisable.** Add something, don't replace it: a third
  lung, two domes on the diaphragm, two irises in one eye. The mutant is
  the same organ, only wrong.

## Flesh rules

1. **Every size is odd,** so doors can be centred.
2. **One door width per room.** A room's doors are all 1 wide or all 3 wide.
3. **Doors are centred on their wall, or in mirrored pairs** (like two
   nostrils or two fallopian tubes). A pair can have a centred door between
   them.
4. **Every connector has `"free": true`.** Flesh rooms join whatever they
   touch, whatever the widths. Defines have no biome-wide switch for this,
   so each connector sets it.
5. **Nothing unreachable.** No spawn cells right beside a door.

Every room sets `"base_floor": "floor_flesh"`, so the ground under walls
and doorways is flesh, never stone or acid.

## Doors

`default_door` is `"none"`, so openings stay open unless a room asks.

- **1-wide connectors use `"iron"`.** Veins, the spinal cord and the small
  organs (side pockets, the kidney, the eye) are behind iron doors.
- **3-wide connectors use `"any"`.** They take the other side's door, or
  stay open.

## Minions

Every spawn cell spawns one minion (unless the cell is lit). Flesh is meant
to be packed, so spawn cells are laid by floor area, not by hand:

| Kind | One spawn per | Minimum |
|---|---|---|
| Combat organ | 7 floor tiles | 6 |
| Kill zone | 5 | 12 |
| Barracks | 5 | 8 |
| Leech Pool | 6 | 6 |
| Maze | 8 | 4 |
| Side pocket | 7 | 2 |
| 3-wide tube | 12 | 2 |
| Vein (1-wide) | 9 | 1 |
| Treasure (guarded) | 10 | 2 |
| Boss | 10 | 8 |
| Entrance, peaceful | none | |

The 84 rooms have 871 spawn cells between them. The two peaceful organs and
the entrances are the only rooms with none.

## Roles and tags

| Kind | role | tags |
|---|---|---|
| Entrance | `entrance` | *(none)* |
| Tube (airway, gut), vein, nerve | `corridor` | `corridor` |
| Combat organ, side pocket | `normal` | `combat` |
| Kill zone | `normal` | `killzone` |
| Peaceful | `normal` | `peaceful` |
| Maze | `normal` | `maze` |
| Barracks | `normal` | `barracks` |
| Leech Pool | `normal` | `combat`, `nest`, and `"favored_minion": {"tag": "leech_flesh", "weight": 30}` |
| Treasure | `normal` | `treasure` (guarded: has spawns) |
| Boss | `boss` | `combat` |

### `defines.json`

- `room_count` 45 to 70. Flesh is a large area.
- `tag_weights`:
  - `corridor` 0.7 (0.49 per piece)
  - `maze` 0.6
  - `killzone` 0.5
  - `peaceful` 0.7

  That puts corridors at about a quarter of random picks.

## Current piece set (2026-09-24)

84 rooms: each organ below, plus `<Organ>_Mutant`. Sizes are in the file
names (grid size = inside + 2).

- **Entrance:** Mouth (teeth, stone tongue), Nasal Cavity (septum, two
  nostrils).
  - Mutants: a wider maw with double teeth rows and a forked tongue, and
    three nostrils.
- **Tubes, 3 wide:** Pharynx (splits in two; mutant splits in three),
  Esophagus (mutant splits and rejoins), Trachea, Larynx (vocal folds pinch
  it to a 1-tile slit; mutant has two), Tonsils, Colon (U; mutant is a W),
  Aorta.
- **Vessels and nerves, 1 wide:** Vein, Vein Short, Vein Bend, Vein Fork, Artery, Capillaries,
  Spinal Cord.
- **Combat:** Lungs (mutant has three), Stomach (mutant has four chambers,
  like a cow), Pancreas, Spleen (mutant has satellite spleens), Skin, Muscle,
  Diaphragm (mutant has two domes).
- **Kill zone:** Liver (mutant has five lobes).
- **Peaceful:** Thyroid (butterfly; mutant has four wings), Thymus.
- **Mazes:**
  - Small Intestine (coiled tubes)
  - Kidney (mutant is a horseshoe kidney)
  - Cochlea (double spiral; mutant adds the three looping canals)
  - Bone Marrow
- **Side pockets:** Appendix, Adrenal Gland, Ovary, Testis, Prostate.
- **Barracks:** Womb (mutant has two horns), Lymph Node (mutant is three
  nodes on a chain).
- **Leech Pool:** Bladder (mutant has a second sac).
- **Treasure:** Gallbladder, Eye (chest in the pupil).
  - Eye Mutant: still one round eye, but with two irises side by side. The
    chest is in the left pupil and a guard waits in the right one.
- **Boss:** Heart (four chambers; mutant has six, two hearts grown
  together), Brain (mutant has four lobes and two cerebellums). The
  generator picks one of the four each run.

Organs without their own room: tongue and teeth (part of the Mouth), the
salivary glands, parathyroid, pituitary and pineal glands, and the
ureters/urethra.

## Adding a new room, step by step

1. **Pick the organ and sketch it** as a text grid: `#` flesh wall, `.` flesh
   floor, `=` stone lane, `~` acid, `D` doors. Pick an odd inside size, then
   add 2 for the grid.
2. **Make it lopsided.** If you can fold it in half and it matches, rough it
   up.
3. **Check the doors.** Are they all one width? Are they centred, or a
   mirrored pair?
4. **Set the connectors.** Give each one `"free": true`, and `"door": "iron"`
   if it's 1 wide or `"door": "any"` if it's 3 wide.
5. **Add spawns** using the density table above.
6. **Build it** in the room editor (`scenes/dungeon/DungeonMaker.tscn`) or by
   copying a similar room's JSON.
7. **Load a flesh dungeon** and watch the Godot output for
   `Room '<id>': ...` warnings.
8. **Add it to the piece list above.**
