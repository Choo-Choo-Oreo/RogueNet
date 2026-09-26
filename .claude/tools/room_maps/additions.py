"""New rooms for existing biomes (dungeon, mine, cave, sewer), each following that biome's own
rules (door widths, free or exact joins, door types, spawn style) and bringing in the new tiles."""
import math, sys
import kit, common
from kit import open_sides, packs, singles, FLOORS
from common import roughen, blobs, keep_doors_clear, safe_path, pillar_grid, objects_far, blocks, along_walls
from rb import Biome, Canvas, report

def track(c, ch, over):
    """Lay `ch` along the shortest routes between the openings (the mine's cart track)."""
    safe_path(c, ch, over, 1)

# ================================================================ dungeon
# Rules: 2-wide doors on even walls, 1-wide on odd; exact joins (not free); wood on combat
# rooms and every 1-wide door; spawns are rolled cells.
DL = {'#': dict(w='wall_cobble_brick'), '%': dict(w='wall_mossy_stone'),
      '.': dict(f='floor_smooth_stone'), ',': dict(f='floor_cobblestone'), ';': dict(f='floor_mossy_cobblestone'),
      '=': dict(f='floor_grate'), 's': dict(f='floor_cobblestone', spawn=True), 'C': dict(f='floor_smooth_stone', obj='chest'),
      'T': dict(f='floor_smooth_stone', obj='torch')}
def ddoor(w, r):
    if w == 1 or 'combat' in r.tags: return 'wood'
    return 'any'
D = Biome('dungeon', DL, door=ddoor, free=False)
def dfix(c): c.connect_regions(set(FLOORS), ',', '#%', 2)

