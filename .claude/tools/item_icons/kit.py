"""Shared kit for the item icon redraw.

Art is drawn with shade letters; a palette turns letters into colours:
  w l m d x   main material, light to dark
  A B C       accent (gem, glow, trim), light to dark
  S T U       second material
  E F G       third material
  k           outline (added automatically around every part)
Each part is outlined on its own, so overlapping parts stay readable.
"""
import numpy as np
from PIL import Image, ImageDraw

K = '#16121a'
DARKER = {'w': 'l', 'l': 'm', 'm': 'd', 'd': 'x', 'x': 'x', 'k': 'k',
          'A': 'B', 'B': 'C', 'C': 'C', 'S': 'T', 'T': 'U', 'U': 'U', 'E': 'F', 'F': 'G', 'G': 'G'}


def grid(rows, w=None, h=None):
    w = w or max(len(r) for r in rows)
    h = h or len(rows)
    g = np.full((h, w), '.', dtype='<U1')
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ' ':
                g[y, x] = c
    return g


def outline(g):
    g = g.copy()
    f = g != '.'
    o = np.zeros_like(f)
    o[1:] |= f[:-1]; o[:-1] |= f[1:]; o[:, 1:] |= f[:, :-1]; o[:, :-1] |= f[:, 1:]
    g[o & ~f] = 'k'
    return g


def place(part, dx=0, dy=0, mirror=False, dark=False, flip=False, line=True):
    """Put a part (grid or row strings) on a 16x16 canvas, with its own outline."""
    if isinstance(part, list) and part and isinstance(part[0], tuple):
        g0 = np.full((16, 16), '.', dtype='<U1')
        for x, y, c in part:
            if 0 <= x < 16 and 0 <= y < 16:
                g0[y, x] = c
        part = g0
    p = grid(part) if isinstance(part, list) else part
    if mirror:
        p = p[:, ::-1]
    if flip:
        p = p[::-1, :]
    g = np.full((16, 16), '.', dtype='<U1')
    for y in range(p.shape[0]):
        for x in range(p.shape[1]):
            c = p[y, x]
            if c != '.' and 0 <= y + dy < 16 and 0 <= x + dx < 16:
                g[y + dy, x + dx] = DARKER.get(c, c) if dark else c
    return outline(g) if line else g


def comp(*layers):
    g = np.full((16, 16), '.', dtype='<U1')
    for l in layers:
        g[l != '.'] = l[l != '.']
    return g


def edit(part, changes):
    part = (grid(part) if isinstance(part, list) else part).copy()
    for (x, y), c in changes.items():
        if 0 <= y < part.shape[0] and 0 <= x < part.shape[1]:
            part[y, x] = c
    return part


def rows(y, *strs, x0=0):
    """Changes that overwrite whole rows (spaces keep what is there)."""
    out = {}
    for i, s in enumerate(strs):
        for x, c in enumerate(s):
            if c != ' ':
                out[(x0 + x, y + i)] = c
    return out


def px(g, pts):
    """Paint pixels straight onto a finished canvas (no new outline)."""
    g = g.copy()
    for x, y, c in pts:
        if 0 <= y < 16 and 0 <= x < 16:
            g[y, x] = c
    return g


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def render(g, pal):
    pal = {**pal, 'k': K}
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            c = g[y, x]
            if c != '.':
                im.putpixel((x, y), hexc(pal.get(c, '#ff00ff')) + (255,))
    return im


def tri(a, b, c, letters):
    return dict(zip(letters, (a, b, c)))


