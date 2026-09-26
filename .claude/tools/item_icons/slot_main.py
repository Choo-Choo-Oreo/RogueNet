"""Main-hand weapons: all on the bold 45-degree diagonal (concept 2a), point to the top right."""
import math
from kit import *


def D(t, x0=1, y0=14):
    return (x0 + t, y0 - t)


def canvas(pts):
    g = np.full((16, 16), '.', dtype='<U1')
    for x, y, c in pts:
        if 0 <= x < 16 and 0 <= y < 16:
            g[y, x] = c
    return g


def part(pts):
    return outline(canvas(pts))


def blade(t0, t1, edge='w', body='m', top=None):
    """2px blade along the diagonal, 3px when top is given (the upper-left side)."""
    p = []
    for t in range(t0, t1 + 1):
        x, y = D(t)
        p.append((x, y, edge))
        if t < t1:
            p.append((x + 1, y, body))
            if top:
                p.append((x, y - 1, top))
    return p


def shaft(t0, t1, a='F', b='G'):
    """1px pole along the diagonal, with a shade pixel under it."""
    p = []
    for t in range(t0, t1 + 1):
        x, y = D(t)
        p.append((x, y, a))
        p.append((x + 1, y, b))
    return p


def guard(t, a='B', b='C', hi='A', size=2):
    x, y = D(t)
    p = [(x + k, y + k, a if k < 0 else b) for k in range(-size, size + 1)]
    p += [(x - size, y - size, hi), (x, y - 1, hi), (x + 1, y, b)]
    return p


def hilt(t, grip='x', pommel='w', pom2='l'):
    return [(*D(t - 1), grip), (*D(t - 2), grip), (*D(t - 3), pommel), (D(t - 3)[0] - 1, D(t - 3)[1], pom2),
            (D(t - 3)[0], D(t - 3)[1] + 1, pom2)]


def sword(L=9, h=3, edge='w', body='m', top=None, g=('B', 'C', 'A'), grip='x', pom=('w', 'l'), gsize=2, extra=()):
    p = blade(h + 1, h + L, edge, body, top) + guard(h, *g, size=gsize) + hilt(h, grip, *pom)
    return part(p + list(extra))


def pole(t0, t1, a='F', b='G', head=(), head_line=True):
    """A shaft with a separately outlined head on top."""
    return comp(part(shaft(t0, t1, a, b)), part(list(head)) if head_line else canvas(list(head)))


def at(x0, y0, rows_):
    """Pixels from a little ascii block placed at (x0, y0)."""
    out = []
    for y, r in enumerate(rows_):
        for x, c in enumerate(r):
            if c not in '. ':
                out.append((x0 + x, y0 + y, c))
    return out


def bow(t0, t1, bulge, limb=('F', 'G'), string='S', grip='C', tips='E'):
    """A bow across the diagonal: the string is straight, the limb bows toward the top left."""
    n = t1 - t0
    lim, strg = [], []
    for i in range(n + 1):
        t = t0 + i
        x, y = D(t)
        strg.append((x, y, string))
        b = round(bulge * math.sin(math.pi * i / n))
        lim.append((x - b, y - b, limb[0]))
        lim.append((x - b + 1, y - b, limb[1]))
        if 0 < i < n:
            lim.append((x - b, y - b + 1, limb[1]))  # close the staircase
    # grip at the middle of the limb
    m = n // 2
    x, y = D(t0 + m)
    b = round(bulge)
    lim += [(x - b, y - b, grip), (x - b + 1, y - b, grip), (x - b + 1, y - b + 1, grip)]
    lim += [(*D(t0), tips), (*D(t1), tips)]
    return comp(canvas(strg), part(lim))


