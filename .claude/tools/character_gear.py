# Gear for the drawn character bodies (character_skins.py: dwarf, elf, kemono). The Human's gear
# art doesn't fit them, so each body gets its own copy of a piece, written next to the Human's:
#   resources/gfx/gear/<slot>/<set>/<skin id>/<Name>-<View>.png   (ItemDatabase.sheet_path)
# How each kind of piece is made for a body:
#  - worn cloth and armour (chest, legs, feet, gloves) is painted onto the body's own pixels, by
#    what they are in its drawn grid (9 a b shirt, c d belt, e f g trousers, k K boots, skin at
#    the end of an arm = hand), in the piece's own colours. A skirt or gown takes the leg armour.
#  - helmets are drawn by hand per head (HELMS); a kemono's ears poke through the top.
#  - the neck piece and held items are the Human's art moved to where this body's chest and
#    hands are (NECK, HANDS).
# Every piece then walks with the body exactly as the body does (character_skins.walk).
# Sets in SETS are painted by hand (militia); every other item's Human art is refitted (fit, touch).
# Run: python .claude/tools/character_gear.py [set or back item ...]   (default: everything)
import os
from PIL import Image
import character_skins as cs

GEAR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../') + 'resources/gfx/gear/'
SKINS = list(cs.D)
SHIRT, TRIM, LEGS, BOOTS, SKIN = '9ab', 'cd', 'efg', 'kK', '4768'
LIGHT, MID, DARK = '94cekK', '7adfw', '68bg'   # body shades -> which of a piece's shades to use

# ---- body map: what each pixel of a body's standing grid is

HUMAN = {'hip': 11}

def grid_of(skin, view):
    """A body's standing grid and its D entry; 'human' is the Human's own sheet."""
    if skin == 'human':
        return [[c if isinstance(c, str) else '?' for c in r] for r in cs.human_grids(view)[0]], HUMAN
    return cs.parse(cs.D[skin]['views'][view][1]), cs.D[skin]

def body_map(skin, view):
    g, info = grid_of(skin, view)
    hip, skirt = info['hip'], info.get('skirt', False)
    shirt_rows = [y for y in range(16) if any(c in SHIRT for c in g[y])]
    first = shirt_rows[0]
    # the belt: the row just above the legs with the most belt pixels
    belt = max(range(hip - 2, hip + 1), key=lambda y: sum(c in TRIM for c in g[y]))
    if not any(c in TRIM for c in g[belt]):
        belt = None
    parts = {}
    last_arm = 15 if skirt else hip    # skirts: the hands hang beside the skirt, below the hip
    for x in range(16):
        arm = [y for y in range(first + 2, last_arm + 1) if g[y][x] in SKIN]
        for y in arm:
            parts[(x, y)] = 'hand' if y == arm[-1] else 'sleeve'
    for y in range(16):
        for x in range(16):
            c = g[y][x]
            if (x, y) in parts:
                continue
            if c in BOOTS or (y == 15 and c in SKIN):   # boots, or bare feet (kemono paws)
                parts[(x, y)] = 'foot'
            elif c in LEGS:
                parts[(x, y)] = 'leg'
            elif y == belt and c in TRIM:
                parts[(x, y)] = 'belt'
            elif y > hip and skirt and c in SHIRT + TRIM:
                parts[(x, y)] = 'skirt'
            elif y >= first and y <= max(hip, belt or 0) and (c in SHIRT + TRIM or (c == 'w' and y > first)):
                parts[(x, y)] = 'torso'
    return g, parts, belt

def shade(c):
    return 0 if c in LIGHT else 2 if c in DARK else 1

# ---- painters: (body grid, parts, belt row, piece) -> gear standing grid of RGB tuples

def paint_chest(g, parts, belt, p):
    """Torso and sleeves; the lowest pixel of each column is the hem, the top row the collar."""
    out = cs.blank()
    cloth = [xy for xy, part in parts.items() if part in ('torso', 'sleeve')]
    top = min(y for _, y in cloth)
    for x, y in cloth:
        if (x, y + 1) not in cloth:
            col = p['hem'][x % 2]
        elif y == top:
            col = p['collar'][shade(g[y][x])]
        else:
            col = p['quilt'][shade(g[y][x])][(x + y) % 2]
        out[y][x] = col
    return out

