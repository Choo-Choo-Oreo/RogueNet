"""Glacier: a frozen river of ice. Snow floors, ice sheets, meltwater crevasses, rock outcrops."""
import math, sys
import kit, common
from kit import open_sides, packs, singles
from common import roughen, blobs, keep_doors_clear, safe_path, river, pillar_grid, objects_far, along_walls
from rb import Biome, Canvas, report

SNOW = 'floor_snow'
L = {
    '#': dict(w='wall_ice'), '%': dict(w='wall_rough_cave'),
    '.': dict(f=SNOW), ',': dict(f='floor_ice'), '~': dict(f='floor_water'), ':': dict(f='floor_gravel'),
    's': dict(f=SNOW, spawn=True), 'y': dict(f=SNOW, spawn='yeti'), 'w': dict(f=SNOW, spawn='wolf'),
    'P': dict(f=SNOW, spawn='penguin'), 'p': dict(f='floor_ice', spawn='penguin'), 'e': dict(f=SNOW, spawn='owl'),
    'B': dict(f=SNOW, boss=True), 'C': dict(f=SNOW, obj='chest'), 'x': dict(f=SNOW, obj='crate'),
    'o': dict(f=SNOW, obj='barrel'),
}
B = Biome('glacier', L, door=lambda w, r: 'none', base_floor=SNOW)
FL = '.,:'   # plain floors spawns may stand on (after conversion)

def ice_sheets(c, n=3, r=(2, 4)): blobs(c, ',', n, r, on='.', min_d=1)
def meltwater(c, n=2, r=(1.5, 3)): blobs(c, '~', n, r, on='.,', min_d=2); keep_doors_clear(c)
def outcrops(c, n=3, r=(1, 2)): blobs(c, '%', n, r, on='.,', min_d=3, jitter=0.4)
def fix(c): keep_doors_clear(c); c.connect_regions(set(kit.FLOORS), '.', '#%', 2)

