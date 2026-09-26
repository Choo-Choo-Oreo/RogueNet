"""Neon Outlaw set (sci-fi rock bard): generates every gear sheet and icon.

Worn pieces are repaints of the Human's own pixels (Human-<Dir>.png), so they follow
the walk bob and the stride frame by frame. The amp backpack reuses the Backpack's
outline per frame. Instruments are drawn once facing Down and once facing Right,
outlined automatically, and shifted with the bob. Facing Up they use the Down art
mirrored about x=7, and facing Up-Right the same art with the body's pixels cut out.
See the held-item rules in game/items and memory notes.

Run from the repo root:  python .claude/tools/neon_outlaw.py [preview.png]
"""
import os
import sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HUMAN = os.path.join(ROOT, "resources/gfx/entities/entities.protagonist/human/Human-%s.png")
GEAR = os.path.join(ROOT, "resources/gfx/gear")
ICONS = os.path.join(ROOT, "resources/gfx/ui/icons/items")
DIRS = ["Down", "DownRight", "Right", "UpRight", "Up"]
FRAMES = 4

# --- palette -------------------------------------------------------------------
OUT = (0, 0, 0, 255)
INK = (20, 16, 30, 255)          # icon outline, like the other icons
LEATHER = [(90, 82, 120, 255), (62, 56, 86, 255), (42, 38, 60, 255)]    # light, mid, dark
PANTS = [(84, 58, 116, 255), (62, 42, 88, 255), (44, 30, 64, 255)]
PANTS_BACK = [(52, 36, 74, 255), (36, 26, 52, 255)]
BOOT = [(66, 62, 90, 255), (44, 40, 62, 255), (30, 28, 42, 255)]
CHROME = (222, 232, 246, 255)
CHROME_D = (140, 150, 176, 255)
PINK_L = (255, 150, 230, 255)
PINK = (255, 56, 196, 255)
PINK_D = (170, 24, 136, 255)
CYAN_L = (180, 252, 255, 255)
CYAN = (64, 228, 255, 255)
CYAN_D = (24, 132, 196, 255)
GREEN_L = (200, 255, 190, 255)
GREEN = (90, 250, 120, 255)
GREEN_D = (30, 150, 80, 255)
KEY_W = (240, 240, 252, 255)
SHAVED = [(78, 68, 86, 255), (58, 50, 66, 255), (42, 36, 50, 255)]

# --- the Human's colours -------------------------------------------------------
HAIR = {(156, 102, 62): 0, (108, 66, 42): 1, (70, 40, 34): 2}
SKIN = {(246, 206, 164): 0, (226, 172, 130): 1, (186, 124, 94): 2, (140, 84, 70): 2}
BACK_FOOT = {(152, 127, 101): 0, (140, 106, 80): 1, (115, 76, 58): 2}
EYE = (48, 30, 48)
TUNIC = {(228, 226, 200): 0, (198, 196, 168): 1, (156, 152, 130): 2}
BELT = {(212, 176, 104): 0, (152, 114, 66): 1}
LEGS = {(152, 98, 64): 0, (118, 72, 50): 1, (86, 50, 42): 2}
LEGS_BACK = {(94, 60, 39): 0, (73, 44, 31): 1}


def rgb(p):
    return p[:3]


def bob(frame):
    """Frames 1 and 3 have the feet planted: the whole upper body is 1 px lower."""
    return frame % 2


def load_body(d):
    im = Image.open(HUMAN % d).convert("RGBA")
    return [im.crop((f * 16, 0, f * 16 + 16, 16)) for f in range(FRAMES)]


