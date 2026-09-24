"""Normal-map generator for every tileset. Output is OpenGL convention (green up).

Usage:  python normal_maps.py                 rebuild every material below
        python normal_maps.py floor_flesh     rebuild only the named ones
        python normal_maps.py --out DIR ...   write to DIR instead of the game folder (for testing)

To add a material: add a line to MATERIALS. Pick a method:
  luminance_floor  brightness of the art = height (dirt, grass)
  wall             tilt + rim bevel + optional brightness bumps (walls with black tops)
  palette          each art colour has a height role (flesh); walls get their wall base under it
  bevel            named "top" colours are flat, everything else slopes away from them (smooth stone)
  door             named "top" colours are the flat top strip of a door leaf, everything else is
                   its south face (tilted at the viewer like a wall face) with brightness bumps
Atlas layout: animation frames run left to right (Aseprite's horizontal strip), variants run
top to bottom, each a 64x64 set. Any image size works because everything is done per tile.
Every method works per 16x16 tile (or 8x8 quarter for bevel) so nothing leaks between tiles.
"""
import math, os, re, sys
from PIL import Image

ROOT = "C:/Users/Orea/Documents/Project-Godot/RogueNet/"
ART = ROOT + "resources/gfx/tileset/"
DOORS = ROOT + "resources/gfx/doors/"
T = 16          # atlas tile size
Q = 8           # dual-grid quarter size
KERNEL = [1, 2, 1]

# ---------- shared helpers ----------

