"""Tomb: a desert necropolis half drowned in sand. Built sandstone halls, brick floors, sand
drifting in through every gap, statues and sarcophagi, an oasis now and then."""
import math, sys
import kit, common
from kit import open_sides, packs, singles
from common import roughen, blobs, keep_doors_clear, safe_path, pillar_grid, objects_far, blocks, niches, along_walls
from rb import Biome, Canvas, report

SAND, BRICK = 'floor_sand', 'floor_brick'
L = {
    '#': dict(w='wall_sandstone'), '%': dict(w='wall_smooth_stone'), '&': dict(w='wall_brick'),
    '.': dict(f=SAND), ',': dict(f=BRICK), '=': dict(f='floor_cobblestone'), '~': dict(f='floor_water'),
    ':': dict(f='floor_gravel'), ';': dict(f='floor_grass'),
    's': dict(f=SAND, spawn=True), 'r': dict(f=BRICK, spawn=True),
    'k': dict(f=SAND, spawn='scorpion'), 'n': dict(f=SAND, spawn='snake'), 'b': dict(f=SAND, spawn='beetle'),
    'l': dict(f=SAND, spawn='lizardman'), 'W': dict(f=BRICK, spawn='skeleton_warrior'),
    'A': dict(f=BRICK, spawn='skeleton_archer'), 'z': dict(f=BRICK, spawn='zombie'), 'M': dict(f=BRICK, spawn='mimic'),
    'B': dict(f=BRICK, boss=True), 'C': dict(f=BRICK, obj='chest'), 'c': dict(f=SAND, obj='chest'),
}
def door(w, r):
    if 'treasure' in r.tags or r.role == 'boss': return 'iron'
    return 'none'
B = Biome('tomb', L, door=door, base_floor=SAND)

def drifts(c, n=3, r=(2, 4), on=','):
    """Sand blown in over the brick: from the openings and in heaps along the walls."""
    for (x, y) in c.cells(lambda ch: ch == 'D'):
        c.ellipse(x, y, c.rnd.uniform(2, 4), c.rnd.uniform(2, 4), '.', only=set(on))
    blobs(c, '.', n, r, on=on, min_d=0)
def fix(c): keep_doors_clear(c, ','); c.connect_regions(set(kit.FLOORS), ',', '#%&', 2)
def built(w, h, seed, sides='nsew', width=3):
    c = kit.box(w, h, seed); c.replace('.', ','); open_sides(c, sides, width, ','); return c

