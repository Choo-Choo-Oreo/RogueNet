"""Garden: royal gardens run wild. Mossy stone garden walls, hedges and trees, flower beds,
leaf litter, cobbled paths, ponds and fountains, a greenhouse of stained glass."""
import math, sys
import kit, common
from kit import open_sides, packs, singles
from common import blobs, keep_doors_clear, safe_path, pillar_grid, objects_far, blocks, niches, along_walls, roughen
from rb import Biome, Canvas, report

GRASS = 'floor_grass'
L = {
    '#': dict(w='wall_mossy_stone'), '%': dict(w='wall_forest'), '&': dict(w='wall_stained_glass'),
    '!': dict(w='wall_smooth_stone'), '|': dict(w='wall_brick'),
    '.': dict(f=GRASS), ',': dict(f='floor_flowers'), ';': dict(f='floor_moss'), ':': dict(f='floor_leaves'),
    '=': dict(f='floor_cobblestone'), '_': dict(f='floor_mossy_cobblestone'), '~': dict(f='floor_water'),
    's': dict(f=GRASS, spawn=True), 'b': dict(f='floor_flowers', spawn='bee'), 'u': dict(f='floor_flowers', spawn='butterfly'),
    'm': dict(f=GRASS, spawn='mandrake'), 'M': dict(f='floor_moss', spawn='mushroom'), 't': dict(f=GRASS, spawn='mantis'),
    'd': dict(f=GRASS, spawn='toad'), 'n': dict(f='floor_leaves', spawn='snake'), 'f': dict(f='floor_water', spawn='dragonfly'),
    'e': dict(f=GRASS, spawn='beetle'), 'S': dict(f='floor_moss', spawn='slime'),
    'B': dict(f='floor_mossy_cobblestone', boss=True), 'C': dict(f='floor_mossy_cobblestone', obj='chest'),
}
def door(w, r):
    if 'treasure' in r.tags: return 'wood'
    return 'wood' if w == 1 else 'none'
B = Biome('garden', L, door=door, base_floor=GRASS)

