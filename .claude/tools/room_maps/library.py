"""Library: the Endless Library. Parquet floors, bookshelf walls and stacks, one carpet colour
per room, stained-glass windows, reading desks, statues. Haunted by what was left in the books."""
import math, sys
import kit, common
from kit import open_sides, packs, singles
from common import blobs, keep_doors_clear, pillar_grid, objects_far, blocks, niches, along_walls
from rb import Biome, Canvas, report

PAR = 'floor_parquet'
L = {
    '#': dict(w='wall_bookshelf'), '%': dict(w='wall_wood_plank'), '&': dict(w='wall_stained_glass'),
    '!': dict(w='wall_smooth_stone'), '|': dict(w='wall_brick'),
    '.': dict(f=PAR), ',': dict(f='floor_carpet_crimson'), ';': dict(f='floor_carpet_indigo'),
    ':': dict(f='floor_carpet_gold'), '_': dict(f='floor_carpet_verdigris'), '=': dict(f='floor_smooth_stone'),
    's': dict(f=PAR, spawn=True), 'g': dict(f=PAR, spawn='ghost'), 'm': dict(f=PAR, spawn='moth'),
    'W': dict(f=PAR, spawn='wraith'), 'h': dict(f=PAR, spawn='witch'), 'c': dict(f=PAR, spawn='cat'),
    'i': dict(f=PAR, spawn='imp'), 'M': dict(f=PAR, spawn='mimic'), 'O': dict(f=PAR, spawn='owl'),
    'r': dict(f=PAR, spawn='rat'), 'G': dict(f=PAR, spawn='gargoyle'),
    'B': dict(f='floor_carpet_gold', boss=True), 'Z': dict(f='floor_carpet_gold', boss='minotaur'),
    'C': dict(f=PAR, obj='chest'), 'x': dict(f=PAR, obj='crate'),
}
def door(w, r):
    if 'treasure' in r.tags or r.role == 'boss': return 'iron'
    return 'wood' if w == 1 else 'none'
B = Biome('library', L, door=door, base_floor=PAR)

def fix(c): c.connect_regions(set(kit.FLOORS), '.', '#%!|', 2)
def carpet(c, ch, box=None, inset=2):
    x0, y0, x1, y1 = box or (1 + inset, 1 + inset, c.w - 2 - inset, c.h - 2 - inset)
    c.rect(x0, y0, x1, y1, ch, only=set('.'))
def windows(c, sides='n', every=4):
    for s in sides:
        for i in range(2, (c.w if s in 'ns' else c.h) - 2, every):
            p = {'n': (i, 0), 's': (i, c.h - 1), 'w': (0, i), 'e': (c.w - 1, i)}[s]
            if c[p] == '#': c[p] = '&'
def stacks(c, box, horizontal=True, gap=3, break_every=9, on='.'):
    """Rows of shelves with a cross-aisle every `break_every` cells."""
    x0, y0, x1, y1 = box
    if horizontal:
        for y in range(y0, y1 + 1, gap + 1):
            for x in range(x0, x1 + 1):
                if (x - x0) % break_every not in (break_every - 3, break_every - 2, break_every - 1) and c[x, y] in on: c[x, y] = '#'
    else:
        for x in range(x0, x1 + 1, gap + 1):
            for y in range(y0, y1 + 1):
                if (y - y0) % break_every not in (break_every - 3, break_every - 2, break_every - 1) and c[x, y] in on: c[x, y] = '#'