def paint_legs(g, parts, belt, p):
    """Trousers, the belt row, and a skirt armoured in the same colours (hem darkest)."""
    out = cs.blank()
    cx = centre(parts)
    belt_px = sorted(x for (x, y), part in parts.items() if part == 'belt')
    for (x, y), part in parts.items():
        if part == 'leg':
            out[y][x] = p['leg'][shade(g[y][x])]
        elif part == 'belt':
            out[y][x] = p['buckle'] if x == min(belt_px, key=lambda b: abs(b - cx)) else p['belt'][shade(g[y][x])]
        elif part == 'skirt':
            hem = (x, y + 1) not in parts or parts[(x, y + 1)] != 'skirt'
            seam = g[y][x] == 'c'   # a gown's centre line
            out[y][x] = p['belt'][1] if hem else p['belt'][0] if seam else p['leg'][shade(g[y][x])]
    return out

def paint_part(name, key):
    def paint(g, parts, belt, p):
        out = cs.blank()
        for (x, y), part in parts.items():
            if part == name:
                out[y][x] = p[key][shade(g[y][x])]
        return out
    return paint

def centre(parts):
    xs = [x for (x, y), part in parts.items() if part in ('torso', 'belt')]
    return (min(xs) + max(xs)) / 2 if xs else 7.5

# ---- helmets: drawn per head. Letters are the piece's colours; the Human's art is used where
# the head is the Human's shape (elf), moved by ELF_HELM.
HELMS = {
 'kemono': {
  'Down': """
................
......000.......
.....0ABA0......
...0CDCDCDE0....
...0CDFDFDE0....
..0CDCDCDCEE0...
..0ABBBBBAAA0...
""",
  'DownRight': """
................
......000.......
.....0ABA0......
...0CDCDCDE0....
...0CDCFCFE0....
..0CDCDCDCEE0...
..0ABBBBBAAA0...
""",
  'Right': """
................
................
................
.....0ABBBBA0...
.....0DCDCFE0...
....0CDCDCDE0...
....0ABBBBAA0...
""",
  'UpRight': """
................
......000.......
.....0ABA0......
...0CDCDCDE0....
...0DCDCDCE0....
..0CDCDCDCEE0...
..0ABBBBBAAA0...
""",
  'Up': """
................
......000.......
.....0ABA0......
...0CDCDCDE0....
...0DCDCDCE0....
..0CDCDCDCEE0...
..0ABBBBBAAA0...
"""},
 'dwarf': {
  'Down': """
................
................
................
.....00000......
....0ABBAA0.....
...0CDCDCDE0....
...0CDFDFDE0....
..0ABBBBBBAA0...
""",
  'DownRight': """
................
................
................
.....00000......
....0ABBAA0.....
...0CDCDCDE0....
...0CDCFDFE0....
..0ABBBBBBAA0...
""",
  'Right': """
................
................
................
......0000......
.....0ABBA0.....
....0CDCDCE0....
....0CDCDFE0....
...0ABBBBBAA0...
""",
  'UpRight': """
................
................
................
.....00000......
....0ABBAA0.....
...0CDCDCDE0....
...0DCDCDCE0....
..0ABBBBBBAA0...
""",
  'Up': """
................
................
................
.....00000......
....0ABBAA0.....
...0CDCDCDE0....
...0DCDCDCE0....
..0ABBBBBBAA0...
"""},
}
ELF_HELM = {'Right': (1, 0)}   # the elf's head is the Human's, its side view 1px further right