def blank():
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def sheet(frames):
    out = Image.new("RGBA", (16 * len(frames), 16), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        out.paste(fr, (i * 16, 0))
    return out


# --- worn pieces: repaints of the body ----------------------------------------
def chest(d, f, body):
    """Studded leather jacket, long sleeves, neon trim; a lightning bolt on the back."""
    dy = bob(f)
    im = blank()
    px = body.load()
    for y in range(6 + dy, 11 + dy):
        for x in range(16):
            c = rgb(px[x, y])
            if c in TUNIC:
                im.putpixel((x, y), LEATHER[TUNIC[c]])
            elif c in SKIN and y > 6 + dy:
                im.putpixel((x, y), LEATHER[SKIN[c]])
    def put(x, y, col):
        if im.getpixel((x, y + dy))[3]:
            im.putpixel((x, y + dy), col)
    if d == "Down":
        for y in range(7, 11):
            put(7, y, PINK)           # neon tee under the open jacket
        put(6, 7, CYAN); put(8, 7, CYAN)          # lapels
        put(4, 7, CHROME); put(10, 7, CHROME)     # shoulder studs
        put(3, 10, CYAN); put(11, 10, CYAN)       # cuffs
    elif d == "DownRight":
        for y in range(7, 11):
            put(8, y, PINK)
        put(7, 7, CYAN); put(9, 7, CYAN)
        put(4, 7, CHROME); put(10, 7, CHROME)
        put(11, 10, CYAN)
    elif d == "Right":
        for y in range(7, 11):
            put(9, y, CYAN)           # front edge trim
        put(7, 7, CHROME); put(7, 10, PINK)       # shoulder stud, cuff
    elif d == "UpRight":
        for x, y in [(8, 7), (7, 8), (8, 8), (7, 9), (6, 10)]:
            put(x, y, PINK)
        put(4, 7, CHROME); put(9, 7, CHROME)
        put(3, 10, CYAN)
    elif d == "Up":
        for x, y in [(8, 7), (7, 8), (8, 8), (7, 9), (6, 10)]:
            put(x, y, PINK)
        put(4, 7, CHROME); put(10, 7, CHROME)
        put(3, 10, CYAN); put(11, 10, CYAN)
    return im


def legs(d, f, body):
    """Dark purple pants, studded belt, a neon stripe down the lit side."""
    dy = bob(f)
    im = blank()
    px = body.load()
    for y in range(11 + dy, 16):
        for x in range(16):
            c = rgb(px[x, y])
            if c in BELT:
                im.putpixel((x, y), CHROME if (x % 2 == 0) == (BELT[c] == 0) else BOOT[2])
            elif c in LEGS:
                im.putpixel((x, y), PINK if LEGS[c] == 0 and y > 11 + dy else PANTS[LEGS[c]])
            elif c in LEGS_BACK:
                im.putpixel((x, y), PANTS_BACK[LEGS_BACK[c]])
    return im


def is_foot(c, y, dy):
    return y >= 12 + dy and (c in SKIN or c in BACK_FOOT)


def feet(d, f, body):
    """Black stomper boots with chrome toecaps and a cyan cuff."""
    dy = bob(f)
    im = blank()
    px = body.load()
    for y in range(12, 16):
        for x in range(16):
            c = rgb(px[x, y])
            if is_foot(c, y, dy):
                shade = SKIN[c] if c in SKIN else BACK_FOOT[c]
                back = c in BACK_FOOT
                im.putpixel((x, y), CHROME if shade == 0 and not back else BOOT[min(2, shade + back)])
    for y in range(12, 15):
        for x in range(16):
            c = rgb(px[x, y])
            below = rgb(px[x, y + 1])
            if (c in LEGS or c in LEGS_BACK) and is_foot(below, y + 1, dy):
                im.putpixel((x, y), CYAN_D if c in LEGS_BACK else CYAN)
    return im


def gloves(d, f, body):
    """Fingerless neon gloves: the hand pixel."""
    dy = bob(f)
    im = blank()
    px = body.load()
    y = 11 + dy
    for x in range(16):
        c = rgb(px[x, y])
        if c in SKIN:
            im.putpixel((x, y), PINK if SKIN[c] < 2 else PINK_D)
    return im


HEAD_CREST_X = {"Down": 7, "DownRight": 7, "UpRight": 7, "Up": 7}


def head(d, f, body):
    """Neon mohawk over a shaved head, and a glowing visor across the eyes."""
    dy = bob(f)
    im = blank()
    px = body.load()
    for y in range(0, 6 + dy):
        for x in range(16):
            c = rgb(px[x, y])
            if c not in HAIR:
                continue
            if d == "Right":
                crest = y <= 1 + dy
            else:
                crest = x == HEAD_CREST_X[d] or (abs(x - HEAD_CREST_X[d]) == 1 and y <= 2 + dy)
            if crest:
                im.putpixel((x, y), PINK_L if (y <= 1 + dy and x == HEAD_CREST_X.get(d, x)) else PINK)
            else:
                im.putpixel((x, y), SHAVED[HAIR[c]])
    # the crest breaks through the outline on top
    top = 0 + dy
    if d == "Right":
        for x in range(16):
            if px[x, top][3]:
                im.putpixel((x, top), PINK_L)
    else:
        im.putpixel((HEAD_CREST_X[d], top), PINK_L)
    y = 3 + dy
    if d in ("Down", "DownRight", "Right"):
        face = [x for x in range(16) if rgb(px[x, y]) in SKIN or rgb(px[x, y]) == EYE]
        for i, x in enumerate(face):
            im.putpixel((x, y), CYAN_L if i == 0 else (CYAN_D if i == len(face) - 1 and d != "Right" else CYAN))
        if d == "Right":   # strap back to the ear
            for x in range(16):
                if rgb(px[x, y]) in HAIR and x < face[0]:
                    im.putpixel((x, y), CHROME_D)
    else:
        for x in range(16):
            if rgb(px[x, y]) in HAIR and x != HEAD_CREST_X[d]:
                im.putpixel((x, y), CHROME_D)
    return im


def neck(d, f, body):
    """A glowing guitar pick on a chrome chain (just the chain from behind)."""
    dy = bob(f)
    im = blank()
    pts = {
        "Down": [((5, 6), CHROME), ((9, 6), CHROME), ((6, 7), PINK_L), ((7, 7), PINK), ((8, 7), PINK), ((7, 8), PINK_D)],
        "DownRight": [((6, 6), CHROME), ((10, 6), CHROME), ((7, 7), PINK_L), ((8, 7), PINK), ((9, 7), PINK), ((8, 8), PINK_D)],
        "Right": [((8, 6), CHROME), ((9, 7), PINK_L), ((9, 8), PINK_D)],
        "UpRight": [((5, 6), CHROME), ((6, 6), CHROME), ((7, 6), CHROME)],
        "Up": [((6, 6), CHROME), ((7, 6), CHROME), ((8, 6), CHROME)],
    }[d]
    for (x, y), col in pts:
        im.putpixel((x, y + dy), col)
    return im


def back(d, f, body):
    """Amp backpack: the Backpack's outline, repainted as a speaker cab whose cone pulses."""
    src = Image.open(os.path.join(GEAR, "back/backpack/Backpack-%s.png" % d)).convert("RGBA")
    src = src.crop((f * 16, 0, f * 16 + 16, 16))
    dy = bob(f)
    im = blank()
    sp = src.load()
    for y in range(16):
        for x in range(16):
            p = sp[x, y]
            if not p[3]:
                continue
            im.putpixel((x, y), OUT if rgb(p) == (0, 0, 0) else BOOT[1])
    # straps over the shoulders: chrome buckles
    strap_row = {"Down": 6, "DownRight": 6, "Right": 5, "UpRight": 6, "Up": 6}[d] + dy
    for x in range(16):
        if im.getpixel((x, strap_row))[3] and im.getpixel((x, strap_row)) != OUT:
            im.putpixel((x, strap_row), BOOT[2])
    pulse = f in (0, 2)
    cone = [CYAN_L, CYAN] if pulse else [PINK_L, PINK]
    if d == "Up":
        cx, cy = 7, 9 + dy
    elif d == "UpRight":
        cx, cy = 7, 9 + dy
    elif d == "Right":
        cx, cy = 2, 9 + dy
    else:
        cx = None
    if d in ("Down", "DownRight"):
        for x in range(16):
            if im.getpixel((x, strap_row))[3] and im.getpixel((x, strap_row)) != OUT:
                im.putpixel((x, strap_row), CHROME_D)
                break
    elif d == "Right":
        im.putpixel((cx, cy), cone[0])
        im.putpixel((cx + 1, cy), cone[1])
        im.putpixel((cx, cy + 1), cone[1])
        im.putpixel((cx + 1, cy + 1), BOOT[2])
        im.putpixel((cx, cy - 1), CHROME_D)
        im.putpixel((cx + 1, cy + 2), CHROME_D)
    else:
        for x in range(cx - 1, cx + 2):
            for y in range(cy - 1, cy + 2):
                if im.getpixel((x, y))[3] and im.getpixel((x, y)) != OUT:
                    im.putpixel((x, y), BOOT[2])
        im.putpixel((cx, cy), cone[0])
        for x, y in [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]:
            im.putpixel((x, y), cone[1])
        im.putpixel((cx + 2, cy - 2), CHROME)      # power light / knob
        im.putpixel((cx - 2, cy + 2), CHROME_D)
    return im


# --- instruments ---------------------------------------------------------------
KEY = {
    "c": CHROME, "C": CHROME_D, "m": PINK, "M": PINK_D, "l": PINK_L, "w": KEY_W, "k": OUT,
    "n": CYAN, "N": CYAN_L, "d": CYAN_D, "g": GREEN, "G": GREEN_L, "e": GREEN_D,
    "b": BOOT[1], "B": BOOT[2], "p": PINK,
}

# Each is a 16x16 grid for frame 0; "+" is the hand (left see-through so the hand or
# glove shows); outlines are added around everything else.
INSTRUMENTS = {
    "LaserKeytar": {
        "Down": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "...............N",
            "..............Nd",
            ".............cd.",
            "............c...",
            "...........c....",
            "..lwkwkwkwm+....",
            "..MmmmmmmmmM....",
            "................",
            "................",
            "................",
        ],
        "Right": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "..............N.",
            ".............Nd.",
            "............c...",
            "...........c....",
            "...lwkw+wkwmc...",
            "...MmmmmmmmM....",
            "................",
            "................",
            "................",
        ],
    },
    "PlasmaGuitar": {
        "Down": [
            "................",
            "................",
            "................",
            "..............NN",
            "..............d.",
            ".............c..",
            ".............c..",
            "............c...",
            "............c...",
            "............c...",
            "...........c....",
            "........nnn+....",
            ".......nNpnn....",
            "......nnnpnd....",
            "......dnnnd.....",
            ".......dd.......",
        ],
        "Right": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "...............N",
            "..............Nd",
            ".............c..",
            "............c...",
            "...........c....",
            "..........c.....",
            "....nnn+nnc.....",
            "....nNpnnnd.....",
            "....nnnpnd......",
            ".....dddd.......",
            "................",
        ],
    },
    "HoloDrumGauntlets": {
        "Down": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            ".............dd.",
            "............dNNd",
            "............dNNd",
            ".............dd.",
            "..........CcC...",
            "..........c+n...",
            "..........CcC...",
            "................",
            "................",
            "................",
        ],
        "Right": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "...........dd...",
            "..........dNNd..",
            "..........dNNd..",
            "......CcC..dd...",
            "......c+n.......",
            "......CcC.......",
            "................",
            "................",
            "................",
        ],
    },
    "ThereminStaff": {
        "Down": [
            "................",
            "................",
            "...........G....",
            "..........gGg...",
            "...........c....",
            "...........c.g..",
            "...........cg.g.",
            "...........c.g..",
            "..........BeB...",
            "..........BbB...",
            "...........c....",
            "...........+....",
            "...........c....",
            "...........C....",
            "...........C....",
            "................",
        ],
        "Right": [
            "................",
            "................",
            "................",
            "............G...",
            "...........gGg..",
            "...........c....",
            "..........c.g...",
            ".........cg.g...",
            ".........c.g....",
            "........BeB.....",
            "........c.......",
            ".......+........",
            ".......C........",
            "......C.........",
            "......C.........",
            "................",
        ],
    },
}
# The glow on each instrument that swaps colour on the off-beat frames.
PULSE = {"LaserKeytar": {CYAN_L: PINK_L, CYAN: PINK}, "PlasmaGuitar": {PINK: CYAN_L},
         "HoloDrumGauntlets": {CYAN_L: PINK_L}, "ThereminStaff": {GREEN_L: CYAN_L}}