def dress(c, kind):
    if kind != 'pocket_sand': c.replace('.', ',')
    if kind == 'tunnel': drifts(c, 1, (1, 2))
    elif kind in ('maze', 'maze_narrow'):
        drifts(c, 2); fix(c)
        packs(c, [('W', 2, 1)], on=',', min_d=6); packs(c, [('k', 2, 1)], on='.', min_d=5); singles(c, 'r', 2, on=',', min_d=6, spacing=5)
    elif kind == 'coil': c[c.w // 2, c.h // 2] = 'C'
    elif kind == 'pocket':
        drifts(c, 1, (1, 2)); objects_far(c, '%', 1, on=',', min_d=3); singles(c, 'z', 1, on=',', min_d=2); singles(c, 'r', 1, on=',', min_d=2)
    fix(c)

common.connective(B, {'dress': dress, 'names': {
    'tunnel': 'Passage', 'crawl': 'Shaft', 'maze': 'Maze',
    'pocket': ['Burial_Niche', 'Canopic_Closet', 'Robbers_Hole']}}, natural=False, seed=2000)

# ================================================================ entrances
c = built(21, 23, 1)
c.rect(1, 1, 19, 6, '.'); c.rect(4, 8, 5, 9, '%'); c.rect(15, 8, 16, 9, '%'); c.rect(4, 15, 5, 16, '%'); c.rect(15, 15, 16, 16, '%')
c.rect(9, 7, 11, 21, '='); fix(c)
B.add('Entrance_Sunken_Stair', c.rows(), 'entrance', ['peaceful'])
c = kit.cavern(23, 21, seed=2, sides='nsew', fill=0.36); c.rect(8, 7, 14, 13, ','); c.rect(10, 9, 12, 11, '%'); fix(c)
B.add('Entrance_Dune_Hollow', c.rows(), 'entrance', ['peaceful'])

# ================================================================ features
# Hypostyle Hall: a forest of 2x2 columns, archers hidden in the rows, sand spilling in
c = built(33, 33, 3); blocks(c, '#', 2, 2, 3, 3, on=',', min_d=3); drifts(c, 4); fix(c)
packs(c, [('A', 3, 3), ('A', 3, 3)], on=',', min_d=7, spacing=12); packs(c, [('W', 3, 1)], on=',', min_d=6); singles(c, 'k', 2, on='.', min_d=5)
B.add('Hypostyle_Hall', c.rows(), 'normal', ['combat'])

# Sand-Drowned Court: a colonnade round a court the dunes have claimed
c = built(31, 31, 4); c.rect(6, 6, 24, 24, '.'); c.ellipse(15, 15, 9, 7, '.', jitter=0.2)
for i in range(6, 25, 3):
    for p in [(4, i), (26, i), (i, 4), (i, 26)]:
        if c[p] == ',' and c.rnd.random() < 0.8: c[p] = '#'
blobs(c, ':', 3, (1, 1.5), on='.', min_d=5); fix(c)
packs(c, [('k', 3, 1), ('n', 3, 2), ('b', 3, 1)], on='.', min_d=6, spacing=9)
B.add('Sand_Drowned_Court', c.rows(), 'normal', ['combat'])

# Sarcophagus Chamber: rows of stone coffins; the dead are up and standing beside them
c = built(23, 27, 5); coffins = blocks(c, '%', 1, 3, 3, 2, box=(4, 4, 19, 22), on=',', min_d=3)
for (x, y) in coffins[::2]:
    if c[x + 1, y + 1] == ',': c[x + 1, y + 1] = 'z'
drifts(c, 1); fix(c); singles(c, 'r', 2, on=',', min_d=5, spacing=5)
B.add('Sarcophagus_Chamber', c.rows(), 'normal', ['combat'])

# Obelisk Plaza: a great obelisk, four small ones, causeways between them
c = built(29, 29, 6); drifts(c, 5, (2, 4))
c.rect(13, 1, 15, 27, '='); c.rect(1, 13, 27, 15, '='); c.rect(12, 12, 16, 16, ','); c.rect(13, 13, 15, 15, '%')
for p in [(7, 7), (21, 7), (7, 21), (21, 21)]: c[p] = '%'
fix(c); packs(c, [('l', 3, 1), ('l', 3, 1)], on='.,', min_d=6, spacing=12); singles(c, 's', 3, on='.', min_d=6)
B.add('Obelisk_Plaza', c.rows(), 'normal', ['combat'])

# Collapsed Gallery: a long hall with the roof down in heaps, archers in the side niches
c = built(37, 17, 7, sides='we'); open_sides(c, [('n', 17)], 3, ',')
for x in (9, 18, 27):
    c.ellipse(x + c.rnd.randint(-1, 1), 8, 2.5, 3, ':', only=set(','), jitter=0.4); c.ellipse(x, 8, 1, 1.5, '#', only=set(':'))
niches(c, 'A', '#', ',', every=6, sides='s'); drifts(c, 2); fix(c)
packs(c, [('W', 3, 1)], on=',', min_d=8); singles(c, 'k', 2, on='.', min_d=4)
B.add('Collapsed_Gallery', c.rows(), 'normal', ['combat'])

# Canal of the Dead: a still canal down the middle, two stone bridges, a mummy guard on each
c = built(31, 23, 8); c.rect(1, 10, 29, 12, '~')
c.rect(7, 10, 9, 12, '='); c.rect(21, 10, 23, 12, '=')
for x in (6, 10, 20, 24): c[x, 9] = '%'; c[x, 13] = '%'
drifts(c, 2); fix(c); packs(c, [('W', 2, 1), ('W', 2, 1), ('z', 2, 1)], on=',', min_d=5, spacing=10)
B.add('Canal_Of_The_Dead', c.rows(), 'normal', ['combat'])

# Buried Temple: half the room a sand dune with the tops of walls poking through
c = built(29, 25, 9)
for (x, y) in c.cells(lambda ch: ch == ','):
    if x + y * 0.6 < 20 + c.rnd.randint(-2, 2): c[x, y] = '.'
blocks(c, '&', 1, 4, 5, 3, on='.,', min_d=3, chance=0.6); fix(c)
packs(c, [('k', 3, 1), ('b', 4, 1)], on='.', min_d=5, spacing=8); packs(c, [('W', 2, 1)], on=',', min_d=6)
B.add('Buried_Temple', c.rows(), 'normal', ['combat'])

# Snake Pit: a sunken sand pit ringed by a walkway, snakes coiled below
c = built(25, 25, 10); c.ellipse(12, 12, 8, 8, '.'); c.ring(12, 12, 8, 9, '&', only=set(','))
for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)): c.line(12 + dx * 7, 12 + dy * 7, 12 + dx * 10, 12 + dy * 10, '.', 3)
fix(c); packs(c, [('n', 4, 2), ('n', 4, 2)], on='.', min_d=5, spacing=6)
B.add('Snake_Pit', c.rows(), 'normal', ['combat'])

