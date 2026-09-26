"""Room builder: char grids -> room JSON (format 2), with validation, generators and previews.

A room is drawn as a list of equal-length strings. Every character is looked up in the
biome's legend: {char: dict(f=floor tile or None, w=wall tile or None, spawn=True/'minion id',
obj='chest'/'torch'/'barrel'/'crate', boss=True)}. ' ' is void. 'D' is an opening: its floor
is the legend's 'D' floor, else the floor just inside it. Connectors are the runs of 'D' on
the outer ring, all "free"; their door comes from the biome's door rule by width.
"""
import json, os, random, collections, math, sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..')).replace(os.sep, '/')
ROOMS = REPO + '/game/rooms'
TILES = {}
for _f in os.listdir(REPO + '/game/tiles'):
    if _f.endswith('.json'):
        _d = json.load(open(REPO + '/game/tiles/' + _f)); TILES[_d['tile_name']] = _d
SEVERE = {n for n, d in TILES.items() if d.get('terrain') == 'severe'}
BOSS_CLEAR = 7          # the dragon is 7x7: every boss spawn needs a 7x7 walkable square around it


class Biome:
    def __init__(self, name, legend, door=lambda w, room: 'none', base_floor=None, free=True):
        self.name, self.legend, self.door, self.base_floor, self.free = name, legend, door, base_floor, free
        self.rooms = []

    def add(self, name, grid, role='normal', tags=(), favored=None, favored_antagonist=None, base_floor=None,
            extra_doors=(), note=None):
        grid = [g if isinstance(g, str) else ''.join(g) for g in grid]
        h, w = len(grid), len(grid[0])
        rid = '%s_%s_%dx%d' % (self.name.capitalize(), name, w, h)
        r = Room(self, rid, grid, role, list(tags), favored, favored_antagonist, base_floor or self.base_floor,
                 list(extra_doors))
        self.rooms.append(r)
        return r


