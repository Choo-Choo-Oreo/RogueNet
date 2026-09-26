"""Foundry: a dwarf-built iron works taken over by goblins and fire spirits. Riveted iron
walls, metal plate floors, grates over the drains, molten channels bridged by grates,
furnaces of brick, slag and coal heaps, barrels and crates everywhere."""
import math, sys
import kit, common
from kit import open_sides, packs, singles
from common import blobs, keep_doors_clear, safe_path, pillar_grid, objects_far, blocks, niches, along_walls, roughen
from rb import Biome, Canvas, report

PLATE = 'floor_metal_plate'
L = {
    '#': dict(w='wall_iron'), '%': dict(w='wall_brick'), '&': dict(w='wall_mine_ore'), '!': dict(w='wall_smooth_stone'),
    '.': dict(f=PLATE), ',': dict(f='floor_grate'), '=': dict(f='floor_cobblestone'), ':': dict(f='floor_gravel'),
    '^': dict(f='floor_lava'), ';': dict(f='floor_lava_crust'), '~': dict(f='floor_water'), '_': dict(f='floor_smooth_stone'),
    's': dict(f=PLATE, spawn=True), 'f': dict(f=PLATE, spawn='fire_spirit'), 'F': dict(f='floor_lava', spawn='fire_spirit'),
    'g': dict(f=PLATE, spawn='goblin'), 'O': dict(f=PLATE, spawn='orc'), 'G': dict(f=PLATE, spawn='gargoyle'),
    'i': dict(f=PLATE, spawn='imp'), 'S': dict(f='floor_grate', spawn='slime'), 'M': dict(f=PLATE, spawn='mimic'),
    'r': dict(f=PLATE, spawn='rat'),
    'B': dict(f=PLATE, boss=True), 'C': dict(f=PLATE, obj='chest'), 'o': dict(f=PLATE, obj='barrel'), 'x': dict(f=PLATE, obj='crate'),
}
HAZ = '^;'
def door(w, r):
    if 'treasure' in r.tags or r.role == 'boss' or w == 1: return 'iron'
    return 'none'
B = Biome('foundry', L, door=door, base_floor=PLATE)

def fix(c):
    keep_doors_clear(c, '.', 2, HAZ + '~')
    c.connect_regions(set(kit.FLOORS), '.', '#%&!', 2)
    safe_path(c, ',', HAZ, 3)
def supplies(c, n=3, min_d=3):
    for p in along_walls(c, 'o', n, min_d=min_d): pass
    for p in along_walls(c, 'x', n, min_d=min_d): pass
def channel(c, a, b, width=2, bridges=2, ch='^'):
    c.line(a[0], a[1], b[0], b[1], ch, width, only=set('.:='))
    n = max(abs(b[0] - a[0]), abs(b[1] - a[1]))
    for k in range(1, bridges + 1):
        t = k / (bridges + 1); x, y = round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t)
        c.rect(x - 1, y - 1, x + 1, y + 1, ',', only=set('^;'))

