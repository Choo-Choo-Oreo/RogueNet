"""Room shapes shared by every new biome. Each returns a Canvas using generic chars:
'#' wall, '.' floor, 'D' opening. Biome scripts decorate them afterwards (pillars, liquid,
spawn chars, objects). Sizes are odd so a 3-wide opening sits centred."""
import math
from rb import Canvas

FLOORS = set('.,=~^_:;')   # anything a biome uses as floor; walls are everything else but ' ' and 'D'

def is_floor(c): return c in FLOORS

def box(w, h, seed=0, inset=1):
    c = Canvas(w, h, '#', seed); c.rect(inset, inset, w - 1 - inset, h - 1 - inset, '.'); return c

def open_sides(c, sides, width=3, floor='.', at=None):
    """sides: string like 'nsew' (each side once) or list of (side, at) pairs."""
    items = [(s, at) for s in sides] if isinstance(sides, str) else sides
    for s, a in items:
        c.door(s, width, a)
        c.dig_to(s, floor, width, a, walls='#%', stop=FLOORS)
    return c

def dist_from_doors(c, passable=None):
    passable = passable or (lambda ch: is_floor(ch) or ch == 'D')
    src = [p for p in c.cells(lambda ch: ch == 'D')]
    d = {p: 0 for p in src}; q = list(src); i = 0
    while i < len(q):
        x, y = q[i]; i += 1
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= n[0] < c.w and 0 <= n[1] < c.h and n not in d and passable(c[n]):
                d[n] = d[(x, y)] + 1; q.append(n)
    return d

def far_cells(c, min_d=4, on='.'):
    d = dist_from_doors(c)
    return [p for p, v in d.items() if v >= min_d and c[p] in on]

def packs(c, groups, on='.', min_d=4, spacing=6):
    """groups: [(char, size, spread)]. Each pack goes to a spot far from the doors and from other packs."""
    d = dist_from_doors(c); centres = []
    cand = [p for p, v in d.items() if v >= min_d and c[p] in on]
    for ch, n, spread in groups:
        c.rnd.shuffle(cand)
        cand.sort(key=lambda p: -min([abs(p[0] - a) + abs(p[1] - b) for a, b in centres] + [999]) + c.rnd.random() * 4)
        pick = next((p for p in cand if all(abs(p[0] - a) + abs(p[1] - b) >= spacing for a, b in centres)), cand[0] if cand else None)
        if pick is None: continue
        centres.append(pick)
        c.pack(ch, n, on, pick, spread, pred=lambda x, y: d.get((x, y), 0) >= min_d - 1)
    return centres

def singles(c, ch, n, on='.', min_d=4, spacing=3):
    d = dist_from_doors(c)
    return c.scatter(ch, n, on, pred=lambda x, y: d.get((x, y), 0) >= min_d, spacing=spacing)

# ---------------------------------------------------------------- corridors
def straight(length, inner=3, seed=0, width=3):
    c = box(inner + 2, length, seed); open_sides(c, 'ns', width); return c

def bend(size=9, inner=3, seed=0, width=3):
    c = Canvas(size, size, '#', seed); m = (size - inner) // 2
    c.rect(m, 1, m + inner - 1, m + inner - 1, '.'); c.rect(m, m, size - 2, m + inner - 1, '.')
    open_sides(c, 'ne', width); return c

def tee(w=11, h=9, inner=3, seed=0, width=3):
    c = Canvas(w, h, '#', seed); m = (w - inner) // 2; my = (h - inner) // 2
    c.rect(1, my, w - 2, my + inner - 1, '.'); c.rect(m, my, m + inner - 1, h - 2, '.')
    open_sides(c, 'wes', width); return c

def cross(size=11, inner=3, seed=0, width=3):
    c = Canvas(size, size, '#', seed); m = (size - inner) // 2
    c.rect(1, m, size - 2, m + inner - 1, '.'); c.rect(m, 1, m + inner - 1, size - 2, '.')
    open_sides(c, 'nsew', width); return c

def serpent(w=11, h=17, inner=3, seed=0, width=3, turns=2):
    """S-curve: in at the top centre, out at the bottom centre, swinging left and right."""
    c = Canvas(w, h, '#', seed); mid = (w - inner) // 2
    ys = [round(1 + (h - 2 - inner) * i / (turns + 1)) for i in range(turns + 2)]
    xs = [mid] + [1 if i % 2 == 0 else w - 1 - inner for i in range(turns)] + [mid]
    for i in range(len(ys) - 1):
        c.rect(xs[i], ys[i], xs[i] + inner - 1, ys[i + 1] + inner - 1, '.')
        c.rect(min(xs[i], xs[i + 1]), ys[i + 1], max(xs[i], xs[i + 1]) + inner - 1, ys[i + 1] + inner - 1, '.')
    open_sides(c, 'ns', width); return c

