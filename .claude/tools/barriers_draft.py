"""Draft generator for barrier_bedrock and barrier_forest_dense.

Geometry (which pixels are transparent / black top / rim / south face) is borrowed
from an existing wall atlas so the dual-grid pieces are guaranteed to line up.
Only the colours and the face/canopy textures are new.
"""
import random, sys
from PIL import Image

ROOT = "C:/Users/Orea/Documents/Project-Godot/RogueNet/"
ART = ROOT + "resources/gfx/tileset/"
OUT = (sys.argv[1].rstrip("/") + "/") if len(sys.argv) > 1 else ART
T, Q = 16, 8
MASK_TO_CELL = {1: (3, 3), 2: (0, 2), 3: (1, 2), 4: (0, 0), 5: (3, 2), 6: (2, 3), 7: (3, 1), 8: (1, 3),
                9: (0, 1), 10: (1, 0), 11: (2, 2), 12: (3, 0), 13: (2, 0), 14: (1, 1), 15: (2, 1)}
CELL_TO_MASK = {v: k for k, v in MASK_TO_CELL.items()}

def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

def quarter_roles(mask):
    """For each quarter (k = TL,TR,BL,BR) return 'face' (floor below it inside the cell),
    'top' (filled) or None (empty)."""
    filled = [bool(mask >> k & 1) for k in range(4)]
    roles = [None] * 4
    for k in range(4):
        if not filled[k]:
            continue
        below = k + 2 if k < 2 else None
        roles[k] = "face" if (below is not None and not filled[below]) else "top"
    return roles