def fix(c): keep_doors_clear(c, '.', 1, '~'); c.connect_regions(set(kit.FLOORS), '.', '#%&!|', 2)
def beds(c, box, ch=',', bw=4, bh=2, gx=2, gy=2, hedge=False):
    for (x, y) in blocks(c, ch, bw, bh, gx, gy, box=box, on='.', min_d=2):
        if hedge:
            c.frame(x - 1, y - 1, x + bw, y + bh, '%'); c[x + bw // 2, y + bh] = '.'
def overgrow(c, n=4, ch=':'): blobs(c, ch, n, (1.5, 3), on='.=_', min_d=0)

def dress(c, kind):
    if kind == 'tunnel': overgrow(c, 2)
    elif kind in ('maze', 'maze_narrow'):
        c.replace('#', '%', 1.0, pred=lambda x, y: 0 < x < c.w - 1 and 0 < y < c.h - 1)   # hedges inside
        overgrow(c, 3); fix(c)
        packs(c, [('t', 2, 1)], min_d=6); singles(c, 'n', 2, on=':', min_d=5, spacing=5); singles(c, 's', 2, min_d=6, spacing=5)
    elif kind == 'coil':
        c.replace('#', '%', 1.0, pred=lambda x, y: 0 < x < c.w - 1 and 0 < y < c.h - 1); c[c.w // 2, c.h // 2] = 'C'
    elif kind == 'pocket':
        blobs(c, ';', 1, (1, 2), min_d=1); singles(c, 'M', 1, on=';', min_d=1); singles(c, 'd', 1, min_d=2)
    fix(c)

common.connective(B, {'dress': dress, 'names': {
    'tunnel': 'Path', 'crawl': 'Hedge_Gap', 'maze': 'Hedge_Maze',
    'pocket': ['Potting_Shed', 'Compost_Corner', 'Bird_Bath']}}, natural=True, seed=5000)

# ================================================================ entrances
c = kit.hall(23, 23, seed=1); c.rect(10, 1, 12, 21, '='); c.rect(1, 10, 21, 12, '=')
c.rect(9, 9, 13, 13, '='); c.ellipse(11, 11, 1, 1, '~'); c[11, 11] = '!'
beds(c, (3, 3, 8, 8)); beds(c, (14, 3, 19, 8)); beds(c, (3, 14, 8, 19)); beds(c, (14, 14, 19, 19)); fix(c)
B.add('Entrance_Garden_Gate', c.rows(), 'entrance', ['peaceful'])
c = kit.hall(25, 19, seed=2); c.rect(1, 1, 23, 5, '_'); c.rect(4, 6, 20, 6, '#'); c.rect(11, 6, 13, 6, '_')
for x in (4, 8, 16, 20): c[x, 10] = '%'
fix(c); B.add('Entrance_Terrace', c.rows(), 'entrance', ['peaceful'])

# ================================================================ features
# Rose Garden: hedged flower beds in a grid, bees on the blooms, mantises in the hedges
c = kit.hall(31, 29, seed=3); c.rect(1, 13, 29, 15, '='); c.rect(14, 1, 16, 27, '=')
beds(c, (3, 3, 12, 11), ',', 3, 2, 3, 3, hedge=True); beds(c, (18, 3, 27, 11), ',', 3, 2, 3, 3, hedge=True)
beds(c, (3, 18, 12, 26), ',', 3, 2, 3, 3, hedge=True); beds(c, (18, 18, 27, 26), ',', 3, 2, 3, 3, hedge=True); fix(c)
packs(c, [('b', 3, 1), ('b', 3, 1)], on=',', min_d=4, spacing=8); packs(c, [('t', 2, 1)], min_d=6)
B.add('Rose_Garden', c.rows(), 'normal', ['combat'])

# Lily Pond: a big pond, stepping stones across, dragonflies over the water, toads on the bank
c = kit.cavern(33, 27, seed=4, fill=0.36); c.ellipse(16, 13, 11, 8, '~', only=set('.'), jitter=0.15)
blobs(c, ';', 3, (1, 1.8), on='~', min_d=4); fix(c); safe_path(c, '_', '~', 1)
packs(c, [('f', 3, 2), ('f', 3, 2)], on='~', min_d=5, spacing=10); packs(c, [('d', 3, 1), ('d', 2, 1)], on='.', min_d=4, spacing=10)
B.add('Lily_Pond', c.rows(), 'normal', ['combat'])

# Topiary Walk: an avenue of clipped trees, statues between, mantises waiting in the shade
c = kit.hall(19, 41, seed=5, sides='ns'); c.rect(8, 1, 10, 39, '=')
for y in range(4, 38, 4): c[4, y] = '%'; c[14, y] = '%'
for y in range(6, 36, 8): c[4, y] = '!'; c[14, y] = '!'
overgrow(c, 3); fix(c); packs(c, [('t', 2, 1), ('t', 2, 1)], on='.:', min_d=7, spacing=12); singles(c, 's', 3, on='.', min_d=6)
B.add('Topiary_Walk', c.rows(), 'normal', ['combat'])

# Greenhouse: stained-glass walls, moss floor, raised beds in rows, mandrakes in the soil
c = kit.hall(29, 21, seed=6); c.frame(0, 0, 28, 20, '&'); open_sides(c, 'nsew'); c.replace('.', ';')
for y in (4, 8, 12, 16): c.rect(3, y, 25, y, '|', only=set(';')); c.rect(3, y - 1, 25, y - 1, ',', only=set(';'))
for x in (13, 14, 15): c.rect(x, 1, x, 19, ';', only=set('|,'))
fix(c); packs(c, [('m', 3, 1), ('m', 3, 1), ('M', 2, 1)], on=';,', min_d=4, spacing=8)
B.add('Greenhouse', c.rows(), 'normal', ['combat'])

# Fountain Court: paths radiating from a great fountain, a ring walk, flower beds between
c = kit.rounded(31, 31, seed=7, jitter=0.03); c.ring(15, 15, 9, 11, '=', only=set('.'))
for a in range(8): c.line(15, 15, round(15 + 14 * math.cos(a * math.pi / 4)), round(15 + 14 * math.sin(a * math.pi / 4)), '=', 1, only=set('.'))
c.ellipse(15, 15, 4, 4, '~'); c.ellipse(15, 15, 1.5, 1.5, '!'); blobs(c, ',', 6, (1.5, 2.5), on='.', min_d=4)
fix(c); packs(c, [('b', 3, 1), ('u', 2, 2), ('e', 3, 1)], on='.,', min_d=5, spacing=9)
B.add('Fountain_Court', c.rows(), 'normal', ['combat'])

# Orchard: rows of fruit trees, fallen leaves, beetles in the windfalls
c = kit.hall(33, 27, seed=8); pillar_grid(c, '%', 4, 1, offset=3, min_d=3); overgrow(c, 7); fix(c)
packs(c, [('e', 3, 1), ('e', 3, 1), ('n', 2, 2)], on='.:', min_d=5, spacing=9); singles(c, 's', 2, min_d=5)
B.add('Orchard', c.rows(), 'normal', ['combat'])

# Mushroom Grotto: a mossy hollow under the garden, mushrooms and slimes
c = kit.cavern(27, 23, seed=9, fill=0.44); c.replace('.', ';'); c.replace('#', '%', 0.15, pred=lambda x, y: 1 < x < 25 and 1 < y < 21)
fix(c); packs(c, [('M', 3, 1), ('M', 3, 1), ('S', 2, 1)], on=';', min_d=4, spacing=8)
B.add('Mushroom_Grotto', c.rows(), 'normal', ['combat'])

# Sunken Garden: terraces stepping down in rings to a pool, stairs on each side
c = kit.hall(29, 29, seed=10)
for r, ch in ((11, '#'), (7, '#')):
    c.frame(14 - r, 14 - r, 14 + r, 14 + r, ch)
    for k, (x, y) in enumerate([(14, 14 - r), (14, 14 + r), (14 - r, 14), (14 + r, 14)]):
        if (k + r) % 2 or r == 7: c.rect(x - 1, y - 1 if x == 14 else y, x + 1, y + 1 if x == 14 else y, '_') if x == 14 else c.rect(x, y - 1, x, y + 1, '_')
c.ellipse(14, 14, 3, 3, '~'); blobs(c, ',', 4, (1, 2), on='.', min_d=3); fix(c)
packs(c, [('d', 3, 1), ('u', 3, 2), ('f', 2, 1)], on='.,', min_d=5, spacing=8)
B.add('Sunken_Garden', c.rows(), 'normal', ['combat'])

# Wild Meadow: the lawn gone to seed, tall flowers everywhere, bees and butterflies
c = kit.cavern(31, 25, seed=11, fill=0.34); blobs(c, ',', 6, (2.5, 4), on='.', min_d=0); blobs(c, '%', 4, (0.8, 1.5), on='.,', min_d=4)
fix(c); packs(c, [('b', 4, 1), ('u', 3, 2), ('b', 3, 1)], on=',', min_d=4, spacing=8)
B.add('Wild_Meadow', c.rows(), 'normal', ['combat'])

# Mantis Thicket (kill zone): hedge thicket with narrow runs; they strike from the green
c = kit.hall(31, 25, seed=12); c.rect(2, 2, 28, 22, '%'); c.maze(2, 2, 28, 22, '.', '%', 3, 0.35, 2)
c.rect(1, 1, 29, 1, '.'); c.rect(1, 23, 29, 23, '.'); fix(c)
packs(c, [('t', 2, 1), ('t', 2, 1), ('t', 2, 1), ('n', 2, 1)], on='.', min_d=5, spacing=7)
B.add('Mantis_Thicket', c.rows(), 'normal', ['killzone'])

# Bramble Walk (kill zone): a long cobbled path hemmed in by bramble; snakes in the leaves
c = kit.hall(13, 45, seed=13, sides='ns'); c.rect(1, 1, 3, 43, '%'); c.rect(9, 1, 11, 43, '%'); c.rect(5, 1, 7, 43, '=')
for y in range(4, 36, 7): c.rect(1, y, 3, y + 2, ':'); c.rect(9, y + 3, 11, y + 5, ':')
fix(c); packs(c, [('n', 2, 1), ('n', 2, 1), ('n', 2, 1), ('t', 2, 1)], on=':', min_d=4, spacing=6)
B.add('Bramble_Walk', c.rows(), 'normal', ['killzone'])

# ================================================================ peaceful
c = kit.rounded(17, 17, seed=14, jitter=0.02); c.ellipse(8, 8, 3, 3, '_'); c.ring(8, 8, 3.2, 4.2, '|', only=set('.'))
for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)): c[8 + dx * 4, 8 + dy * 4] = '_'
fix(c); B.add('Gazebo', c.rows(), 'normal', ['peaceful'])
c = kit.hall(19, 15, seed=15, sides='we'); c.rect(7, 5, 11, 9, ','); c.rect(8, 6, 10, 8, '!'); fix(c)
B.add('Tea_Lawn', c.rows(), 'normal', ['peaceful'])
c = kit.hall(15, 19, seed=16, sides='ns'); c.rect(6, 1, 8, 17, '_'); beds(c, (2, 3, 4, 15), ',', 2, 2, 1, 1); beds(c, (10, 3, 12, 15), ',', 2, 2, 1, 1); fix(c)
B.add('Herb_Garden', c.rows(), 'normal', ['peaceful'])