class Room:
    def __init__(self, biome, rid, grid, role, tags, favored, fav_ant, base_floor, doors):
        self.biome, self.id, self.grid, self.role, self.tags = biome, rid, grid, role, tags
        self.favored, self.fav_ant, self.base_floor, self.doors = favored, fav_ant, base_floor, doors
        self.h, self.w = len(grid), len(grid[0])

    # ------------------------------------------------------------ cell helpers
    def L(self, x, y):
        c = self.grid[y][x]
        if c == ' ': return {}
        if c == 'D': return self.biome.legend.get('D', {})
        if c not in self.biome.legend: raise KeyError('%s: unknown char %r at %d,%d' % (self.id, c, x, y))
        return self.biome.legend[c]

    def is_edge(self, x, y): return x in (0, self.w - 1) or y in (0, self.h - 1)

    def walk(self, x, y):
        if not (0 <= x < self.w and 0 <= y < self.h): return False
        if self.grid[y][x] == 'D': return True
        e = self.L(x, y)
        return bool(e.get('f')) and not e.get('w')

    def floor_at(self, x, y):
        if self.grid[y][x] == 'D':
            f = self.biome.legend.get('D', {}).get('f')
            if f: return f
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < self.w and 0 <= ny < self.h and not self.is_edge(nx, ny) and self.walk(nx, ny):
                    return self.floor_at(nx, ny)
            return None
        e = self.L(x, y)
        return None if e.get('w') else e.get('f')

    def connectors(self):
        runs = []
        edges = [[(x, 0) for x in range(self.w)], [(x, self.h - 1) for x in range(self.w)],
                 [(0, y) for y in range(self.h)], [(self.w - 1, y) for y in range(self.h)]]
        for edge in edges:
            cur = []
            for p in edge + [None]:
                if p is not None and self.grid[p[1]][p[0]] == 'D': cur.append(p)
                elif cur: runs.append(cur); cur = []
        return runs

    # ------------------------------------------------------------ validation
    def problems(self):
        out = []
        if self.w > 100 or self.h > 100: out.append('bigger than 100')
        if any(len(r) != self.w for r in self.grid): return ['ragged rows']
        corners = {(0, 0), (self.w - 1, 0), (0, self.h - 1), (self.w - 1, self.h - 1)}
        for y in range(self.h):
            for x in range(self.w):
                c = self.grid[y][x]
                if c == 'D' and not self.is_edge(x, y): out.append('D inside at %d,%d' % (x, y))
                if self.is_edge(x, y) and c not in ' D' and not self.L(x, y).get('w'):
                    out.append('floor on the outer ring at %d,%d' % (x, y))
                if (x, y) in corners and c == 'D': out.append('corner opening')
        runs = self.connectors()
        if not runs: out.append('no connectors')
        walk = {(x, y) for y in range(self.h) for x in range(self.w) if self.walk(x, y)}
        for run in runs:
            for (x, y) in run:
                inner = (min(max(x, 1), self.w - 2), min(max(y, 1), self.h - 2))
                if inner not in walk: out.append('opening %d,%d leads into a wall' % (x, y))
                if self.floor_at(*inner) in SEVERE: out.append('hazard just inside opening %d,%d' % (x, y))
        if runs:
            seen = self._fill(runs[0][0], walk)
            lost = walk - seen
            if lost: out.append('%d walkable cells unreachable, e.g. %s' % (len(lost), sorted(lost)[0]))
            safe = {p for p in walk if self.floor_at(*p) not in SEVERE}
            safe_seen = self._fill(runs[0][0], safe)
            for run in runs[1:]:
                if run[0] not in safe_seen: out.append('no hazard-free path to opening %s' % (run[0],))
        spawns, boss, objs = self.markers()
        for (x, y), _ in spawns:
            if (x, y) not in walk: out.append('spawn off floor %d,%d' % (x, y))
        if spawns and (self.role in ('entrance', 'boss')): out.append('spawns in %s room' % self.role)
        if self.role == 'boss':
            if not boss: out.append('boss room without antagonist spawn')
            for (bx, by) in boss:
                r = BOSS_CLEAR // 2
                if not all((bx + dx, by + dy) in walk and self.floor_at(bx + dx, by + dy) not in SEVERE
                           for dx in range(-r, r + 1) for dy in range(-r, r + 1)):
                    out.append('boss spawn %d,%d lacks a clear %dx%d' % (bx, by, BOSS_CLEAR, BOSS_CLEAR))
        if 'treasure' in self.tags and not any(o == 'chest' for _, o in objs): out.append('treasure without chest')
        if len(runs) == 1 and self.role == 'corridor': out.append('dead-end corridor')
        return out

    def _fill(self, start, cells):
        seen = {start}; q = [start]
        while q:
            x, y = q.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in cells and n not in seen: seen.add(n); q.append(n)
        return seen

    def markers(self):
        spawns, boss, objs = [], [], []
        for y in range(self.h):
            for x in range(self.w):
                e = self.L(x, y) if self.grid[y][x] != 'D' else {}
                if e.get('spawn'): spawns.append(((x, y), e['spawn']))
                if e.get('boss'): boss.append((x, y)); self._boss_minion = e['boss'] if isinstance(e['boss'], str) else None
                if e.get('obj'): objs.append(((x, y), e['obj']))
        return spawns, boss, objs

    # ------------------------------------------------------------ JSON
    def to_json(self):
        floor = [[None] * self.w for _ in range(self.h)]
        walls = [[None] * self.w for _ in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                c = self.grid[y][x]
                if c == ' ': continue
                if c == 'D': floor[y][x] = self.floor_at(x, y); continue
                e = self.L(x, y)
                if e.get('w'): walls[y][x] = e['w']
                else: floor[y][x] = e.get('f')
        conns = []
        for run in self.connectors():
            a, b = run[0], run[-1]
            cn = {'a': {'x': a[0], 'y': a[1]}, 'b': {'x': b[0], 'y': b[1]}}
            if self.biome.free: cn['free'] = True
            cn['door'] = self.biome.door(len(run), self); conns.append(cn)
        spawns, boss, objs = self.markers()
        d = {'id': self.id, 'biome': self.biome.name, 'format': 2, 'width': self.w, 'height': self.h,
             'role': self.role, 'tags': self.tags}
        if self.base_floor: d['base_floor'] = self.base_floor
        d['floor'] = floor; d['walls'] = walls; d['connectors'] = conns
        if spawns:
            d['spawn_cells'] = [dict({'position': {'x': x, 'y': y}}, **({'minion': m} if isinstance(m, str) else {}))
                                for (x, y), m in spawns]
        if boss: d['antagonist_spawns'] = [dict({'position': {'x': x, 'y': y}}, **({'minion': self._boss_minion} if self._boss_minion else {})) for x, y in boss]
        if self.fav_ant: d['favored_antagonist'] = self.fav_ant
        if self.favored: d['favored_minion'] = self.favored
        if self.doors: d['doors'] = self.doors
        d['objects'] = [{'type': o, 'position': {'x': float(x * 16 + 8), 'y': float(y * 16 + 8)}, 'rotation': 0.0}
                        for (x, y), o in objs]
        return d

    def write(self, folder=None):
        folder = folder or os.path.join(ROOMS, self.biome.name)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, self.id + '.json'), 'w', newline='\n') as f:
            json.dump(self.to_json(), f, indent='\t'); f.write('\n')


