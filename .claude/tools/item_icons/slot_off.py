"""Off-hand: shields (each its own shape), books, orb, knives and odd things."""
import math
from kit import *
from slot_main import sword, D, canvas, part

HEATER = mask_rows(["................",
                    "..############..",
                    "..############..",
                    "..############..",
                    "..############..",
                    "..############..",
                    "..############..",
                    "..############..",
                    "..############..",
                    "...##########...",
                    "...##########...",
                    "....########....",
                    ".....######.....",
                    "......####......",
                    ".......##......."])
KITE = mask_rows(["................",
                  "......####......",
                  "....########....",
                  "...##########...",
                  "...##########...",
                  "...##########...",
                  "...##########...",
                  "....########....",
                  "....########....",
                  ".....######.....",
                  ".....######.....",
                  "......####......",
                  "......####......",
                  ".......##......."])
HEX = mask_rows(["................",
                 ".......##.......",
                 "......####......",
                 ".....######.....",
                 "....########....",
                 "...##########...",
                 "...##########...",
                 "...##########...",
                 "...##########...",
                 "...##########...",
                 "....########....",
                 ".....######.....",
                 "......####......",
                 ".......##......."])


def shifted(mask, dy):
    return np.roll(mask, dy, axis=0)


def heater_emblem(rim, field, pts=()):
    return place(over(shade(HEATER, field, rim=rim), pts))


def shell():
    y, x = np.mgrid[0:16, 0:16]
    m = mask_circle(7.5, 8.5, 6.6) & (y <= 10)
    m |= mask_rows(["", "", "", "", "", "", "", "", "", "", "", "...##########...", "....########....",
                    "......####......", "......####......"])
    g = shade(m, 'ASTUU')
    for ang in (-60, -30, 0, 30, 60):       # ridges fanning out from the hinge
        a = math.radians(ang - 90)
        for r in range(2, 9):
            px_, py_ = round(7.5 + r * math.cos(a)), round(12.5 + r * math.sin(a))
            if 0 <= px_ < 16 and 0 <= py_ < 16 and m[py_, px_] and py_ > 1:
                g[py_, px_] = 'U'
    g = over(g, [(7, 13, 'A'), (8, 13, 'B')])
    return place(g)


def round_shield(r, field, rim, pts=()):
    return place(over(shade(mask_circle(7.5, 7.5, r), field, rim=rim), pts))


def cog():
    m = mask_circle(7.5, 7.5, 5.4)
    for k in range(8):
        a = k * math.pi / 4
        cx, cy = 7.5 + 6.3 * math.cos(a), 7.5 + 6.3 * math.sin(a)
        m |= mask_circle(cx, cy, 1.2)
    g = shade(m, 'wlmdx')
    ring = mask_circle(7.5, 7.5, 3.2) & ~mask_circle(7.5, 7.5, 2.2)
    g[ring] = 'x'
    g = over(g, at(6, 6, ["AA", "AB"]) + [(8, 7, 'C'), (8, 6, 'B')])
    return place(g)


def book(field, pts=(), torn=()):
    rows_ = ["................",
             "................",
             "..wllllllll.....",
             "..lllllllmmPP...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..lllllllmmPQ...",
             "..mmmmmmmmdPQ...",
             "...QQQQQQQQQQ..."]
    g = grid(rows_, 16, 16)
    g[:, 2] = np.where(g[:, 2] != '.', 'd', '.')   # spine
    g[2, 2] = 'm'
    g = over(g, pts)
    for x, y in torn:
        g[y, x] = '.'
    return place(g)


BOTTLE_GREEN = {'w': '#eaffd8', 'l': '#90dc68', 'm': '#50a844', 'd': '#2c6e2c', 'x': '#1a4418'}
GLASS = {'w': '#ffffff', 'l': '#b8d4cc', 'm': '#80a098', 'd': '#4a6a64', 'x': '#2a3a38'}
FIRE = {'A': '#fff8c0', 'B': '#ffc030', 'C': '#e05818'}
SEED = {'w': '#8a8490', 'l': '#5a5460', 'm': '#443e4a', 'd': '#2c2830', 'x': '#1a1620'}