# ================================================================ barracks
c = kit.hall(25, 21, seed=17, sides='nsw'); blocks(c, '|', 1, 1, 3, 3, box=(4, 4, 20, 16), on='.', min_d=3)
blobs(c, ',', 5, (1.5, 2.5), on='.', min_d=2); fix(c); packs(c, [('b', 4, 1), ('b', 4, 1), ('b', 4, 1)], on='.,', min_d=4, spacing=6)
B.add('Apiary', c.rows(), 'normal', ['barracks'])
c = kit.cavern(25, 21, seed=18, fill=0.4); c.ellipse(12, 10, 6, 4, '~', only=set('.')); fix(c); safe_path(c, '_', '~')
packs(c, [('d', 4, 1), ('d', 4, 1), ('f', 3, 1)], on='.~', min_d=4, spacing=7)
B.add('Toad_Marsh', c.rows(), 'normal', ['barracks'])

# ================================================================ treasure
c = kit.rounded(13, 13, seed=19, sides='s', width=1); c.ring(6, 5, 2.5, 3.5, '%', only=set('.')); c.rect(6, 8, 6, 11, '.'); c[6, 5] = 'C'; fix(c)
B.add('Treasure_Hidden_Arbor', c.rows(), 'normal', ['treasure'])
c = kit.hall(17, 15, seed=20, sides='w')
for p in [(5, 4), (5, 10), (10, 4), (10, 10)]: c[p] = '!'
c[13, 7] = 'C'; c.rect(12, 6, 14, 8, '_'); c[13, 7] = 'C'; fix(c); packs(c, [('t', 2, 1)], min_d=4)
B.add('Treasure_Statue_Garden', c.rows(), 'normal', ['treasure'])

