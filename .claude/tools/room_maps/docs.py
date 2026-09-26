"""Write game/rooms/<biome>/README.md for the five biomes added 2026-09-26. The piece list is read
from the room files, so rerun this after regenerating the rooms."""
import json, glob, os, collections
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))

THEORY = """## Map design: what these rooms are built to do

The assembler builds a tree of rooms, so the variety has to come from the rooms themselves. Each
room was built to do at least one of these jobs:

- **Tension and release.** Fights come in waves. After a big combat room the player should find a
  corridor or a `peaceful` room (no spawns) to catch their breath. That's why every biome has
  peaceful rooms and short tunnels as well as big fights.
- **Loops inside rooms.** A tree has no loops, so the loops are built into the rooms: pillar
  halls, rings round a core, braided mazes, district blocks with several ways round each one.
  A loop lets a party split up, kite a minion round a pillar or flank a pack.
- **Landmarks.** Every big room has one thing you can steer by: a fountain, an obelisk, a
  rotunda, standing stones, the furnace. In a vast room it's how a player remembers where they
  are.
- **Chokepoints and killzones.** `killzone` rooms are long galleries or bridges with many spawns
  and little cover. The weight keeps them rare, so they spike the difficulty instead of setting it.
- **Cover and flanking lanes.** Big rooms are broken up with pillars, shelves, crates and
  hedges, so ranged minions can't cover the whole floor and melee players have a way in.
- **Dead ends pay out.** A dead end should hold something. Coil mazes end in a chest, treasure
  rooms have one door, and 1-wide pockets hide the small stuff.
- **Varied scale.** Rooms run from 3x11 crawls to 99x99 set pieces. Small, big, small again is
  more interesting than the same size every time.
- **A safe way through.** Every hazard room (water, lava, ice) has a hazard-free path between
  all its openings: grates, fords or bridges. The hazard is a shortcut or a detour, never a wall.
- **Vast rooms are rare.** Rooms tagged `vast` (60+ tiles a side) get weight 0.35, so a dive
  meets about one, sometimes none. The huge boss rooms (90+) and the medium boss rooms split the
  boss slot roughly half and half.

"""

COMMON_RULES = """## Rules

- **Sizes are odd** (grid size), so 3-wide and 1-wide openings centre on a wall.
- **Openings are 3 wide (rooms, tunnels) or 1 wide (crawls, pockets, side rooms).** Every
  connector is `free`, so rooms of different widths can join.
- **No floor on the outer ring, no opening in a corner.** Each opening leads straight into floor,
  never into a hazard.
- **Every walkable cell is connected**, with a hazard-free path between every pair of openings.
- **No spawns in entrance or boss rooms.** A boss room has an antagonist spawn with a clear 7x7
  around it (room for the biggest bosses).
- **Treasure rooms hold at least one chest.** Corridors never dead-end, except the pockets and
  the coil maze, which do so on purpose and hold a reward.
"""