# ---- where the Human's neck piece and held items go on each body, per view: (dx, dy)
HANDS = {
 'elf_male': {'Right': (1, 0)},
 'elf_female': {v: (0, -1) for v in cs.VIEWS} | {'Right': (1, -1)},
 'kemono_male': {'Right': (1, 0)},
 'kemono_female': {'Right': (1, 0)},
 'dwarf_male': {'Down': (0, 1), 'DownRight': (0, 1), 'Right': (-1, 1), 'UpRight': (1, 1), 'Up': (0, 1)},
 'dwarf_female': {'Down': (0, 1), 'DownRight': (0, 1), 'Right': (2, 1), 'UpRight': (1, 1), 'Up': (0, 1)},
}
OFF_HAND = {   # where the off hand differs from the main hand
 'dwarf_male': {'DownRight': (-1, 1), 'UpRight': (0, 1)},
 'dwarf_female': {'DownRight': (-1, 1), 'UpRight': (0, 1)},
}
# neck: (dx, dy) and the first row it may show on (a dwarf's string is hidden in the beard)
NECK = {
 'elf_male': ((0, 0), 0), 'elf_female': ((0, -1), 0),
 'kemono_male': ((0, 1), 0), 'kemono_female': ((0, 1), 0),
 'dwarf_male': ((0, 2), 9), 'dwarf_female': ((0, 2), 9),
}
NECK_RIGHT_DX = {'elf_male': 1, 'elf_female': 1, 'kemono_male': 1, 'kemono_female': 1, 'dwarf_male': -1, 'dwarf_female': 0}

# ---- the sets. Colours per piece; worn pieces list what paints them.
MILITIA = {
 'chest': ('chest/militia/MilitiaGambeson', paint_chest, {
     'quilt': [((240,228,200), (216,200,164)), ((216,200,164), (192,172,132)), ((160,140,104), (122,104,76))],
     'collar': [(160,140,104), (138,146,154), (122,104,76)],
     'hem': [(138,90,50), (94,62,34)]}),
 'legs': ('legs/militia/MilitiaTrousers', paint_legs, {
     'leg': [(138,122,90), (122,106,76), (94,80,56)],
     'belt': [(106,84,64), (74,58,42), (74,58,42)], 'buckle': (138,146,154)}),
 'feet': ('feet/militia/MilitiaBoots', paint_part('foot', 'boot'), {
     'boot': [(122,90,58), (90,64,40), (62,42,26)]}),
 'gloves': ('gloves/militia/MilitiaMitts', paint_part('hand', 'mitt'), {
     'mitt': [(154,122,88), (154,122,88), (106,80,56)]}),
 'head': ('helmets/militia/MilitiaBucketHelm', 'helm', {
     'A': (90,96,104), 'B': (138,146,154), 'C': (208,160,104), 'D': (168,116,62), 'E': (126,82,40), 'F': (30,24,18)}),
 'neck': ('amulets/militia/MilitiaCopperBadge', 'neck', None),
 'main_hand': ('main_hand/militia/MilitiaRustySword', 'held', None),
 'off_hand': ('off_hand/militia/MilitiaWoodenShield', 'held', None),
}
SETS = {'militia': MILITIA}

# ---- the Human's sheets

def human_frames(art, view):
    path = GEAR + art + '-' + view + '.png'
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert('RGBA')
    out = []
    for f in range(4):
        g = cs.blank()
        for y in range(16):
            for x in range(16):
                p = im.getpixel((f * 16 + x, y))
                if p[3]:
                    g[y][x] = p[:3]
        out.append(g)
    return out

def moved(g, dx, dy, from_row=0):
    out = cs.blank()
    for y in range(16):
        for x in range(16):
            if g[y][x] != '.' and y + dy >= from_row:
                cs.put(out, x + dx, y + dy, g[y][x])
    return out

def helm(skin, view, art, colours):
    race = skin.split('_')[0]
    if race in HELMS:
        out = cs.blank()
        for y, row in enumerate(HELMS[race][view].strip('\n').split('\n')):
            for x, c in enumerate(row):
                if c != '.':
                    out[y][x] = (0, 0, 0) if c == '0' else colours[c]
        return out
    return moved(human_frames(art, view)[0], *ELF_HELM.get(view, (0, 0)))

def walked(skin, view, stand):
    info = cs.D[skin]
    spec = info['views'][view]
    return cs.walk(stand, info, view, spec[0], cs.parse(spec[2]) if len(spec) > 2 else None, gear=True)