# Undercroft 70x70: the vaults under the keep. Cobbled chambers, mossy where the damp gets in,
# grated drains, several ways round every block.
c, rects = kit.districts(70, 70, seed=31, min_leaf=12, loops=0.55, margin=(1, 2), width=2, gap=2)
c.replace('.', ',')
for (x0, y0, x1, y1) in rects:
    r = c.rnd.random()
    if r < 0.3: c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, ';', only=set(','))
    elif r < 0.55: blocks(c, '%', 1, 1, 3, 3, box=(x0 + 2, y0 + 2, x1 - 2, y1 - 2), on=',', min_d=2)
    elif r < 0.75: c.rect((x0 + x1) // 2, y0 + 1, (x0 + x1) // 2, y1 - 1, '=', only=set(','))
dfix(c); packs(c, [('s', 3, 2)] * 8, on=',;', min_d=10, spacing=14)
D.add('Undercroft', c.rows(), 'normal', ['combat', 'vast'])

# Drain Hall 20x16: a grated drain down the middle, mossy pillars either side
c = kit.hall(20, 16, seed=32, width=2); c.replace('.', ','); c.rect(9, 1, 10, 14, '=')
for y in (4, 8, 11): c[5, y] = '%'; c[14, y] = '%'
dfix(c); singles(c, 's', 4, on=',', min_d=4, spacing=4)
D.add('Combat_Drain_Hall', c.rows(), 'normal', ['combat'])

# Mossy Vault 18x18: a ring of mossy pillars round a sunken, damp centre
c = kit.hall(18, 18, seed=33, width=2); c.replace('.', ','); c.rect(6, 6, 11, 11, ';')
for p in [(5, 5), (12, 5), (5, 12), (12, 12), (8, 4), (9, 13), (4, 9), (13, 8)]: c[p] = '%'
dfix(c); singles(c, 's', 4, on=',;', min_d=4, spacing=4)
D.add('Combat_Mossy_Vault', c.rows(), 'normal', ['combat'])

# Cobbled Court 22x22: an open-air court inside the walls, a well in the middle
c = kit.hall(22, 22, seed=34, width=2); c.replace('.', ','); c.rect(9, 9, 12, 12, ';'); c.rect(10, 10, 11, 11, '%')
blobs(c, ';', 3, (1, 2), on=',', min_d=3); dfix(c)
D.add('Peaceful_Cobbled_Court', c.rows(), 'normal', ['peaceful'])

# Oubliette 11x11: a narrow door, a grated pit, a forgotten chest
c = kit.hall(11, 11, seed=35, sides='s', width=1); c.rect(3, 3, 7, 5, '='); c[5, 2] = 'C'; dfix(c)
D.add('Treasure_Oubliette', c.rows(), 'normal', ['treasure'])

# ================================================================ mine
# Rules: odd sizes, 3-wide and 1-wide doors, exact joins, 'any' doors; timber (planks) track.
ML = {'#': dict(w='wall_rough_cave'), '&': dict(w='wall_mine_ore'), '%': dict(w='wall_wood_plank'),
      '.': dict(f='floor_dirt'), ':': dict(f='floor_gravel'), '=': dict(f='floor_wood_planks'),
      's': dict(f='floor_dirt', spawn=True), 'g': dict(f='floor_gravel', spawn=True), 'C': dict(f='floor_dirt', obj='chest'),
      'o': dict(f='floor_dirt', obj='barrel'), 'x': dict(f='floor_dirt', obj='crate')}
M = Biome('mine', ML, door=lambda w, r: 'any', free=False)
def mfix(c):
    c.connect_regions(set(FLOORS), '.', '#&%', 2)
    for (x, y) in c.cells(lambda ch: ch == 'D'):      # timber frames every doorway
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < c.w and 0 <= y + dy < c.h and c[x + dx, y + dy] in '#&' and \
                    (x + dx in (0, c.w - 1) or y + dy in (0, c.h - 1)): c[x + dx, y + dy] = '%'

# Grand Excavation 81x81: the open pit. Terraced gravel, ore faces everywhere, timber props,
# a plank track snaking between the four portals.
c = kit.cavern(81, 81, seed=41, fill=0.40, steps=6)
for (x, y) in c.cells(lambda ch: ch == '#'):
    if c.count_near(x, y, '.') >= 1 and c.rnd.random() < 0.35: c[x, y] = '&'
for r in (30, 20, 10):
    c.ring(40, 40, r - 0.5, r + 0.5, ':', only=set('.'))
blobs(c, ':', 10, (2, 4), min_d=4); blobs(c, '%', 6, (0.5, 0.9), on='.:', min_d=6)
track(c, '=', '.:'); mfix(c)
for p in objects_far(c, 'x', 4, on='.', min_d=12): pass
packs(c, [('s', 3, 1)] * 5 + [('g', 3, 1)] * 3, on='.:', min_d=10, spacing=14)
M.add('Grand_Excavation', c.rows(), 'normal', ['combat', 'vast'])

# Ore Vein 23x19: a gallery where the seam shows: ore on every face, rubble underfoot
c = kit.box(23, 19, 42); open_sides(c, 'we'); roughen(c, 1, 0.3, 0.06)
c.replace('#', '&', 0.5, pred=lambda x, y: c.near(x, y, '.', 1)); blobs(c, ':', 3, (1.5, 2.5), min_d=3)
track(c, '=', '.:'); mfix(c); singles(c, 's', 4, on='.:', min_d=4, spacing=4)
M.add('Ore_Vein', c.rows(), 'normal', ['combat'])

# Gravel Pit 25x25: a round pit of loose gravel, timber ramps down from each door
c = kit.rounded(25, 25, seed=43); c.ellipse(12, 12, 8, 8, ':'); c.ellipse(12, 12, 2, 2, '&')
track(c, '=', '.:'); mfix(c); packs(c, [('g', 3, 1), ('g', 3, 1)], on=':', min_d=5, spacing=8)
M.add('Gravel_Pit', c.rows(), 'normal', ['combat'])

# Collapsed Stope 21x21: the roof came down; heaps of rubble, props still standing
c = kit.box(21, 21, 44); open_sides(c, 'ns'); blobs(c, ':', 5, (1.5, 3), min_d=3); blobs(c, '#', 3, (1, 1.8), on=':', min_d=4)
pillar_grid(c, '%', 5, 1, on='.:', offset=5, min_d=3); track(c, '=', '.:'); mfix(c); singles(c, 's', 4, on='.:', min_d=4, spacing=4)
M.add('Collapsed_Stope', c.rows(), 'normal', ['combat'])

# ================================================================ cave
# Rules: odd sizes, one opening width (3 or 1), free, no doors, rough; swarms of 5 cells,
# 2 apart within 4 of their centre, 6+ apart and away from the openings.
CL = {'#': dict(w='wall_rough_cave'), 'O': dict(w='wall_smooth_cave'), 'I': dict(w='wall_ice'), '%': dict(w='wall_mossy_stone'),
      '.': dict(f='floor_dirt'), ';': dict(f='floor_moss'), '~': dict(f='floor_water'), ',': dict(f='floor_ice'),
      ':': dict(f='floor_gravel'), '=': dict(f='floor_smooth_cave'),
      's': dict(f='floor_dirt', spawn=True), 'm': dict(f='floor_moss', spawn=True), 'i': dict(f='floor_ice', spawn=True),
      'C': dict(f='floor_smooth_cave', obj='chest')}
CV = Biome('cave', CL, door=lambda w, r: 'none', base_floor='floor_dirt')
def cfix(c): keep_doors_clear(c, '.', 1, '~'); c.connect_regions(set(FLOORS), '.', '#OI%', 2)
def swarms(c, ch, n, on):
    packs(c, [(ch, 5, 2)] * n, on=on, min_d=5, spacing=8)

# Moss Cathedral 71x61: a vast cavern where daylight falls through a hole in the roof; the
# moss has taken the whole floor, flowstone columns hold the roof, pools collect the drip.
c = kit.cavern(71, 61, seed=51, fill=0.41, steps=6); c.replace('.', ';', 1.0)
c.ellipse(35, 30, 9, 7, '.', only=set(';')); blobs(c, '~', 6, (1.5, 3), on=';', min_d=6)
for (x, y) in c.cells(lambda ch: ch == '#'):
    if c.count_near(x, y, ';~') >= 6: c[x, y] = 'O'
blobs(c, 'O', 8, (0.6, 1.2), on=';', min_d=6); blobs(c, '%', 3, (1, 2), on=';', min_d=8)
cfix(c); swarms(c, 'm', 8, ';')
CV.add('Moss_Cathedral', c.rows(), 'normal', ['combat', 'vast'])

c = kit.cavern(25, 21, seed=52, fill=0.43); c.replace('.', ';', 0.8); blobs(c, '~', 1, (1.5, 2), on=';.', min_d=4); cfix(c); swarms(c, 'm', 2, ';')
CV.add('Moss_Garden', c.rows(), 'normal', ['combat'])
c = kit.cavern(23, 21, seed=53, fill=0.42); c.replace('#', 'I', 0.6, pred=lambda x, y: c.near(x, y, '.', 1)); c.replace('.', ',', 0.7)
cfix(c); swarms(c, 'i', 2, ',')
CV.add('Frozen_Grotto', c.rows(), 'normal', ['combat'])
c = kit.cavern(27, 19, seed=54, sides='we', fill=0.4)
for (x, y) in c.cells(lambda ch: ch == '.'):
    if y < 7 + c.rnd.randint(-1, 1): c[x, y] = ':'
cfix(c); swarms(c, 's', 2, '.')
CV.add('Scree_Slope', c.rows(), 'normal', ['combat'])

# ================================================================ sewer
# Rules: odd sizes, one opening width per room (5 mains/big rooms, 3, 1), free, 'any' doors
# (iron on side rooms and treasure); openings carry the floor inside them; rat swarms of 5,
# dense (2 apart within 3), never in water.
SL = {'#': dict(w='wall_cobble_brick'), '|': dict(w='wall_brick'), '!': dict(w='wall_smooth_stone'), 'I': dict(w='wall_iron'),
      '.': dict(f='floor_smooth_stone'), ',': dict(f='floor_brick'), '=': dict(f='floor_grate'), '~': dict(f='floor_water'),
      's': dict(f='floor_brick', spawn=True), 'r': dict(f='floor_smooth_stone', spawn=True)}
SW = Biome('sewer', SL, door=lambda w, r: 'iron' if 'Cistern' in r.id else 'any', base_floor='floor_smooth_stone')
def sfix(c): c.connect_regions(set(FLOORS), ',', '#|!I', 2)

# Great Cistern 71x71: a columned cistern the size of a cathedral. Brick walkways on a grid
# over the water, grates at the crossings, one dry island of brick in the middle.
c = kit.box(71, 71, 61); c.replace('.', '~')
for k in range(5, 66, 10):
    c.rect(1, k, 69, k + 2, ','); c.rect(k, 1, k + 2, 69, ',')
for k in range(5, 66, 10):
    for j in range(5, 66, 10): c.rect(k, j, k + 2, j + 2, '=')
for y in range(10, 62, 10):
    for x in range(10, 62, 10): c.rect(x, y, x + 1, y + 1, '|')
c.rect(28, 28, 42, 42, ','); c.rect(33, 33, 37, 37, '!')
for s in 'nsew': open_sides(c, s, 5, ',')
sfix(c); packs(c, [('s', 5, 2)] * 8, on=',', min_d=8, spacing=10)
SW.add('Great_Cistern', c.rows(), 'normal', ['combat', 'vast'])

# Grate Junction 25x25: four mains meet over a grated sump
c = kit.hall(25, 25, seed=62, width=5); c.rect(10, 1, 14, 23, ','); c.rect(1, 10, 23, 14, ',')
c.rect(11, 1, 13, 23, '~'); c.rect(1, 11, 23, 13, '~'); c.rect(10, 10, 14, 14, '=')
for s in 'nsew': open_sides(c, s, 5, ',')
sfix(c); packs(c, [('s', 5, 2)], on=',.', min_d=5)
SW.add('Grate_Junction', c.rows(), 'normal', ['combat'])

# Brick Culvert 13x31: an arched brick culvert, a narrow channel, grated steps
c = kit.hall(13, 31, seed=63, sides='ns', width=5); c.replace('.', ','); c.rect(5, 1, 7, 29, '~')
for y in (8, 15, 22): c.rect(5, y, 7, y, '=')
sfix(c); packs(c, [('s', 5, 2)], on=',', min_d=6)
SW.add('Brick_Culvert', c.rows(), 'normal', ['combat'])

ALL = [D, M, CV, SW]
if __name__ == '__main__':
    for b in ALL: report(b)
    if '--write' in sys.argv:
        for b in ALL:
            for r in b.rooms: r.write()
        print('written')