def draw_grid(grid, pulse=None):
    im = blank()
    hand = None
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == "+":
                hand = (x, y)
            elif ch != ".":
                col = KEY[ch]
                if pulse:
                    col = pulse.get(col, col)
                im.putpixel((x, y), col)
    # outline: every empty pixel next to a filled one (4 directions)
    filled = {(x, y) for x in range(16) for y in range(16) if im.getpixel((x, y))[3]}
    for (x, y) in filled:
        for nx, ny in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
            if 0 <= nx < 16 and 0 <= ny < 16 and (nx, ny) not in filled and (nx, ny) != hand:
                im.putpixel((nx, ny), OUT)
    return im


def shift(im, dy):
    out = blank()
    out.paste(im, (0, dy))
    return out


def instrument(name, d, f, body, upright_body=None):
    pulse = PULSE[name] if f in (1, 3) else None
    if d == "Right":
        base = draw_grid(INSTRUMENTS[name]["Right"], pulse)
    else:
        base = draw_grid(INSTRUMENTS[name]["Down"], pulse)
        if d in ("Up", "UpRight"):
            mirrored = blank()
            for y in range(16):
                for x in range(15):
                    mirrored.putpixel((14 - x, y), base.getpixel((x, y)))
            base = mirrored
    im = shift(base, bob(f))
    if d == "UpRight":
        for y in range(16):
            for x in range(16):
                if body.getpixel((x, y))[3]:
                    im.putpixel((x, y), (0, 0, 0, 0))
    return im