# Hall of Kings: statues of kings down both sides, a causeway, lizardmen raiding it
c = built(19, 39, 11, sides='ns'); c.rect(8, 1, 10, 37, '=')
for y in range(4, 36, 4): c[3, y] = '%'; c[15, y] = '%'
drifts(c, 2); fix(c); packs(c, [('l', 3, 1), ('l', 3, 1)], on='.,', min_d=8, spacing=12); singles(c, 'r', 3, on=',', min_d=6)
B.add('Hall_Of_Kings', c.rows(), 'normal', ['combat'])

# Arrow Gallery (kill zone): a long straight corridor, archers in slits all down both walls
c = built(13, 43, 12, sides='ns'); niches(c, 'A', '#', ',', every=5, sides='we')
for y in (12, 22, 32): c.rect(4, y, 8, y, '%', only=set(','))    # low walls to duck behind
c.rect(6, 1, 6, 41, ','); fix(c); packs(c, [('W', 3, 1)], on=',', min_d=15)
B.add('Arrow_Gallery', c.rows(), 'normal', ['killzone'])

# Sphinx Court (kill zone): a colossal sphinx fills the court; everything comes round its paws
c = built(37, 33, 13); drifts(c, 7, (3, 5))
c.rect(12, 9, 24, 22, '%'); c.rect(14, 23, 16, 27, '%'); c.rect(20, 23, 22, 27, '%'); c.rect(15, 5, 21, 9, '%')
c.rect(13, 10, 23, 21, '%'); fix(c)
packs(c, [('l', 3, 1), ('n', 3, 2), ('k', 3, 1), ('A', 3, 2)], on='.,', min_d=6, spacing=10)
B.add('Sphinx_Court', c.rows(), 'normal', ['killzone'])

# ================================================================ peaceful
c = kit.cavern(25, 21, seed=14, sides='nsew', fill=0.34)
c.ellipse(12, 10, 5, 4, ';'); c.ellipse(12, 10, 3, 2, '~'); c.ellipse(7, 7, 1, 1, '%', only=set(';.')); fix(c)
B.add('Oasis', c.rows(), 'normal', ['peaceful'])
c = built(15, 15, 15, sides='ns'); c.rect(6, 6, 8, 8, '='); c[7, 7] = '%'; drifts(c, 1); fix(c)
B.add('Shrine_Of_The_Sun', c.rows(), 'normal', ['peaceful'])
c = built(17, 13, 16, sides='we'); blocks(c, '%', 3, 1, 2, 3, box=(3, 3, 13, 9), on=','); fix(c)
B.add('Embalmers_Workshop', c.rows(), 'normal', ['peaceful'])

# ================================================================ barracks
c = kit.cavern(25, 23, seed=17, sides='nse', fill=0.44); blobs(c, ':', 2, (1, 2), min_d=4); fix(c)
packs(c, [('k', 4, 1), ('k', 4, 1), ('k', 3, 1)], on='.', min_d=5, spacing=7)
B.add('Scorpion_Nest', c.rows(), 'normal', ['barracks'])
c = built(25, 21, 18, sides='we'); blocks(c, '%', 3, 1, 2, 2, box=(3, 3, 21, 17), on=',', min_d=3); fix(c)
packs(c, [('W', 3, 1), ('W', 3, 1), ('A', 3, 2)], on=',', min_d=5, spacing=8)
B.add('Guard_Barracks', c.rows(), 'normal', ['barracks'])
c = kit.cavern(23, 23, seed=19, sides='ns', fill=0.42); fix(c)
packs(c, [('b', 5, 1), ('b', 5, 1)], on='.', min_d=5, spacing=8)
B.add('Scarab_Swarm', c.rows(), 'normal', ['barracks'])

# ================================================================ treasure
c = built(11, 13, 20, sides='s', width=1); c[5, 3] = 'C'; c[3, 3] = '%'; c[7, 3] = '%'; fix(c)
B.add('Treasure_Pharaoh_Vault', c.rows(), 'normal', ['treasure'])
c = kit.cavern(15, 13, seed=21, sides='w', fill=0.3); objects_far(c, 'c', 1, min_d=4); fix(c)
B.add('Treasure_Buried_Chest', c.rows(), 'normal', ['treasure'])
c = built(17, 15, 22, sides='s')   # the false tomb: three chests, two of them bite
c.rect(3, 3, 13, 5, ','); c[4, 3] = 'M'; c[8, 3] = 'C'; c[12, 3] = 'M'; c[3, 9] = '%'; c[13, 9] = '%'; fix(c)
B.add('Treasure_False_Tomb', c.rows(), 'normal', ['treasure'])