def items():
    I = {}
    I['abyssal_shell_shield'] = (shell(), {})
    I['cleric_buckler'] = (round_shield(5.6, 'wlmdx', 'STU',
                                        [(7, 4, 'B'), (7, 5, 'B'), (7, 6, 'B'), (7, 7, 'B'), (7, 8, 'B'), (7, 9, 'C'),
                                         (8, 5, 'C'), (8, 6, 'C'), (8, 8, 'C'), (8, 9, 'C'), (5, 6, 'B'), (6, 6, 'B'),
                                         (9, 6, 'C'), (10, 6, 'C'), (8, 7, 'C')]), {})
    I['clockwork_cog_shield'] = (cog(), {})
    I['frost_crystal_shield'] = (place(over(shade(HEX, 'wlmdx'),
                                            [(7, 2, 'w'), (7, 3, 'w'), (7, 4, 'w'), (7, 5, 'w'), (7, 6, 'A'),
                                             (7, 7, 'w'), (7, 8, 'l'), (7, 9, 'l'), (7, 10, 'l'), (7, 11, 'm'),
                                             (5, 5, 'w'), (4, 6, 'w'), (6, 7, 'l'), (9, 7, 'd'), (10, 6, 'd'),
                                             (11, 5, 'd'), (5, 9, 'l'), (9, 10, 'd'), (10, 9, 'd')])), {})
    seed = mask_rows(["................",
                      ".......##.......",
                      "......####......",
                      ".....######.....",
                      "....########....",
                      "....########....",
                      "...##########...",
                      "...##########...",
                      "...##########...",
                      "...##########...",
                      "...##########...",
                      "....########....",
                      "....########....",
                      ".....######.....",
                      "......####......"])
    sg = shade(seed, 'wlmdx')
    for y in range(2, 15):
        for x in (5, 7, 10):
            if seed[y, x] and y not in (1,):
                sg[y, x] = 'S' if x != 10 else 'T'
    I['hamster_seed_shield'] = (place(over(sg, [(7, 1, 'S'), (6, 2, 'S')])), SEED)
    I['heavy_iron_shield'] = (heater_emblem('FGG', 'wlmdx',
                                            [(7, y, 'd') for y in range(2, 13)] + [(x, 6, 'd') for x in range(3, 13)] +
                                            [(6, 5, 'A'), (7, 5, 'A'), (8, 5, 'B'), (6, 6, 'A'), (7, 6, 'B'),
                                             (8, 6, 'C'), (6, 7, 'B'), (7, 7, 'C'), (8, 7, 'C'),
                                             (4, 3, 'F'), (10, 3, 'F'), (4, 10, 'F'), (10, 10, 'F')]), {})
    inf = place(over(shade(shifted(HEATER, 1), 'wlmdx', rim='STU'),
                     [(5, 6, 'A'), (6, 6, 'B'), (9, 6, 'B'), (10, 6, 'A'), (4, 5, 'x'), (5, 5, 'x'),
                      (10, 5, 'x'), (11, 5, 'x'), (5, 9, 'x'), (6, 9, 'E'), (7, 9, 'x'), (8, 9, 'x'),
                      (9, 9, 'E'), (10, 9, 'x'), (6, 10, 'E'), (9, 10, 'E')]))
    horns = place(at(0, 0, ["E..............E",
                            "EF............FF",
                            ".EF..........FG."]))
    I['infernal_demon_shield'] = (comp(horns, inf), {})
    ob = KITE.copy()
    for x, y in [(6, 1), (9, 1), (3, 3), (12, 5), (3, 6), (12, 8), (5, 10)]:
        ob[y, x] = False
    I['magma_obsidian_shield'] = (place(over(shade(ob, 'wlmdx'),
                                             [(7, 3, 'B'), (7, 4, 'A'), (8, 5, 'B'), (6, 6, 'B'), (8, 6, 'A'),
                                              (9, 7, 'B'), (5, 7, 'C'), (7, 8, 'B'), (8, 9, 'C'), (7, 10, 'C'),
                                              (10, 4, 'C')])), {})
    wood = shade(mask_circle(7.5, 7.5, 6.6), 'EEFGG', rim='STU')
    for y in range(16):
        for x in (5, 10):
            if wood[y, x] in 'EFG':
                wood[y, x] = 'G'
    I['militia_wooden_shield'] = (place(over(wood, at(6, 6, ["ST", "TU"]) + [(7, 6, 'S')])), {})
    plank = mask_rows(["................",
                       "..###.####.###..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..############..",
                       "..###.#####.##..",
                       "................"])
    pg = shade(plank, 'EEFGG')
    for y in range(16):
        for x in (5, 10):
            if plank[y, x]:
                pg[y, x] = 'x'
    for i in range(10):
        pg[3 + i, 3 + i] = 'F' if i % 2 else 'E'
    pg = over(pg, [(3, 3, 'S'), (12, 3, 'S'), (3, 12, 'S'), (12, 12, 'S'), (8, 8, 'T'), (4, 8, 'A'), (11, 6, 'B')])
    I['scrapper_plank_shield'] = (place(pg), {})
    ser = place(over(shade(shifted(HEATER, 1), 'wlmdx', rim='ABC'),
                     [(7, 5, 'B'), (8, 5, 'B'), (6, 6, 'B'), (7, 6, 'A'), (8, 6, 'A'), (9, 6, 'B'), (6, 7, 'B'),
                      (7, 7, 'A'), (8, 7, 'B'), (9, 7, 'C'), (7, 8, 'C'), (8, 8, 'C'), (7, 3, 'B'), (4, 6, 'B'),
                      (11, 6, 'C'), (7, 10, 'C')]))
    wings = place(at(0, 2, ["w..............w",
                            "ww............wl",
                            "lw............lm",
                            ".l............m."]))
    I['seraph_aegis'] = (comp(wings, ser), {})

    # books
    I['apprentice_tattered_book'] = (book('wlmdx', [(5, 6, 'A'), (6, 6, 'B'), (5, 7, 'B'), (6, 7, 'C'),
                                                     (7, 9, 'x'), (4, 10, 'x'), (8, 4, 'd')],
                                          torn=[(10, 2), (2, 13), (12, 3)]),
                                     {**dict(zip('wlmdx', ('#c88858', '#9a5a38', '#7a4028', '#5a2c1c', '#3a1a10'))),
                                      'P': '#fff0d0', 'Q': '#d0b890'})
    I['archmage_codex'] = (book('wlmdx', [(2, 2, 'S'), (3, 2, 'S'), (2, 3, 'S'), (9, 2, 'S'), (10, 2, 'S'),
                                          (10, 3, 'T'), (2, 12, 'T'), (2, 13, 'T'), (3, 13, 'T'), (10, 13, 'U'),
                                          (9, 13, 'U'), (10, 12, 'U'),
                                          (6, 6, 'A'), (7, 6, 'B'), (5, 7, 'A'), (6, 7, 'B'), (7, 7, 'B'),
                                          (8, 7, 'C'), (6, 8, 'B'), (7, 8, 'C'), (6, 5, 'S'), (6, 9, 'T'),
                                          (4, 7, 'S'), (9, 7, 'T')]),
                           {'P': '#fff0d0', 'Q': '#d0b890'})
    orb = shade(mask_circle(7.5, 6.5, 4.6), 'Slmdx')
    orb = over(orb, [(5, 4, 'w'), (6, 4, 'w'), (5, 5, 'w'), (8, 7, 'T'), (9, 5, 'S')])
    stand = place(at(4, 10, [".A....B.",
                             "AABBBBCC",
                             ".BBBBCC.",
                             "..BCCC..",
                             ".ABBBCC."]))
    I['arcane_orb'] = (comp(stand, place(orb)), {'w': '#ffffff'})
    I['assassin_stiletto'] = (sword(8, 3, 'S', 'T', None, ('B', 'C', 'A'), 'x', ('B', 'C'), 1), {})
    I['rogue_hunting_knife'] = (sword(6, 4, 'E', 'F', 'E', ('T', 'U', 'S'), 'S', ('S', 'T'), 1,
                                      extra=[(9, 4, 'E'), (11, 3, 'E')]), {})
    I['wraith_spectral_dagger'] = (sword(7, 3, 'A', 'B', 'C', ('S', 'T', 'S'), 'x', ('C', 'B'), 1,
                                         extra=[(13, 5, 'C'), (9, 9, 'C')]), {})
    # broken bottle, held by the neck, jagged end to the top right
    bp = []
    for t in range(1, 5):
        x, y = D(t)
        bp += [(x, y, 'l'), (x + 1, y, 'd')]
    for t in range(5, 11):
        x, y = D(t)
        bp += [(x, y - 1, 'w' if t < 9 else 'l'), (x, y, 'l'), (x + 1, y, 'm'), (x + 1, y + 1, 'd'),
               (x - 1, y - 1, 'l'), (x + 2, y + 1, 'd')]
    bp += [(12, 2, 'l'), (13, 4, 'm'), (10, 1, 'w')]
    bp = [p for p in bp if (p[0], p[1]) not in [(11, 3), (12, 4), (10, 2)]]
    I['cutpurse_broken_bottle'] = (part(bp + [(1, 14, 'x'), (2, 13, 'd')]), BOTTLE_GREEN)
    phyl = grid(["................",
                 "......STS.......",
                 "....SSSTTTU.....",
                 ".....dxxxd......",
                 "....lwlllmd.....",
                 "...lwABBBCmd....",
                 "...lABAABCmd....",
                 "...lBAABBCmd....",
                 "...lBBBCCCmd....",
                 "...lmBCCCmdd....",
                 "....mmmmmdd.....",
                 "...SSSTTTTUU....",
                 "....TTUUUU......"], 16, 16)
    I['necromancer_phylactery'] = (place(phyl, 1, 1), GLASS)
    tp = []
    for t in range(0, 8):
        x, y = D(t)
        tp += [(x, y, 'E'), (x + 1, y, 'F')]
    for t in (8, 9):
        x, y = D(t)
        tp += [(x, y, 'S'), (x + 1, y, 'T'), (x, y - 1, 'S'), (x + 1, y + 1, 'U')]
    flame = at(10, 0, ["...A.",
                       "..AB.",
                       ".ABBA",
                       "ABBC.",
                       ".BC.."])
    I['poacher_torch'] = (comp(part(tp), place(canvas(flame))), {**mat('wood', 'EFG'), **FIRE})
    pod = shade(mask_circle(7.5, 9.5, 4.8), 'wlmdx')
    pod = over(pod, [(5, 8, 'B'), (9, 7, 'B'), (8, 11, 'B'), (6, 12, 'C'), (10, 10, 'C'), (6, 7, 'A')])
    stalk = place(at(7, 2, ["S.", "ST", ".T"]))
    spores = canvas([(3, 2, 'E'), (11, 1, 'E'), (12, 4, 'F'), (4, 4, 'F'), (13, 2, 'E')])
    I['sporecaller_spore_pod'] = (comp(stalk, place(pod), spores), {})
    moon = mask_circle(7.5, 7.5, 6.3) & ~mask_circle(10.5, 5.5, 5.2)
    I['starforged_moon'] = (comp(place(shade(moon, 'AABCC')),
                                 canvas([(12, 11, 'A'), (13, 12, 'B'), (11, 12, 'B'), (12, 13, 'B'), (12, 12, 'A'),
                                         (13, 2, 'A'), (9, 14, 'B')])), {})
    return I


ALL = items()


def build(name):
    g, extra = ALL[name]
    return g, {**SETS[set_of(name)], **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ALL], 'sheet_off.png')
