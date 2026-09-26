"""Dressing helpers and the standard connective set every new biome shares in shape
(tunnels, crawls, mazes, side pockets). Biome scripts pass their own chars."""
import math
import kit
from kit import FLOORS, is_floor, open_sides, packs, singles, dist_from_doors

def roughen(c, passes=2, bite=0.35, grow=0.12, keep='D'):
    """Natural edges: nibble walls next to floor, drop a few boulders, smooth. Openings are kept."""
    for _ in range(passes):
        g = [r[:] for r in c.g]
        for y in range(1, c.h - 1):
            for x in range(1, c.w - 1):
                ch = c.g[y][x]
                n = c.count_near(x, y, '#')
                if ch == '#' and n <= 5 and c.rnd.random() < bite: g[y][x] = '.'
                elif ch == '.' and n >= 3 and c.rnd.random() < grow and not c.near(x, y, 'D', 2): g[y][x] = '#'
        c.g = g
    c.seal_ring()
    c.connect_regions(FLOORS, '.', '#', 2)

def blobs(c, ch, n, r=(2, 4), on='.', min_d=3, jitter=0.25):
    d = dist_from_doors(c); out = []
    cand = [p for p, v in d.items() if v >= min_d + r[1] and c[p] in on]
    for _ in range(n):
        if not cand: break
        x, y = c.rnd.choice(cand); rx, ry = c.rnd.uniform(*r), c.rnd.uniform(*r)
        c.ellipse(x, y, rx, ry, ch, only=set(on), jitter=jitter); out.append((x, y))
    return out

def keep_doors_clear(c, floor='.', depth=2, hazards='~^;'):
    """No liquid in or just inside an opening."""
    for (x, y) in c.cells(lambda ch: ch == 'D'):
        for dx in range(-depth, depth + 1):
            for dy in range(-depth, depth + 1):
                p = (x + dx, y + dy)
                if 0 < p[0] < c.w - 1 and 0 < p[1] < c.h - 1 and c[p] in hazards: c[p] = floor