BIOMES = {
 'glacier': dict(
  title='Glacier', brief="""A frozen valley under a glacier. Open snowfields broken by crevasses, ice
caves, frozen lakes and a palace of ice. Wide and bright: fights happen at range, and the ice is
the terrain to watch. Water (under the ice) slows you down; there's always a way round on
snow or gravel.""",
  look=[('`wall_ice`', 'ice walls, seracs, the palace'), ('`wall_rough_cave`', 'rock, moraine'),
        ('`floor_snow`', 'the main floor'), ('`floor_ice`', 'frozen lakes, slick paths'),
        ('`floor_water`', 'meltwater, hot springs (difficult terrain)'), ('`floor_gravel`', 'moraine, fords')],
  doors='No doors: it is outdoors.',
  minions="""Wolf packs on the snow, penguin colonies (a whole flock in one room), yetis alone or in
pairs in their dens, owls and echo bats in the ice caves. The dens (`Penguin_Colony`,
`Wolf_Hollow`, `Yeti_Den`) are one minion each."""),
 'tomb': dict(
  title='Tomb', brief="""A desert necropolis half buried in sand. Sandstone halls, hypostyle
forests of columns, a buried city and a pyramid. The dead guard it; the desert has moved in.
Sand floors, brick and cobble where the builders laid it, water only at the oasis and the canal.""",
  look=[('`wall_sandstone`', 'the main walls, columns'), ('`wall_smooth_stone`', 'sarcophagi, obelisks, the sphinx'),
        ('`wall_brick`', 'mud-brick houses in the city'), ('`floor_sand`', 'the main floor, drifts'),
        ('`floor_brick`', 'processional floors'), ('`floor_cobblestone`', 'plazas'),
        ('`floor_water`', 'oasis, canal (difficult terrain)'), ('`floor_gravel`', 'rubble'), ('`floor_grass`', 'oasis banks')],
  doors='No doors, except iron on treasure rooms and the boss.',
  minions="""Scorpions and snakes in the sand, beetle swarms, skeleton warriors and archers guarding
the halls (archers in lines across the `Hypostyle_Hall`), zombies in the burial rooms,
lizardmen on the plazas, and mimics in the `False_Tomb`. The nests (`Scorpion_Nest`,
`Scarab_Swarm`, `Snake_Pit`) are one minion each."""),
 'library': dict(
  title='Library', brief="""An endless haunted library. Stacks you can get lost in, reading rooms,
a rotunda under a dome, an orrery, and a forbidden section. Bookshelves are the walls, so every
room is full of cover and sight lines are short. Each room has its own carpet colour.""",
  look=[('`wall_bookshelf`', 'the stacks, the main walls'), ('`wall_wood_plank`', 'desks, catalogues'),
        ('`wall_stained_glass`', 'windows, the chapel'), ('`wall_smooth_stone`', 'columns, the orrery'),
        ('`wall_brick`', 'outer walls'), ('`floor_parquet`', 'the main floor'),
        ('`floor_carpet_*`', 'crimson, indigo, gold, verdigris: one per room'), ('`floor_smooth_stone`', 'the atrium')],
  doors='No doors on 3-wide openings; wood on 1-wide ones; iron on treasure and the boss.',
  minions="""Ghosts and moths everywhere, wraiths in the forbidden section, rats in the archive,
witches, imps, the librarian's cat and owls, gargoyles on the galleries, mimics among the
chests. `Boss_Heart_Of_The_Archive` always gets the minotaur: a labyrinth of shelves has to."""),
 'foundry': dict(
  title='Foundry', brief="""A dwarven-scale forge in the deep. Lava channels, casting floors,
conveyors, rail yards, slag heaps and a great crucible. Metal-plate floors, iron walls, and lava
that kills: every lava room has a grated walkway or a crust bridge between its openings.""",
  look=[('`wall_iron`', 'machinery, the main walls'), ('`wall_brick`', 'furnaces, chimneys'),
        ('`wall_mine_ore`', 'ore heaps, the bunkers'), ('`wall_smooth_stone`', 'moulds, anvils'),
        ('`floor_metal_plate`', 'the main floor'), ('`floor_grate`', 'walkways over lava and water'),
        ('`floor_lava`', 'channels and pools (severe)'), ('`floor_lava_crust`', 'cooling crust (severe)'),
        ('`floor_cobblestone`', 'yards'), ('`floor_gravel`', 'slag'), ('`floor_water`', 'quench pools')],
  doors='No doors on 3-wide openings; iron on 1-wide ones, treasure and the boss.',
  minions="""Goblin crews and orcs working the floor, fire spirits (on the lava as well as off
it), imps, gargoyles watching the gallery, slimes in the drains, rats, the odd mimic.
`Goblin_Bunks`, `Orc_Mess` and `Spirit_Forge` are one crew each."""),
 'garden': dict(
  title='Garden', brief="""An overgrown palace garden. Hedge mazes, rose gardens, a parterre the
size of a town, lily ponds, orchards and a greenhouse. The hedges are the walls, so it is a maze
biome at heart; the lawns between them are wide open.""",
  look=[('`wall_forest`', 'hedges'), ('`wall_mossy_stone`', 'garden walls, statues'),
        ('`wall_stained_glass`', 'the greenhouse'), ('`wall_smooth_stone`', 'fountains, plinths'),
        ('`wall_brick`', 'sheds'), ('`floor_grass`', 'the main floor'), ('`floor_flowers`', 'beds'),
        ('`floor_moss`', 'shade'), ('`floor_leaves`', 'the orchard'), ('`floor_cobblestone`', 'paths'),
        ('`floor_mossy_cobblestone`', 'old paths'), ('`floor_water`', 'ponds (difficult terrain)')],
  doors='No doors on 3-wide openings; wood on 1-wide ones and treasure.',
  minions="""Bees round the apiary, mantises in the thicket, toads in the marsh, mandrakes and
mushrooms in the beds, beetles, butterflies, dragonflies over the ponds, snakes, slimes.
`Apiary` and `Toad_Marsh` are one minion each (plus dragonflies over the marsh)."""),
}

