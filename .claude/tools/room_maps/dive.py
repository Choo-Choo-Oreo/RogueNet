"""Format-2 port of DungeonAssembler.generate (Python RNG, so not seed-identical) plus a renderer,
for previewing a biome: python dive.py <biome> [seeds...] | --gallery <biome>"""
import sys, os, json, glob, random, collections
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import render_dungeon as rd
from PIL import Image, ImageDraw
from rb import TILES, ROOMS
T = 16
rd.FLOOR_ORDER = {n: d.get('sort_order', 5) for n, d in TILES.items()}
rd.FLOOR_ORDER['floor_void'] = 10
_sheets = {}; _rnd = random.Random(3)
def quarter(name, cell, q):
    if name not in _sheets:
        p = os.path.join(rd.GFX, 'tileset', name + '.png')
        im = Image.open(p).convert('RGBA') if os.path.exists(p) else Image.new('RGBA', (64, 64), (255, 0, 255, 255))
        n = im.height // 64; w = (TILES.get(name, {}).get('variant_weights') or [1] * n)[:n]
        _sheets[name] = (im, n, w + [1] * (n - len(w)))
    im, n, w = _sheets[name]
    v = _rnd.choices(range(n), w)[0] if n > 1 else 0
    x, y = cell[0] * 16 + q[0] * 8, v * 64 + cell[1] * 16 + q[1] * 8
    return im.crop((x, y, x + 8, y + 8))
rd.quarter = quarter
class _Shim:
    def __getattr__(self, k): return getattr(Image, k)
    def open(self, p):
        p = str(p).replace('Tortch.png', 'Torch.png')
        return Image.new('RGBA', (48, 16)) if p.endswith('Door.png') else Image.open(p)
rd.Image = _Shim()

N, S, E, W = 0, 1, 2, 3
OPP = {N: S, S: N, E: W, W: E}; STEP = {N: (0, -1), S: (0, 1), E: (1, 0), W: (-1, 0)}
def A(c): return (c['a']['x'], c['a']['y'])
def B(c): return (c['b']['x'], c['b']['y'])
def width(c): return max(B(c)[0] - A(c)[0], B(c)[1] - A(c)[1]) + 1
def cdir(r, p): return N if p[1] == 0 else S if p[1] == r['height'] - 1 else W if p[0] == 0 else E
def axis(d): return (1, 0) if d in (N, S) else (0, 1)

def rot(r):
    w, h = r['width'], r['height']; o = dict(r)
    for k in ('floor', 'walls'):
        g = [[None] * h for _ in range(w)]
        for y in range(h):
            for x in range(w): g[x][h - 1 - y] = r[k][y][x]
        o[k] = g
    def rc(c):
        a, b = (h - 1 - A(c)[1], A(c)[0]), (h - 1 - B(c)[1], B(c)[0])
        lo, hi = (min(a[0], b[0]), min(a[1], b[1])), (max(a[0], b[0]), max(a[1], b[1]))
        return dict(c, a={'x': lo[0], 'y': lo[1]}, b={'x': hi[0], 'y': hi[1]})
    o['connectors'] = [rc(c) for c in r['connectors']]
    pt = lambda p: {'x': h - 1 - p['y'], 'y': p['x']}
    o['spawn_cells'] = [dict(s, position=pt(s['position'])) for s in r.get('spawn_cells', [])]
    o['antagonist_spawns'] = [dict(s, position=pt(s['position'])) for s in r.get('antagonist_spawns', [])]
    o['objects'] = [dict(ob, position={'x': h * T - ob['position']['y'], 'y': ob['position']['x']}) for ob in r.get('objects', [])]
    o['width'], o['height'] = h, w
    return o

def load(biome, extra=None):
    base = {}
    for f in sorted(glob.glob(os.path.join(ROOMS, biome, '*.json'))):
        if os.path.basename(f) == 'defines.json': continue
        r = json.load(open(f)); r['base'] = r['id']; base[r['id']] = r
    for r in extra or []: r['base'] = r['id']; base[r['id']] = r
    out = dict(base)
    for i, r in base.items():
        if r.get('role', 'normal') == 'entrance': continue
        v = r; seen = {json.dumps([r['floor'], r['walls'], r['connectors']])}
        for t in (1, 2, 3):
            v = rot(v); sig = json.dumps([v['floor'], v['walls'], v['connectors']])
            if sig in seen: continue
            seen.add(sig); out['%s#r%d' % (i, t)] = dict(v, id='%s#r%d' % (i, t))
    try: defines = json.load(open(os.path.join(ROOMS, biome, 'defines.json')))
    except Exception: defines = {}
    return base, out, defines