def piece(skin, view, slot, spec):
    """The 4 frames of one piece on one body facing one way (None: nothing to draw)."""
    art, how, colours = spec
    if how == 'helm':
        return walked(skin, view, helm(skin, view, art, colours))
    if how == 'neck':
        (dx, dy), from_row = NECK[skin]
        if view == 'Right':
            dx = NECK_RIGHT_DX[skin]
        return walked(skin, view, moved(human_frames(art, view)[0], dx, dy, from_row))
    if how == 'held':
        frames = human_frames(art, view)
        dx, dy = OFF_HAND.get(skin, {}).get(view) or HANDS[skin].get(view, (0, 0)) if slot == 'off_hand' \
            else HANDS[skin].get(view, (0, 0))
        return [moved(g, dx, dy) for g in frames]
    g, parts, belt = body_map(skin, view)
    return walked(skin, view, how(g, parts, belt, colours))

def left(skin, spec):
    """A held item's own left-facing art (a shield's face), moved like the near hand: the
    body facing left is its side view mirrored, so the hand moves the other way."""
    frames = human_frames(spec[0], 'Left')
    if frames is None:
        return None
    dx, dy = HANDS[skin].get('Right', (0, 0))
    return [moved(g, -dx, dy) for g in frames]

# ---- every other set: the Human's own art refitted to the body, then given a touch of the race
# (touch). Rows are mapped anchor to anchor (collar to collar, belt to belt, sole to sole),
# and within a row the Human's outline-to-outline span is stretched onto the body's, so a
# pauldron or a flared hem stays just as far outside the body as it was on the Human.

HEAD = {   # the head's box on each body, outline included: (x0, y0, x1, y1)
 'human': {'Down': (4, 0, 10, 5), 'DownRight': (4, 0, 10, 5), 'Right': (5, 0, 10, 5), 'UpRight': (4, 0, 10, 5),
           'Up': (4, 0, 10, 5)},
 'dwarf_male': {v: (3, 4, 11, 8) for v in cs.VIEWS} | {'Right': (4, 4, 11, 8)},
 'dwarf_female': {v: (3, 3, 11, 8) for v in cs.VIEWS} | {'Right': (4, 4, 11, 8)},
 'kemono_male': {v: (3, 2, 11, 6) for v in cs.VIEWS} | {'Right': (5, 2, 11, 6)},
 'kemono_female': {v: (3, 2, 11, 6) for v in cs.VIEWS} | {'Right': (5, 2, 11, 6)},
}
HAIR = '123'
BEARD = {'dwarf_male'}   # his beard hangs over what he wears; all other hair (braids, locks) goes under it

def lin(a0, a1, b0, b1, v):
    """v on [a0, a1] mapped onto [b0, b1]; past the ends it moves 1:1 with the nearer end."""
    if v <= a0 or a1 == a0:
        return b0 + (v - a0)
    if v >= a1:
        return b1 + (v - a1)
    return b0 + round((v - a0) * (b1 - b0) / (a1 - a0))

def rows_of(parts, kinds):
    return sorted({y for (x, y), p in parts.items() if p in kinds})

def span(parts, y, kinds):
    """The row's outline-to-outline span (the nearest row that has one, for rows without)."""
    rows = rows_of(parts, kinds)
    if not rows:
        return None
    y = min(rows, key=lambda r: abs(r - y))
    xs = [x for (x, yy), p in parts.items() if yy == y and p in kinds]
    return min(xs) - 1, max(xs) + 1