def dress(c, kind):
    if kind == 'tunnel': ice_sheets(c, 2, (1, 2)); outcrops(c, 1, (0.6, 1))
    elif kind in ('maze', 'maze_narrow'):
        ice_sheets(c, 3, (1, 3)); fix(c)
        packs(c, [('w', 3, 1)], on='.', min_d=6); singles(c, 's', 2, on='.', min_d=6, spacing=5)
    elif kind == 'coil': c[c.w // 2, c.h // 2] = 'C'
    elif kind == 'pocket':
        ice_sheets(c, 1, (1, 2)); objects_far(c, 'x', 1, min_d=3); singles(c, 's', 2, min_d=2, spacing=2)
    fix(c)

common.connective(B, {'dress': dress, 'names': {
    'tunnel': 'Ice_Tunnel', 'crawl': 'Crevice_Crawl', 'maze': 'Maze',
    'pocket': ['Snow_Hollow', 'Ice_Grotto', 'Frozen_Cleft']}}, natural=True, seed=1000)

# ================================================================ entrances
c = kit.rounded(21, 21, seed=1, sides='nsew')
roughen(c, 1); outcrops(c, 2)
for p in [(8, 8), (12, 8), (8, 12), (12, 12)]: c[p] = 'x'
c[10, 7] = 'o'; c[7, 10] = 'o'
fix(c)
B.add('Entrance_Base_Camp', c.rows(), 'entrance', ['peaceful'])

c = kit.cavern(19, 25, seed=2, sides='nsew', fill=0.38)
c.rect(8, 9, 10, 15, ','); fix(c)
B.add('Entrance_Ice_Gate', c.rows(), 'entrance', ['peaceful'])

# ================================================================ features
# Crevasse Field: meltwater cracks across the room, snow bridges over each
c = kit.box(31, 25, seed=3); open_sides(c, 'nsew'); roughen(c, 2)
for i in range(4):
    y = 4 + i * 5 + c.rnd.randint(-1, 1)
    c.wiggle((2, y), (28, y + c.rnd.randint(-2, 2)), '~', 1 + (i % 2), 1.5, only=set('.'), steps=5)
for x in (6, 15, 24):   # bridges: snow over the cracks every so often
    c.rect(x, 1, x + 1, 23, '.', only={'~'})
fix(c); packs(c, [('w', 4, 1), ('w', 3, 1)], min_d=5); singles(c, 's', 2, min_d=5)
B.add('Crevasse_Field', c.rows(), 'normal', ['combat'])

# Frozen Lake: a great ice sheet, holes of open water, rock islands; penguins slide the ice
c = kit.cavern(35, 29, seed=4, sides='nsew', fill=0.36)
c.ellipse(17, 14, 13, 10, ',', only=set('.'), jitter=0.15)
blobs(c, '~', 4, (1.5, 2.5), on=',', min_d=4); blobs(c, '%', 3, (1, 1.8), on=',', min_d=5)
fix(c); packs(c, [('p', 4, 2), ('p', 4, 2)], on=',', min_d=6, spacing=10); packs(c, [('w', 3, 1)], min_d=4)
B.add('Frozen_Lake', c.rows(), 'normal', ['combat'])

# Serac Field: tumbled ice blocks, cover everywhere, yetis waiting behind them
c = kit.box(27, 27, seed=5); open_sides(c, 'nsew'); roughen(c, 1)
for _ in range(16):
    x, y = c.rnd.randint(3, 22), c.rnd.randint(3, 22)
    if abs(x - 13) < 3 and abs(y - 13) < 3: continue
    c.rect(x, y, x + c.rnd.randint(1, 2), y + c.rnd.randint(1, 2), '#', only=set('.'))
ice_sheets(c, 3); fix(c); packs(c, [('y', 2, 2), ('y', 2, 2), ('w', 3, 1)], min_d=5, spacing=8)
B.add('Serac_Field', c.rows(), 'normal', ['combat'])

# Ice Pillar Hall: rows of ice pillars, ice aisles between them
c = kit.hall(25, 33, seed=6, sides='nsew')
for x in range(3, 22, 4): c.rect(x, 2, x + 1, 30, ',', only=set('.'))
pillar_grid(c, '#', gap=4, size=2, on='.,', offset=4, min_d=3); fix(c)
packs(c, [('w', 3, 1), ('P', 3, 2)], on='.,', min_d=5, spacing=12); singles(c, 's', 3, on='.,', min_d=6, spacing=6)
B.add('Ice_Pillar_Hall', c.rows(), 'normal', ['combat'])

# Frozen Waterfall: an ice fall along the north wall, a plunge pool, rock ledges each side
c = kit.box(27, 23, seed=7); open_sides(c, 'swe'); roughen(c, 1)
c.rect(8, 1, 18, 4, '#'); c.rect(10, 1, 16, 2, ',')      # the frozen fall itself (ice)
c.ellipse(13, 7, 6, 3, '~'); c.ellipse(13, 7, 3, 1.5, ',')
c.rect(2, 3, 6, 5, '%'); c.rect(20, 3, 24, 5, '%')
fix(c); safe_path(c, ':', '~'); packs(c, [('y', 2, 2), ('e', 2, 3)], min_d=5); singles(c, 's', 2, min_d=5)
B.add('Frozen_Waterfall', c.rows(), 'normal', ['combat'])

# Glacier Tongue: long and wide, moraine gravel along the edges, a meltwater stream with fords
c = kit.box(45, 19, seed=8); open_sides(c, 'wens' if False else 'we'); open_sides(c, [('n', 10), ('s', 30)])
roughen(c, 2)
for (x, y) in c.cells(lambda ch: ch == '.'):
    if c.near(x, y, '#', 1) and c.rnd.random() < 0.7: c[x, y] = ':'
river(c, '~', horizontal=True, width=2, amp=3, only='.:')
fix(c); safe_path(c, '.', '~', 3)
packs(c, [('w', 4, 1), ('w', 3, 1)], on='.:', min_d=6, spacing=14); singles(c, 's', 3, on='.:', min_d=6, spacing=6)
B.add('Glacier_Tongue', c.rows(), 'normal', ['combat'])

# Ice Cave: organic ice cave, all walls ice, glassy floor patches
c = kit.cavern(29, 25, seed=9, sides='nsew', fill=0.45)
ice_sheets(c, 4, (2, 3)); fix(c); packs(c, [('y', 2, 2)], min_d=6); singles(c, 's', 4, on='.,', min_d=5, spacing=5)
B.add('Ice_Cave', c.rows(), 'normal', ['combat'])

# Moraine Ridges: diagonal ridges of rock split the room into lanes: flank or be flanked
c = kit.box(33, 23, seed=10)
for i in range(-2, 5):
    x0 = 3 + i * 7
    c.line(x0, 3, x0 + 12, 19, '%', 1, only=set('.:'))
for y in (7, 15): c.rect(1, y, 31, y + 1, '.', only={'%'})   # gaps through every ridge
for (x, y) in c.cells(lambda ch: ch == '.'):
    if c.near(x, y, '%', 1) and c.rnd.random() < 0.5: c[x, y] = ':'   # scree at the foot of each ridge
open_sides(c, 'nsew'); fix(c); packs(c, [('w', 3, 1), ('w', 3, 1), ('y', 1, 1)], on='.:', min_d=5, spacing=9)
B.add('Moraine_Ridges', c.rows(), 'normal', ['combat'])

# Standing Stones: a ring of rock stones round an ice circle under the aurora (a landmark)
c = kit.rounded(25, 25, seed=11, sides='nsew', jitter=0.08)
c.ellipse(12, 12, 4, 4, ',')
for i in range(8):
    a = i * math.pi / 4 + math.pi / 8; c[round(12 + 7 * math.cos(a)), round(12 + 7 * math.sin(a))] = '%'
fix(c); packs(c, [('w', 3, 1)], min_d=5); singles(c, 's', 3, on='.', min_d=6, spacing=6)
B.add('Standing_Stones', c.rows(), 'normal', ['combat'])

# Ice Bridge: a great crevasse, one wide snow bridge and two thin ice ledges round the ends
c = kit.box(35, 25, seed=12); open_sides(c, 'ns'); roughen(c, 1)
c.rect(1, 9, 33, 15, '~')
c.rect(15, 9, 19, 15, '.')           # the bridge
c.rect(2, 9, 2, 15, ','); c.rect(32, 9, 32, 15, ',')   # ledges along the walls
fix(c); packs(c, [('w', 4, 1)], min_d=6); packs(c, [('e', 2, 2), ('y', 1, 1)], min_d=6, spacing=10)
B.add('Ice_Bridge', c.rows(), 'normal', ['killzone'])

# Avalanche Chute: long lane, boulders for cover, the pack comes down from the top
c = kit.box(15, 45, seed=13); open_sides(c, 'ns'); roughen(c, 1)
for y in range(6, 40, 5):
    x = c.rnd.choice([3, 7, 10]); c.rect(x, y, x + 1, y + 1, '%')
c.replace('.', ',', 0.15); fix(c)
packs(c, [('w', 4, 1), ('w', 4, 1), ('y', 2, 2)], on='.,', min_d=8, spacing=10); singles(c, 's', 2, on='.,', min_d=8)
B.add('Avalanche_Chute', c.rows(), 'normal', ['killzone'])

# ================================================================ peaceful
c = kit.rounded(17, 17, seed=14, sides='ns')
c.ellipse(8, 8, 4, 3.5, '~'); c.ring(8, 8, 4.4, 5.6, ':', only=set('.'))
fix(c); safe_path(c, ':', '~')
B.add('Hot_Spring', c.rows(), 'normal', ['peaceful'])

c = kit.rounded(15, 15, seed=15, sides='ew', jitter=0.05)
c.ellipse(7, 7, 2, 2, ','); c[7, 3] = '%'; c[7, 11] = '%'; fix(c)
B.add('Frozen_Shrine', c.rows(), 'normal', ['peaceful'])

c = kit.cavern(21, 17, seed=16, sides='we', fill=0.4)
for p in objects_far(c, 'x', 3, min_d=4): pass
c.rect(9, 7, 11, 9, ':'); fix(c)
B.add('Abandoned_Camp', c.rows(), 'normal', ['peaceful'])

# ================================================================ barracks
c = kit.cavern(27, 23, seed=17, sides='nsw', fill=0.42)
blobs(c, ':', 3, (1.5, 2.2), min_d=5)
fix(c); packs(c, [('y', 2, 2), ('y', 2, 2), ('y', 2, 2)], on='.:', min_d=5, spacing=8)
B.add('Yeti_Den', c.rows(), 'normal', ['barracks'])

c = kit.rounded(29, 23, seed=18, sides='nse')
c.ellipse(14, 11, 11, 8, ',', only=set('.')); blobs(c, '~', 3, (1, 2), on=',', min_d=5)
fix(c); packs(c, [('p', 5, 2), ('p', 5, 2), ('p', 4, 2)], on=',', min_d=5, spacing=7)
B.add('Penguin_Colony', c.rows(), 'normal', ['barracks'])

c = kit.cavern(25, 21, seed=19, sides='ew', fill=0.46)
fix(c); packs(c, [('w', 4, 1), ('w', 4, 1), ('w', 3, 1)], min_d=5, spacing=7)
B.add('Wolf_Hollow', c.rows(), 'normal', ['barracks'])

# ================================================================ treasure
c = kit.rounded(11, 11, seed=20, sides='s', width=1); c.ellipse(5, 4, 2, 2, ','); c[5, 4] = 'C'; fix(c)
B.add('Treasure_Frozen_Hoard', c.rows(), 'normal', ['treasure'])

c = kit.box(17, 13, seed=21); open_sides(c, 'w'); roughen(c, 1)
c[13, 6] = 'C'
for p in [(12, 3), (14, 3), (12, 9), (14, 9), (10, 5)]: c[p] = 'x'
fix(c); packs(c, [('w', 3, 1)], min_d=4)
B.add('Treasure_Lost_Expedition', c.rows(), 'normal', ['treasure'])

c = kit.rounded(15, 15, seed=22, sides='s', width=3)
c.ring(7, 7, 2.5, 4.6, '~'); c.rect(6, 9, 8, 12, '.'); c.ellipse(7, 7, 2, 2, ','); c[7, 6] = 'C'
fix(c)
B.add('Treasure_Crevasse_Cache', c.rows(), 'normal', ['treasure'])

# ================================================================ huge set pieces
# Glacier Expanse 71x71: a wide frozen valley. Lakes, crevasses, seracs, camps; four ways in.
c = kit.cavern(71, 71, seed=23, sides='nsew', fill=0.42, steps=6)
blobs(c, ',', 5, (4, 7), on='.', min_d=6)
for _ in range(3):
    a = (c.rnd.randint(8, 62), c.rnd.randint(8, 62)); b = (c.rnd.randint(8, 62), c.rnd.randint(8, 62))
    c.wiggle(a, b, '~', 2, 5, only=set('.,'), steps=6)
blobs(c, '%', 8, (1, 2.5), on='.,', min_d=6, jitter=0.4)
blobs(c, '~', 5, (1, 2), on=',', min_d=6)
fix(c); safe_path(c, '.', '~', 3)
for p in objects_far(c, 'x', 3, min_d=15): pass
packs(c, [('w', 4, 1), ('w', 4, 1), ('y', 2, 2), ('y', 2, 2), ('P', 4, 2), ('w', 3, 1)], on='.', min_d=10, spacing=14)
packs(c, [('p', 4, 2), ('p', 4, 2)], on=',', min_d=10, spacing=16); singles(c, 's', 6, on='.', min_d=10, spacing=10)
B.add('Glacier_Expanse', c.rows(), 'normal', ['combat', 'vast'])

# Ice Palace 61x61: concentric ice walls with their gates turned against each other, a court
# in the middle. Walking in means walking round: three loops inside one room.
c = Canvas(61, 61, '#', 24); c.rect(1, 1, 59, 59, '.')
for k, r in enumerate((8, 16, 23)):
    m = 30; c.frame(m - r, m - r, m + r, m + r, '#'); c.frame(m - r - 1, m - r - 1, m + r + 1, m + r + 1, '#')
    gates = [(m - 1, m - r - 1, 'h'), (m - 1, m + r - 0, 'h'), (m - r - 1, m - 1, 'v'), (m + r, m - 1, 'v')]
    for i, (x, y, o) in enumerate(gates):
        if (i + k) % 2: continue          # two gates per wall, alternating round the rings
        if o == 'h': c.rect(x, y, x + 2, y + 1, '.')
        else: c.rect(x, y, x + 1, y + 2, '.')
    for i in range(0, 4):                # buttresses between the rings
        pass
c.ellipse(30, 30, 4, 4, ','); c[30, 30] = '%'
for x, y in [(30 - 20, 30 - 20), (30 + 20, 30 - 20), (30 - 20, 30 + 20), (30 + 20, 30 + 20)]: c.rect(x - 1, y - 1, x + 1, y + 1, '%')
blobs(c, ',', 10, (2, 4), on='.', min_d=0)
open_sides(c, 'nsew'); fix(c)
packs(c, [('y', 2, 2), ('y', 2, 2), ('w', 4, 1), ('w', 4, 1), ('P', 3, 2), ('P', 3, 2)], on='.,', min_d=8, spacing=12)
singles(c, 's', 6, on='.,', min_d=8, spacing=8)
B.add('Ice_Palace', c.rows(), 'normal', ['combat', 'vast'])

# ================================================================ bosses
# Frozen Throat 41x41: a crevasse ring round an ice plateau, four snow bridges, rock teeth.
c = kit.rounded(41, 41, seed=25, sides='s', jitter=0.05)
c.ring(20, 20, 11, 14, '~'); c.ellipse(20, 20, 10.5, 10.5, ',')
for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
    c.line(20 + dx * 10, 20 + dy * 10, 20 + dx * 15, 20 + dy * 15, '.', 3)
for i in range(12):
    a = i * math.pi / 6 + math.pi / 12; c[round(20 + 17 * math.cos(a)), round(20 + 17 * math.sin(a))] = '%'
fix(c); common.boss_mark(c, 'B', ',')
B.add('Boss_Frozen_Throat', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'giant', 'weight': 3})