def shifts(fr, cr):
    fw, cw = width(fr), width(cr)
    if not (fr.get('free') or cr.get('free')): return [0] if fw == cw else []
    out = []
    for s in [(fw - cw) // 2, 0, fw - cw]:
        if s not in out: out.append(s)
    return out

def conn_at(r, a):
    for c in r['connectors']:
        if A(c) == a: return c
    return {'a': {'x': a[0], 'y': a[1]}, 'b': {'x': a[0], 'y': a[1]}}

def overlaps(a, occ):
    return any(a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3] for b in occ)

def weight(r, tw):
    w = tw.get(r.get('role', 'normal'), 1.0)
    for t in r.get('tags', []): w *= tw.get(t, 1.0)
    return max(w, 0.0001)

def place(rooms, cid, conn_order, P, pi, lp, occ):
    fp = P[pi]; fr_room = rooms[fp['id']]; d = cdir(fr_room, lp); need = OPP[d]
    ax = axis(d); tc = (fp['off'][0] + lp[0] + STEP[d][0], fp['off'][1] + lp[1] + STEP[d][1])
    fr = conn_at(fr_room, lp); r = rooms[cid]
    for c in conn_order:
        la = A(c)
        if cdir(r, la) != need: continue
        for s in shifts(fr, c):
            off = (tc[0] + ax[0] * s - la[0], tc[1] + ax[1] * s - la[1])
            rect = (off[0], off[1], r['width'], r['height'])
            if overlaps(rect, occ): continue
            lo, hi = max(0, s), min(width(fr) - 1, s + width(c) - 1)
            joint = [(fp['off'][0] + lp[0] + ax[0] * i + STEP[d][0], fp['off'][1] + lp[1] + ax[1] * i + STEP[d][1])
                     for i in range(lo, hi + 1)]
            p = {'id': cid, 'off': off, 'depth': fp['depth'] + 1, 'locked': [], 'used': la, 'parent': pi, 'joint': joint,
                 'from_joint': [(lp[0] + ax[0] * i, lp[1] + ax[1] * i) for i in range(lo, hi + 1)]}
            fp.setdefault('joints', {})[lp] = p['from_joint']
            P.append(p); occ.append(rect); return p
    return None