def refit(src, anchors, skin, view, kinds, squeeze=()):
    """Move a Human piece onto a body. anchors: [(body row, Human row)], rows between are
    stretched; squeeze: body rows (a skirt) that take the Human's row with its gaps closed."""
    _, hparts, _ = body_map('human', view)
    hg, _, _ = body_map('human', view)
    _, parts, _ = body_map(skin, view)
    out = cs.blank()
    for y in range(16):
        sy = anchors[0][1] + y - anchors[0][0]
        for (b0, h0), (b1, h1) in zip(anchors, anchors[1:]):
            if y >= b0:
                sy = lin(b0, b1, h0, h1, y)
        if not 0 <= sy < 16 or not (ds := span(parts, y, kinds)) or not (hs := span(hparts, sy, kinds)):
            continue
        if y in squeeze:   # the Human's row without the dark gap between its legs, spread edge to edge
            px = [src[sy][x] for x in range(16) if src[sy][x] != '.' and hg[sy][x] not in '.0?']
            x0, x1 = ds[0] + 1, ds[1] - 1
            for x in range(x0, x1 + 1):
                if px:
                    out[y][x] = px[lin(x0, x1, 0, len(px) - 1, x)]
            continue
        if y < anchors[0][0]:   # above the body (a pennant's flag, a quiver's arrows): moved, not stretched
            ds, hs = span(parts, anchors[0][0], kinds), span(hparts, anchors[0][1], kinds)
            dx = round((ds[0] + ds[1] - hs[0] - hs[1]) / 2)
            ds, hs = (0, 15), (-dx, 15 - dx)
        for x in range(16):
            sx = lin(*ds, *hs, x)
            if 0 <= sx < 16 and src[sy][sx] != '.':
                out[y][x] = src[sy][sx]
    return out

def pw(anchors, v):
    """lin() through several (from, to) anchors in order."""
    if v <= anchors[0][0]:
        return anchors[0][1] + v - anchors[0][0]
    for (a0, b0), (a1, b1) in zip(anchors, anchors[1:]):
        if v <= a1:
            return lin(a0, a1, b0, b1, v)
    return anchors[-1][1] + v - anchors[-1][0]

def eyes(skin, view):
    g, _ = grid_of(skin, view)
    return [(x, y) for y in range(16) for x in range(16) if g[y][x] == '5']

def fit_head(src, skin, view):
    """The Human's helmet stretched over this head, eye row to eye row and eye to eye, so eye
    slits and visors land on the eyes."""
    if len([y for y in range(16) if any(c != '.' for c in src[y])]) <= 2:
        return fit_ring(src, skin, view)
    if skin.startswith('elf'):
        return moved(src, *ELF_HELM.get(view, (0, 0)))
    hx0, hy0, hx1, hy1 = HEAD['human'][view]
    bx0, by0, bx1, by1 = HEAD[skin][view]
    xs, ys = [(bx0, hx0)], [(by0, hy0)]
    he, be = eyes('human', view), eyes(skin, view)
    if he and be and len(he) == len(be):
        ys.append((be[0][1], he[0][1]))
        xs += [(b[0], h[0]) for b, h in zip(sorted(be), sorted(he))]
    xs.append((bx1, hx1)); ys.append((by1, hy1))
    out = cs.blank()
    g, _ = grid_of(skin, view)
    kemono = skin.startswith('kemono')
    for y in range(16):
        for x in range(16):
            sx, sy = pw(xs, x), pw(ys, y)
            if 0 <= sx < 16 and 0 <= sy < 16 and src[sy][sx] != '.':
                if kemono and be and y >= be[0][1] and open_face(x, be, (bx0, bx1), view):
                    continue
                out[y][x] = src[sy][sx]
    return out

RING_EDGE = (46, 30, 24)