# ------------------------------------------------------------------ materials
MAT = {
    'steel': ('#eef4f8', '#a8b4c0', '#6a7484'),
    'iron': ('#b8c0c8', '#7c8490', '#4a505c'),
    'rust': ('#d08050', '#9a5030', '#5a2a18'),
    'gold': ('#fff0a0', '#e8b840', '#a07020'),
    'bronze': ('#f0c070', '#b87830', '#704010'),
    'copper': ('#f8b080', '#c87040', '#804028'),
    'silver': ('#ffffff', '#c8d0dc', '#8890a0'),
    'wood': ('#c89058', '#8a5a32', '#56341c'),
    'darkwood': ('#8a6040', '#5a3a24', '#34200f'),
    'leather': ('#b07850', '#7a4a2c', '#4a2a18'),
    'bone': ('#fff8e8', '#dcd0b0', '#a09070'),
    'skin': ('#f8cca0', '#d09070', '#98583c'),
    'cloth_red': ('#ff7060', '#c83030', '#801828'),
    'paper': ('#fff4d8', '#e0c890', '#a88858'),
    'glass': ('#ffffff', '#c8e8f0', '#88b0c0'),
    'fire': ('#fff8c0', '#ffc030', '#e05818'),
}


def mat(name, letters='EFG'):
    return tri(*MAT[name], letters)


# ------------------------------------------------------------------ set palettes
def pal(main, accent, second, third):
    p = dict(zip('wlmdx', main))
    p.update(zip('ABC', accent))
    p.update(zip('STU', second))
    p.update(zip('EFG', third))
    return p