def dress(c, kind):
    if kind == 'tunnel': blobs(c, ',', 1, (1, 1.5), min_d=1); supplies(c, 1, 2)
    elif kind in ('maze', 'maze_narrow'):
        blobs(c, ',', 2, (1, 2), min_d=2); fix(c)
        packs(c, [('g', 3, 1)], min_d=6); singles(c, 'f', 2, min_d=6, spacing=5)
    elif kind == 'coil': c[c.w // 2, c.h // 2] = 'C'
    elif kind == 'pocket':
        supplies(c, 1, 2); singles(c, 'r', 2, min_d=2, spacing=2)
    fix(c)

common.connective(B, {'dress': dress, 'names': {
    'tunnel': 'Gantry', 'crawl': 'Duct', 'maze': 'Maze',
    'pocket': ['Tool_Store', 'Coal_Hole', 'Boiler_Closet']}}, natural=False, seed=4000)

# ================================================================ entrances
c = kit.hall(23, 21, seed=1); c.rect(1, 1, 21, 4, '=')
for p in [(3, 6), (4, 6), (3, 7), (18, 6), (19, 6), (19, 7), (3, 15), (19, 15)]: c[p] = 'x'
for p in [(5, 6), (17, 6), (4, 15), (18, 15)]: c[p] = 'o'
fix(c); B.add('Entrance_Loading_Dock', c.rows(), 'entrance', ['peaceful'])
c = kit.hall(19, 23, seed=2); c.rect(1, 9, 17, 13, '='); c.rect(4, 4, 5, 5, '%'); c.rect(13, 4, 14, 5, '%'); c.rect(4, 17, 5, 18, '%'); c.rect(13, 17, 14, 18, '%')
fix(c); B.add('Entrance_Gatehouse', c.rows(), 'entrance', ['peaceful'])

# ================================================================ features
# Casting Floor: parallel molten runs from the furnace to the moulds, grate bridges across
c = kit.hall(33, 27, seed=3, sides='swe'); c.rect(12, 1, 20, 4, '%'); c.rect(14, 2, 18, 3, '^')
for x in (6, 16, 26): channel(c, (x, 5), (x, 24), 2, 2)
blocks(c, '!', 2, 2, 5, 5, box=(3, 8, 29, 23), on='.', min_d=3, chance=0.5); fix(c)
packs(c, [('g', 3, 1), ('g', 3, 1)], min_d=6, spacing=10); packs(c, [('F', 2, 2)], on='^', min_d=4); singles(c, 'f', 2, min_d=5)
B.add('Casting_Floor', c.rows(), 'normal', ['combat'])

# Smelter: a great brick furnace in the middle, glowing mouth, ore heaps round it
c = kit.hall(29, 29, seed=4); c.rect(9, 9, 19, 19, '%'); c.rect(11, 11, 17, 17, '^'); c.rect(13, 19, 15, 19, '^'); c.rect(13, 20, 15, 21, ';')
blobs(c, ':', 4, (1.5, 2.5), min_d=4); c.ellipse(4, 4, 2, 2, '&', only=set('.:')); c.ellipse(24, 24, 2, 2, '&', only=set('.:'))
fix(c); packs(c, [('f', 3, 2), ('O', 2, 1), ('g', 3, 1)], on='.:', min_d=5, spacing=8)
B.add('Smelter', c.rows(), 'normal', ['combat'])

# Slag Heaps: gravel mounds and cooling slag; hot crust you want to walk round
c = kit.hall(31, 25, seed=5); blobs(c, ':', 7, (2, 3.5), min_d=3); blobs(c, ';', 4, (1.5, 2.5), on=':', min_d=4)
blobs(c, '&', 3, (1, 1.5), on=':', min_d=4); fix(c)
packs(c, [('f', 2, 2), ('g', 3, 1), ('S', 2, 1)], on='.:', min_d=5, spacing=9); singles(c, 's', 2, min_d=5)
B.add('Slag_Heaps', c.rows(), 'normal', ['combat'])

# Bellows Hall: huge brick bellows in two rows, the goblins pumping them
c = kit.hall(29, 23, seed=6); blocks(c, '%', 3, 4, 4, 3, box=(4, 4, 25, 19), on='.', min_d=3)
c.rect(1, 11, 27, 11, ','); fix(c); packs(c, [('g', 3, 1), ('g', 3, 1), ('i', 2, 2)], min_d=5, spacing=9)
B.add('Bellows_Hall', c.rows(), 'normal', ['combat'])

# Conveyor Lines: long lines of crates on belts with gaps; lanes and cross lanes
c = kit.hall(33, 25, seed=7)
for y in range(5, 22, 4):
    for x in range(4, 30):
        if (x // 6) % 2 == 0 or (x % 6) < 3: c[x, y] = ','
        if x % 6 == 0 and c.rnd.random() < 0.6: c[x, y] = 'x'
fix(c); packs(c, [('g', 3, 1), ('g', 3, 1), ('O', 2, 1)], on='.,', min_d=5, spacing=9)
B.add('Conveyor_Lines', c.rows(), 'normal', ['combat'])

# Coal Bunker: heaps of coal against ore walls, a narrow rail line through
c = kit.box(27, 23, 8); open_sides(c, 'nsew'); roughen(c, 1, 0.25, 0.08)
c.replace('#', '&', 0.4, pred=lambda x, y: 0 < x < 26 and 0 < y < 22); blobs(c, ':', 5, (2, 3), min_d=3)
c.rect(1, 11, 25, 11, '='); c.rect(13, 1, 13, 21, '='); fix(c)
packs(c, [('r', 3, 1), ('g', 3, 1)], on='.:', min_d=5, spacing=9); singles(c, 'f', 2, on='.:', min_d=5)
B.add('Coal_Bunker', c.rows(), 'normal', ['combat'])

# Anvil Row: anvils down the room, quench troughs, the smiths still at work
c = kit.hall(31, 19, seed=9, sides='we')
for x in range(5, 27, 5): c[x, 6] = '!'; c[x, 12] = '!'; c.rect(x - 1, 9, x + 1, 9, '~')
fix(c); packs(c, [('O', 2, 1), ('g', 3, 1), ('g', 3, 1)], min_d=5, spacing=8)
B.add('Anvil_Row', c.rows(), 'normal', ['combat'])

# Pipe Works: grate floor over the drains, pipes (iron) in runs, slimes in the drains
c = kit.hall(27, 27, seed=10); c.replace('.', ',')
for y in (6, 13, 20): c.rect(3, y, 23, y, '#', only=set(',')); c.rect(c.rnd.randint(5, 18), y, c.rnd.randint(5, 18) + 2, y, ',')
for x in (8, 18): c.rect(x, 3, x, 23, '#', only=set(',')); c.rect(x, c.rnd.randint(4, 20), x, 0, ',')
fix(c); packs(c, [('S', 3, 1), ('S', 3, 1)], on=',', min_d=5, spacing=10); singles(c, 'r', 3, on=',', min_d=4)
B.add('Pipe_Works', c.rows(), 'normal', ['combat'])

# Quench Pools: water tanks steaming between walkways
c = kit.hall(29, 23, seed=11); blocks(c, '~', 5, 4, 3, 3, box=(3, 3, 25, 19), on='.', min_d=2)
fix(c); packs(c, [('S', 2, 1), ('g', 3, 1), ('f', 2, 2)], on='.', min_d=5, spacing=8)
B.add('Quench_Pools', c.rows(), 'normal', ['combat'])

# Crucible Bridge (kill zone): a molten lake, a single grate bridge, gargoyles on the far side
c = kit.hall(35, 27, seed=12, sides='ns'); c.rect(1, 7, 33, 19, '^'); c.rect(16, 7, 18, 19, ',')
blobs(c, ';', 4, (1.5, 2.5), on='^', min_d=3); fix(c)
packs(c, [('G', 2, 2), ('G', 2, 2), ('f', 2, 2)], on='.', min_d=8, spacing=8); packs(c, [('F', 3, 2)], on='^', min_d=5)
B.add('Crucible_Bridge', c.rows(), 'normal', ['killzone'])

# Gargoyle Gallery (kill zone): a long hall of pillars, a gargoyle on every other one
c = kit.hall(15, 45, seed=13, sides='ns'); niches(c, 'G', '#', '.', every=6, sides='we')
for y in range(6, 40, 6): c[4, y] = '%'; c[10, y] = '%'
c.rect(7, 1, 7, 43, ','); fix(c); packs(c, [('i', 3, 2)], min_d=15)
B.add('Gargoyle_Gallery', c.rows(), 'normal', ['killzone'])

# ================================================================ peaceful
c = kit.hall(15, 13, seed=14, sides='we'); c.rect(3, 3, 5, 3, '%'); c[11, 3] = 'x'; c[11, 9] = 'o'; c.rect(6, 6, 8, 6, '_'); fix(c)
B.add('Foremans_Office', c.rows(), 'normal', ['peaceful'])
c = kit.hall(17, 17, seed=15, sides='ns'); c.ellipse(8, 8, 4, 3, '~'); c.ring(8, 8, 4.5, 5.5, '_', only=set('.')); fix(c)
B.add('Cooling_Cistern', c.rows(), 'normal', ['peaceful'])
c = kit.hall(19, 15, seed=16, sides='nsw'); blocks(c, '%', 1, 3, 2, 2, box=(3, 3, 15, 11), on='.'); fix(c)
B.add('Pattern_Shop', c.rows(), 'normal', ['peaceful'])

# ================================================================ barracks
c = kit.hall(27, 21, seed=17, sides='we'); blocks(c, 'x', 2, 1, 2, 3, box=(3, 3, 23, 17), on='.', min_d=3); fix(c)
packs(c, [('g', 4, 1), ('g', 4, 1), ('g', 3, 1)], min_d=4, spacing=7)
B.add('Goblin_Bunks', c.rows(), 'normal', ['barracks'])
c = kit.hall(23, 21, seed=18, sides='nse'); c.rect(6, 8, 16, 12, '%'); c.rect(7, 9, 15, 11, '_'); fix(c)
packs(c, [('O', 3, 1), ('O', 3, 1)], on='._', min_d=4, spacing=8)
B.add('Orc_Mess', c.rows(), 'normal', ['barracks'])
c = kit.hall(21, 21, seed=19, sides='ns'); c.ellipse(10, 10, 5, 5, '^'); c.ellipse(10, 10, 2, 2, ';'); fix(c)
packs(c, [('F', 4, 2)], on='^', min_d=3); packs(c, [('f', 3, 2), ('i', 3, 2)], min_d=4, spacing=8)
B.add('Spirit_Forge', c.rows(), 'normal', ['barracks'])

# ================================================================ treasure
c = kit.hall(11, 11, seed=20, sides='s', width=1); c.rect(3, 2, 7, 3, '_'); c[5, 2] = 'C'; c[3, 2] = 'x'; c[7, 2] = 'x'; fix(c)
B.add('Treasure_Strongroom', c.rows(), 'normal', ['treasure'])
c = kit.hall(15, 13, seed=21, sides='w'); blocks(c, 'x', 1, 1, 1, 1, box=(6, 2, 12, 10), on='.', min_d=3, chance=0.7)
c[12, 6] = 'C'; c[11, 3] = 'M'; fix(c)
B.add('Treasure_Crate_Hoard', c.rows(), 'normal', ['treasure'])
c = kit.hall(15, 15, seed=22, sides='s'); c.ring(7, 6, 3, 5, '^'); c.rect(6, 8, 8, 13, ','); c[7, 6] = 'C'; fix(c)
B.add('Treasure_Ingot_Island', c.rows(), 'normal', ['treasure'])

# ================================================================ huge set pieces
# Great Forge 81x81: one gigantic furnace in the middle, molten canals out to the corners,
# grate bridges, workshops round the edge; you circle the furnace to cross the canals.
c = kit.hall(81, 81, seed=23)
c.rect(30, 30, 50, 50, '%'); c.rect(33, 33, 47, 47, '^'); c.rect(38, 38, 42, 42, ';')
for (ax, ay) in [(33, 33), (47, 33), (33, 47), (47, 47)]:
    bx, by = (4 if ax < 40 else 76), (4 if ay < 40 else 76)
    c.line(ax, ay, bx, by, '^', 3, only=set('.%'))
    for t in (0.35, 0.7):
        x, y = round(ax + (bx - ax) * t), round(ay + (by - ay) * t); c.rect(x - 2, y - 2, x + 2, y + 2, ',', only=set('^'))
for (x0, y0) in [(6, 36), (36, 6), (66, 36), (36, 66)]:
    c.rect(x0, y0, x0 + 8, y0 + 8, '#'); c.rect(x0 + 1, y0 + 1, x0 + 7, y0 + 7, '_'); c.rect(x0 + 3, y0 + (8 if y0 < 40 else 0), x0 + 5, y0 + (8 if y0 < 40 else 0), '.')
    c.rect(x0 + (8 if x0 < 40 else 0), y0 + 3, x0 + (8 if x0 < 40 else 0), y0 + 5, '.')
blobs(c, ':', 8, (2, 3), min_d=6); supplies(c, 8, 6); fix(c)
packs(c, [('g', 4, 1), ('g', 4, 1), ('O', 3, 1), ('O', 3, 1), ('f', 3, 2), ('f', 3, 2), ('G', 2, 2), ('i', 3, 2)], on='._:', min_d=10, spacing=14)
packs(c, [('F', 3, 2), ('F', 3, 2)], on='^', min_d=8, spacing=20); singles(c, 's', 6, min_d=10, spacing=10)
B.add('Great_Forge', c.rows(), 'normal', ['combat', 'vast'])

# Rail Yard 61x61: rail lines (cobble) in a grid, wagons of crates and ore, sheds with
# two doors each: a grid of loops.
c = kit.hall(61, 61, seed=24)
for k in range(8, 60, 11): c.rect(1, k, 59, k + 1, '='); c.rect(k, 1, k + 1, 59, '=')
for by in range(11, 55, 11):
    for bx in range(11, 55, 11):
        r = c.rnd.random()
        if r < 0.45:
            c.rect(bx, by, bx + 7, by + 7, '#'); c.rect(bx + 1, by + 1, bx + 6, by + 6, '.')
            c.rect(bx + 3, by, bx + 4, by, '.'); c.rect(bx + 3, by + 7, bx + 4, by + 7, '.')
        elif r < 0.7: blobs(c, ':', 1, (2, 3), min_d=2); c.ellipse(bx + 3.5, by + 3.5, 2, 2, '&', only=set('.'))
        else:
            for y in range(by + 1, by + 7, 2): c.rect(bx + 1, y, bx + 3, y, 'x', only=set('.'))
fix(c)
packs(c, [('g', 4, 1), ('g', 4, 1), ('O', 3, 1), ('r', 3, 1), ('f', 2, 2), ('g', 3, 1)], on='.=', min_d=8, spacing=12)
B.add('Rail_Yard', c.rows(), 'normal', ['combat', 'vast'])

# ================================================================ bosses
# The Crucible 45x45: a platform ringed by a molten moat, four grate drawbridges, brick
# chimneys round the rim.
c = kit.hall(45, 45, seed=25, sides='s'); c.ellipse(22, 22, 17, 17, '^'); c.ellipse(22, 22, 12, 12, '.')
for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)): c.line(22 + dx * 12, 22 + dy * 12, 22 + dx * 18, 22 + dy * 18, ',', 3, only=set('^'))
for i in range(8):
    a = i * math.pi / 4 + math.pi / 8; x, y = round(22 + 19.5 * math.cos(a)), round(22 + 19.5 * math.sin(a)); c.rect(x - 1, y - 1, x, y, '%')