def blur(h, W, H, size):
    """1-2-1 blur that never reaches across a `size` x `size` cell boundary."""
    out = [[0.0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            cx, cy = x // size * size, y // size * size
            acc = wsum = 0.0
            for j in (-1, 0, 1):
                for i in (-1, 0, 1):
                    xx = min(max(x + i, cx), cx + size - 1)
                    yy = min(max(y + j, cy), cy + size - 1)
                    w = KERNEL[i + 1] * KERNEL[j + 1]
                    acc += h[yy][xx] * w; wsum += w
            out[y][x] = acc / wsum
    return out

def pack(nx, ny, nz, alpha=255):
    l = math.sqrt(nx * nx + ny * ny + nz * nz)
    return tuple(round((v / l * 0.5 + 0.5) * 255) for v in (nx, ny, nz)) + (alpha,)

def sampler(h, x, y, size):
    """Height lookup clamped to the cell containing (x, y)."""
    cx, cy = x // size * size, y // size * size
    return lambda xx, yy: h[min(max(yy, cy), cy + size - 1)][min(max(xx, cx), cx + size - 1)]

def gradient(hs, x, y):
    return (hs(x + 1, y) - hs(x - 1, y)) * 0.5, (hs(x, y + 1) - hs(x, y - 1)) * 0.5

def flat(W, H):
    return Image.new("RGBA", (W, H), (128, 128, 255, 255))

def plain(src):
    """Completely flat normals, for surfaces that emit light (lava) and shouldn't take shading."""
    return flat(*src.size)

def apply_height(src, base, h, strength):
    """Add the slope of height map `h` on top of `base` normals (only where the art has pixels)."""
    W, H = src.size; px = src.load(); bp = base.load()
    res = base.copy(); rp = res.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0: continue
            gx, gy = gradient(sampler(h, x, y, T), x, y)
            r, g, b, a = bp[x, y]
            rp[x, y] = pack((r / 255 * 2 - 1) - gx * strength, (g / 255 * 2 - 1) + gy * strength, b / 255 * 2 - 1, a)
    return res

# ---------- methods ----------

def luminance_floor(src, lum_weight=1.5, blur_passes=1, strength=4.5, fade=2, alpha_weight=0.0):
    W, H = src.size; px = src.load()
    h = [[0.0] * W for _ in range(H)]
    for ty in range(0, H, T):
        for tx in range(0, W, T):
            vals = [(0.299 * px[x, y][0] + 0.587 * px[x, y][1] + 0.114 * px[x, y][2]) / 255.0
                    for y in range(ty, ty + T) for x in range(tx, tx + T) if px[x, y][3] > 0]
            mean = sum(vals) / len(vals) if vals else 0.0
            for y in range(ty, ty + T):
                for x in range(tx, tx + T):
                    r, g, b, a = px[x, y]
                    h[y][x] = (lum_weight * ((0.299 * r + 0.587 * g + 0.114 * b) / 255.0) + alpha_weight) if a > 0 else lum_weight * mean
    for _ in range(blur_passes): h = blur(h, W, H, T)
    def edge_dist(x, y):
        tx, ty = x // T * T, y // T * T; best = fade
        for j in range(-fade, fade + 1):
            for i in range(-fade, fade + 1):
                xx, yy = x + i, y + j
                if xx < tx or xx >= tx + T or yy < ty or yy >= ty + T or px[xx, yy][3] == 0:
                    best = min(best, max(abs(i), abs(j)))
        return best
    res = Image.new("RGBA", (W, H)); rp = res.load()
    for y in range(H):
        for x in range(W):
            nx = ny = 0.0
            if px[x, y][3] != 0:
                f = min(edge_dist(x, y) / fade, 1.0)
                gx, gy = gradient(sampler(h, x, y, T), x, y)
                nx, ny = -gx * strength * f, gy * strength * f
            rp[x, y] = pack(nx, ny, 1.0)
    return res

def wall(src, tilt=0.25, bump=2.0, bevel=1.2):
    """Black pixels are the wall top (flat). The face leans toward the viewer by `tilt`,
    art brightness adds `bump`, and the rim slopes away from the top by `bevel`."""
    W, H = src.size; px = src.load()
    res = Image.new("RGBA", src.size, (128, 128, 255, 0)); rp = res.load()
    for ty in range(0, H, T):
        for tx in range(0, W, T):
            p = {(x, y): px[tx + x, ty + y] for y in range(T) for x in range(T)}
            def at(x, y): return p[min(max(x, 0), T - 1), min(max(y, 0), T - 1)]
            def alpha(x, y): return at(x, y)[3] > 0
            def lum(x, y): return sum(at(x, y)[:3]) / 765.0
            def top(x, y): return at(x, y)[3] > 0 and sum(at(x, y)[:3]) < 12
            def face_h(x, y, cx, cy): return lum(x, y) if alpha(x, y) and not top(x, y) else lum(cx, cy)
            def tmask(x, y): return sum(1.0 if top(x + dx, y + dy) else 0.0 for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
            for y in range(T):
                for x in range(T):
                    a = p[x, y][3]
                    if a == 0: continue
                    nx = ny = 0.0
                    if not top(x, y):
                        gx = (face_h(x + 1, y, x, y) - face_h(x - 1, y, x, y)) / 2
                        gy = (face_h(x, y + 1, x, y) - face_h(x, y - 1, x, y)) / 2
                        nx, ny = -gx * bump, gy * bump - tilt
                        nx += -(tmask(x + 1, y) - tmask(x - 1, y)) / 2 * bevel
                        ny += (tmask(x, y + 1) - tmask(x, y - 1)) / 2 * bevel
                    nz = math.sqrt(max(0.05, 1 - nx * nx - ny * ny)) if abs(nx) < 1 and abs(ny) < 1 else 0.3
                    rp[tx + x, ty + y] = pack(nx, ny, nz, a)
    return res

def palette(src, heights, base="flat", strength=6.0, blur_passes=1, **wall_kw):
    """heights: {(r,g,b): height or None}. None = painted light/shadow, takes its neighbours' height.
    Colours not listed count as 0. base is 'flat' or 'wall' (wall_kw go to wall(); use bump=0)."""
    W, H = src.size; px = src.load()
    base_img = wall(src, **wall_kw) if base == "wall" else flat(W, H)
    def known(x, y): return px[x, y][3] > 0 and px[x, y][:3] in heights and heights[px[x, y][:3]] is not None
    h = [[0.0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0: continue
            v = heights.get(px[x, y][:3], 0.0)
            if v is None:
                near = [heights.get(px[xx, yy][:3], 0.0) for xx, yy in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                        if 0 <= xx < W and 0 <= yy < H and known(xx, yy) and xx // T == x // T and yy // T == y // T]
                v = max(near) if near else 0.0
            h[y][x] = v
    for _ in range(blur_passes): h = blur(h, W, H, T)
    return apply_height(src, base_img, h, strength)

def bevel(src, tops, reach=3.0, blur_passes=2, strength=6.0):
    """`tops` colours stay flat; other pixels slope by distance from them (per 8x8 quarter)."""
    W, H = src.size; px = src.load()
    solid = lambda x, y: px[x, y][3] > 0
    is_top = lambda x, y: solid(x, y) and px[x, y][:3] in tops
    h = [[0.0] * W for _ in range(H)]
    r = int(reach)
    for y in range(H):
        for x in range(W):
            if not solid(x, y): continue
            qx, qy = x // Q * Q, y // Q * Q; best = reach
            for j in range(-r, r + 1):
                for i in range(-r, r + 1):
                    xx, yy = x + i, y + j
                    if qx <= xx < qx + Q and qy <= yy < qy + Q and is_top(xx, yy):
                        best = min(best, math.hypot(i, j))
            h[y][x] = 1.0 - best / reach
    for _ in range(blur_passes): h = blur(h, W, H, Q)
    res = Image.new("RGBA", (W, H), (128, 128, 255, 0)); rp = res.load()
    for y in range(H):
        for x in range(W):
            if not solid(x, y): continue
            nx = ny = 0.0
            if not is_top(x, y):
                gx, gy = gradient(sampler(h, x, y, Q), x, y)
                nx, ny = -gx * strength, gy * strength
            rp[x, y] = pack(nx, ny, 1.0)
    return res

def door(src, tops, tilt=0.25, bump=2.0):
    """Door atlases (<Style>_W<Width>.png, 16x32 pieces = own cell + the cell north of it) with no black wall top: the
    `tops` colours are the leaf's flat top strip, every other opaque pixel is a face that leans
    toward the viewer by `tilt` and takes brightness bumps from the art, per 16x16 tile."""
    W, H = src.size; px = src.load()
    res = Image.new("RGBA", src.size, (128, 128, 255, 0)); rp = res.load()
    for ty in range(0, H, T):
        for tx in range(0, W, T):
            p = {(x, y): px[tx + x, ty + y] for y in range(T) for x in range(T)}
            def at(x, y): return p[min(max(x, 0), T - 1), min(max(y, 0), T - 1)]
            def is_top(x, y): return at(x, y)[3] > 0 and at(x, y)[:3] in tops
            def lum(x, y): return sum(at(x, y)[:3]) / 765.0
            def face_h(x, y, cx, cy): return lum(x, y) if at(x, y)[3] > 0 and not is_top(x, y) else lum(cx, cy)
            for y in range(T):
                for x in range(T):
                    a = p[x, y][3]
                    if a == 0: continue
                    nx = ny = 0.0
                    if not is_top(x, y):
                        gx = (face_h(x + 1, y, x, y) - face_h(x - 1, y, x, y)) / 2
                        gy = (face_h(x, y + 1, x, y) - face_h(x, y - 1, x, y)) / 2
                        nx, ny = -gx * bump, gy * bump - tilt
                    nz = math.sqrt(max(0.05, 1 - nx * nx - ny * ny)) if abs(nx) < 1 and abs(ny) < 1 else 0.3
                    rp[tx + x, ty + y] = pack(nx, ny, nz, a)
    return res

# ---------- materials ----------

WOOD_TOPS = {(86, 46, 38)}      # door_build.py WOOD_T
IRON_TOPS = {(52, 54, 60)}      # door_build.py IRON_D (also the 1px cross bar; close enough)
DUNGEON_TOPS = {(120, 50, 50), (50, 65, 125), (165, 165, 172)}   # door_boss.py placeholder leaf/frame tops

FLESH = {
    (0xAC, 0x32, 0x32): 0.0,   # base
    (0x69, 0x0E, 0x0E): -0.5,  # base indent (depth)
    (0xD9, 0x57, 0x63): 0.6,   # vein
    (0xEE, 0xC3, 0x9A): 1.0,   # bone
    (0x77, 0x14, 0x14): None,  # painted shadow accent
    (0xFF, 0xFF, 0xFF): None,  # painted vein glare
}
WATER = {(0x5B, 0x6E, 0xE1): 0.0, (0x44, 0x55, 0xBA): 0.0, (0x63, 0x9B, 0xFF): 0.5}   # shallows, deep (same level: calm), ripple highlight
ACID = {(0x4F, 0x7A, 0x12): 0.0, (0x37, 0x94, 0x6E): 0.5}    # base, teal highlight
STONE_TOPS ={(0x92, 0x96, 0xA1), (0x76, 0x7A, 0x84), (0x67, 0x6B, 0x75)}

MATERIALS = {
    "wall_smooth_stone": (wall, dict(bump=0.8, tilt=0.25, bevel=1.2)),
    "wall_cobble_brick": (wall, dict(bump=4.0, tilt=0.25, bevel=1.2)),
    "wall_wood_plank":   (wall, dict(bump=2.5, tilt=0.25, bevel=1.2)),
    "wall_rough_cave":   (wall, dict(bump=3.0, tilt=0.25, bevel=1.2)),
    "wall_smooth_cave":  (wall, dict(bump=1.2, tilt=0.25, bevel=1.2)),
    "wall_flesh":        (palette, dict(heights=FLESH, base="wall", bump=0.0, tilt=0.25, bevel=1.2)),
    "floor_dirt":        (luminance_floor, {}),
    "floor_grass":       (luminance_floor, {}),
    "floor_flesh":       (palette, dict(heights=FLESH)),
    "floor_smooth_stone": (bevel, dict(tops=STONE_TOPS)),
    "floor_smooth_cave": (luminance_floor, dict(strength=3.0)),   # flat worn pads: gentle bumps from the art's brightness
    "floor_water":       (palette, dict(heights=WATER, strength=3.0)),
    "floor_lava":        (plain, {}),   # emits its own light, so no shading from the player's
    "floor_acid":        (palette, dict(heights=ACID, strength=3.0)),
    "Wood":              (door, dict(tops=WOOD_TOPS, bump=2.5)),
    "Wood_Fold":         (door, dict(tops=WOOD_TOPS, bump=2.5)),
    "Dungeon":           (door, dict(tops=DUNGEON_TOPS, bump=0.0)),   # flat placeholder, no grain yet
    "Iron":              (door, dict(tops=IRON_TOPS, bump=2.0)),
    "IronSink":          (door, dict(tops=IRON_TOPS, bump=2.0)),
}

# Materials that don't live in the tileset folder. Doors are one atlas per width,
# <Style>_W<Width>.png or <Style>_W<Min>-<Max>.png -> same name + _Normal.png. Boss doors
# (doors/doors.boss/) are layered: <Style>_W<n>_Frame.png and _Leaves.png each get a normal, the
# translucent _Overlay.png does not.
BOSS = DOORS + "doors.boss/"
FOLDERS = {"Wood": DOORS, "Wood_Fold": DOORS, "Dungeon": BOSS, "Iron": DOORS, "IronSink": DOORS}

# Boss door frame sets, cut from the wall tiles: <Set>_W<n>_Frame.png in doors.boss/. Their flat
# "tops" are whatever the wall's top regions use (black + rims; canopy for the forest wall).
FRAME_SETS = {"CobbleBrick": "wall_cobble_brick", "Flesh": "wall_flesh", "Forest": "wall_forest", "Marble": "wall_marble",
              "RoughCave": "wall_rough_cave", "SmoothStone": "wall_smooth_stone", "WoodPlank": "wall_wood_plank"}


def _wall_tops(tile):
    im = Image.open(ART + tile + ".png").convert("RGBA"); px = im.load()
    regions = [(32, 16, 48, 32), (48, 8, 64, 16), (24, 0, 32, 16), (48, 32, 56, 48), (8, 24, 16, 32), (32, 56, 40, 64)]   # interior, north edge, west, east, two corners
    return {px[x, y][:3] for x0, y0, x1, y1 in regions for y in range(y0, y1) for x in range(x0, x1) if px[x, y][3]}


for _set, _tile in FRAME_SETS.items():
    if not os.path.exists(ART + _tile + ".png"):
        continue                                   # wall tile gone (wall_marble was removed 2026-09-24): no frame material
    MATERIALS[_set] = (door, dict(tops=_wall_tops(_tile), bump=1.5))
    FOLDERS[_set] = BOSS

# Boss door leaf tiers: <Tier>_W<n>_Leaves.png in doors.boss/. Wood and Iron are the same
# materials as the room doors, so those two materials look in both folders.
FOLDERS["Wood"] = (DOORS, BOSS)
FOLDERS["Iron"] = (DOORS, BOSS)
for _tier, _top in (("Bronze", (84, 50, 24)), ("Silver", (112, 120, 132)), ("Gold", (146, 100, 20))):
    MATERIALS[_tier] = (door, dict(tops={_top}, bump=2.0))     # door_leaves.py METALS[tier]["TOP"]
    FOLDERS[_tier] = BOSS

# The dirt and grass PNGs in the game were made with different settings than these defaults
# (about 1400-1600 pixels differ), so a plain rebuild leaves them alone. Name them to rebuild.
SKIP_BY_DEFAULT = {"floor_dirt", "floor_grass"}

def build(name, out_dir=None):
    method, kw = MATERIALS[name]
    folders = FOLDERS.get(name, ART)
    for folder in (folders if isinstance(folders, tuple) else (folders,)):
        if folder in (DOORS, BOSS):
            targets = [f[:-4] for f in sorted(os.listdir(folder)) if re.fullmatch(name + r"_W\d+(-\d+)?(_Frame|_Leaves)?\.png", f)]
            suffix = "_Normal"
        else:
            targets, suffix = [name], "_normal"
        for t in targets:
            if not os.path.exists(folder + t + ".png"):
                continue
            src = Image.open(folder + t + ".png").convert("RGBA")
            method(src, **kw).save((out_dir or folder) + t + suffix + ".png")
            print("ok", t, src.size)

if __name__ == "__main__":
    args = sys.argv[1:]; out = None
    if "--out" in args:
        i = args.index("--out"); out = args[i + 1].rstrip("/") + "/"; del args[i:i + 2]
    for n in (args or [m for m in MATERIALS if m not in SKIP_BY_DEFAULT]):
        build(n, out)