c = kit.rounded(13, 15, seed=25, sides='n', width=1); c.ellipse(6, 8, 2, 2, '|'); c.ellipse(6, 8, 1, 1, '~'); c[6, 12] = 'C'
blobs(c, ',', 2, (1, 1.5), on='.', min_d=2); fix(c)
B.add('Treasure_Wishing_Well', c.rows(), 'normal', ['treasure'])

# ================================================================ huge set pieces
# Great Hedge Maze 75x75: a real hedge maze, wide enough to fight in, braided so there are
# many ways through, with a fountain garden at the heart and gazebos at the dead ends.
c = Canvas(75, 75, '#', 21); c.maze(1, 1, 73, 73, '.', '%', 6, 0.18, 3)
c.replace('#', '%', pred=lambda x, y: 0 < x < 74 and 0 < y < 74)
c.rect(29, 29, 45, 45, '.'); c.ellipse(37, 37, 5, 5, '='); c.ellipse(37, 37, 2.5, 2.5, '~'); c[37, 37] = '!'
open_sides(c, 'nsew'); overgrow(c, 10); fix(c)
packs(c, [('t', 2, 1), ('t', 2, 1), ('n', 2, 1), ('b', 3, 1), ('e', 3, 1), ('m', 3, 1)], on='.:', min_d=12, spacing=14)
singles(c, 's', 8, on='.', min_d=10, spacing=10)
B.add('Great_Hedge_Maze', c.rows(), 'normal', ['maze', 'vast'])