ITEMS = {
    'heavy_iron_longsword': lambda: sword(9, 3, 'w', 'm', None, ('B', 'C', 'A'), 'T', ('A', 'B')),
    'infernal_greatsword': lambda: sword(9, 3, 'A', 'l', 'w', ('E', 'F', 'E'), 'x', ('B', 'C'), 2,
                                         extra=[(8, 3, 'l'), (11, 4, 'B')]),
    'magma_lava_blade': lambda: comp(sword(9, 3, 'B', 'm', 'l', ('d', 'x', 'l'), 'x', ('B', 'C')),
                                     canvas([(7, 8, 'A'), (9, 6, 'A'), (11, 4, 'B'), (8, 6, 'C')])),
    'militia_rusty_sword': lambda: comp(sword(7, 4, 'S', 'T', None, ('F', 'G', 'E'), 'd', ('T', 'U')),
                                        canvas([(8, 9, 'C'), (10, 7, 'B'), (11, 5, 'C'), (7, 9, 'B')])),
    'hamster_carrot_sword': lambda: sword(8, 4, 'w', 'l', 'l', ('E', 'F', 'E'), 'G', ('E', 'F'),
                                          extra=[(7, 8, 'd'), (9, 6, 'd'), (11, 4, 'd'), (12, 2, 'm')]),
    'assassin_fang': lambda: sword(6, 4, 'S', 'T', 'S', ('B', 'C', 'A'), 'x', ('B', 'C'), 1,
                                   extra=[(11, 5, 'B'), (9, 6, 'B'), (12, 3, 'S')]),
    'cutpurse_chipped_knife': lambda: comp(sword(5, 5, 'w', 'l', None, ('F', 'G', 'E'), 'F', ('E', 'F'), 1),
                                           canvas([(8, 7, 'k'), (10, 5, 'k')])),
    'apprentice_crooked_staff': lambda: pole(0, 9, 'E', 'F', at(9, 1, [".EEF.",
                                                                       "E.AFG",
                                                                       "E.BF.",
                                                                       "..FG."])),
    'arcane_staff': lambda: pole(0, 9, 'E', 'F', at(9, 0, ["..SS..",
                                                             ".SwSU.",
                                                             "ASSTUB",
                                                             ".BTUB.",
                                                             "..BC..",
                                                             "..C..."])),
    'archmage_void_staff': lambda: pole(0, 8, 'E', 'F', at(8, 0, ["..T...",
                                                                  ".TAAB.",
                                                                  "TAABBC",
                                                                  ".ABBCT",
                                                                  "..BCT.",
                                                                  "...T.."])),
    'sporecaller_glowcap_staff': lambda: pole(0, 9, 'T', 'U', at(8, 0, [".EEEE.",
                                                                        "EEwEEF",
                                                                        "FEEFFG",
                                                                        "..TT..",
                                                                        "..T..."])),
    'starforged_staff': lambda: pole(0, 9, 'S', 'T', at(9, 0, ["..A..",
                                                               ".ABB.",
                                                               "AABBC",
                                                               ".BBC.",
                                                               ".C.C."])),
    'necromancer_bone_wand': lambda: pole(2, 8, 'S', 'T', at(9, 2, [".SSS.",
                                                                    "SASAT",
                                                                    "SSSTU",
                                                                    ".T.U."])),
    'seraph_sun_scepter': lambda: pole(0, 8, 'A', 'C', at(8, 0, ["..A..A",
                                                                 ".ABBA.",
                                                                 "ABwBBA",
                                                                 ".BBBC.",
                                                                 "A.CC.A"])),
    'cleric_mace': lambda: pole(0, 8, 'E', 'F', at(8, 1, [".m.l.",
                                                          "mwlll",
                                                          ".lTlm",
                                                          "llmmd",
                                                          ".m.d."])),
    'scrapper_nail_club': lambda: comp(part(shaft(0, 5, 'F', 'G') + at(6, 2, ["...EE..",
                                                                              "..EEFF.",
                                                                              ".EEEFFG",
                                                                              "EEEFFG.",
                                                                              "EEFFG..",
                                                                              ".FFG...",
                                                                              "..G...."])),
                                       canvas([(8, 1, 'S'), (13, 3, 'S'), (6, 4, 'S'), (12, 6, 'T')])),
    'clockwork_wrench': lambda: pole(0, 8, 'F', 'G', at(8, 0, [".E..E.",
                                                               ".EF.EF",
                                                               "EFF.FG",
                                                               "EFFFG.",
                                                               ".FFG..",
                                                               "..G..."])),
    'abyssal_trident': lambda: pole(0, 8, 'F', 'G', [(8, 3, 'l'), (9, 4, 'l'), (10, 5, 'm'), (11, 6, 'm'),
                                                    (12, 7, 'd'), (9, 5, 'd'), (10, 6, 'd'),
                                                    (9, 2, 'l'), (10, 1, 'w'), (11, 4, 'l'), (12, 3, 'l'),
                                                    (13, 2, 'l'), (14, 1, 'w'), (13, 6, 'l'), (14, 5, 'w'),
                                                    (12, 4, 'm'), (13, 3, 'm')]),
    'frost_icicle_spear': lambda: pole(0, 8, 'S', 'T', at(9, 0, ["....w",
                                                                  "..wl.",
                                                                  ".wlm.",
                                                                  "Ald..",
                                                                  "A.A.."])),
    'poacher_shortbow': lambda: bow(2, 11, 2.5, ('E', 'F'), 'S', 'C', 'E'),
    'rogue_longbow': lambda: bow(0, 13, 3.5, ('l', 'm'), 'S', 'B', 'w'),
    'wraith_bonebow': lambda: bow(0, 13, 3.5, ('S', 'T'), 'B', 'C', 'A'),
}

EXTRA = {
    'hamster_carrot_sword': {},
    'militia_rusty_sword': {},
    'cutpurse_chipped_knife': {**mat('wood', 'EFG'), 'w': '#e8ecf0', 'l': '#a0a8b4'},
    'rogue_longbow': {},
    'cleric_mace': {'T': '#30b070'},
}


def build(name):
    return ITEMS[name](), {**SETS[set_of(name)], **EXTRA.get(name, {})}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ITEMS], 'sheet_main.png')