def loop(w=13, h=13, inner=3, seed=0, width=3, sides='ns'):
    """A tunnel that splits round a solid core and meets again: a tiny loop, two ways through."""
    c = Canvas(w, h, '#', seed)
    c.rect(1, 1, w - 2, h - 2, '.'); c.rect(1 + inner, 1 + inner, w - 2 - inner, h - 2 - inner, '#')
    open_sides(c, sides, width); return c

def narrow(length, seed=0, bends=0):
    """1-wide crawl, optionally kinked."""
    w = 5 if bends else 3
    c = Canvas(w, length, '#', seed); x = w // 2
    if bends:
        seg = (length - 2) // (bends + 1); y = 1; xs = [2, 1, 3]
        for i in range(bends + 1):
            nx = xs[i % 3] if i < bends else 2
            c.rect(x, y, x, min(y + seg, length - 2), '.')
            y2 = min(y + seg, length - 2); c.rect(min(x, nx), y2, max(x, nx), y2, '.'); x = nx; y = y2
        c.rect(x, y, x, length - 2, '.'); c.rect(2, 1, 2, 1, '.')
    else:
        c.rect(1, 1, 1, length - 2, '.')
    c.door('n', 1); c.door('s', 1)
    c.connect_regions(set('.'), '.', '#')
    return c

# ---------------------------------------------------------------- rooms
def hall(w, h, seed=0, pillars=0, pillar_gap=4, sides='nsew', width=3):
    c = box(w, h, seed)
    if pillars:
        for y in range(1 + pillar_gap, h - 1 - pillar_gap + 1, pillar_gap):
            for x in range(1 + pillar_gap, w - 1 - pillar_gap + 1, pillar_gap):
                c.rect(x, y, x + pillars - 1, y + pillars - 1, '%')
    open_sides(c, sides, width); return c

def rounded(w, h, seed=0, sides='nsew', width=3, jitter=0.12):
    c = Canvas(w, h, '#', seed)
    c.ellipse((w - 1) / 2, (h - 1) / 2, (w - 3) / 2, (h - 3) / 2, '.', jitter=jitter)
    c.seal_ring(); open_sides(c, sides, width); c.connect_regions(FLOORS, '.', '#%'); return c

def cavern(w, h, seed=0, sides='nsew', width=3, fill=0.44, steps=5, blob=True):
    """Organic cave; `blob` keeps it roughly oval so it does not fill the corners."""
    c = Canvas(w, h, '#', seed); c.cave('.', '#', fill, steps)
    if blob:
        for (x, y) in c.cells():
            if ((x - (w - 1) / 2) / ((w - 2) / 2)) ** 2 + ((y - (h - 1) / 2) / ((h - 2) / 2)) ** 2 > 1 + c.rnd.uniform(-.08, .08):
                c[x, y] = '#'
    c.seal_ring(); open_sides(c, sides, width); c.connect_regions(FLOORS, '.', '#%', width=2); return c

def ring_room(size, seed=0, core=None, sides='nsew', width=3, track=4):
    """Loop around a solid core (the only kind of loop the generator can have)."""
    c = box(size, size, seed); core = core or size - 2 - 2 * track
    m = (size - core) // 2; c.rect(m, m, m + core - 1, m + core - 1, '%')
    open_sides(c, sides, width); return c

def maze_room(w, h, seed=0, sides='nsew', width=3, cell=4, corridor=3, loops=0.15):
    c = Canvas(w, h, '#', seed)
    c.maze(1, 1, w - 2, h - 2, '.', '#', cell, loops, corridor)
    open_sides(c, sides, width); c.connect_regions(FLOORS, '.', '#'); return c

def spiral(size, seed=0, width=1, side='s', lane=1):
    """A coiled dead end: walk the spiral in to the prize at the centre."""
    c = Canvas(size, size, '#', seed); step = lane + 1
    x0, y0, x1, y1 = 1, 1, size - 2, size - 2
    pts = []; x, y = (size - 1) // 2, size - 2
    # walls of the spiral: concentric frames with a gap rotating round
    c.rect(1, 1, size - 2, size - 2, '.')
    k = 0; lo, hi = 1 + lane, size - 2 - lane
    while hi - lo >= 2:
        c.frame(lo, lo, hi, hi, '#')
        gap = [(lo + 1 if k % 2 == 0 else hi - 1, lo), (hi, lo + 1), (hi - 1 if k % 2 == 0 else lo + 1, hi), (lo, hi - 1)][k % 4]
        c[gap] = '.'
        if k % 4 == 0: c[lo + 1, lo] = '.'
        lo += step; hi -= step; k += 1
    c.door(side, width); c.dig_to(side, '.', width, stop=FLOORS)
    c.connect_regions(FLOORS, '.', '#')
    return c