def safe_path(c, path_ch, hazards, width=1):
    """Lay `path_ch` along the shortest route between every pair of openings through hazards
    (a ford, a bridge, a crust path): the fast way through."""
    doors = [p for p in c.cells(lambda ch: ch == 'D')]
    if not doors: return
    groups = []
    for p in doors:
        if not any(abs(p[0] - q[0]) + abs(p[1] - q[1]) <= 1 for g in groups for q in g): groups.append([p])
        else: next(g for g in groups if any(abs(p[0] - q[0]) + abs(p[1] - q[1]) <= 1 for q in g)).append(p)
    heads = [g[len(g) // 2] for g in groups]
    import heapq
    walk = lambda ch: is_floor(ch) or ch == 'D'
    for b in heads[1:]:
        a = heads[0]
        dist = {a: 0}; prev = {}; pq = [(0, a)]
        while pq:
            d, p = heapq.heappop(pq)
            if p == b: break
            if d > dist.get(p, 1e9): continue
            for n in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)):
                if not (0 <= n[0] < c.w and 0 <= n[1] < c.h) or not walk(c[n]): continue
                nd = d + (6 if c[n] in hazards else 1)
                if nd < dist.get(n, 1e9): dist[n] = nd; prev[n] = p; heapq.heappush(pq, (nd, n))
        p = b
        while p in prev:
            if c[p] in hazards:
                for dx in range(-(width // 2), width - width // 2):
                    for dy in range(-(width // 2), width - width // 2):
                        q = (p[0] + dx, p[1] + dy)
                        if c[q] in hazards: c[q] = path_ch
            p = prev[p]

def river(c, ch, horizontal=True, width=3, amp=3, only='.'):
    if horizontal:
        a, b = (1, c.h // 2 + c.rnd.randint(-2, 2)), (c.w - 2, c.h // 2 + c.rnd.randint(-2, 2))
    else:
        a, b = (c.w // 2 + c.rnd.randint(-2, 2), 1), (c.w // 2 + c.rnd.randint(-2, 2), c.h - 2)
    c.wiggle(a, b, ch, width, amp, only=set(only), steps=max(3, (c.w if horizontal else c.h) // 6))

def pillar_grid(c, ch, gap=4, size=1, on='.', offset=None, min_d=2):
    d = dist_from_doors(c); ox = offset or gap
    for y in range(ox, c.h - 1, gap):
        for x in range(ox, c.w - 1, gap):
            cells = [(x + i, y + j) for i in range(size) for j in range(size)]
            if all(c[p] in on and d.get(p, 99) >= min_d for p in cells if 0 < p[0] < c.w - 1 and 0 < p[1] < c.h - 1):
                for p in cells: c[p] = ch

def objects_far(c, ch, n, on='.', min_d=5):
    d = dist_from_doors(c)
    cand = sorted([p for p, v in d.items() if c[p] in on and v >= min_d], key=lambda p: -d[p])
    out = []
    for p in cand:
        if len(out) >= n: break
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) > 4 for q in out): c[p] = ch; out.append(p)
    return out

def along_walls(c, ch, n, on='.', wall='#', min_d=3):
    d = dist_from_doors(c)
    return c.scatter(ch, n, on, pred=lambda x, y: c.near(x, y, wall, 1) and d.get((x, y), 0) >= min_d, spacing=2)

def boss_mark(c, ch='B', clear='.', r=3):
    """Boss spawn at the centre of the biggest clear square, cleared to 7x7 of `clear` floor."""
    cx, cy = c.w // 2, c.h // 2
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1): c[cx + dx, cy + dy] = clear
    c[cx, cy] = ch
    return (cx, cy)

# ---------------------------------------------------------------- standard connective set
def connective(B, S, natural=False, seed=100):
    """Adds tunnels, crawls, mazes and side pockets to biome B, dressed by S (a dict of callables
    / chars from the biome: 'dress'(canvas, kind), 'maze_wall', 'names')."""
    nm = S['names']; dress = S['dress']
    def done(c, kind, rough=natural):
        if rough and kind in ('tunnel', 'pocket'): roughen(c, 1, 0.3, 0.06)
        dress(c, kind); return c.rows()
    s = seed
    B.add(nm['tunnel'] + '_Short', done(kit.straight(9, seed=s), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['tunnel'] + '_Long', done(kit.straight(19, seed=s + 1), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['tunnel'] + '_Bend', done(kit.bend(9, seed=s + 2), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['tunnel'] + '_Fork', done(kit.tee(11, 9, seed=s + 3), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['tunnel'] + '_Cross', done(kit.cross(11, seed=s + 4), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['tunnel'] + '_Serpent', done(kit.serpent(13, 19, seed=s + 5), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['tunnel'] + '_Loop', done(kit.loop(13, 15, seed=s + 6), 'tunnel'), 'corridor', ['corridor'])
    B.add(nm['crawl'], done(kit.narrow(11, seed=s + 7), 'crawl', False), 'corridor', ['corridor'])
    B.add(nm['crawl'] + '_Kinked', done(kit.narrow(15, seed=s + 8, bends=2), 'crawl', False), 'corridor', ['corridor'])
    # mazes: five kinds (braided maze, wide labyrinth, switchback, u-turn, hub)
    B.add(nm['maze'] + '_Braided', done(kit.maze_room(23, 23, seed=s + 9, cell=4, corridor=3, loops=0.2), 'maze'),
          'normal', ['maze'])
    B.add(nm['maze'] + '_Tangle', done(kit.maze_room(25, 19, seed=s + 10, sides='wes', cell=2, corridor=1, loops=0.12), 'maze_narrow', False),
          'normal', ['maze'])
    sw = kit.serpent(21, 25, seed=s + 11, turns=4)
    B.add(nm['maze'] + '_Switchback', done(sw, 'maze'), 'normal', ['maze'])
    u = kit.Canvas(19, 17, '#', s + 12); u.rect(2, 1, 16, 15, '.'); u.rect(8, 1, 10, 11, '#')
    for x in (5, 13):
        for y in range(4, 14, 4): u.rect(x - 1 if x == 5 else x, y, x if x == 5 else x + 1, y, '#')
    open_sides(u, [('n', 3), ('n', 13)], 3)
    B.add(nm['maze'] + '_Uturn', done(u, 'maze'), 'normal', ['maze'])
    hub = kit.hall(25, 25, seed=s + 13, pillars=2, pillar_gap=4, sides=[('n', 5), ('n', 17), ('s', 11), ('w', 6), ('e', 16)])
    B.add(nm['maze'] + '_Hub', done(hub, 'maze'), 'normal', ['maze'])
    sp = kit.spiral(17, seed=s + 14, width=1)
    B.add(nm['maze'] + '_Coil', done(sp, 'coil', False), 'normal', ['maze'])
    # side pockets: 1-wide dead ends with something in them
    for i, (w, h) in enumerate([(9, 9), (11, 7), (7, 11)]):
        c = kit.rounded(w, h, seed=s + 20 + i, sides='s', width=1) if natural else kit.box(w, h, s + 20 + i)
        if not natural: open_sides(c, 's', 1)
        B.add(nm['pocket'][i], done(c, 'pocket', False), 'normal', ['combat'])

def blocks(c, ch, bw, bh, gx, gy, box=None, on='.', min_d=2, chance=1.0):
    """A regular grid of bw x bh blocks with gx/gy gaps (pillars, shelves, beds, trees)."""
    x0, y0, x1, y1 = box or (1 + gx, 1 + gy, c.w - 2 - gx, c.h - 2 - gy)
    d = dist_from_doors(c); out = []
    for y in range(y0, y1 - bh + 2, bh + gy):
        for x in range(x0, x1 - bw + 2, bw + gx):
            cells = [(x + i, y + j) for i in range(bw) for j in range(bh)]
            if c.rnd.random() <= chance and all(c[p] in on and d.get(p, 99) >= min_d for p in cells):
                for p in cells: c[p] = ch
                out.append((x, y))
    return out

def niches(c, spawn, wall='#', floor='.', every=4, sides='we', depth=1):
    """Cut 1-wide niches into the long walls, a minion standing in each (arrow slits, alcoves)."""
    out = []
    for s in sides:
        if s in 'we':
            x = 1 if s == 'w' else c.w - 2
            for y in range(3, c.h - 3, every):
                if c[x, y] in floor + spawn:
                    xx = x - 1 if s == 'w' else x + 1
                    if 0 < xx < c.w - 1 and c[xx, y] == wall: c[xx, y] = spawn; out.append((xx, y))
        else:
            y = 1 if s == 'n' else c.h - 2
            for x in range(3, c.w - 3, every):
                if c[x, y] in floor + spawn:
                    yy = y - 1 if s == 'n' else y + 1
                    if 0 < yy < c.h - 1 and c[x, yy] == wall: c[x, yy] = spawn; out.append((x, yy))
    return out

def square_spiral(c, floor='.', lane=3, wall=2, shortcuts=2):
    """Square spiral corridor from the outer corner in to a chamber in the middle (a pyramid's
    ramps), with a few shortcuts knocked through so it is not one long line."""
    c.rect(1, 1, c.w - 2, c.h - 2, '#')
    step = lane + wall; lo, hi = 1, c.w - 1 - lane
    pts = [(lo, hi)]
    while hi - lo >= step:
        pts += [(lo, lo), (hi, lo), (hi, hi), (lo + step, hi)]
        lo += step; hi -= step
        pts.append((lo, hi))
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        c.rect(min(ax, bx), min(ay, by), max(ax, bx) + lane - 1, max(ay, by) + lane - 1, floor)
    m = c.w // 2; r = max(lane, (hi - lo) // 2 + lane)
    c.rect(m - r + 1, m - r + 1, m + r - 1, m + r - 1, floor)
    for _ in range(shortcuts):
        k = c.rnd.randint(1, 3) * step; side = c.rnd.choice('nsew'); p = m + c.rnd.randint(-4, 4)
        if side == 'n': c.rect(p, 1 + k - wall, p + lane - 1, 1 + k - 1, floor)
        elif side == 's': c.rect(p, c.h - 1 - k, p + lane - 1, c.h - 2 - k + wall, floor)
        elif side == 'w': c.rect(1 + k - wall, p, k, p + lane - 1, floor)
        else: c.rect(c.w - 1 - k, p, c.w - 2 - k + wall, p + lane - 1, floor)
