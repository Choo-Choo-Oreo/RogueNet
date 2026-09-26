# room_maps: room generators

Python scripts that write room JSON (format 2) into `game/rooms/<biome>/`. They made the
`glacier`, `tomb`, `library`, `foundry` and `garden` biomes and the 2026-09-26 additions to
`dungeon`, `mine`, `cave` and `sewer`. Needs Python 3 and Pillow (for the previews).

Run everything from this folder.

| Command | What it does |
|---|---|
| `python glacier.py` | Builds every glacier room and checks it. Writes nothing. |
| `python glacier.py --write` | Same, then writes the rooms. Overwrites hand edits to those files. |
| `python additions.py [--write]` | The rooms added to the older biomes. |
| `python dive.py --gallery glacier [scale]` | Every room in a biome on one sheet: `gal_glacier.png`. |
| `python dive.py glacier 1 2 3` | Builds whole dives with those seeds and renders them, with a key map. Python RNG, so not seed-identical to the game. |
| `python stats.py glacier tomb` | 200 dives per biome: failures, boss picks, share of each kind, average size, `vast` rooms per run. |
| `python docs.py` | Rewrites the five new biomes' `README.md` from the room files. |

Every script is seeded, so running `--write` again gives the same rooms.

## The files

- **`rb.py`**: `Biome`, `Room` and `Canvas`. A room is drawn as rows of characters, and a
  legend turns each character into a floor, wall, spawn, object or boss spawn. `D` on the
  outer ring is an opening; each run of `D`s becomes a connector. `Room.problems()` is the
  checker; the rules it enforces are in each biome's README (*Rules*).
- **`kit.py`**: room shapes: box, hall, rounded, cavern, ring room, maze room, spiral,
  districts (split into blocks with loops between them), and the corridor pieces.
- **`common.py`**: shared dressing: roughening, blobs, a safe path through hazards, pillar
  grids, rivers, niches, and `connective()`, the tunnels, crawls, mazes and pockets every new
  biome shares.
- **`<biome>.py`**: one biome each: its legend, door rule and rooms.
- **`dive.py`, `stats.py`**: a Python port of the assembler, for previews and numbers only. The
  game's own assembler is `scripts/dungeon/DungeonAssembler.gd`.