def generate(rooms, seed, defines):
    rng = random.Random(seed)
    rc = defines.get('room_count', {}); target = rng.randint(rc.get('min', 20), rc.get('max', 30))
    tw = defines.get('tag_weights', {})
    ent, boss, tre, pool, cor = [], [], [], [], []
    for i in sorted(rooms):
        r = rooms[i]; role = r.get('role', 'normal')
        if role == 'entrance': ent.append(i)
        elif role == 'boss': boss.append(i)
        elif 'treasure' in r.get('tags', []): tre.append(i)
        else:
            pool.append(i)
            if role == 'corridor': cor.append(i)
    e = rng.choice(ent); er = rooms[e]
    P = [{'id': e, 'off': (-(er['width'] // 2), -(er['height'] // 2)), 'depth': 0, 'locked': [], 'used': None, 'parent': None, 'joint': []}]
    occ = [(P[0]['off'][0], P[0]['off'][1], er['width'], er['height'])]
    sortc = lambda r: sorted(r['connectors'], key=lambda c: (A(c)[1], A(c)[0]))
    q = [(0, A(c)) for c in sortc(er)]; rng.shuffle(q)
    keep = []; rem = tot = len(q); removed = 0
    for en in q:
        if rem <= 1: keep.append(en); continue
        if rng.random() < (removed + 1) / tot: P[0]['locked'].append(en[1]); removed += 1; rem -= 1
        else: keep.append(en)
    q = keep; budget = max(target - 2, 1)
    while q and len(P) < budget:
        pi, lp = q.pop(0); avoid = len(P) < budget - 3
        ids = sorted(pool, key=lambda i: -(rng.random() ** (1 / weight(rooms[i], tw))))
        if avoid: ids = [i for i in ids if len(rooms[i]['connectors']) > 1] + [i for i in ids if len(rooms[i]['connectors']) <= 1]
        placed = None
        for cid in ids:
            cs = list(rooms[cid]['connectors']); rng.shuffle(cs)
            placed = place(rooms, cid, cs, P, pi, lp, occ)
            if placed:
                for c in sortc(rooms[cid]):
                    if A(c) != placed['used']: q.append((len(P) - 1, A(c)))
                break
        if not placed: P[pi]['locked'].append(lp)
    for pi, lp in q: P[pi]['locked'].append(lp)

    def place_locked(rid, pi, lp):
        n = place(rooms, rid, sortc(rooms[rid]), P, pi, lp, occ)
        if n:
            P[pi]['locked'].remove(lp); n['locked'] = [A(c) for c in sortc(rooms[rid]) if A(c) != n['used']]
        return n
    got_boss = not boss
    if boss:
        order = [rng.choice(boss)]; order += [b for b in boss if b not in order]
        for b in order:
            cands = sorted(((p['depth'], i, lp) for i, p in enumerate(P) for lp in p['locked']), key=lambda t: -t[0])
            for _, i, lp in cands:
                if place_locked(b, i, lp): got_boss = True; break
            if not got_boss:
                for _, i, lp in cands:
                    if lp not in P[i]['locked']: continue
                    cur, cl = i, lp
                    for _x in range(8):
                        if place_locked(b, cur, cl): got_boss = True; break
                        nxt = None
                        for c in cor:
                            nxt = place_locked(c, cur, cl)
                            if nxt: break
                        if not nxt or not nxt['locked']: break
                        cur, cl = len(P) - 1, nxt['locked'][0]
                    if got_boss: break
            if got_boss: break
    got_t = not tre
    for i in range(len(P)):
        for lp in list(P[i]['locked']):
            if any(place_locked(t, i, lp) for t in tre): got_t = True; break
        if got_t: break
    return P, got_boss and got_t, target

def dominant(grid):
    c = collections.Counter(t for row in grid for t in row if t)
    return min(c, key=lambda k: (-c[k], k)) if c else 'floor_void'

def paint(rooms, P, defines=None):
    floor = {}; wall = {}; objects = []; spawns = []
    for p in P:
        r = rooms[p['id']]; ox, oy = p['off']
        base = r.get('base_floor') or dominant(r['floor'])
        for y in range(r['height']):
            for x in range(r['width']):
                f = r['floor'][y][x]; w = r['walls'][y][x]; pos = (ox + x, oy + y)
                if f: floor[pos] = f
                elif w: floor[pos] = base
                if w: wall[pos] = w
        joints = dict(p.get('joints', {}))
        if p['used']: joints[p['used']] = None
        dw = dominant(r['walls'])
        for c in r['connectors']:
            a, b = A(c), B(c)
            cells = [(a[0] + i * (b[0] > a[0]), a[1] + i * (b[1] > a[1])) for i in range(width(c))]
            open_cells = set(cells) if a in joints and joints[a] is None else set(joints.get(a, []))
            if a == p['used']:   # cells of the joining run outside the overlap get walled
                ov = len(p['joint']); open_cells = set(cells)   # approximate: keep whole run open
            for cell in cells:
                pos = (ox + cell[0], oy + cell[1])
                if cell in open_cells: floor[pos] = r['floor'][cell[1]][cell[0]] or base
                else: wall[pos] = dw
        for ob in r.get('objects', []): objects.append((ob['type'], ox * T + ob['position']['x'], oy * T + ob['position']['y']))
        for s in r.get('spawn_cells', []): spawns.append((ox + s['position']['x'], oy + s['position']['y'], s.get('minion')))
        for s in r.get('antagonist_spawns', []): spawns.append((ox + s['position']['x'], oy + s['position']['y'], 'BOSS'))
    xs = [k[0] for k in floor] + [k[0] for k in wall]; ys = [k[1] for k in floor] + [k[1] for k in wall]
    bounds = (min(xs) - 2, min(ys) - 2, max(xs) + 2, max(ys) + 2)
    for y in range(bounds[1], bounds[3] + 1):
        for x in range(bounds[0], bounds[2] + 1): floor.setdefault((x, y), 'floor_void')
    return floor, wall, objects, spawns, bounds

SP_COL = {'BOSS': (255, 40, 40), None: (255, 230, 60)}
def render(floor, wall, objects, spawns, bounds, marks=True):
    img = rd.render(floor, wall, {}, objects, bounds, True)
    for kind, px, py in objects:
        pp = os.path.join(rd.GFX, 'objects', 'props', kind.capitalize() + '.png')
        if os.path.exists(pp):
            spr = Image.open(pp).convert('RGBA').crop((0, 0, 16, 16))
            img.alpha_composite(spr, (int(px) - bounds[0] * T - 8 + 8, int(py) - bounds[1] * T - 8 + 8))
    if marks:
        d = ImageDraw.Draw(img); x0, y0 = bounds[0], bounds[1]
        for x, y, m in spawns:
            px, py = (x - x0) * T + 8, (y - y0) * T + 8
            col = SP_COL.get(m, (255, 120, 220))
            r = 6 if m == 'BOSS' else 3
            d.ellipse((px + 8 - r, py + 8 - r, px + 8 + r, py + 8 + r), outline=col, width=2)
    return img

def gallery(base, width=3000, scale=1):
    tiles = []
    for rid in sorted(base):
        r = base[rid]; P = [{'id': rid, 'off': (0, 0), 'depth': 0, 'locked': [], 'used': None, 'parent': None, 'joint': []}]
        fl, wl, ob, sp, bd = paint({rid: r}, P)
        for c in r['connectors']:    # all openings open
            a, b = A(c), B(c)
            for i in range(width_(c)):
                cell = (a[0] + i * (b[0] > a[0]), a[1] + i * (b[1] > a[1])); wl.pop(cell, None)
                fl[cell] = r['floor'][cell[1]][cell[0]] or r.get('base_floor') or dominant(r['floor'])
        im = render(fl, wl, ob, sp, bd)
        if scale != 1: im = im.resize((im.width // scale, im.height // scale), Image.LANCZOS)
        tiles.append((rid, im))
    x = y = 0; row_h = 0; spots = []
    width = max(width, max(im.width for _, im in tiles))
    for rid, im in tiles:
        if x and x + im.width > width: x = 0; y += row_h + 24; row_h = 0
        spots.append((rid, im, x, y)); x += im.width + 12; row_h = max(row_h, im.height)
    sheet = Image.new('RGB', (width, y + row_h + 24), (24, 24, 28)); d = ImageDraw.Draw(sheet)
    for rid, im, px, py in spots:
        sheet.paste(im.convert('RGB'), (px, py + 14)); d.text((px + 2, py + 1), rid, fill=(255, 255, 255))
    return sheet
width_ = width

def key_map(rooms, P, bounds, scale=4):
    x0, y0, x1, y1 = bounds
    img = Image.new('RGB', ((x1 - x0 + 2) * scale, (y1 - y0 + 2) * scale), (12, 12, 14)); d = ImageDraw.Draw(img)
    col = {'entrance': (70, 200, 90), 'boss': (230, 60, 60), 'corridor': (110, 110, 125), 'normal': (70, 110, 170)}
    cen = lambda p: ((p['off'][0] - x0 + rooms[p['id']]['width'] / 2) * scale, (p['off'][1] - y0 + rooms[p['id']]['height'] / 2) * scale)
    for p in P:
        r = rooms[p['id']]; c = col.get(r.get('role', 'normal'))
        if 'treasure' in r.get('tags', []): c = (225, 185, 60)
        if 'maze' in r.get('tags', []): c = (140, 90, 170)
        bx, by = (p['off'][0] - x0) * scale, (p['off'][1] - y0) * scale
        d.rectangle((bx, by, bx + r['width'] * scale - 1, by + r['height'] * scale - 1), fill=c, outline=(0, 0, 0))
    for p in P:
        if p['parent'] is not None: d.line((cen(P[p['parent']]), cen(p)), fill=(235, 235, 235), width=1)
    for p in P:
        d.text(((p['off'][0] - x0) * scale + 2, (p['off'][1] - y0) * scale + 1), p['id'].split('_', 1)[1][:22], fill=(255, 255, 255))
    return img

def dive(biome, seed, out, extra=None, scale=1):
    base, rooms, defines = load(biome, extra)
    for a in range(20):
        P, ok, target = generate(rooms, seed + a, defines)
        if ok: break
    painted = paint(rooms, P)
    img = render(*painted)
    if scale != 1: img = img.resize((img.width // scale, img.height // scale), Image.LANCZOS)
    img.convert('RGB').save(out + '.png'); key_map(rooms, P, painted[4]).save(out + '_key.png')
    kinds = collections.Counter(('corridor' if rooms[p['id']].get('role') == 'corridor' else
                                 'maze' if 'maze' in rooms[p['id']].get('tags', []) else rooms[p['id']].get('role', 'normal')) for p in P)
    tiles = sum(rooms[p['id']]['width'] * rooms[p['id']]['height'] for p in P)
    print('%s seed %d: %d/%d rooms ok=%s %s, %d room tiles, %d spawns, image %dx%d' % (
        biome, seed, len(P), target, ok, dict(kinds), tiles, len([s for s in painted[3] if s[2] != 'BOSS']), img.width, img.height))
    return P, rooms

if __name__ == '__main__':
    if sys.argv[1] == '--gallery':
        base, _, _ = load(sys.argv[2]); sc = int(sys.argv[3]) if len(sys.argv) > 3 else 1
        gallery(base, scale=sc).save('gal_%s.png' % sys.argv[2]); print('ok')
    else:
        for s in sys.argv[2:] or ['1']: dive(sys.argv[1], int(s), 'dive_%s_%s' % (sys.argv[1], s))
