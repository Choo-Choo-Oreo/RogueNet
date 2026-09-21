import math, os
from PIL import Image
ROOT = "C:/Users/Orea/Documents/Project-Godot/RogueNet/"
S = ROOT + "resources/gfx/tileset/"
BASES = ROOT + ".claude/tools/normal_bases/"
T = 16
# Palette roles for the flesh art -> height. None = painted light/shadow: takes its
# neighbours' height instead of adding a bump of its own.
HEIGHT = {
    (0xAC, 0x32, 0x32): 0.0,    # base
    (0x69, 0x0E, 0x0E): -0.5,   # base indent (depth)
    (0xD9, 0x57, 0x63): 0.6,    # vein
    (0xEE, 0xC3, 0x9A): 1.0,    # bone
    (0x77, 0x14, 0x14): None,   # painted shadow accent
    (0xFF, 0xFF, 0xFF): None,   # painted vein glare
}
def wall_base(name):
    # the wall's own tilt + rim bevel, without any brightness-based bumps
    src = open(ROOT + ".claude/tools/wall_normals.py").read().split("# Per-material")[0]
    ns = {}; exec(src, ns)
    os.makedirs(BASES, exist_ok=True); path = BASES + name + "_flatbase.png"
    cwd = os.getcwd(); os.chdir(S)
    try: ns["make"](name, path, bump=0.0, tilt=0.25, bevel=1.2)
    finally: os.chdir(cwd)
    return Image.open(path).convert("RGBA")
def build(name, is_wall, strength=6.0, blur_passes=1):
    src = Image.open(S + name + ".png").convert("RGBA"); W, H = src.size; px = src.load()
    base = wall_base(name) if is_wall else Image.new("RGBA", (W, H), (128, 128, 255, 255))
    bp = base.load()
    h = [[0.0] * W for _ in range(H)]
    def known(x, y): return px[x, y][3] > 0 and px[x, y][:3] in HEIGHT and HEIGHT[px[x, y][:3]] is not None
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0: continue
            v = HEIGHT.get(px[x, y][:3], 0.0)
            if v is None:
                near = [HEIGHT[px[xx, yy][:3]] for xx, yy in ((x+1,y),(x-1,y),(x,y+1),(x,y-1))
                        if 0 <= xx < W and 0 <= yy < H and known(xx, yy) and xx // T == x // T and yy // T == y // T]
                v = max(near) if near else 0.0
            h[y][x] = v
    def blur(a):
        o = [[0.0] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                tx, ty = x // T * T, y // T * T; s = w = 0.0
                for j in (-1, 0, 1):
                    for i in (-1, 0, 1):
                        xx = min(max(x + i, tx), tx + T - 1); yy = min(max(y + j, ty), ty + T - 1)
                        k = (2 - abs(i)) * (2 - abs(j)); s += a[yy][xx] * k; w += k
                o[y][x] = s / w
        return o
    for _ in range(blur_passes): h = blur(h)
    res = base.copy(); rp = res.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0: continue
            tx, ty = x // T * T, y // T * T
            def hs(xx, yy): return h[min(max(yy, ty), ty + T - 1)][min(max(xx, tx), tx + T - 1)]
            gx = (hs(x+1, y) - hs(x-1, y)) * 0.5; gy = (hs(x, y+1) - hs(x, y-1)) * 0.5
            r, g, b, a = bp[x, y]
            nx = (r/255*2-1) - gx*strength; ny = (g/255*2-1) + gy*strength; nz = b/255*2-1
            l = math.sqrt(nx*nx + ny*ny + nz*nz)
            rp[x, y] = (round((nx/l*.5+.5)*255), round((ny/l*.5+.5)*255), round((nz/l*.5+.5)*255), a)
    res.save(S + name + "_normal.png"); print("ok", name)
if __name__ == "__main__":
    build("floor_flesh", False)
    build("wall_flesh", True)