fix(c); common.boss_mark(c, 'B', '.')
B.add('Boss_Crucible', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'giant', 'weight': 3})

# Heart of the Forge 97x97: the whole works in one hall. Concentric walls of iron with the
# molten heart in the middle, conveyor lanes, slag fields and gantries. The boss stands on
# the anvil platform over the heart.
c = kit.hall(97, 97, seed=26, sides='s')
for r, ch in ((44, '.'), (34, '#'), (26, '.'), (18, '^')):
    pass
c.frame(14, 14, 82, 82, '#'); c.frame(15, 15, 81, 81, '#')
for k in range(0, 4):
    m = c.rnd.randint(30, 66)
    [c.rect(m, 14, m + 2, 15, '.'), c.rect(m, 81, m + 2, 82, '.'), c.rect(14, m, 15, m + 2, '.'), c.rect(81, m, 82, m + 2, '.')][k]
c.frame(28, 28, 68, 68, '%'); c.frame(29, 29, 67, 67, '%')
for m in (47,): c.rect(m, 28, m + 2, 29, '.'); c.rect(m, 67, m + 2, 68, '.'); c.rect(28, m, 29, m + 2, '.'); c.rect(67, m, 68, m + 2, '.')
c.ellipse(48, 48, 15, 15, '^', only=set('.')); c.ellipse(48, 48, 7, 7, '_')
for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)): c.line(48 + dx * 7, 48 + dy * 7, 48 + dx * 17, 48 + dy * 17, ',', 3, only=set('^'))
blobs(c, ':', 12, (2, 3.5), min_d=6); blobs(c, ';', 5, (1.5, 2.5), on=':', min_d=8)
for y in range(20, 78, 6): c.rect(3, y, 10, y, ',') ; c.rect(86, y, 93, y, ',')
supplies(c, 10, 8); fix(c); common.boss_mark(c, 'B', '_')
B.add('Boss_Heart_Of_The_Forge', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'giant', 'weight': 3})

if __name__ == '__main__':
    report(B)
    if '--write' in sys.argv:
        for r in B.rooms: r.write()
        print('written', len(B.rooms))