def districts(w, h, seed=0, sides='nsew', width=3, min_leaf=11, loops=0.5, gap=3, margin=(0, 2), wall='#'):
    """A huge room cut into chambers by walls (binary space partition). Siblings are joined by
    gaps (a tree), then `loops` of the other shared walls get a gap too, so the room holds
    several ways round. Returns (canvas, leaves)."""
    c = Canvas(w, h, wall, seed); rnd = c.rnd
    leaves = []
    def split(x0, y0, x1, y1, depth):
        ww, hh = x1 - x0 + 1, y1 - y0 + 1
        can_v = ww >= 2 * min_leaf + 1; can_h = hh >= 2 * min_leaf + 1
        if not (can_v or can_h) or (depth > 2 and rnd.random() < 0.15):
            leaves.append((x0, y0, x1, y1)); return
        vert = can_v and (not can_h or ww > hh or (ww == hh and rnd.random() < .5))
        if vert:
            s = rnd.randint(x0 + min_leaf, x1 - min_leaf)
            split(x0, y0, s - 1, y1, depth + 1); split(s + 1, y0, x1, y1, depth + 1)
        else:
            s = rnd.randint(y0 + min_leaf, y1 - min_leaf)
            split(x0, y0, x1, s - 1, depth + 1); split(x0, s + 1, x1, y1, depth + 1)
    split(1, 1, w - 2, h - 2, 0)
    rects = []
    for (x0, y0, x1, y1) in leaves:
        m = [rnd.randint(*margin) for _ in range(4)]
        r = (x0 + m[0], y0 + m[1], x1 - m[2], y1 - m[3]); rects.append(r)
        c.rect(*r, '.')
    # adjacency between leaves (they share a wall line)
    def touching(a, b):
        if a[2] + 2 == b[0] or b[2] + 2 == a[0]:
            lo, hi = max(a[1], b[1]), min(a[3], b[3])
            if hi - lo >= gap + 1: return ('v', lo, hi)
        if a[3] + 2 == b[1] or b[3] + 2 == a[1]:
            lo, hi = max(a[0], b[0]), min(a[2], b[2])
            if hi - lo >= gap + 1: return ('h', lo, hi)
        return None
    pairs = [(i, j, touching(leaves[i], leaves[j])) for i in range(len(leaves)) for j in range(i + 1, len(leaves))]
    pairs = [p for p in pairs if p[2]]; rnd.shuffle(pairs)
    parent = list(range(len(leaves)))
    def find(i):
        while parent[i] != i: parent[i] = parent[parent[i]]; i = parent[i]
        return i
    def join(i, j, t):
        a, b = leaves[i], leaves[j]; kind, lo, hi = t
        g = rnd.randint(lo + 1, hi - gap)
        if kind == 'v':
            x0, x1 = min(a[2], b[2]), max(a[0], b[0])
            for x in range(x0 - 3, x1 + 4): c.rect(x, g, x, g + gap - 1, '.', only={wall})
            # carve until meeting the shrunk rooms on both sides
        else:
            y0, y1 = min(a[3], b[3]), max(a[1], b[1])
            for y in range(y0 - 3, y1 + 4): c.rect(g, y, g + gap - 1, y, '.', only={wall})
    for i, j, t in pairs:
        if find(i) != find(j): parent[find(i)] = find(j); join(i, j, t)
        elif rnd.random() < loops: join(i, j, t)
    c.seal_ring(wall)
    open_sides(c, sides, width)
    c.connect_regions(FLOORS, '.', wall + '%', width=gap)
    return c, rects

def chambers_ring(size, seed=0, n=8, sides='nsew', width=3):
    """A big round hall: an outer ring road with chambers hanging off it and a central court."""
    c = Canvas(size, size, '#', seed); m = (size - 1) / 2
    c.ring(m, m, size / 2 - 1 - 5, size / 2 - 1.5, '.')
    c.ellipse(m, m, size * 0.18, size * 0.18, '.')
    for i in range(n):
        a = 2 * math.pi * i / n
        r = size * 0.3
        c.line(round(m + math.cos(a) * size * 0.18), round(m + math.sin(a) * size * 0.18),
               round(m + math.cos(a) * r), round(m + math.sin(a) * r), '.', 3)
    c.seal_ring(); open_sides(c, sides, width); c.connect_regions(FLOORS, '.', '#%', 3)
    return c