def kind(r):
    t = r.get('tags', [])
    if r['role'] != 'normal': return r['role']
    return next((x for x in ['treasure', 'maze', 'killzone', 'peaceful'] if x in t), 'combat')

LABEL = [('entrance', 'Entrances'), ('corridor', 'Tunnels and crawls'), ('combat', 'Combat'),
         ('killzone', 'Kill zones'), ('peaceful', 'Peaceful'), ('maze', 'Mazes'),
         ('treasure', 'Treasure'), ('boss', 'Boss')]

for b, m in BIOMES.items():
    rooms = []
    for f in sorted(glob.glob(f'{REPO}/game/rooms/{b}/*.json')):
        if f.endswith('defines.json'): continue
        rooms.append(json.load(open(f)))
    g = collections.defaultdict(list)
    for r in rooms:
        name = r['id'].split('_', 1)[1]
        size = name.rsplit('_', 1)[1].replace('x', '×'); name = name.rsplit('_', 1)[0].replace('_', ' ')
        for p in ('Boss ', 'Entrance ', 'Treasure '): name = name.replace(p, '') if name.startswith(p) else name
        g[kind(r)].append(f"{name} {size}" + (' (vast)' if 'vast' in r.get('tags', []) else ''))
    d = json.load(open(f'{REPO}/game/rooms/{b}/defines.json'))
    out = [f"# {m['title']}: how to make rooms\n", "Added 2026-09-26.\n", m['brief'] + "\n",
           "The rooms are made by script (see *Regenerating* below), not by hand. Hand-made rooms are",
           "welcome too; follow the rules below.\n",
           "## The look\n", "| Tile | Used for |", "|---|---|"]
    out += [f"| {a} | {u} |" for a, u in m['look']]
    out += ["", COMMON_RULES, "## Doors\n", m['doors'] + "\n", "## Minions\n", m['minions'] + "\n",
            "Most rooms pin a mix that suits them (the `minion` on each spawn cell). Cells without one",
            "are rolled from `monsters` in `defines.json`.\n",
            "## `defines.json`\n", "| key | value |", "|---|---|",
            f"| `room_count` | {d['room_count']['min']}-{d['room_count']['max']} |",
            "| `tag_weights` | " + ', '.join(f"`{k}` {v}" for k, v in d['tag_weights'].items()) + " |",
            "| `monsters` | " + ', '.join(f"{k} {v}" for k, v in d['monsters'].items()) + " |",
            f"| `music` | `{os.path.basename(d.get('music', ''))}` |",
            f"| `ambience` | `{os.path.basename(d.get('ambience', ''))}` (a placeholder until the biome gets its own) |", "",
            f"## Current piece set (2026-09-26)\n", f"{len(rooms)} rooms. The sizes are the grid size.\n"]
    for k, lab in LABEL:
        if g[k]: out.append(f"- **{lab}:** " + ', '.join(g[k]) + '.')
    out += ["", THEORY,
            "## Regenerating\n",
            f"The rooms are written by `.claude/tools/room_maps/{b}.py` (run from that folder:",
            f"`python {b}.py` checks every room, `python {b}.py --write` writes them). Editing the",
            "JSON by hand is fine, but a later `--write` overwrites it.\n"]
    open(f'{REPO}/game/rooms/{b}/README.md', 'w', encoding='utf-8').write('\n'.join(out))
    print(b, len(rooms))