# Glacier Heart 99x99: the biggest room there is. A meltwater river spirals in to a frozen lake;
# snow terraces between the coils, seracs and camps on the way, the heart of the ice at the centre.
c = Canvas(99, 99, '#', 26); c.cave('.', '#', 0.40, 6)
for (x, y) in c.cells():
    if math.hypot(x - 49, y - 49) > 47 + c.rnd.uniform(-1.5, 1): c[x, y] = '#'
pts = []
for i in range(260):
    t = i / 259; a = t * math.pi * 5.0; r = 44 * (1 - t) + 12 * t
    pts.append((round(49 + r * math.cos(a)), round(49 + r * math.sin(a))))
c.path(pts, '~', 3, only=set('.#'))
c.ellipse(49, 49, 12, 12, ','); c.ellipse(49, 49, 9, 9, ',')
for i in range(6):
    a = i * math.pi / 3; c.rect(round(49 + 14 * math.cos(a)) - 1, round(49 + 14 * math.sin(a)) - 1,
                                  round(49 + 14 * math.cos(a)) + 1, round(49 + 14 * math.sin(a)) + 1, '%')
blobs(c, '%', 14, (1, 2.5), on='.', min_d=8, jitter=0.4); blobs(c, ',', 8, (2, 4), on='.', min_d=6)
c.seal_ring(); open_sides(c, 's'); fix(c); safe_path(c, '.', '~', 3)
for p in objects_far(c, 'x', 4, min_d=20): pass
common.boss_mark(c, 'B', ',')
B.add('Boss_Glacier_Heart', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'beast', 'weight': 3})

if __name__ == '__main__':
    ok = report(B)
    if '--write' in sys.argv:
        for r in B.rooms: r.write()
        print('written', len(B.rooms))