# ================================================================ canvas + generators
class Canvas:
    """Mutable char grid. Everything starts as `fill` (default wall '#')."""
    def __init__(self, w, h, fill='#', seed=0):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]
        self.rnd = random.Random(seed)

    def __getitem__(self, p): return self.g[p[1]][p[0]]
    def __setitem__(self, p, c):
        if 0 <= p[0] < self.w and 0 <= p[1] < self.h: self.g[p[1]][p[0]] = c
    def inside(self, x, y, m=1): return m <= x < self.w - m and m <= y < self.h - m
    def cells(self, pred=None):
        return [(x, y) for y in range(self.h) for x in range(self.w) if pred is None or pred(self.g[y][x])]

    def rect(self, x0, y0, x1, y1, c, only=None):
        for y in range(max(y0, 0), min(y1, self.h - 1) + 1):
            for x in range(max(x0, 0), min(x1, self.w - 1) + 1):
                if only is None or self.g[y][x] in only: self.g[y][x] = c
    def frame(self, x0, y0, x1, y1, c):
        for x in range(x0, x1 + 1): self[x, y0] = c; self[x, y1] = c
        for y in range(y0, y1 + 1): self[x0, y] = c; self[x1, y] = c
    def ellipse(self, cx, cy, rx, ry, c, only=None, jitter=0.0):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if not (0 <= x < self.w and 0 <= y < self.h): continue
                d = ((x - cx) / max(rx, .5)) ** 2 + ((y - cy) / max(ry, .5)) ** 2
                if d <= 1 + (self.rnd.uniform(-jitter, jitter) if jitter else 0):
                    if only is None or self.g[y][x] in only: self.g[y][x] = c
    def ring(self, cx, cy, r0, r1, c, only=None):
        for y in range(self.h):
            for x in range(self.w):
                d = math.hypot(x - cx, y - cy)
                if r0 <= d <= r1 and (only is None or self.g[y][x] in only): self.g[y][x] = c
    def line(self, x0, y0, x1, y1, c, width=1, only=None, inner=False):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
            for dx in range(-(width // 2), width - width // 2):
                for dy in range(-(width // 2), width - width // 2):
                    m = 1 if inner else 0
                    if m <= x + dx < self.w - m and m <= y + dy < self.h - m and (only is None or self.g[y + dy][x + dx] in only):
                        self.g[y + dy][x + dx] = c
    def path(self, pts, c, width=1, only=None):
        for a, b in zip(pts, pts[1:]): self.line(a[0], a[1], b[0], b[1], c, width, only)
    def wiggle(self, a, b, c, width=3, amp=4, only=None, steps=6):
        """A meandering path from a to b (a river, a trail)."""
        pts = [a]
        for i in range(1, steps):
            t = i / steps
            x = a[0] + (b[0] - a[0]) * t; y = a[1] + (b[1] - a[1]) * t
            nx, ny = -(b[1] - a[1]), b[0] - a[0]; L = math.hypot(nx, ny) or 1
            o = self.rnd.uniform(-amp, amp)
            pts.append((round(x + nx / L * o), round(y + ny / L * o)))
        pts.append(b); self.path(pts, c, width, only)
    def replace(self, old, new, chance=1.0, pred=None):
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] in old and self.rnd.random() < chance and (pred is None or pred(x, y)):
                    self.g[y][x] = new
    def near(self, x, y, chars, r=1):
        return any(0 <= x + dx < self.w and 0 <= y + dy < self.h and self.g[y + dy][x + dx] in chars
                   for dx in range(-r, r + 1) for dy in range(-r, r + 1) if dx or dy)
    def count_near(self, x, y, chars):
        return sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and
                   (not (0 <= x + dx < self.w and 0 <= y + dy < self.h) or self.g[y + dy][x + dx] in chars))

    def cave(self, floor='.', wall='#', fill=0.45, steps=5, region=None, keep=None):
        """Cellular-automaton cave inside the ring (or region x0,y0,x1,y1)."""
        x0, y0, x1, y1 = region or (1, 1, self.w - 2, self.h - 2)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if keep and self.g[y][x] in keep: continue
                self.g[y][x] = wall if self.rnd.random() < fill else floor
        for _ in range(steps):
            new = [r[:] for r in self.g]
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if keep and self.g[y][x] in keep: continue
                    n = self.count_near(x, y, wall)
                    new[y][x] = wall if n >= 5 else floor if n <= 3 else self.g[y][x]
            self.g = new

    def maze(self, x0, y0, x1, y1, floor='.', wall='#', cell=2, loops=0.1, corridor=1):
        """Recursive-backtracker maze in the box, cells `cell` apart, passages `corridor` wide; `loops`
        is the chance each remaining wall between two cells is knocked out (braids the maze)."""
        cols = (x1 - x0 + 1 - corridor) // cell + 1; rows = (y1 - y0 + 1 - corridor) // cell + 1
        pos = lambda cx, cy: (x0 + cx * cell, y0 + cy * cell)
        def carve(px, py, w=corridor, h=corridor): self.rect(px, py, px + w - 1, py + h - 1, floor)
        seen = {(0, 0)}; stack = [(0, 0)]; carve(*pos(0, 0))
        while stack:
            cx, cy = stack[-1]
            nbs = [(cx + dx, cy + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if 0 <= cx + dx < cols and 0 <= cy + dy < rows and (cx + dx, cy + dy) not in seen]
            if not nbs: stack.pop(); continue
            nx, ny = self.rnd.choice(nbs); seen.add((nx, ny)); stack.append((nx, ny))
            (ax, ay), (bx, by) = pos(cx, cy), pos(nx, ny)
            carve(min(ax, bx), min(ay, by), abs(bx - ax) + corridor, abs(by - ay) + corridor)
        for cy in range(rows):
            for cx in range(cols):
                for dx, dy in ((1, 0), (0, 1)):
                    if cx + dx < cols and cy + dy < rows and self.rnd.random() < loops:
                        (ax, ay), (bx, by) = pos(cx, cy), pos(cx + dx, cy + dy)
                        carve(min(ax, bx), min(ay, by), abs(bx - ax) + corridor, abs(by - ay) + corridor)

    def scatter(self, char, n, on, pred=None, spacing=1, tries=4000):
        """Put `char` on n random cells that are `on`, keeping `spacing` apart. Returns the cells."""
        got = []
        for _ in range(tries):
            if len(got) >= n: break
            x, y = self.rnd.randrange(self.w), self.rnd.randrange(self.h)
            if self.g[y][x] not in on or (pred and not pred(x, y)): continue
            if any(abs(x - a) <= spacing and abs(y - b) <= spacing for a, b in got): continue
            self.g[y][x] = char; got.append((x, y))
        return got

    def pack(self, char, n, on, centre=None, spread=1, pred=None):
        """A tight group of n cells near `centre` (or a random `on` cell)."""
        if centre is None:
            opts = [p for p in self.cells(lambda c: c in on) if pred is None or pred(*p)]
            if not opts: return []
            centre = self.rnd.choice(opts)
        cand = sorted(((x, y) for y in range(self.h) for x in range(self.w)
                       if self.g[y][x] in on and (pred is None or pred(x, y))),
                      key=lambda p: (abs(p[0] - centre[0]) + abs(p[1] - centre[1]), self.rnd.random()))
        got = []
        for p in cand:
            if len(got) >= n: break
            if spread > 1 and any(max(abs(p[0] - a), abs(p[1] - b)) < spread for a, b in got): continue
            self.g[p[1]][p[0]] = char; got.append(p)
        return got

    def door(self, side, width=3, at=None):
        """Opening on a side ('n','s','w','e'), centred unless `at` (first cell index along the side).
        Carves floor inward until it meets walkable floor (never into wall chars in `keep`)."""
        if side in 'ns':
            start = at if at is not None else (self.w - width) // 2
            y = 0 if side == 'n' else self.h - 1
            for x in range(start, start + width): self.g[y][x] = 'D'
        else:
            start = at if at is not None else (self.h - width) // 2
            x = 0 if side == 'w' else self.w - 1
            for y in range(start, start + width): self.g[y][x] = 'D'
        return self

    def dig_to(self, side, floor='.', width=3, at=None, walls='#', stop=None):
        """Carve from the opening on `side` straight in until the run meets a stop char (default: floor)."""
        stop = stop or {floor}
        if side in 'ns':
            start = at if at is not None else (self.w - width) // 2
            ys = range(1, self.h - 1) if side == 'n' else range(self.h - 2, 0, -1)
            for y in ys:
                row = [self.g[y][x] for x in range(start, start + width)]
                if any(c in stop for c in row) and y != (1 if side == 'n' else self.h - 2): break
                for x in range(start, start + width):
                    if self.g[y][x] in walls: self.g[y][x] = floor
        else:
            start = at if at is not None else (self.h - width) // 2
            xs = range(1, self.w - 1) if side == 'w' else range(self.w - 2, 0, -1)
            for x in xs:
                col = [self.g[y][x] for y in range(start, start + width)]
                if any(c in stop for c in col) and x != (1 if side == 'w' else self.w - 2): break
                for y in range(start, start + width):
                    if self.g[y][x] in walls: self.g[y][x] = floor
        return self

    def connect_regions(self, floor_chars, carve='.', walls='#', width=1):
        """Join every separate walkable region to the biggest by carving the shortest straight-ish tunnel."""
        while True:
            walk = {p for p in self.cells(lambda c: c in floor_chars or c == 'D')}
            regions = []; left = set(walk)
            while left:
                s = left.pop(); reg = {s}; q = [s]
                while q:
                    x, y = q.pop()
                    for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if n in left: left.discard(n); reg.add(n); q.append(n)
                regions.append(reg)
            if len(regions) <= 1: return
            regions.sort(key=len, reverse=True)
            main, small = regions[0], regions[1]
            best = min(((a, b) for a in self.rnd.sample(sorted(small), min(40, len(small)))
                        for b in self.rnd.sample(sorted(main), min(200, len(main)))),
                       key=lambda ab: abs(ab[0][0] - ab[1][0]) + abs(ab[0][1] - ab[1][1]))
            (ax, ay), (bx, by) = best
            before = sum(r.count(carve) for r in self.g)
            self.line(ax, ay, bx, ay, carve, width, only=set(walls), inner=True)
            self.line(bx, ay, bx, by, carve, width, only=set(walls), inner=True)
            if sum(r.count(carve) for r in self.g) == before:   # nothing carved: fall back to 1 wide
                self.line(ax, ay, bx, ay, carve, 1, only=set(walls), inner=True)
                self.line(bx, ay, bx, by, carve, 1, only=set(walls), inner=True)

    def seal_ring(self, wall='#'):
        for x in range(self.w):
            for y in (0, self.h - 1):
                if self.g[y][x] != 'D' and self.g[y][x] != ' ': self.g[y][x] = wall
        for y in range(self.h):
            for x in (0, self.w - 1):
                if self.g[y][x] != 'D' and self.g[y][x] != ' ': self.g[y][x] = wall

    def mirror_x(self):
        for y in range(self.h):
            for x in range(self.w // 2): self.g[y][self.w - 1 - x] = self.g[y][x]
    def mirror_y(self):
        for y in range(self.h // 2): self.g[self.h - 1 - y] = self.g[y][:]

    def rows(self): return [''.join(r) for r in self.g]


def art(s):
    """Multi-line string -> list of rows (strips a leading newline; pads rows to equal width with '#')."""
    lines = [l for l in s.strip('\n').split('\n')]
    w = max(len(l) for l in lines)
    return [l.ljust(w, '#') for l in lines]


def from_art(s, seed=0):
    rows = art(s); c = Canvas(len(rows[0]), len(rows), seed=seed)
    c.g = [list(r) for r in rows]; return c


# ================================================================ report
def report(biome):
    bad = 0
    for r in biome.rooms:
        p = r.problems()
        if p: bad += 1; print('  !! %s: %s' % (r.id, '; '.join(p[:4])))
    ids = [r.id for r in biome.rooms]
    dup = [i for i, n in collections.Counter(ids).items() if n > 1]
    if dup: print('  !! duplicate ids', dup); bad += 1
    kinds = collections.Counter()
    for r in biome.rooms:
        k = r.role if r.role in ('entrance', 'boss', 'corridor') else 'treasure' if 'treasure' in r.tags else \
            'maze' if 'maze' in r.tags else 'normal'
        kinds[k] += 1
    sp = sum(len(r.markers()[0]) for r in biome.rooms)
    print('%s: %d rooms %s, %d spawn cells, %d problem rooms' % (biome.name, len(biome.rooms), dict(kinds), sp, bad))
    return bad == 0