# ================================================================ huge set pieces
# Necropolis 81x81: a city of the dead. Streets of cobble between walled tomb blocks, sand
# drifts in the squares, several ways round every block.
c, rects = kit.districts(81, 81, seed=23, min_leaf=13, loops=0.6, margin=(1, 2), wall='#')
c.replace('.', ',')
for (x0, y0, x1, y1) in rects:
    kind = c.rnd.random()
    if kind < 0.35 and x1 - x0 > 8 and y1 - y0 > 8:     # a mausoleum: brick walls, 1 door
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        c.rect(cx - 3, cy - 3, cx + 3, cy + 3, '&'); c.rect(cx - 2, cy - 2, cx + 2, cy + 2, ','); c[cx, cy + 3] = ','
        c[cx, cy] = '%'
    elif kind < 0.6: c.ellipse((x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2.5, (y1 - y0) / 2.5, '.', only=set(','), jitter=0.2)
    else: blocks(c, '%', 1, 1, 3, 3, box=(x0 + 2, y0 + 2, x1 - 2, y1 - 2), on=',', min_d=2)
for (x, y) in c.cells(lambda ch: ch == ','):
    if c.near(x, y, 'D', 3): c[x, y] = '='
drifts(c, 6, (2, 4)); fix(c)
packs(c, [('W', 3, 1), ('W', 3, 1), ('A', 3, 2), ('A', 3, 2), ('z', 3, 1), ('z', 3, 1)], on=',', min_d=10, spacing=14)
packs(c, [('k', 3, 1), ('n', 3, 2), ('l', 3, 1)], on='.', min_d=10, spacing=14); singles(c, 'r', 6, on=',', min_d=10, spacing=10)
B.add('Necropolis', c.rows(), 'normal', ['combat', 'vast'])

# Pyramid Interior 63x63: the ramps spiral in to the burial chamber; robbers' shortcuts cut
# through here and there.
c = Canvas(63, 63, '#', 24); common.square_spiral(c, ',', 3, 2, shortcuts=3)
open_sides(c, 'nsew', 3, ','); drifts(c, 8, (1.5, 3))
c[31, 31] = '%'; fix(c)
packs(c, [('W', 2, 1), ('W', 2, 1), ('z', 3, 1), ('A', 2, 1), ('A', 2, 1)], on=',', min_d=12, spacing=16)
singles(c, 'r', 5, on=',', min_d=10, spacing=10); singles(c, 'b', 3, on='.', min_d=6, spacing=8)
B.add('Pyramid_Interior', c.rows(), 'normal', ['combat', 'vast'])

# ================================================================ bosses
# Throne of Sand 45x45: two ranks of columns lead up to the throne; sand pours from the roof.
c = built(45, 45, 25, sides='s')
for y in range(6, 40, 5): c.rect(10, y, 11, y + 1, '#'); c.rect(33, y, 34, y + 1, '#')
c.rect(16, 3, 28, 7, '='); c.rect(20, 2, 24, 3, '%')
blobs(c, '.', 5, (2, 4), on=',', min_d=6); fix(c); common.boss_mark(c, 'B', ',')
B.add('Boss_Throne_Of_Sand', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'beast', 'weight': 3})

# Buried City 91x91: a sea of dunes with the tops of a drowned city showing through; the
# temple platform at the centre is where it waits.
c = Canvas(91, 91, '#', 26); c.cave('.', '#', 0.36, 6)
for (x, y) in c.cells():
    if math.hypot(x - 45, y - 45) > 43 + c.rnd.uniform(-1.5, 1): c[x, y] = '#'
for _ in range(22):
    x, y = c.rnd.randint(8, 80), c.rnd.randint(8, 80)
    if math.hypot(x - 45, y - 45) < 16: continue
    w, h = c.rnd.randint(4, 9), c.rnd.randint(4, 9)
    c.frame(x, y, x + w, y + h, '&'); c.rect(x + 1, y + 1, x + w - 1, y + h - 1, ',')
    for _k in range(2): c[c.rnd.choice([(x + w // 2, y), (x + w // 2, y + h), (x, y + h // 2), (x + w, y + h // 2)])] = ','
c.rect(33, 33, 57, 57, ','); c.frame(33, 33, 57, 57, '&')
for m in (43, 45, 47): c[m, 33] = '='; c[m, 57] = '='; c[33, m] = '='; c[57, m] = '='
for p in [(36, 36), (54, 36), (36, 54), (54, 54)]: c.rect(p[0] - 1, p[1] - 1, p[0], p[1], '%')
blobs(c, ':', 8, (1, 2), on='.', min_d=6)
c.seal_ring(); open_sides(c, 's', 3); fix(c); common.boss_mark(c, 'B', ',')
B.add('Boss_Buried_City', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'beast', 'weight': 3})

if __name__ == '__main__':
    report(B)
    if '--write' in sys.argv:
        for r in B.rooms: r.write()
        print('written', len(B.rooms))