SETS = {
    'abyssal': pal(('#c8fff0', '#41babb', '#19777d', '#1a5a6a', '#0d3a45'), ('#ffffff', '#e8d9f5', '#b890d0'),
                   ('#ffa8a8', '#e06878', '#9a3a50'), MAT['gold']),
    'apprentice': pal(('#eee0b4', '#c5b07e', '#a7956f', '#8a7b5e', '#5e5040'), ('#9ab0f0', '#5e70b0', '#2e3a60'),
                      MAT['leather'], MAT['wood']),
    'arcane': pal(('#c4a4f4', '#9467cb', '#735cae', '#584291', '#3a2a6a'), ('#fff0a0', '#e0b048', '#906020'),
                  ('#ffffff', '#d8c4ff', '#9a78d8'), MAT['wood']),
    'archmage': pal(('#a068e0', '#6a3aa8', '#4a2a78', '#2e1a4a', '#1e1030'), ('#ffc0ff', '#e040ff', '#9020b0'),
                    ('#ffe8a0', '#e8c060', '#a8803a'), MAT['darkwood']),
    'assassin': pal(('#bca4cc', '#9c7eaf', '#7b6b91', '#5a5270', '#38324c'), ('#ff7070', '#d02030', '#701020'),
                    MAT['steel'], ('#5a5270', '#38324c', '#1d1a25')),
    'cleric': pal(('#ffffff', '#e4e8f0', '#bcc4d0', '#949eae', '#646c7e'), ('#90ffc0', '#30b070', '#1a7048'),
                  MAT['gold'], MAT['leather']),
    'clockwork': pal(('#ffe6a0', '#d5a148', '#b07a34', '#8a5424', '#5a280c'), ('#90fff0', '#3ab0a8', '#1a6a68'),
                     ('#9a7050', '#6d4020', '#3d2211'), MAT['iron']),
    'cutpurse': pal(('#c8b494', '#a59171', '#857c6a', '#655e52', '#48403a'), ('#7090d0', '#34508a', '#1c2a58'),
                    MAT['skin'], ('#9a7a58', '#6a5440', '#48362a')),
    'frost': pal(('#ffffff', '#c8f6ff', '#90d0f4', '#5886bf', '#2b4b84'), ('#ffffff', '#e0f8ff', '#a0e0ff'),
                 ('#d0dce4', '#98a4b0', '#65717c'), ('#ffffff', '#e4ecf0', '#b0c0cc')),
    'hamster': pal(('#ffd8a0', '#f3b775', '#e8924a', '#c86430', '#8a2c10'), ('#ffb0c0', '#e07090', '#a04060'),
                   ('#fffaf0', '#fde4c0', '#e0bf98'), ('#b0f070', '#60a830', '#306018')),
    'heavy_iron': pal(('#eef6f8', '#a8bcc4', '#7e8994', '#5d6977', '#3a4452'), ('#ffe890', '#ddb65a', '#9a7a30'),
                      MAT['leather'], MAT['iron']),
    'infernal': pal(('#c85040', '#942e26', '#6a2020', '#4a1418', '#2a0c10'), ('#fff8c0', '#ffc838', '#f07818'),
                    ('#8a7a70', '#5a4a44', '#2e2420'), MAT['bone']),
    'magma': pal(('#a898b8', '#786485', '#58445d', '#3c3044', '#221a28'), ('#fff080', '#ffa020', '#c83c14'),
                 ('#ff8040', '#c03818', '#701808'), MAT['iron']),
    'militia': pal(('#e0c898', '#b89c6a', '#9a7858', '#7a5640', '#56382a'), ('#ffb070', '#c86a30', '#804020'),
                   MAT['iron'], MAT['wood']),
    'necromancer': pal(('#90a880', '#6d7e62', '#54614d', '#3a4636', '#232c20'), ('#d8ffb8', '#88e060', '#40a030'),
                       MAT['bone'], ('#a080b0', '#6a4a80', '#3a2848')),
    'poacher': pal(('#d4ac8a', '#a88870', '#886454', '#604638', '#3c2a20'), ('#ff6a50', '#b02818', '#601810'),
                   ('#fff2d8', '#dcc8a4', '#a89478'), ('#b8c080', '#858b5b', '#5a5830')),
    'rogue': pal(('#d8a878', '#a07048', '#7d4a2d', '#5a3020', '#3a180e'), ('#80c060', '#3a7028', '#1b4216'),
                 ('#e8d8a8', '#b7a76f', '#807040'), MAT['steel']),
    'scrapper': pal(('#f3deb3', '#c8ac80', '#a0845a', '#76603e', '#4e3e2a'), ('#f08050', '#a04a24', '#5a1c0c'),
                    ('#dce4e8', '#a0a8b0', '#687078'), MAT['wood']),
    'seraph': pal(('#ffffff', '#f0f0fa', '#c8cce4', '#9a9eba', '#62667e'), ('#fff4b0', '#ffd860', '#d8a028'),
                  ('#d0f0ff', '#88c0f0', '#4a80c0'), ('#b08858', '#7a5836', '#4f3b27')),
    'sporecaller': pal(('#b0e888', '#70ae48', '#488a34', '#2e6a24', '#1a4418'), ('#ff9090', '#d02c38', '#80102c'),
                       ('#c89868', '#a07044', '#664020'), ('#90fff0', '#30c0c0', '#1a7888')),
    'starforged': pal(('#7aa0f0', '#4a70d0', '#2e3c98', '#1c2670', '#0e1450'), ('#ffffff', '#fff0a0', '#e8c050'),
                      ('#f0c070', '#b07828', '#703b14'), ('#d0e8ff', '#88b8f8', '#4878d0')),
    'wraith': pal(('#6a9aa4', '#467480', '#2e5a66', '#1c3c48', '#10262e'), ('#e8fffa', '#a0fff0', '#40e0d0'),
                  ('#d4ece8', '#9cbcb8', '#688884'), ('#505a66', '#30363e', '#191f28')),
}

GREY = pal(('#f0f0f0', '#b8b8b8', '#8c8c8c', '#646464', '#404040'), ('#ffffff', '#d8d8d8', '#a8a8a8'),
           ('#e0e0e0', '#a0a0a0', '#686868'), ('#c8c8c8', '#909090', '#585858'))


def set_of(name):
    for s in sorted(SETS, key=len, reverse=True):
        if name.startswith(s + '_'):
            return s
    return None