def fit_ring(src, skin, view):
    """A thin ring over the head (a halo): kept its own size, not stretched, and lowered until its
    ends rest beside the head's first full-width row, so it sits on the head instead of floating."""
    def crown(s):   # (the first row with an unbroken run at least 6 wide (not the ears), its centre)
        g, _ = grid_of(s, view)
        for y in range(16):
            run = []
            for x in range(17):
                if x < 16 and g[y][x] != '.':
                    run.append(x)
                elif len(run) >= 6:
                    return y, (run[0] + run[-1]) / 2
                else:
                    run = []
    bottom = max(y for y in range(16) if any(c != '.' for c in src[y]))
    (by, bx), (_, hx) = crown(skin), crown('human')
    out = moved(src, round(bx - hx), by - bottom)
    g, _ = grid_of(skin, view)
    edge = [(x, y) for y in range(16) for x in range(16) if out[y][x] == '.' and g[y][x] not in '.0'
            and any(0 <= y + dy < 16 and 0 <= x + dx < 16 and out[y + dy][x + dx] != '.'
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:   # a dark line where it lies on the hair, so a gold halo shows on gold hair
        out[y][x] = RING_EDGE
    return out

def open_face(x, eye_px, box, view):
    """A kemono's helmet is open-faced: from the eyes down only the cheek guards stay (the back
    of the head, seen from the side), so its eyes, snout and muzzle show."""
    if view == 'Right':
        return x >= min(ex for ex, _ in eye_px) - 1
    return box[0] + 1 < x < box[1] - 1

def fit_hands(src, skin, view):
    """Gloves: each hand's glove moved to where this body's hand on that side is."""
    _, hparts, _ = body_map('human', view)
    _, parts, _ = body_map(skin, view)
    out = cs.blank()
    hands = lambda ps: [xy for xy, p in ps.items() if p == 'hand']
    mid = 7.5
    for side in (lambda x: x < mid, lambda x: x >= mid):
        h = [xy for xy in hands(hparts) if side(xy[0])]
        b = [xy for xy in hands(parts) if side(xy[0])]
        if not h or not b:
            continue
        dx = round(sum(x for x, _ in b) / len(b) - sum(x for x, _ in h) / len(h))
        dy = max(y for _, y in b) - max(y for _, y in h)
        for y in range(16):
            for x in range(16):
                if src[y][x] != '.' and side(x):
                    cs.put(out, x + dx, y + dy, src[y][x])
    return out

UPPER, LOWER, ALL = ('torso', 'sleeve', 'hand', 'belt'), ('leg', 'belt', 'skirt', 'foot'), \
    ('torso', 'sleeve', 'hand', 'belt', 'leg', 'skirt', 'foot')

def torso_rows(skin, view):
    _, parts, _ = body_map(skin, view)
    rows = rows_of(parts, ('torso', 'sleeve'))
    return rows[0], rows[-1]

def fit(slot, src, skin, view):
    g, parts, belt = body_map(skin, view)
    _, hparts, hbelt = body_map('human', view)
    (t0, t1), (h0, h1) = torso_rows(skin, view), torso_rows('human', view)
    if skin.startswith('elf'):   # the Human's build: the armour sits where it does on the Human,
        t0, t1 = h0, h1          # over the long hair facing away
    if slot == 'head':
        return fit_head(src, skin, view)
    if slot == 'gloves':
        return fit_hands(src, skin, view)
    if slot == 'chest':
        return refit(src, [(t0, h0), (t1, h1)], skin, view, UPPER)
    if slot == 'back':
        return refit(src, [(t0, h0), (t1, h1), (15, 15)], skin, view, ALL)
    if slot == 'feet':
        if not rows_of(parts, ('foot',)):
            return None   # a floor-length gown hides the feet
        return refit(src, [(15, 15)], skin, view, ('foot',))
    # legs: belt to belt, the legs (or the skirt) down to the ankle
    leg_rows = rows_of(parts, ('leg', 'skirt'))
    hl = rows_of(hparts, ('leg',))
    b = belt if belt is not None else leg_rows[0] - 1
    skirt = rows_of(parts, ('skirt',))
    last = leg_rows[-1] if not skirt else 15
    return refit(src, [(b, hbelt), (last, hl[-1])], skin, view, LOWER, squeeze=skirt)

def mix(a, b, t):
    return tuple(round(p + (q - p) * t) for p, q in zip(a, b))

GOLD = {'elf': (240, 204, 96), 'dwarf': (236, 196, 80)}
FUR = (240, 226, 204)

def touch(slot, out, skin, view):
    """What makes a piece look made for this race: an elf's gold filigree hem and collar, a
    dwarf's studded hem and big buckle (and his beard over it all), a kemono's fur cuffs (its own
    chest tuft is the collar; its face and ears show through a helmet)."""
    race = skin.split('_')[0]
    g, parts, belt = body_map(skin, view)
    cols = {}
    for y in range(16):
        for x in range(16):
            if out[y][x] != '.' and (x, y) in parts:
                cols.setdefault(x, []).append(y)
    if slot == 'chest':
        for x, ys in cols.items():
            top, bottom = min(ys), max(ys)
            if race == 'elf':
                out[bottom][x] = mix(out[bottom][x], GOLD['elf'], 0.55)
                out[top][x] = mix(out[top][x], GOLD['elf'], 0.35)
            elif race == 'dwarf' and x % 2 == 0:
                out[bottom][x] = mix(out[bottom][x], GOLD['dwarf'], 0.7)
            elif race == 'kemono':
                if parts.get((x, bottom)) == 'sleeve':
                    out[bottom][x] = mix(out[bottom][x], FUR, 0.6)
    if slot == 'legs' and race == 'dwarf' and belt is not None:
        xs = sorted(x for x in range(16) if out[belt][x] != '.' and (x, belt) in parts)
        if xs:
            m = (xs[0] + xs[-1]) // 2
            for x in (m, m + 1):
                out[belt][x] = GOLD['dwarf']
    if skin in BEARD and slot in ('chest', 'back', 'neck') and not view.startswith('Up'):
        for y in range(torso_rows(skin, view)[0], 16):
            for x in range(16):
                if g[y][x] in HAIR:
                    out[y][x] = '.'
    return out

def items():
    """(slot, art) of every item with worn art, from game/items."""
    import glob, json
    found = []
    for f in sorted(glob.glob(GEAR + '../../../game/items/**/*.json', recursive=True)):
        try:
            data = json.load(open(f, encoding='utf-8'))
        except (ValueError, OSError):
            continue
        for it in data if isinstance(data, list) else [data]:
            if isinstance(it, dict) and it.get('art') and it.get('slot'):
                found.append((it['slot'], it['art'].replace('res://resources/gfx/gear/', '')))
    return sorted(set(found))

def build_refit(slot, art, skin):
    folder, name = os.path.split(art)
    out = GEAR + folder + '/' + skin + '/'
    if slot in ('neck', 'main_hand', 'off_hand'):
        spec = (art, 'neck' if slot == 'neck' else 'held', None)
        views = {v: piece(skin, v, slot, spec) for v in cs.VIEWS if human_frames(art, v)}
        if slot == 'neck':
            views = {v: [touch('neck', f, skin, v) for f in fr] for v, fr in views.items()}
        left_frames = left(skin, spec) if slot != 'neck' else None
    else:
        views, left_frames = {}, None
        for v in cs.VIEWS:
            src = human_frames(art, v)
            if not src:
                continue
            g = fit(slot, src[0], skin, v)
            if g is None:
                g = cs.blank()
            views[v] = walked(skin, v, touch(slot, g, skin, v))
    os.makedirs(out, exist_ok=True)
    for v, frames in views.items():
        save(frames, out + name + '-' + v + '.png')
    if left_frames:
        save(left_frames, out + name + '-Left.png')

def save(frames, path):
    im = Image.new('RGBA', (64, 16))
    for f, g in enumerate(frames):
        for y in range(16):
            for x in range(16):
                if g[y][x] != '.':
                    im.putpixel((f * 16 + x, y), g[y][x] + (255,))
    im.save(path)

def build(set_id, skin):
    for slot, spec in SETS[set_id].items():
        folder, name = os.path.split(spec[0])
        out = GEAR + folder + '/' + skin + '/'
        os.makedirs(out, exist_ok=True)
        for view in cs.VIEWS:
            save(piece(skin, view, slot, spec), out + name + '-' + view + '.png')
        if spec[1] == 'held' and (frames := left(skin, spec)):
            save(frames, out + name + '-Left.png')

if __name__ == '__main__':
    import sys
    only = sys.argv[1:]   # set ids or back item folders to build; none = everything
    for set_id in SETS:
        if not only or set_id in only:
            for skin in SKINS:
                build(set_id, skin)
    done = [a for a in items() if a[1].split('/')[1] not in SETS and (not only or a[1].split('/')[1] in only)]
    for slot, art in done:
        for skin in SKINS:
            build_refit(slot, art, skin)
    print('gear:', len(done), 'refitted pieces +', ', '.join(SETS), 'x', ', '.join(SKINS))
