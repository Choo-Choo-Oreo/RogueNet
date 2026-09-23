# Renders a generated dungeon (or a gallery of every room in a biome) to a PNG at full 16px-per-tile detail.
#
#   python render_dungeon.py cathedral                  one random dungeon from game/rooms/cathedral/
#   python render_dungeon.py mine --seed 42             repeatable
#   python render_dungeon.py flesh --every-room         force every room of the biome into one connected map
#   python render_dungeon.py cave --gallery             contact sheet: each room on its own, with its name
#   add --objects to draw torches/chests (the game itself does not spawn them yet), --out DIR to pick a folder
#
# This is a Python copy of DungeonAssembler.generate() + DungeonPainter._paint() + DualGridRender.
# Same rules, DIFFERENT dice: Python's random is not Godot's RandomNumberGenerator, so seed N here is
# not the dungeon seed N builds in the game. Art is drawn unlit (no torch light, no normal maps).
import argparse, collections, copy, glob, json, os, random, sys, time
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ROOMS = os.path.join(REPO, 'game', 'rooms')
GFX = os.path.join(REPO, 'resources', 'gfx')
T = 16
N, S, E, W = 0, 1, 2, 3
OPP = {N: S, S: N, E: W, W: E}
STEP = {N: (0, -1), S: (0, 1), E: (1, 0), W: (-1, 0)}
MASK_TO_CELL = {1: (3, 3), 2: (0, 2), 3: (1, 2), 4: (0, 0), 5: (3, 2), 6: (2, 3), 7: (3, 1), 8: (1, 3),
                9: (0, 1), 10: (1, 0), 11: (2, 2), 12: (3, 0), 13: (2, 0), 14: (1, 1), 15: (2, 1)}
# draw order = TileType.sort_order, ties broken by name (the order TileInitialize creates the layers in)
FLOOR_ORDER = {'floor_smooth_stone': 1, 'floor_wood_planks': 1, 'floor_dirt': 2, 'floor_grass': 3, 'floor_flesh': 4, 'floor_void': 10}
VOID_PADDING = 2

# ---------------------------------------------------------------- assembler (port of DungeonAssembler.gd)
def cdir(r, p): return N if p[1] == 0 else S if p[1] == r['height'] - 1 else W if p[0] == 0 else E

def rot(r):
    w, h = r['width'], r['height']; o = dict(r)
    for k in ('floor', 'walls'):
        g = [[None] * h for _ in range(w)]
        for y in range(h):
            for x in range(w): g[x][h - 1 - y] = r[k][y][x]
        o[k] = g
    o['connectors'] = [{'position': {'x': h - 1 - c['position']['y'], 'y': c['position']['x']}} for c in r['connectors']]
    # the game's rotate_room() leaves objects alone; they are rotated here so --objects looks right
    o['objects'] = [dict(ob, position={'x': h * T - ob['position']['y'], 'y': ob['position']['x']}) for ob in r.get('objects', [])]
    o['width'], o['height'] = h, w
    return o

def load(biome):
    base = {}
    for f in sorted(glob.glob(os.path.join(ROOMS, biome, '*.json'))):
        if os.path.basename(f) == 'defines.json':
            continue
        r = json.load(open(f)); r['base'] = r['id']; base[r['id']] = r
    out = dict(base)
    for i, r in base.items():
        if r.get('role', 'normal') in ('entrance', 'boss'): continue
        seen = {json.dumps([r['floor'], r['walls'], r['connectors']])}; v = r
        for t in (1, 2, 3):
            v = rot(v); sig = json.dumps([v['floor'], v['walls'], v['connectors']])
            if sig in seen: continue
            seen.add(sig); v2 = dict(v); v2['id'] = '%s#r%d' % (i, t); out[v2['id']] = v2
    return base, out

def conns(r): return sorted(((c['position']['x'], c['position']['y']) for c in r['connectors']), key=lambda p: (p[1], p[0]))

def overlaps(a, occ):
    return any(a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3] for b in occ)

def fit(rooms, rid, P, pi, lp, occ, order=None):
    fp = P[pi]; d = cdir(rooms[fp['id']], lp); need = OPP[d]
    tc = (fp['off'][0] + lp[0] + STEP[d][0], fp['off'][1] + lp[1] + STEP[d][1]); r = rooms[rid]
    for c in (order or conns(r)):
        if cdir(r, c) != need: continue
        off = (tc[0] - c[0], tc[1] - c[1]); rect = (off[0], off[1], r['width'], r['height'])
        if overlaps(rect, occ): continue
        p = {'id': rid, 'off': off, 'depth': fp['depth'] + 1, 'locked': [], 'used': c, 'parent': pi, 'via': lp}
        P.append(p); occ.append(rect); return p
    return None