# --- icons ---------------------------------------------------------------------
ICON_KEY = dict(KEY, o=INK, k=INK, L=LEATHER[0], j=LEATHER[1], J=LEATHER[2],
                P=PANTS[0], q=PANTS[1], Q=PANTS[2], s=SHAVED[1], S=SHAVED[2],
                x=BOOT[0], X=BOOT[2])
ICON_GRIDS = {
    "neon_outlaw_visor": [
        "................",
        "................",
        ".......oo.......",
        "......olmo......",
        ".....oolmoo.....",
        "....osslmsso....",
        "...ossslmssso...",
        "...ossslmssso...",
        "..oooooooooooo..",
        "..oNNnnnnnnndo..",
        "..oNnnnnnnnddo..",
        "..oooooooooooo..",
        "...osso..osso...",
        "....oo....oo....",
        "................",
        "................",
    ],
    "neon_outlaw_jacket": [
        "................",
        "...ooo....ooo...",
        "..ocLLooooLLco..",
        ".oLLLnomMonjjjo.",
        ".oLLjjnmmnjjjJo.",
        ".oLjjjomMojjjJo.",
        ".oLjjjomMojjcJo.",
        ".oLjjjomMojjjJo.",
        ".oLjjjomMojjjJo.",
        ".onjjjomMojjjdo.",
        ".oononjomMojnoo.",
        "..o.ojjomMojJo..",
        "....ooooooooo...",
        "................",
        "................",
        "................",
    ],
    "neon_outlaw_gloves": [
        "................",
        "................",
        "...oooo.........",
        "..olmmmo........",
        "..omMmMoooo.....",
        "..ommmmolmmo....",
        "..ommmmommmo....",
        "..oCcCcomMmo....",
        "..oXXXXommmo....",
        "..oXxXXoCcCo....",
        "...oooooXXXo....",
        "........oXxo....",
        ".........ooo....",
        "................",
        "................",
        "................",
    ],
    "neon_outlaw_pants": [
        "................",
        "...oooooooooo...",
        "...ocXcXcXcXo...",
        "...oPPqqqqqQo...",
        "...omPqqqqqmo...",
        "...omPqqoqqmo...",
        "...omPqqoqqmo...",
        "...omPqo.oqmo...",
        "...omPqo.oqmo...",
        "...omPqo.oqmo...",
        "...omPqo.oqmo...",
        "...omPqo.oqmo...",
        "...ooooo.oooo...",
        "................",
        "................",
        "................",
    ],
    "neon_outlaw_boots": [
        "................",
        "................",
        "................",
        ".......ooooo....",
        ".......onnnno...",
        ".......oxxXXo...",
        "...ooooxxxXXo...",
        "...onnnoxxXXo...",
        "...oxxXXoxXXoo..",
        "...oxxXXoxccCo..",
        "...oxxXXXXcccCo.",
        "...oxxccCooooo..",
        "...oxcccCo......",
        "...ooooooo......",
        "................",
        "................",
    ],
    "neon_outlaw_pick_pendant": [
        "................",
        "...oo......oo...",
        "...oco....oco...",
        "....oco..oco....",
        ".....oco.co.....",
        "......ocoo......",
        ".....oooooo.....",
        "....olllmmmo....",
        "....olmmmmMo....",
        "....ommmmmMo....",
        ".....ommmMo.....",
        ".....ommMMo.....",
        "......oMMo......",
        ".......oo.......",
        "................",
        "................",
    ],
    "amp_backpack": [
        "................",
        "....oo....oo....",
        "...oXo....oXo...",
        "..oooooooooooo..",
        "..oxxxxxxxxxXo..",
        "..oxccxxxxxcXo..",
        "..oxxoooooxxXo..",
        "..oxoBdddBoxXo..",
        "..oxodnNndoxXo..",
        "..oxodNNNdoxXo..",
        "..oxodnNndoxXo..",
        "..oxoBdddBoxXo..",
        "..oxxoooooxxXo..",
        "..oXXXXXXXXXXo..",
        "..oooooooooooo..",
        "................",
    ],
    "laser_keytar": [
        "................",
        "............ooo.",
        "...........oNNo.",
        "..........ocdo..",
        ".........oco....",
        ".......ooco.....",
        ".....oolmmo.....",
        "...oolwkwmMo....",
        ".oolwkwkwmMo....",
        "olwkwkwkmMo.....",
        "omkwkwmmMo......",
        "ommmmmMMo.......",
        "oMMMMMoo........",
        ".ooooo..........",
        "................",
        "................",
    ],
    "plasma_guitar": [
        "..............o.",
        ".............oNo",
        "............oNdo",
        "...........ocoo.",
        "..........oco...",
        ".........oco....",
        "........oco.....",
        "...ooooocoo.....",
        "..onnnnNnno.....",
        ".onNnpnnnno.....",
        ".onnpnpnnnno....",
        ".onnnpnnndo.....",
        "..onnnnnddo.....",
        "..odnnnddo......",
        "...ooddoo.......",
        ".....oo.........",
    ],
    "holo_drum_gauntlets": [
        "................",
        "........oooo....",
        ".......odNNdo...",
        "......odNNNNdo..",
        "......odNNNNdo..",
        ".......odNNdo...",
        "........oooo....",
        "................",
        "..ooooo.........",
        ".oCcccCo........",
        ".ocnNncoo.......",
        ".ocnNnccCo......",
        ".oCcccCCCo......",
        "..oXXXXXo.......",
        "...ooooo........",
        "................",
    ],
    "theremin_staff": [
        "...........o....",
        "..........oGo...",
        ".........ogGgo..",
        "..........oco...",
        "..........oco...",
        ".........ooco...",
        "........ogoco...",
        ".......og.gco...",
        "........ogoco...",
        ".........oBeBo..",
        ".........oBbBo..",
        "..........oco...",
        "..........oco...",
        "..........oCo...",
        "..........oCo...",
        "...........o....",
    ],
}