def sheet(items, path, S=5, cols=11, orig_dir='icons_orig'):
    """items: list of (name, grid, palette). Old above new, dark and grey backgrounds."""
    cell = 16 * S
    rows_n = (len(items) + cols - 1) // cols
    bh = 4 * cell + 26
    out = Image.new('RGBA', (cols * (cell + 8) + 8, rows_n * bh + 8), (40, 36, 36, 255))
    d = ImageDraw.Draw(out)
    for i, (name, g, p) in enumerate(items):
        x = 8 + (i % cols) * (cell + 8)
        y0 = 4 + (i // cols) * bh
        try:
            old = Image.open(f'{orig_dir}/{name}.png').convert('RGBA')
        except FileNotFoundError:
            old = None
        new = render(g, p)
        for r, (im, bg) in enumerate([(old, (20, 18, 18)), (new, (20, 18, 18)), (old, (100, 88, 84)), (new, (100, 88, 84))]):
            y = y0 + r * cell
            out.paste(Image.new('RGBA', (cell, cell), bg + (255,)), (x, y))
            if im:
                out.alpha_composite(im.resize((cell, cell), Image.NEAREST), (x, y))
        d.text((x, y0 + 4 * cell + 4), name.replace('_', ' ')[:15], fill=(230, 230, 230))
    out.save(path)


# ------------------------------------------------------------------ auto shading
def mask_rows(rows_):
    g = grid(rows_, 16, 16)
    return g != '.'


def mask_circle(cx, cy, r):
    y, x = np.mgrid[0:16, 0:16]
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def shade(mask, letters='wlmdx', rim=None, flat=False):
    """Fill a mask lit from the top left: a bright top-left edge, a dark bottom-right edge,
    and a two-tone body split along the diagonal. rim='EFG' makes the edge ring a separate material."""
    w, l, m, d, x = letters
    g = np.full((16, 16), '.', dtype='<U1')
    ys, xs = np.where(mask)
    if not len(xs):
        return g
    s = xs + ys
    mid = (s.min() + s.max()) / 2
    for yy, xx in zip(ys, xs):
        g[yy, xx] = l if xx + yy < mid + (0 if not flat else 99) else m
    inside = lambda yy, xx: 0 <= yy < 16 and 0 <= xx < 16 and mask[yy, xx]
    edge = np.zeros_like(mask)
    for yy, xx in zip(ys, xs):
        up, left = inside(yy - 1, xx), inside(yy, xx - 1)
        down, right = inside(yy + 1, xx), inside(yy, xx + 1)
        if not (up and left and down and right):
            edge[yy, xx] = True
        if rim:
            continue
        if not up or not left:
            g[yy, xx] = w
        elif not down or not right:
            g[yy, xx] = d
    if rim:
        a, b, c = rim
        for yy, xx in zip(*np.where(edge)):
            g[yy, xx] = a if xx + yy < mid else (b if xx + yy < mid + 4 else c)
        # a highlight just inside the rim, top left; a shadow just inside, bottom right
        for yy, xx in zip(ys, xs):
            if edge[yy, xx]:
                continue
            nb = [edge[yy - 1, xx], edge[yy, xx - 1], edge[yy + 1, xx], edge[yy, xx + 1]]
            if (nb[0] or nb[1]) and xx + yy < mid:
                g[yy, xx] = w
            elif (nb[2] or nb[3]) and xx + yy > mid:
                g[yy, xx] = d
    return g


def over(g, pts):
    """Paint pixels onto a part before it is outlined."""
    g = g.copy()
    for x, y, c in pts:
        if 0 <= y < 16 and 0 <= x < 16:
            g[y, x] = c
    return g


def at(x0, y0, rows_):
    out = []
    for y, r in enumerate(rows_):
        for x, c in enumerate(r):
            if c not in '. ':
                out.append((x0 + x, y0 + y, c))
    return out


def paint(y, *strs, x0=0):
    """Like rows(), but '.' and ' ' keep what is there and '_' erases."""
    out = {}
    for i, s in enumerate(strs):
        for x, c in enumerate(s):
            if c not in ' .':
                out[(x0 + x, y + i)] = '.' if c == '_' else c
    return out