# Palace Parterre 81x81: the formal garden, now half wild. Symmetric beds and canals, a long
# canal down the middle with bridges, groves in the corners that the forest has taken back.
c = kit.hall(81, 81, seed=22); c.rect(37, 1, 43, 79, '~'); c.rect(1, 38, 79, 42, '=')
for y in (12, 28, 52, 68): c.rect(37, y, 43, y + 2, '_')
for qx, qy in [(4, 4), (46, 4), (4, 46), (46, 46)]:
    beds(c, (qx + 2, qy + 2, qx + 28, qy + 28), ',', 5, 2, 3, 3, hedge=True)
for qx, qy in [(4, 4), (60, 60)]:
    c.cave('.', '%', 0.42, 4, region=(qx, qy, qx + 16, qy + 16))
c.mirror_x() if False else None
overgrow(c, 12); open_sides(c, 'nsew'); fix(c); safe_path(c, '_', '~', 3)
packs(c, [('b', 3, 1), ('b', 3, 1), ('u', 3, 2), ('t', 2, 1), ('t', 2, 1), ('e', 3, 1), ('d', 3, 1)], on='.,:', min_d=10, spacing=14)
packs(c, [('f', 3, 2), ('f', 3, 2)], on='~', min_d=10, spacing=20); singles(c, 's', 6, on='.', min_d=10, spacing=10)
B.add('Palace_Parterre', c.rows(), 'normal', ['combat', 'vast'])

# ================================================================ bosses
# Queen's Bower 45x45: a ring of great trees round a mossy lawn, webs of hedge between them.
c = kit.rounded(45, 45, seed=23, sides='s', jitter=0.05)
for i in range(10):
    a = i * math.pi / 5; x, y = round(22 + 17 * math.cos(a)), round(22 + 17 * math.sin(a)); c.ellipse(x, y, 1.6, 1.6, '%')
c.ellipse(22, 22, 12, 12, ';'); blobs(c, ':', 5, (2, 3), on='.', min_d=3); fix(c); common.boss_mark(c, 'B', '_')
B.add('Boss_Queens_Bower', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'beast', 'weight': 3})

# The Wild Heart 91x91: the garden's heart, gone feral. Forest has eaten the old walls; the
# ruined formal garden shows through; a lake wraps round the island where it waits.
c = Canvas(91, 91, '#', 24); c.cave('.', '%', 0.44, 6)
for (x, y) in c.cells():
    if math.hypot(x - 45, y - 45) > 43 + c.rnd.uniform(-1.5, 1): c[x, y] = '#'
for _ in range(10):
    x, y = c.rnd.randint(8, 74), c.rnd.randint(8, 74)
    if math.hypot(x - 45, y - 45) < 20: continue
    c.frame(x, y, x + 8, y + 8, '#'); c.rect(x + 1, y + 1, x + 7, y + 7, ','); c[x + 4, y] = '_'; c[x + 4, y + 8] = '_'; c[x, y + 4] = '_'
c.ring(45, 45, 13, 19, '~'); c.ellipse(45, 45, 13, 13, ';'); c.ellipse(45, 45, 8, 8, '_')
for dx, dy in ((0, 1), (1, 0), (-1, 0)): c.line(45 + dx * 12, 45 + dy * 12, 45 + dx * 20, 45 + dy * 20, '_', 3, only=set('~'))
blobs(c, ':', 10, (2, 4), on='.', min_d=4)
c.seal_ring(); open_sides(c, 's'); fix(c); safe_path(c, '_', '~', 3); common.boss_mark(c, 'B', '_')
B.add('Boss_Wild_Heart', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'beast', 'weight': 3})

if __name__ == '__main__':
    report(B)
    if '--write' in sys.argv:
        for r in B.rooms: r.write()
        print('written', len(B.rooms))