def dress(c, kind):
    if kind == 'tunnel': windows(c, 'we', 3)
    elif kind in ('maze', 'maze_narrow'):
        fix(c); packs(c, [('g', 2, 2)], min_d=6); singles(c, 'm', 3, min_d=5, spacing=4); singles(c, 's', 1, min_d=6)
    elif kind == 'coil': c[c.w // 2, c.h // 2] = 'C'
    elif kind == 'pocket':
        objects_far(c, 'x', 1, min_d=3); singles(c, 'r', 2, min_d=2, spacing=2)
    fix(c)

common.connective(B, {'dress': dress, 'names': {
    'tunnel': 'Hallway', 'crawl': 'Servants_Stair', 'maze': 'Maze',
    'pocket': ['Book_Closet', 'Map_Cupboard', 'Bindery_Nook']}}, natural=False, seed=3000)

# ================================================================ entrances
c = kit.hall(23, 21, seed=1); carpet(c, ':', (9, 1, 13, 19)); c.rect(7, 7, 15, 8, '%'); c.rect(4, 3, 5, 4, '!'); c.rect(17, 3, 18, 4, '!')
windows(c, 'n', 3); fix(c)
B.add('Entrance_Front_Desk', c.rows(), 'entrance', ['peaceful'])
c = kit.rounded(25, 25, seed=2, jitter=0.0); c.ellipse(12, 12, 6, 6, ':'); c.ring(12, 12, 10.5, 11.5, '&', only={'#'}); c[12, 12] = '!'; fix(c)
B.add('Entrance_Atrium', c.rows(), 'entrance', ['peaceful'])

# ================================================================ features
# The Stacks: long shelf rows, cross-aisles, ghosts drifting down the rows
c = kit.hall(33, 29, seed=3); stacks(c, (3, 3, 29, 25), True, 3, 10); fix(c)
packs(c, [('g', 2, 2), ('W', 2, 2)], min_d=6, spacing=10); singles(c, 'm', 3, min_d=5, spacing=5); singles(c, 's', 2, min_d=6)
B.add('Stacks', c.rows(), 'normal', ['combat'])

# Reading Room: long tables on crimson, tall windows
c = kit.hall(29, 21, seed=4); carpet(c, ','); blocks(c, '%', 6, 1, 3, 3, box=(3, 4, 25, 16), on=',', min_d=3)
windows(c, 'ns', 3); fix(c); packs(c, [('g', 2, 2), ('c', 2, 2)], on='.,', min_d=5, spacing=10); singles(c, 'm', 2, min_d=4)
B.add('Reading_Room', c.rows(), 'normal', ['combat'])

# Rotunda: rings of shelves round a statue, radial aisles; a landmark
c = kit.rounded(33, 33, seed=5, jitter=0.0)
for r in (6, 10, 13): c.ring(16, 16, r - 0.5, r + 0.5, '#', only=set('.'))
for a in range(8):
    ang = a * math.pi / 4 + (0.39 if a % 2 else 0)
    c.line(16, 16, round(16 + 15 * math.cos(ang)), round(16 + 15 * math.sin(ang)), '.', 2, only=set('#'), inner=True)
c.seal_ring(); c.ellipse(16, 16, 3, 3, ';'); c[16, 16] = '!'; windows(c, 'nsew', 5); fix(c)
packs(c, [('W', 2, 2), ('g', 2, 2), ('m', 3, 2)], min_d=6, spacing=10)
B.add('Rotunda', c.rows(), 'normal', ['combat'])

# Scriptorium: a grid of writing desks, the monks' imps still copying
c = kit.hall(25, 23, seed=6); carpet(c, '_'); blocks(c, '%', 2, 1, 2, 2, box=(3, 3, 21, 19), on='_', min_d=3); fix(c)
packs(c, [('i', 3, 2), ('h', 1, 1)], on='._', min_d=5, spacing=8); singles(c, 's', 2, on='._', min_d=5)
B.add('Scriptorium', c.rows(), 'normal', ['combat'])

# Map Room: a great globe on gold carpet, chart tables round it
c = kit.hall(23, 23, seed=7, sides='nsw'); c.ellipse(11, 11, 7, 7, ':'); c.ellipse(11, 11, 2, 2, '!')
for p in [(4, 4), (17, 4), (4, 17), (17, 17)]: c.rect(p[0], p[1], p[0] + 1, p[1] + 1, '%')
fix(c); packs(c, [('O', 2, 2), ('g', 2, 2)], on='.:', min_d=5, spacing=8)
B.add('Map_Room', c.rows(), 'normal', ['combat'])

# Fallen Shelves: the stacks have toppled like dominoes, diagonal ruins to climb round
c = kit.hall(31, 25, seed=8)
for i in range(6):
    x = 3 + i * 5; c.line(x, 3, x + 6, 21, '#', 1, only=set('.'))
for y in (8, 16): c.rect(1, y, 29, y + 1, '.', only={'#'})
blobs(c, ',', 2, (1.5, 2.5), min_d=3); fix(c)
packs(c, [('r', 3, 1), ('r', 3, 1), ('g', 2, 2)], on='.,', min_d=5, spacing=8)
B.add('Fallen_Shelves', c.rows(), 'normal', ['combat'])

# Orrery: brass rings (planks) circling a sun statue; you cross the orbits
c = kit.rounded(29, 29, seed=9, jitter=0.0)
for r, gap in ((5, 0), (8, 2), (11, 4)):
    c.ring(14, 14, r - 0.5, r + 0.5, '%', only=set('.'))
    a = gap * 0.8; c.line(14, 14, round(14 + 13 * math.cos(a)), round(14 + 13 * math.sin(a)), '.', 3, only={'%'})
    a += math.pi; c.line(14, 14, round(14 + 13 * math.cos(a)), round(14 + 13 * math.sin(a)), '.', 3, only={'%'})
c.ellipse(14, 14, 2, 2, ':'); c[14, 14] = '!'; fix(c)
packs(c, [('G', 2, 2), ('i', 3, 2)], min_d=6, spacing=10); singles(c, 's', 2, min_d=6)
B.add('Orrery', c.rows(), 'normal', ['combat'])

# Forbidden Section (kill zone): a locked ring of shelves, witches inside, one way in
c = kit.hall(27, 27, seed=10); c.frame(6, 6, 20, 20, '|'); c.rect(12, 20, 14, 20, '.'); carpet(c, ';', (7, 7, 19, 19), 0)
stacks(c, (8, 9, 18, 18), True, 2, 12, on=';'); fix(c)
packs(c, [('h', 2, 2), ('W', 3, 2)], on=';', min_d=10, spacing=5); packs(c, [('g', 2, 2)], min_d=5)
B.add('Forbidden_Section', c.rows(), 'normal', ['killzone'])

# Gallery of Echoes (kill zone): a long window gallery, statues to hide behind, ghosts pouring in
c = kit.hall(15, 47, seed=11, sides='ns'); windows(c, 'we', 2)
for y in range(6, 42, 6): c[4, y] = '!'; c[10, y + 3] = '!'
carpet(c, ',', (6, 1, 8, 45), 0); fix(c)
packs(c, [('g', 3, 2), ('g', 3, 2), ('W', 2, 2), ('O', 2, 2)], on='.,', min_d=8, spacing=9)
B.add('Gallery_Of_Echoes', c.rows(), 'normal', ['killzone'])

# Card Catalogue: a grid of 1-wide drawers, ambush in every row
c = kit.hall(25, 25, seed=12); blocks(c, '%', 1, 1, 1, 1, box=(3, 3, 21, 21), on='.', min_d=3, chance=0.8); fix(c)
singles(c, 'm', 4, min_d=5, spacing=4); singles(c, 'M', 1, min_d=7)
B.add('Card_Catalogue', c.rows(), 'normal', ['combat'])

# ================================================================ peaceful
c = kit.hall(17, 17, seed=13, sides='ns'); carpet(c, ';'); c.rect(7, 3, 9, 3, '!'); windows(c, 'we', 2); fix(c)
B.add('Chapel_Of_Silence', c.rows(), 'normal', ['peaceful'])
c = kit.hall(15, 13, seed=14, sides='we'); carpet(c, '_'); c.rect(4, 3, 6, 3, '%'); c.rect(9, 9, 10, 9, '%'); fix(c)
B.add('Librarians_Study', c.rows(), 'normal', ['peaceful'])
c = kit.hall(19, 15, seed=15, sides='nse'); carpet(c, ':'); blocks(c, '%', 1, 1, 3, 3, on=':'); windows(c, 'n', 3); fix(c)
B.add('Tea_Room', c.rows(), 'normal', ['peaceful'])

# ================================================================ barracks
c = kit.hall(25, 21, seed=16, sides='we'); stacks(c, (3, 3, 21, 17), False, 3, 8); fix(c)
packs(c, [('m', 5, 2), ('m', 5, 2), ('O', 2, 2)], min_d=5, spacing=7)
B.add('Moth_Roost', c.rows(), 'normal', ['barracks'])
c = kit.hall(23, 19, seed=17, sides='nsw'); blobs(c, '=', 3, (1.5, 2.5), min_d=4)
for p in objects_far(c, 'x', 3, on='.', min_d=4): pass
fix(c); packs(c, [('r', 4, 1), ('r', 4, 1), ('c', 2, 1)], on='.=', min_d=5, spacing=7)
B.add('Rat_Archive', c.rows(), 'normal', ['barracks'])

# ================================================================ treasure
c = kit.hall(13, 11, seed=18, sides='s', width=1); carpet(c, ':', (4, 2, 8, 5), 0); c[6, 2] = 'C'; c[4, 2] = 'M'; c[8, 2] = 'M'
c[6, 2] = 'C'; fix(c)
B.add('Treasure_Restricted_Vault', c.rows(), 'normal', ['treasure'])
c = kit.hall(11, 11, seed=19, sides='s', width=1); c.ring(5, 4, 2.5, 3.2, '#', only=set('.')); c.rect(5, 6, 5, 8, '.'); c[5, 4] = 'C'; fix(c)
B.add('Treasure_Hidden_Reading_Nook', c.rows(), 'normal', ['treasure'])
c = kit.hall(17, 15, seed=20, sides='w'); carpet(c, ','); c[13, 7] = 'C'; c.rect(10, 3, 10, 11, '|'); c[10, 7] = ','
fix(c); packs(c, [('G', 2, 2)], on='.,', min_d=4)
B.add('Treasure_Curators_Cabinet', c.rows(), 'normal', ['treasure'])

# ================================================================ huge set pieces
# The Endless Stacks 91x91: a regular city of bookcases. Wide aisles every so often, a
# reading court in each quarter, collapsed shelves blocking some aisles so you must go round.
c = kit.hall(91, 91, seed=21)
for by in range(4, 86, 12):
    for bx in range(4, 86, 12):
        c.rect(bx, by, bx + 8, by + 8, '#')
        for y in range(by + 2, by + 8, 2): c.rect(bx + 1, y, bx + 7, y, '.')   # aisles into each block
        side = c.rnd.choice('nsew')
        if side in 'ns': c.rect(bx + 1, by + 2, bx + 1, by + 7, '.')
        else: c.rect(bx + 7, by + 2, bx + 7, by + 7, '.')
for (cx, cy) in [(22, 22), (68, 22), (22, 68), (68, 68), (45, 45)]:
    c.rect(cx - 5, cy - 5, cx + 5, cy + 5, '.'); c.rect(cx - 4, cy - 4, cx + 4, cy + 4, ',' if cx != 45 else ':')
    c.rect(cx - 1, cy - 1, cx + 1, cy + 1, '!' if cx == 45 else '%')
for _ in range(10):   # fallen shelves across the aisles
    x, y = c.rnd.randrange(13, 80, 12), c.rnd.randint(5, 85)
    c.rect(x, y, x + 2, y, '#', only=set('.'))
windows(c, 'nsew', 6); fix(c)
packs(c, [('g', 3, 2), ('g', 3, 2), ('W', 2, 2), ('W', 2, 2), ('m', 4, 2), ('m', 4, 2), ('h', 1, 1), ('c', 2, 2)], on='.,', min_d=10, spacing=16)
singles(c, 'M', 2, on='.', min_d=20, spacing=30); singles(c, 's', 8, on='.', min_d=10, spacing=10)
B.add('Endless_Stacks', c.rows(), 'normal', ['combat', 'vast'])

# Grand Atrium 63x63: galleries round a great open well of gold carpet, stained glass all
# round; balconies (shelf rings with gaps) make loops at three depths.
c = kit.hall(63, 63, seed=22)
for r in (28, 20, 12):
    c.frame(31 - r, 31 - r, 31 + r, 31 + r, '#')
    for k in range(4):
        off = c.rnd.randint(-r + 3, r - 5)
        for side in range(2):
            if (k + side) % 2: continue
        gaps = [(31 + off, 31 - r, 'h'), (31 - off, 31 + r, 'h'), (31 - r, 31 + off // 2, 'v'), (31 + r, 31 - off // 2, 'v')]
        x, y, o = gaps[k]
        if o == 'h': c.rect(x - 1, y, x + 1, y, '.')
        else: c.rect(x, y - 1, x, y + 1, '.')
c.rect(24, 24, 38, 38, ':'); c.rect(29, 29, 33, 33, '!'); c.rect(30, 30, 32, 32, ':')
c.rect(4, 30, 58, 32, ',', only=set('.')); c.rect(30, 4, 32, 58, ',', only=set('.'))
windows(c, 'nsew', 3); fix(c)
packs(c, [('G', 2, 2), ('G', 2, 2), ('W', 2, 2), ('g', 3, 2), ('O', 2, 2), ('i', 3, 2)], on='.,:', min_d=8, spacing=12)
B.add('Grand_Atrium', c.rows(), 'normal', ['combat', 'vast'])

# ================================================================ bosses
# Heart of the Archive 49x49: the Minotaur's labyrinth of books: broken shelf rings round a
# gold arena. Always the Minotaur here.
c = kit.rounded(49, 49, seed=23, sides='s', jitter=0.0)
for r in (21, 17, 13):
    c.ring(24, 24, r - 0.5, r + 0.6, '#', only=set('.'))
    for k in range(3):
        a = c.rnd.uniform(0, 2 * math.pi)
        c.line(24, 24, round(24 + 23 * math.cos(a)), round(24 + 23 * math.sin(a)), '.', 3, only={'#'}, inner=True)
c.seal_ring(); c.ellipse(24, 24, 9, 9, ':'); fix(c); common.boss_mark(c, 'Z', ':')
B.add('Boss_Heart_Of_The_Archive', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'beast', 'weight': 3})

# Great Reading Hall 75x75: a cathedral of books. Nave of crimson, rows of desks, shelf
# chapels down both sides, a window of stained glass behind the dais.
c = kit.hall(75, 75, seed=24, sides='s'); carpet(c, ',', (30, 3, 44, 71), 0)
for y in range(10, 66, 4):
    c.rect(8, y, 26, y, '%'); c.rect(48, y, 66, y, '%')
for y in range(6, 70, 8):
    c.rect(1, y, 5, y, '#'); c.rect(69, y, 73, y, '#')
for y in range(8, 68, 10): c.rect(28, y, 28, y + 1, '!'); c.rect(46, y, 46, y + 1, '!')
windows(c, 'n', 2); windows(c, 'we', 4); c.rect(33, 2, 41, 6, ':'); fix(c); common.boss_mark(c, 'B', ',')
B.add('Boss_Great_Reading_Hall', c.rows(), 'boss', ['combat'], favored_antagonist={'tag': 'giant', 'weight': 3})

if __name__ == '__main__':
    report(B)
    if '--write' in sys.argv:
        for r in B.rooms: r.write()
        print('written', len(B.rooms))