def role_at(mask, x, y):
    k = (x // Q) + 2 * (y // Q)
    return quarter_roles(mask)[k]

# ---------------- bedrock ----------------

BED = {  # dark, cool, heavy. 5 colours + pure black top.
    "crack": hexc("#15131b"),
    "deep":  hexc("#26232e"),
    "base":  hexc("#38343f"),
    "lit":   hexc("#4b4654"),
    "edge":  hexc("#5f5967"),
}

def bedrock_face(seed):
    """16x8 seamless (in x) strip of big dark slabs with thin cracks."""
    rnd = random.Random(seed)
    strip = [[BED["base"]] * T for _ in range(Q)]
    # two slab rows, 3 and 5 tall, with vertical cracks at offset positions
    rows = [(0, 3), (3, 8)]
    for i, (y0, y1) in enumerate(rows):
        cracks = sorted(rnd.sample(range(T), 2)) if i == 0 else sorted(rnd.sample(range(T), 2))
        for y in range(y0, y1):
            for x in range(T):
                c = BED["base"]
                if y == y0 and i > 0:
                    c = BED["crack"]            # horizontal seam between slabs
                elif y == y0 + 1 or (i == 0 and y == 0):
                    c = BED["edge"]             # light catches the slab's upper lip
                elif y == y1 - 1:
                    c = BED["deep"]             # underside shadow
                if x in cracks and y > y0:
                    c = BED["crack"]
                elif (x - 1) in cracks and y > y0 + 1 and rnd.random() < 0.6:
                    c = BED["deep"]
                strip[y][x] = c
    # a few chips so it isn't perfectly regular
    for _ in range(3):
        x, y = rnd.randrange(T), rnd.randrange(1, Q)
        if strip[y][x] == BED["base"]:
            strip[y][x] = BED["deep"]
    return strip

def build_bedrock():
    src = Image.open(ART + "wall_rough_cave.png").convert("RGBA")
    px = src.load()
    # rank the cave's face colours by brightness and map them to the bedrock palette
    cave_cols = sorted({px[x, y][:3] for y in range(64) for x in range(64)
                        if px[x, y][3] and sum(px[x, y][:3]) >= 12}, key=sum)
    ramp = [BED["crack"], BED["deep"], BED["deep"], BED["base"], BED["lit"], BED["edge"]]
    rim_map = {c: ramp[min(len(ramp) - 1, i * len(ramp) // len(cave_cols))] for i, c in enumerate(cave_cols)}
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); op = out.load()
    face = bedrock_face(7)
    for cy in range(4):
        for cx in range(4):
            mask = CELL_TO_MASK.get((cx, cy), 0)
            for y in range(T):
                for x in range(T):
                    p = px[cx * T + x, cy * T + y]
                    if p[3] == 0:
                        continue
                    if sum(p[:3]) < 12:
                        op[cx * T + x, cy * T + y] = (0, 0, 0, 255); continue
                    if role_at(mask, x, y) == "face":
                        op[cx * T + x, cy * T + y] = face[y % Q][x]
                    else:
                        op[cx * T + x, cy * T + y] = rim_map[p[:3]]
    return out

# ---------------- dense forest ----------------

FOR = {  # canopy: gap + 3 greens. trunks: gap + 3 browns. 7 colours, the dark one shared.
    "gap":     hexc("#0c0916"),   # shared with wall_forest so the two blend
    "shade":   hexc("#0f2419"),
    "leaf":    hexc("#1b3f28"),
    "glint":   hexc("#2f6540"),
    "bark":    hexc("#2b1c14"),
    "barkmid": hexc("#3a2719"),
    "barklit": hexc("#4a3222"),
}

def canopy_tile(seed):
    """Seamless 16x16 canopy: many small round crowns packed tight, drawn back to front.
    (The lumpy version Orea preferred, 2026-09-22.)"""
    rnd = random.Random(seed)
    tile = [[FOR["gap"]] * T for _ in range(T)]
    crowns = []
    for gy in range(0, T, 4):
        for gx in range(0, T, 4):
            crowns.append((gx + rnd.randrange(-1, 2), gy + rnd.randrange(-1, 2), rnd.choice((2, 3, 3))))
    crowns.sort(key=lambda c: c[1])
    for cx, cy, r in crowns:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                d2 = dx * dx + dy * dy
                if d2 > r * r + 1:
                    continue
                x, y = (cx + dx) % T, (cy + dy) % T
                if d2 > (r - 1) * (r - 1) + 1:
                    c = FOR["gap"] if dy > 0 or dx < 0 else FOR["shade"]   # outline, darker low-left
                elif dy > 0 or dx < 0:
                    c = FOR["shade"] if d2 > (r - 2) * (r - 2) else FOR["leaf"]
                else:
                    c = FOR["leaf"]
                tile[y][x] = c
        # one glint high-right on some crowns
        if r >= 3 and rnd.random() < 0.35:
            gx, gy = (cx + 1) % T, (cy - 1) % T
            tile[gy][gx] = FOR["glint"]
    # dense: swallow leftover gaps that are not touching an outline
    for y in range(T):
        for x in range(T):
            if tile[y][x] == FOR["gap"]:
                n = sum(tile[(y + j) % T][(x + i) % T] == FOR["gap"] for j in (-1, 0, 1) for i in (-1, 0, 1))
                if n >= 6:
                    tile[y][x] = FOR["shade"]
    return tile

def trunk_strip(seed):
    """16x8 face: a solid palisade of trunks with grain, knots and root flare. No daylight between them."""
    rnd = random.Random(seed)
    strip = [[FOR["bark"]] * T for _ in range(Q)]
    x = 0
    trunks = []
    while x < T:
        w = rnd.choice((3, 3, 4, 4))
        if x + w > T:
            w = T - x
        trunks.append((x, w)); x += w
    for x0, w in trunks:
        for y in range(Q):
            for i in range(w):
                x = x0 + i
                if i == 0:
                    c = FOR["gap"]                              # crease between trunks
                elif i == 1:
                    c = FOR["barklit"]                          # lit side
                elif i == w - 1 and w == 4:
                    c = FOR["bark"] if y % 3 else FOR["barkmid"]  # shadow side, faint grain
                else:
                    c = FOR["barkmid"] if (y + i) % 4 == 0 else FOR["bark"]   # vertical grain dashes
                if y == 0:
                    c = FOR["shade"]                            # canopy shadow on the trunk tops
                if y == Q - 1 and i == 1:
                    c = FOR["barkmid"]                          # root flare, dark at the ground
                if y == Q - 1 and i == 0 and w >= 3:
                    c = FOR["barkmid"]                          # roots spread over the crease
                strip[y][x] = c
        # a knot: dark pixel with a lit lip above it
        if w >= 3 and rnd.random() < 0.8:
            kx, ky = x0 + rnd.randrange(2, w), rnd.randrange(2, Q - 2)
            strip[ky][kx] = FOR["gap"]; strip[ky - 1][kx] = FOR["barklit"]
    # a couple of leaves hanging over the trunk tops
    for _ in range(3):
        lx = rnd.randrange(T)
        strip[1][lx] = FOR["leaf"]; strip[0][lx] = FOR["leaf"]
    return strip

def build_forest(variants=4):
    src = Image.open(ART + "wall_forest.png").convert("RGBA")
    px = src.load()
    out = Image.new("RGBA", (64, 64 * variants), (0, 0, 0, 0)); op = out.load()
    trunks = trunk_strip(3)
    for v in range(variants):
        canopy = canopy_tile(11 + v)
        for cy in range(4):
            for cx in range(4):
                mask = CELL_TO_MASK.get((cx, cy), 0)
                for y in range(T):
                    for x in range(T):
                        p = px[cx * T + x, cy * T + y]           # variant 0 silhouette for every variant
                        if p[3] == 0:
                            continue
                        role = role_at(mask, x, y)
                        if role == "face":
                            c = trunks[y % Q][x]
                            # let the canopy overhang the first 2 rows of the trunk face
                            if y % Q < 2 and canopy[y % Q + 6][x] != FOR["gap"]:
                                c = canopy[y % Q + 6][x]
                        else:
                            c = canopy[y][x]
                        op[cx * T + x, v * 64 + cy * T + y] = c
    return out

# ---------------- preview: assemble a little scene with the real dual-grid rule ----------------

def dual_grid(atlas, filled, W, H):
    """filled(x,y) -> bool over a W x H data grid. Returns an RGBA image of the display layer."""
    variants = max(1, atlas.height // 64)
    img = Image.new("RGBA", ((W + 1) * T, (H + 1) * T), (0, 0, 0, 0))
    for y in range(-1, H):
        for x in range(-1, W):
            ids = [filled(x, y), filled(x + 1, y), filled(x, y + 1), filled(x + 1, y + 1)]
            mask = sum(1 << k for k in range(4) if ids[k])
            if mask == 0:
                continue
            c = MASK_TO_CELL[mask]
            for k in range(4):
                if not ids[k]:
                    continue
                q = (k & 1, k >> 1)
                cell = ((x + 1) * 2 + q[0], (y + 1) * 2 + q[1])
                ax, ay = c[0] * 2 + q[0], c[1] * 2 + q[1]
                if mask == 15:
                    ay += 8 * ((((cell[0] * 73856093) ^ (cell[1] * 19349663)) & 0x7fffffff) % variants)
                piece = atlas.crop((ax * Q, ay * Q, ax * Q + Q, ay * Q + Q))
                img.alpha_composite(piece, (cell[0] * Q, cell[1] * Q))
    return img

def preview(name, barrier, wall_name, floor_name):
    wall = Image.open(ART + wall_name + ".png").convert("RGBA")
    floor = Image.open(ART + floor_name + ".png").convert("RGBA")
    W, H = 14, 9
    # a room: floor inside, one ring of wall, then a ring of barrier outside that
    def is_barrier(x, y): return 0 <= x < W and 0 <= y < H and (x in (0, W - 1) or y in (0, H - 1))
    def is_wall(x, y): return 0 <= x < W and 0 <= y < H and not is_barrier(x, y) and (x in (1, W - 2) or y in (1, H - 2))
    def is_wall_or_barrier(x, y): return is_wall(x, y) or is_barrier(x, y)
    def is_floor(x, y): return 0 <= x < W and 0 <= y < H and not is_wall_or_barrier(x, y)
    # a barrier pillar inside, to see it against the floor on every side
    def is_barrier2(x, y): return is_barrier(x, y) or (x, y) in ((6, 4), (7, 4))
    def is_floor2(x, y): return is_floor(x, y) and not is_barrier2(x, y)
    def group(x, y): return is_wall(x, y) or is_barrier2(x, y)
    scene = Image.new("RGBA", ((W + 1) * T, (H + 1) * T), (0, 0, 0, 255))
    scene.alpha_composite(dual_grid(floor, is_floor2, W, H))
    # walls and barriers share the group, so each draws with the union mask but only its own quarters
    for atlas, own in ((wall, is_wall), (barrier, is_barrier2)):
        layer = dual_grid_group(atlas, group, own, W, H)
        scene.alpha_composite(layer)
    scene = scene.resize((scene.width * 4, scene.height * 4), Image.NEAREST)
    scene.save(OUT + name + "_preview.png")

def dual_grid_group(atlas, group, own, W, H):
    variants = max(1, atlas.height // 64)
    img = Image.new("RGBA", ((W + 1) * T, (H + 1) * T), (0, 0, 0, 0))
    for y in range(-1, H):
        for x in range(-1, W):
            pts = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            mask = sum(1 << k for k in range(4) if group(*pts[k]))
            if mask == 0:
                continue
            c = MASK_TO_CELL[mask]
            for k in range(4):
                if not own(*pts[k]):
                    continue
                q = (k & 1, k >> 1)
                cell = ((x + 1) * 2 + q[0], (y + 1) * 2 + q[1])
                ax, ay = c[0] * 2 + q[0], c[1] * 2 + q[1]
                if mask == 15:
                    ay += 8 * ((((cell[0] * 73856093) ^ (cell[1] * 19349663)) & 0x7fffffff) % variants)
                piece = atlas.crop((ax * Q, ay * Q, ax * Q + Q, ay * Q + Q))
                img.alpha_composite(piece, (cell[0] * Q, cell[1] * Q))
    return img

if __name__ == "__main__":
    bed = build_bedrock(); bed.save(OUT + "barrier_bedrock.png")
    bed.resize((512, 512), Image.NEAREST).save(OUT + "barrier_bedrock_x8.png")
    preview("barrier_bedrock", bed, "wall_rough_cave", "floor_dirt")
    fo = build_forest(); fo.save(OUT + "barrier_forest_dense.png")
    fo.crop((0, 0, 64, 64)).resize((512, 512), Image.NEAREST).save(OUT + "barrier_forest_dense_x8.png")
    preview("barrier_forest_dense", fo, "wall_forest", "floor_grass")
    from collections import Counter
    for n, im in (("bedrock", bed), ("forest", fo)):
        cols = {p[:3] for p in im.getdata() if p[3]}
        print(n, "colours:", len(cols), sorted(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in cols))
