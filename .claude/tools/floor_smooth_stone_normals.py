import math
from PIL import Image
S = "C:/Users/Orea/Documents/Project-Godot/RogueNet/resources/gfx/tileset/"
Q = 8  # dual-grid quarter size
TOPS = {(0x92, 0x96, 0xA1), (0x76, 0x7A, 0x84), (0x67, 0x6B, 0x75)}

def make(name="floor_smooth_stone", reach=3.0, blur_passes=2, strength=6.0):
    src = Image.open(S + name + ".png").convert("RGBA")
    W, H = src.size
    px = src.load()
    def solid(x, y): return px[x, y][3] > 0
    def top(x, y): return solid(x, y) and px[x, y][:3] in TOPS
    # height: 1 on tops, falling to 0 over `reach` pixels (measured inside each 8x8 quarter)
    height = [[0.0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if not solid(x, y): continue
            qx, qy = x // Q * Q, y // Q * Q
            best = reach
            for j in range(-int(reach), int(reach) + 1):
                for i in range(-int(reach), int(reach) + 1):
                    xx, yy = x + i, y + j
                    if qx <= xx < qx + Q and qy <= yy < qy + Q and top(xx, yy):
                        best = min(best, math.hypot(i, j))
            height[y][x] = 1.0 - best / reach
    def blur(h):
        out = [[0.0] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                qx, qy = x // Q * Q, y // Q * Q
                acc = ws = 0.0
                for j in (-1, 0, 1):
                    for i in (-1, 0, 1):
                        xx = min(max(x + i, qx), qx + Q - 1); yy = min(max(y + j, qy), qy + Q - 1)
                        w = (2 - abs(i)) * (2 - abs(j)); acc += h[yy][xx] * w; ws += w
                out[y][x] = acc / ws
        return out
    for _ in range(blur_passes): height = blur(height)
    res = Image.new("RGBA", (W, H), (128, 128, 255, 0))
    rp = res.load()
    for y in range(H):
        for x in range(W):
            if not solid(x, y): continue
            qx, qy = x // Q * Q, y // Q * Q
            def hs(xx, yy):
                return height[min(max(yy, qy), qy + Q - 1)][min(max(xx, qx), qx + Q - 1)]
            nx = ny = 0.0
            if not top(x, y):
                nx = -(hs(x + 1, y) - hs(x - 1, y)) * 0.5 * strength
                ny = (hs(x, y + 1) - hs(x, y - 1)) * 0.5 * strength
            l = math.sqrt(nx * nx + ny * ny + 1.0)
            rp[x, y] = (round((nx / l * 0.5 + 0.5) * 255), round((ny / l * 0.5 + 0.5) * 255), round((1 / l * 0.5 + 0.5) * 255), 255)
    res.save(S + name + "_normal.png")
    print("ok", name)

if __name__ == "__main__":
    make()
