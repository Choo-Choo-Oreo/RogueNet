# Regenerates normal maps from the diffuse art. Works per 16x16 tile (atlas cells)
# so nothing leaks between neighbouring tiles. Output is OpenGL convention (green up),
# which is what Godot expects.
import sys, math
from PIL import Image

SRC = "C:/Users/Orea/Documents/Project-Godot/RogueNet/resources/gfx/tileset/"
OUT = "normals/"
TILE = 16
K = [1, 2, 1]  # small blur kernel

def make(name, lum_weight=0.5, alpha_weight=1.0, blur_passes=2, strength=2.0):
    d = Image.open(SRC + name + ".png").convert("RGBA")
    W, H = d.size
    px = d.load()
    height = [[0.0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            height[y][x] = alpha_weight * (a / 255.0) + lum_weight * lum * (a / 255.0)

    def blur(h):
        out = [[0.0] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                tx, ty = x // TILE * TILE, y // TILE * TILE
                acc = 0.0; wsum = 0.0
                for j in range(-1, 2):
                    for i in range(-1, 2):
                        xx = min(max(x + i, tx), tx + TILE - 1)
                        yy = min(max(y + j, ty), ty + TILE - 1)
                        w = K[i + 1] * K[j + 1]
                        acc += h[yy][xx] * w; wsum += w
                out[y][x] = acc / wsum
        return out
    for _ in range(blur_passes):
        height = blur(height)

    res = Image.new("RGBA", (W, H))
    rp = res.load()
    for y in range(H):
        for x in range(W):
            tx, ty = x // TILE * TILE, y // TILE * TILE
            def hs(xx, yy):
                xx = min(max(xx, tx), tx + TILE - 1); yy = min(max(yy, ty), ty + TILE - 1)
                return height[yy][xx]
            dx = (hs(x + 1, y) - hs(x - 1, y)) * 0.5
            dy = (hs(x, y + 1) - hs(x, y - 1)) * 0.5
            if px[x, y][3] == 0:
                nx = ny = 0.0
            else:
                nx = -dx * strength
                ny = dy * strength
            nz = 1.0
            l = math.sqrt(nx * nx + ny * ny + nz * nz)
            nx, ny, nz = nx / l, ny / l, nz / l
            rp[x, y] = (round((nx * 0.5 + 0.5) * 255), round((ny * 0.5 + 0.5) * 255), round((nz * 0.5 + 0.5) * 255), 255)
    res.save(OUT + name + "_normal.png")
    return res

if __name__ == "__main__":
    for n in ["wall_smooth_stone", "wall_cobble_brick", "floor_flesh", "floor_smooth_stone"]:
        make(n)
        print("wrote", n)