def generate(rooms, seed, every_room=False):
    rng = random.Random(seed); target = rng.randint(20, 30)
    ent = boss = None; tre = []; pool = []; cor = []
    for i in sorted(rooms):
        r = rooms[i]; role = r.get('role', 'normal')
        if role == 'entrance': ent = i
        elif role == 'boss': boss = i
        elif 'treasure' in r.get('tags', []): tre.append(i)
        else:
            pool.append(i)
            if role == 'corridor': cor.append(i)
    if ent is None: sys.exit('no entrance room in this biome')
    if every_room: target = max(target, len({rooms[i]['base'] for i in pool}) + 8)
    er = rooms[ent]
    P = [{'id': ent, 'off': (-(er['width'] // 2), -(er['height'] // 2)), 'depth': 0, 'locked': [], 'used': None, 'parent': None, 'via': None}]
    occ = [(P[0]['off'][0], P[0]['off'][1], er['width'], er['height'])]
    q = [(0, c) for c in conns(er)]; rng.shuffle(q)
    keep = []; rem = tot = len(q); removed = 0
    for e in q:
        if rem <= 1: keep.append(e); continue
        if rng.random() < (removed + 1) / tot: P[0]['locked'].append(e[1]); removed += 1; rem -= 1
        else: keep.append(e)
    q = keep; budget = max(target - 2, 1); used_bases = set()
    while q and len(P) < budget:
        pi, lp = q.pop(0); avoid = len(P) < budget - 3
        ids = pool[:]; rng.shuffle(ids)
        if avoid: ids = [i for i in ids if len(rooms[i]['connectors']) > 1] + [i for i in ids if len(rooms[i]['connectors']) <= 1]
        if every_room: ids.sort(key=lambda i: rooms[i]['base'] in used_bases)   # not in the game: unused rooms first
        placed = None
        for cid in ids:
            cs = conns(rooms[cid]); rng.shuffle(cs)
            placed = fit(rooms, cid, P, pi, lp, occ, cs)
            if placed:
                used_bases.add(rooms[cid]['base'])
                for c in conns(rooms[cid]):
                    if c != placed['used']: q.append((len(P) - 1, c))
                break
        if not placed: P[pi]['locked'].append(lp)
    for pi, lp in q: P[pi]['locked'].append(lp)

    def place_locked(rid, pi, lp):
        n = fit(rooms, rid, P, pi, lp, occ)
        if n:
            P[pi]['locked'].remove(lp); n['locked'] = [c for c in conns(rooms[rid]) if c != n['used']]
        return n
    got_boss = boss is None
    if boss:
        cands = sorted(((p['depth'], i, lp) for i, p in enumerate(P) for lp in p['locked']), key=lambda t: -t[0])
        for _, i, lp in cands:
            if place_locked(boss, i, lp): got_boss = True; break
        if not got_boss:
            for _, i, lp in cands:
                if lp not in P[i]['locked']: continue
                cur, cl = i, lp
                for _ext in range(8):
                    if place_locked(boss, cur, cl): got_boss = True; break
                    nxt = None
                    for c in cor:
                        nxt = place_locked(c, cur, cl)
                        if nxt: break
                    if not nxt or not nxt['locked']: break
                    cur, cl = len(P) - 1, nxt['locked'][0]
                if got_boss: break
    got_t = not tre
    for i in range(len(P)):
        for lp in list(P[i]['locked']):
            if any(place_locked(t, i, lp) for t in tre): got_t = True; break
        if got_t: break
    return P, got_boss and got_t

def generate_with_retry(rooms, seed, every_room):
    for attempt in range(20):
        P, ok = generate(rooms, seed + attempt, every_room)
        if ok: return P
    return generate(rooms, seed, every_room)[0]

# ---------------------------------------------------------------- painter (port of DungeonPainter._paint)
def dominant(grid, skip):
    c = collections.Counter(t for row in grid for t in row if t and t != skip)
    return min(c, key=lambda k: (-c[k], k)) if c else ''

def paint(rooms, P, all_doors_open=False):
    floor = {}; wall = {}; door_dir = {}; objects = []
    for p in P:
        r = rooms[p['id']]; ox, oy = p['off']
        locked = set() if all_doors_open else set(p['locked']); sup = {p['used']} if p['used'] else set()
        sealed = dominant(r['walls'], 'wall_door'); ftile = dominant(r['floor'], None)
        for y in range(r['height']):
            for x in range(r['width']):
                f = r['floor'][y][x]; w = r['walls'][y][x]; pos = (ox + x, oy + y)
                if f: floor[pos] = f
                elif w: floor[pos] = ftile
                if w == 'wall_door':
                    if (x, y) in sup: w = None
                    elif (x, y) in locked: w = sealed
                    else: w = 'wall_door_open'; door_dir[pos] = cdir(r, (x, y))
                if w: wall[pos] = w
        for c in conns(r): floor[(ox + c[0], oy + c[1])] = ftile
        for ob in r.get('objects', []): objects.append((ob['type'], ox * T + ob['position']['x'], oy * T + ob['position']['y']))
    xs = [k[0] for k in floor] + [k[0] for k in wall]; ys = [k[1] for k in floor] + [k[1] for k in wall]
    x0, x1, y0, y1 = min(xs) - VOID_PADDING, max(xs) + VOID_PADDING, min(ys) - VOID_PADDING, max(ys) + VOID_PADDING
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): floor.setdefault((x, y), 'floor_void')
    return floor, wall, door_dir, objects, (x0, y0, x1, y1)

# ---------------------------------------------------------------- renderer (port of DualGridRender / StaticTileRender)
_quarters = {}
def quarter(name, cell, q):
    key = (name, cell, q)
    if key not in _quarters:
        if name not in _quarters:
            _quarters[name] = Image.open(os.path.join(GFX, 'tileset', name + '.png')).convert('RGBA')
        x, y = cell[0] * T + q[0] * 8, cell[1] * T + q[1] * 8
        _quarters[key] = _quarters[name].crop((x, y, x + 8, y + 8))
    return _quarters[key]

def render(floor, wall, door_dir, objects, bounds, show_objects):
    x0, y0, x1, y1 = bounds
    img = Image.new('RGBA', ((x1 - x0 + 2) * T, (y1 - y0 + 2) * T), (0, 0, 0, 255))
    def to_px(x, y): return ((x - x0) * T + T // 2, (y - y0) * T + T // 2)   # display layer sits half a tile in
    def draw_layer(name, cells, filled, clip):
        touched = {(x + dx, y + dy) for (x, y) in cells for dx in (0, -1) for dy in (0, -1)}
        for (x, y) in touched:
            nb = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            mask = sum(1 << k for k in range(4) if filled(nb[k]))
            if not mask: continue
            c = MASK_TO_CELL[mask]; px, py = to_px(x, y)
            for k in range(4):
                if clip and wall.get(nb[k]) != name: continue
                q = (k & 1, k >> 1)
                img.alpha_composite(quarter(name, c, q), (px + q[0] * 8, py + q[1] * 8))
    by_floor = collections.defaultdict(list)
    for pos, n in floor.items(): by_floor[n].append(pos)
    for name in sorted(by_floor, key=lambda n: (FLOOR_ORDER.get(n, 5), n)):
        draw_layer(name, by_floor[name], lambda p, name=name: floor.get(p) == name, False)
    dual = {n for n in wall.values() if not n.startswith('wall_door')}
    def wall_filled(p):                                # a wall-group tile, or nothing at all (void) counts as wall
        w = wall.get(p)
        if w is not None: return w in dual
        return floor.get(p) in (None, 'floor_void')
    by_wall = collections.defaultdict(list)
    for pos, n in wall.items(): by_wall[n].append(pos)
    for name in sorted(dual): draw_layer(name, by_wall[name], wall_filled, True)
    door = Image.open(os.path.join(GFX, 'objects', 'Door.png')).convert('RGBA').crop((2 * T, 0, 3 * T, T))
    turned = {S: door, W: door.rotate(-90), N: door.rotate(180), E: door.rotate(90)}
    for pos in by_wall.get('wall_door_open', []):
        img.alpha_composite(turned[door_dir[pos]], ((pos[0] - x0) * T, (pos[1] - y0) * T))
    if show_objects:
        art = {'torch': 'Tortch.png', 'chest': 'Chest_Wood.png'}
        spr = {k: Image.open(os.path.join(GFX, 'objects', v)).convert('RGBA').crop((0, 0, T, T)) for k, v in art.items()}
        for kind, px, py in objects:
            if kind in spr: img.alpha_composite(spr[kind], (int(px) - x0 * T - 8, int(py) - y0 * T - 8))
    return img

# ---------------------------------------------------------------- key map: names, depth and the route to the boss
ROLE_COL = {'entrance': (70, 200, 90), 'boss': (230, 60, 60), 'corridor': (110, 110, 125), 'normal': (70, 110, 170)}
def key_map(rooms, P, bounds, scale=6):
    x0, y0, x1, y1 = bounds
    img = Image.new('RGB', ((x1 - x0 + 2) * scale, (y1 - y0 + 2) * scale), (12, 12, 14)); d = ImageDraw.Draw(img)
    def centre(p):
        r = rooms[p['id']]; return ((p['off'][0] - x0 + r['width'] / 2) * scale, (p['off'][1] - y0 + r['height'] / 2) * scale)
    for p in P:
        r = rooms[p['id']]; col = ROLE_COL.get(r.get('role', 'normal'), ROLE_COL['normal'])
        if 'treasure' in r.get('tags', []): col = (225, 185, 60)
        if '_Maze_' in p['id']: col = (140, 90, 170)
        bx, by = (p['off'][0] - x0) * scale, (p['off'][1] - y0) * scale
        d.rectangle((bx, by, bx + r['width'] * scale - 1, by + r['height'] * scale - 1), fill=col, outline=(0, 0, 0))
    for p in P:
        if p['parent'] is not None: d.line((centre(P[p['parent']]), centre(p)), fill=(235, 235, 235), width=1)
    boss = next((p for p in P if rooms[p['id']].get('role') == 'boss'), None)
    while boss and boss['parent'] is not None:                       # entrance -> boss route, drawn thick
        d.line((centre(P[boss['parent']]), centre(boss)), fill=(255, 235, 0), width=3); boss = P[boss['parent']]
    for p in P:
        r = rooms[p['id']]; name = r['base'].split('_', 1)[-1].rsplit('_', 1)[0]
        d.text(((p['off'][0] - x0) * scale + 2, (p['off'][1] - y0) * scale + 1), '%d %s' % (p['depth'], name), fill=(255, 255, 255))
    return img

def gallery(base, show_objects):
    tiles = []
    for rid in sorted(base):
        r = base[rid]; rooms = {rid: r}
        P = [{'id': rid, 'off': (0, 0), 'depth': 0, 'locked': [], 'used': None, 'parent': None, 'via': None}]
        tiles.append((rid, render(*paint(rooms, P, all_doors_open=True), show_objects)))
    width = 2400; x = y = 0; row_h = 0; spots = []
    for rid, im in tiles:
        if x and x + im.width > width: x = 0; y += row_h + 24; row_h = 0
        spots.append((rid, im, x, y)); x += im.width + 12; row_h = max(row_h, im.height)
    sheet = Image.new('RGB', (max(width, max(im.width for _, im in tiles)), y + row_h + 24), (24, 24, 28)); d = ImageDraw.Draw(sheet)
    for rid, im, px, py in spots:
        sheet.paste(im.convert('RGB'), (px, py + 14)); d.text((px + 2, py + 1), rid, fill=(255, 255, 255))
    return sheet

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description='Render a generated RogueNet dungeon to PNG.')
    ap.add_argument('biome'); ap.add_argument('--seed', type=int); ap.add_argument('--every-room', action='store_true')
    ap.add_argument('--gallery', action='store_true'); ap.add_argument('--objects', action='store_true'); ap.add_argument('--out', default='.')
    a = ap.parse_args(); t0 = time.time()
    base, rooms = load(a.biome)
    if not base: sys.exit('no rooms in ' + os.path.join(ROOMS, a.biome))
    if a.gallery:
        path = os.path.join(a.out, 'rooms_%s_gallery.png' % a.biome); gallery(base, a.objects).save(path)
        print('%d rooms -> %s' % (len(base), path)); sys.exit()
    seed = a.seed if a.seed is not None else random.randrange(1 << 31)
    P = generate_with_retry(rooms, seed, a.every_room)
    painted = paint(rooms, P)
    stem = os.path.join(a.out, 'dungeon_%s_%d%s' % (a.biome, seed, '_every' if a.every_room else ''))
    img = render(*painted, a.objects); img.save(stem + '.png'); key_map(rooms, P, painted[4]).save(stem + '_key.png')
    used = {rooms[p['id']]['base'] for p in P}
    print('%d rooms placed, %d of %d designs used, %dx%d px, %.1fs' % (len(P), len(used), len(base), img.width, img.height, time.time() - t0))
    if a.every_room and len(used) < len(base): print('never fitted:', ', '.join(sorted(set(base) - used)))
    print(stem + '.png\n' + stem + '_key.png')