def draw_icon(grid):
    im = blank()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), ICON_KEY[ch])
    return im


# --- output --------------------------------------------------------------------
PIECES = [
    # (folder under gear/, file base, painter, icon id)
    ("helmets/neon_outlaw", "NeonOutlawVisor", head, "neon_outlaw_visor"),
    ("chest/neon_outlaw", "NeonOutlawJacket", chest, "neon_outlaw_jacket"),
    ("gloves/neon_outlaw", "NeonOutlawGloves", gloves, "neon_outlaw_gloves"),
    ("legs/neon_outlaw", "NeonOutlawPants", legs, "neon_outlaw_pants"),
    ("feet/neon_outlaw", "NeonOutlawBoots", feet, "neon_outlaw_boots"),
    ("amulets/neon_outlaw", "NeonOutlawPickPendant", neck, "neon_outlaw_pick_pendant"),
    ("back/amp_backpack", "AmpBackpack", back, "amp_backpack"),
]
INSTRUMENT_ICONS = {"LaserKeytar": "laser_keytar", "PlasmaGuitar": "plasma_guitar",
                    "HoloDrumGauntlets": "holo_drum_gauntlets", "ThereminStaff": "theremin_staff"}


def build():
    bodies = {d: load_body(d) for d in DIRS}
    written = []
    for folder, base, painter, icon_id in PIECES:
        os.makedirs(os.path.join(GEAR, folder), exist_ok=True)
        for d in DIRS:
            path = os.path.join(GEAR, folder, "%s-%s.png" % (base, d))
            sheet([painter(d, f, bodies[d][f]) for f in range(FRAMES)]).save(path)
            written.append(path)
        draw_icon(ICON_GRIDS[icon_id]).save(os.path.join(ICONS, icon_id + ".png"))
    os.makedirs(os.path.join(GEAR, "main_hand/neon_outlaw"), exist_ok=True)
    for name, icon_id in INSTRUMENT_ICONS.items():
        for d in DIRS:
            path = os.path.join(GEAR, "main_hand/neon_outlaw", "%s-%s.png" % (name, d))
            sheet([instrument(name, d, f, bodies[d][f]) for f in range(FRAMES)]).save(path)
            written.append(path)
        draw_icon(ICON_GRIDS[icon_id]).save(os.path.join(ICONS, icon_id + ".png"))
    return written


if __name__ == "__main__":
    for p in build():
        print(os.path.relpath(p, ROOT))
