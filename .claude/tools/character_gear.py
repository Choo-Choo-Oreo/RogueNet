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
# Run: python .claude/tools/character_gear.py   (all sets in SETS, all drawn bodies)
import os
from PIL import Image
import character_skins as cs

GEAR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../') + 'resources/gfx/gear/'
SKINS = list(cs.D)
SHIRT, TRIM, LEGS, BOOTS, SKIN = '9ab', 'cd', 'efg', 'kK', '4768'
LIGHT, MID, DARK = '94cekK', '7adfw', '68bg'   # body shades -> which of a piece's shades to use

# ---- body map: what each pixel of a body's standing grid is

def body_map(skin, view):
    info = cs.D[skin]
    spec = info['views'][view]
    g = cs.parse(spec[1])
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
    for set_id in SETS:
        for skin in SKINS:
            build(set_id, skin)
    print('gear:', ', '.join(SETS), 'x', ', '.join(SKINS))
