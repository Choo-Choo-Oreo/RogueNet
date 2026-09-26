"""Neck, rings, potions, materials, misc and back items."""
import math
from kit import *
from slot_main import sword, D, canvas, part


def line(x0, y0, x1, y1):
    pts = []
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        pts.append((round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)))
    return pts


def chain(a='E', b='F', left=(3, 1), right=(12, 1), bottom=(7, 8)):
    pts = []
    for i, (x, y) in enumerate(line(*left, bottom[0], bottom[1])):
        pts.append((x, y, a if i % 2 else b))
    for i, (x, y) in enumerate(line(*right, bottom[0] + 1, bottom[1])):
        pts.append((x, y, b if i % 2 else a))
    return place(pts)


def pend(rows_, x, y):
    return place(at(x, y, rows_))


def P(base, **kw):
    """A palette for items without a set: grey base plus named letter groups."""
    p = dict(base)
    for letters, colours in kw.items():
        p.update(zip(letters, (colours,) if isinstance(colours, str) else colours))
    return p


GOLD, SILVER, IRON, COPPER = MAT['gold'], MAT['silver'], MAT['iron'], MAT['copper']
CORD = ('#b88858', '#7a5030', '#4a2e18')


def amulets():
    I = {}
    I['abyssal_pearl_amulet'] = (comp(chain('E', 'F'), pend([".EFE.", "EAABF", "EABCF", ".FBCF.", "..G.."], 5, 8)), {})
    beads = place([(2, 1, 'E'), (3, 2, 'F'), (3, 3, 'E'), (4, 4, 'F'), (4, 5, 'E'), (5, 6, 'F'), (6, 7, 'E'),
                   (13, 1, 'F'), (12, 2, 'E'), (12, 3, 'F'), (11, 4, 'E'), (11, 5, 'F'), (10, 6, 'E'), (9, 7, 'F'),
                   (2, 2, 'F'), (4, 3, 'G'), (13, 2, 'G'), (11, 3, 'G'), (5, 5, 'G'), (10, 5, 'G')])
    I['apprentice_wooden_beads'] = (comp(beads, pend([".EEF.", "EAABF", "EABBF", ".FFG."], 5, 8)), {})
    I['arcane_eye_amulet'] = (comp(chain('A', 'B'), pend([".ABBA.", "AwSSTB", "ASxxTB", "BTTUUC", ".BBCC."], 5, 8)),
                              {})
    I['archmage_sigil_amulet'] = (comp(chain('S', 'T'), pend(["..S...", ".SAB..", "SAABB.", ".ABBT.", "..BT..",
                                                              "..T..."], 5, 8)), {})
    I['arrowhead_amulet'] = (comp(chain('E', 'F'), pend(["wllmd", ".lmd.", ".lmd.", "..d.."], 5, 9)),
                             P(GREY, EFG=CORD, wlmdx=('#e8e8e0', '#a8a8a0', '#787870', '#505048', '#303028')))
    I['bone_skull_amulet'] = (comp(chain('E', 'F'), pend([".wwll.", "wllllm", "lxlmxm", "lllmmd", ".lTmd.",
                                                          ".l.m.."], 5, 8)),
                              P(GREY, EFG=CORD, wlmdx=('#fffcf0', '#e0d8c0', '#b8ac90', '#887c64', '#2a2018'),
                                T='#2a2018'))
    I['clockwork_key_amulet'] = (comp(chain('E', 'F'), pend([".lll.", "l.A.m", ".lmm.", "..l..", "..lm.", "..l..",
                                                             "..lm."], 5, 8)), {})
    I['cutpurse_lucky_coin'] = (comp(chain('E', 'F'), pend([".AAB.", "AAxBC", "ABBBC", ".BCC."], 5, 9)),
                                P(SETS['cutpurse'], ABC=GOLD))
    I['frost_icicle_amulet'] = (comp(chain('S', 'T'), pend(["wllmd", ".wlm.", ".wlm.", "..lm.", "..l..", "..A.."],
                                                           5, 8)), {})
    col = (((np.mgrid[0:16, 0:16][1] - 7.5) / 6.5) ** 2 + ((np.mgrid[0:16, 0:16][0] - 5.5) / 4.0) ** 2 <= 1) & \
          ~(((np.mgrid[0:16, 0:16][1] - 7.5) / 4.8) ** 2 + ((np.mgrid[0:16, 0:16][0] - 5.0) / 2.5) ** 2 <= 1)
    I['hamster_bell_collar'] = (comp(place(shade(col, 'ABBCC')),
                                     pend([".EF.", "EEFF", "EEFG", "GxxG"], 6, 9)),
                                P(SETS['hamster'], ABC=('#ff7070', '#d02838', '#801828'), EFG=GOLD))
    I['infernal_heart_amulet'] = (comp(chain('S', 'T'), pend([".A..A.", "ABBABC", "BBBBCC", ".BCCC.", "..CC.."],
                                                             5, 8)),
                                  P(SETS['infernal'], ABC=('#ffd060', '#f05028', '#a01818')))
    I['magma_ember_amulet'] = (comp(chain('l', 'm'), pend(["l....m", "dAAB.d", ".ABBC.", ".BBCC.", "..CC.."], 5, 8)),
                               {})
    badge = shade(mask_rows(["", "", "", "....########....", "...##########...", "...##########...",
                             "...##########...", "...##########...", "....########....", "....########....",
                             ".....######.....", "......####......", ".......##......."]), 'ABBCC')
    badge = over(badge, [(7, 5, 'A'), (8, 5, 'A'), (6, 6, 'A'), (7, 6, 'B'), (8, 6, 'B'), (9, 6, 'A'), (7, 7, 'C'),
                         (8, 7, 'C'), (7, 8, 'C')])
    pin = place([(5, 1, 'S'), (6, 1, 'S'), (7, 1, 'T'), (8, 1, 'T'), (9, 1, 'U'), (10, 1, 'U'), (5, 2, 'T'),
                 (10, 2, 'U')])
    I['militia_copper_badge'] = (comp(pin, place(badge)), {})
    I['poacher_rabbit_foot'] = (comp(chain('E', 'F'), pend([".TT.", "SSST", "SSTU", "SSTU", ".TU.", "AA.."], 6, 8)),
                                P(SETS['poacher'], EFG=CORD, A='#ffb0b8'))
    I['poison_vial_amulet'] = (comp(chain('E', 'F'), pend([".dd.", ".wl.", "wABC", "ABBC", "ABCC", ".CC."], 6, 8)),
                               P(GREY, EFG=SILVER, ABC=('#b8ff80', '#58c838', '#287a20'),
                                 wd=('#ffffff', '#7a5a40')))
    I['scrapper_spoon_charm'] = (comp(chain('E', 'F'), pend(["..S.", "..S.", "..S.", ".STT", "SSTU", "STTU", ".UU."],
                                                            5, 8)), {})
    I['seraph_feather_amulet'] = (comp(chain('A', 'B'), pend(["...wl", "..wlm", ".wlmd", "wlmd.", "lmd..", "B...."],
                                                             5, 8)), {})
    I['sporecaller_seed_charm'] = (comp(chain('S', 'T'), pend(["..wl.", ".E..", ".TTU.", "SSTTU", "STTUU", ".TUU.",
                                                               "..U.."], 5, 7)),
                                   {'w': '#b0e888', 'l': '#70ae48'})
    I['starforged_star_amulet'] = (comp(chain('S', 'T'), pend(["..A..", "..A..", "AABBC", ".ABC.", "AB.CC"], 5, 9)),
                                   {})
    I['sun_pendant_amulet'] = (comp(chain('B', 'C'), pend(["A.A.A", ".ABB.", "AAwBC", ".BBC.", "B.C.C"], 5, 9)),
                               P(GREY, ABC=GOLD, w='#ffffff'))
    I['wolf_fang_amulet'] = (comp(chain('E', 'F'), pend(["ww.ll", "wl.lm", "wl.lm", ".l..m", ".l..."], 5, 9)),
                             P(GREY, EFG=CORD, wlmdx=('#ffffff', '#e8e0c8', '#b8a888', '#887858', '#403828')))
    I['wraith_soul_amulet'] = (comp(chain('S', 'T'), pend(["T.S.T", "TABBT", "TACBT", "TBBCT", ".TTT."], 5, 8)), {})
    return I


def ring(band, gem=None, plain=False, extra=()):
    y, x = np.mgrid[0:16, 0:16]
    cy = 10.0 if gem else 8.0
    rx, ry, ix, iy = (6.6, 5.4, 3.9, 2.8) if plain else (6.2, 4.6, 3.6, 2.2)
    m = (((x - 7.5) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1) & ~(((x - 7.5) / ix) ** 2 + ((y - cy) / iy) ** 2 <= 1)
    layers = [place(shade(m, band))]
    if gem:
        layers.append(pend(gem, 5, 1))
    return comp(*layers, *extra)


GEM_ROUND = [".wAB.", "wAABC", "ABBCC", ".BCC.", "..F.."]
GEM_SQUARE = ["wAAB.", "AABBC", "ABBCC", "BCCC.", ".FF.."]


def rings():
    I = {}
    I['amethyst_ring'] = (ring('wlmdx', GEM_ROUND), P(GREY, wlmdx=SILVER + ('#686e7c', '#484c58'),
                                                     ABC=('#e8b0ff', '#a050e0', '#602090'), F='#8890a0'))
    I['sapphire_ring'] = (ring('wlmdx', GEM_SQUARE), P(GREY, wlmdx=SILVER + ('#686e7c', '#484c58'),
                                                      ABC=('#a0d0ff', '#3070e0', '#1a3a90'), F='#8890a0'))
    I['ruby_ring'] = (ring('wlmdx', GEM_ROUND), P(GREY, wlmdx=GOLD + ('#704810', '#4a2c08'),
                                                 ABC=('#ffa0a0', '#e02030', '#801020'), F='#a07020'))
    I['emerald_ring'] = (ring('wlmdx', GEM_SQUARE), P(GREY, wlmdx=GOLD + ('#704810', '#4a2c08'),
                                                     ABC=('#b0ffb0', '#20c050', '#10703a'), F='#a07020'))
    I['ember_heart_ring'] = (ring('wlmdx', [".A.A.", "ABABC", "ABBCC", ".BCC.", "..F.."]),
                             P(GREY, wlmdx=IRON + ('#343840', '#20242a'), ABC=('#ffe070', '#ff7020', '#b02010'),
                               F='#4a505c'))
    I['frostbound_ring'] = (ring('wlmdx', ["..w..", ".wAB.", "wAABC", ".BCC.", "..F.."]),
                            P(GREY, wlmdx=SILVER + ('#686e7c', '#484c58'), ABC=('#e8fcff', '#90d8f8', '#4a90c8'),
                              F='#8890a0'))
    I['voidstar_ring'] = (ring('wlmdx', ["..A..", ".ABC.", "ABxBC", ".BCC.", "C.F.C"]),
                          P(GREY, wlmdx=('#8870a8', '#5a4878', '#3c2e54', '#281e3a', '#180e24'),
                            ABC=('#f0c8ff', '#9040e0', '#401070'), F='#3c2e54'))
    I['gold_band_ring'] = (ring('wlmdx', plain=True, extra=[canvas([(3, 3, 'w'), (2, 2, 'w'), (4, 2, 'w'),
                                                                     (3, 1, 'w')])]),
                           P(GREY, wlmdx=('#fff8c0',) + GOLD + ('#6a4410',)))
    I['silver_band_ring'] = (ring('wlmdx', plain=True, extra=[canvas([(x, 8 + (x % 2) * 0, 'd') for x in ()])]),
                             P(GREY, wlmdx=('#ffffff', '#dce2ec', '#a8b0c0', '#747c8c', '#4a5060')))
    I['copper_band_ring'] = (comp(ring('wlmdx', plain=True), canvas([(3, 6, 'A'), (11, 11, 'A'), (12, 8, 'B')])),
                             P(GREY, wlmdx=('#ffc8a0',) + COPPER + ('#4a2414',), AB=('#70d0a0', '#40a070')))
    I['iron_band_ring'] = (comp(ring('lmmdx', plain=True), canvas([(2, 8, 'w'), (13, 8, 'd'), (7, 4, 'w'),
                                                                   (8, 13, 'd')])),
                           P(GREY, wlmdx=('#d0d8e0',) + IRON + ('#2a2e36',)))
    I['bone_ring'] = (comp(ring('wlmdx', plain=True), canvas([(4, 5, 'd'), (7, 4, 'd'), (10, 5, 'd'), (5, 12, 'd'),
                                                              (10, 12, 'd')])),
                      P(GREY, wlmdx=MAT['bone'] + ('#6a5c44', '#3a3020')))
    return I


def flask(rows_):
    return place(grid(rows_, 16, 16))


def potions():
    I = {}
    glass = dict(zip('wlmd', ('#ffffff', '#d8ecf4', '#98b8c8', '#607888')))
    cork = dict(zip('EFG', MAT['wood']))
    I['health_potion'] = (flask(["................",
                                 "......EEF.......",
                                 "......EFG.......",
                                 ".......l........",
                                 "......wlm.......",
                                 ".....wAABm......",
                                 "....wAABBBm.....",
                                 "...wAwABBBCm....",
                                 "...lAwABBBCm....",
                                 "...lAABBBCCm....",
                                 "...lBBBBCCCm....",
                                 "....mBBCCCm.....",
                                 ".....mmmmm......"]),
                          P(GREY, **{'wlmd': tuple(glass.values())}, **{'EFG': MAT['wood']},
                            ABC=('#ff8080', '#e02838', '#901020')))
    I['mana_potion'] = (flask(["................",
                               ".......EF.......",
                               ".......FG.......",
                               ".......lm.......",
                               ".......lm.......",
                               "......wAAm......",
                               "......wABm......",
                               ".....wAABBm.....",
                               ".....lwABCm.....",
                               "....lAABBCCm....",
                               "....lABBBCCm....",
                               "...lAABBBCCCm...",
                               "...lBBBBCCCCm...",
                               "...mmmmmmmmmm..."]),
                        P(GREY, **{'wlmd': tuple(glass.values())}, **{'EFG': MAT['wood']},
                          ABC=('#a0c8ff', '#3868e0', '#1a3090')))
    I['antidote'] = (flask(["................",
                            "......EEFF......",
                            "......EFFG......",
                            ".......lm.......",
                            ".....wllmm......",
                            "....wlllmmm.....",
                            "....lwAABBm.....",
                            "....lwABBCm.....",
                            "....lAABBCm.....",
                            "....lABBBCm.....",
                            "....lABBCCm.....",
                            "....lBBCCCm.....",
                            "....mmmmmmm....."]),
                     P(GREY, **{'wlmd': tuple(glass.values())}, **{'EFG': MAT['wood']},
                       ABC=('#c8ff90', '#60c838', '#2a7a20')))
    return I


def misc():
    I = {}
    kp = []
    for t in range(3, 11):
        x, y = D(t)
        kp += [(x, y, 'l'), (x + 1, y, 'm')]
    kp += at(1, 10, [".lll.", "lw.dm", "l...m", "lm.dm", ".mmd."]) + [(10, 6, 'l'), (11, 7, 'm'), (12, 4, 'l'),
                                                                     (13, 5, 'm'), (12, 5, 'd')]
    I['dungeon_key'] = (part(kp), P(GREY, wlmdx=('#fff8c0',) + GOLD + ('#6a4410',)))
    I['old_map'] = (place(grid(["................",
                                "................",
                                "..EEF...........",
                                ".EwllllllllmmF..",
                                ".EllldllllmmmF..",
                                ".FlBllldllmmmG..",
                                "..lllBlllldmm...",
                                "..llllBBllmmd...",
                                "..lldllllAmmd...",
                                "..llllllAAAmd...",
                                ".EllldllmAmmmF..",
                                ".FllllllmmmmmG..",
                                ".FlllmmmmmmmdG..",
                                "..........FFG..."])),
                    P(GREY, wlmdx=MAT['paper'] + ('#806040', '#503820'), EFG=MAT['wood'],
                      AB=('#e02020', '#8a6a48')))
    cap = shade(mask_circle(7.5, 7.5, 5.8) & (np.mgrid[0:16, 0:16][0] <= 7), 'wAABC')
    stem = place(at(6, 8, [".SS.", ".ST.", "SSTU", ".TU."]))
    I['glowcap'] = (comp(stem, place(over(cap, [(8, 4, 'w'), (5, 5, 'w'), (10, 6, 'w')])),
                         canvas([(2, 1, 'A'), (13, 2, 'B'), (12, 11, 'A')])),
                    P(GREY, w='#e8fffa', ABC=('#90fff0', '#30c0c0', '#1a7888'), STU=('#fff4e0', '#d8c8b0', '#a09080')))
    ore = shade(mask_rows(["", "", "", "......####......", "....#######.....", "...#########....",
                           "..###########...", "..############..", "..############..", "...###########..",
                           "....#########...", ".....######....."]), 'lmmdx')
    ore = over(ore, [(5, 5, 'A'), (6, 5, 'B'), (9, 7, 'A'), (10, 7, 'B'), (4, 9, 'B'), (7, 9, 'A'), (11, 10, 'B'),
                     (6, 4, 'w'), (4, 6, 'w')])
    I['iron_ore'] = (place(ore), P(GREY, wlmdx=('#a89888', '#7a6c60', '#5a5048', '#3c3430', '#241e1c'),
                                   AB=('#e8f0f8', '#98a8b8')))
    bp = []
    for t in range(3, 11):
        x, y = D(t)
        bp += [(x, y, 'w'), (x + 1, y, 'm'), (x, y - 1, 'l')]
    bp += at(0, 10, [".wl..", "wllm.", "lmmd.", ".mdd.", "....."]) + at(10, 1, [".wl..", "wllm.", "lmmd.", ".md.."])
    I['monster_bone'] = (part(bp), P(GREY, wlmdx=MAT['bone'] + ('#6a5c44', '#3a3020')))
    return I


def back():
    I = {}
    # sword in its scabbard, with the belt strap across it
    sc = []
    for t in range(4, 13):
        x, y = D(t)
        sc += [(x, y, 'S'), (x + 1, y, 'T'), (x, y - 1, 'S'), (x + 1, y + 1, 'U')]
    sc += [(13, 1, 'A')]
    hil = [(2, 9, 'A'), (3, 10, 'B'), (4, 11, 'B'), (5, 12, 'C'), (3, 12, 'x'), (2, 13, 'x'), (1, 14, 'A'),
           (4, 10, 'A')]
    strap = [(x, 13 - x + 2 * (x // 1) - x, 'E') for x in ()]
    I['back_sword'] = (comp(part(sc), part(hil), place([(8, 4, 'E'), (9, 5, 'E'), (10, 6, 'F'), (7, 3, 'E')])),
                       P(GREY, STU=MAT['leather'], ABC=GOLD, EFG=('#c8a070', '#8a6040', '#5a3a20'),
                         x='#3a2a20'))
    I['backpack'] = (place(grid(["................",
                                 "......xxxx......",
                                 ".....x....x.....",
                                 "...EEEEEEEEF....",
                                 "..EEEEEEEEEFG...",
                                 "..EEEEEEEEFFG...",
                                 "..wlllAAlllmd...",
                                 "..llllABllmmd...",
                                 "..lllllllmmmd...",
                                 ".SlllllllmmmdT..",
                                 ".SllllllmmmmdT..",
                                 ".TlSSSSSTTmmdU..",
                                 "..lSSSSSTTmmd...",
                                 "..mmmmmmmmmdd...",
                                 "................"])),
                     P(GREY, wlmdx=MAT['leather'][:1] + MAT['leather'] + ('#2e1a0e',), EFG=('#8ab860', '#5a8a38', '#34581c'),
                       ABC=GOLD, STU=('#d0a070', '#a07048', '#6a4428')))
    cape = place(grid(["................",
                       "................",
                       ".....AB..BC.....",
                       "....wlllmmmd....",
                       "...wllllmmmmd...",
                       "...llllmlmmmd...",
                       "..wlllmllmmmmd..",
                       "..llldlllmdmmd..",
                       "..llllmllmmmmd..",
                       ".wlllldlllmdmmd.",
                       ".lllllmllmmmmmd.",
                       ".llllldllmmdmmd.",
                       ".lllllllmmmmmdd.",
                       ".ld.ll.lm.mm.dd.",
                       "................"]))
    I['crimson_cape'] = (comp(cape, place([(6, 1, 'A'), (7, 1, 'B'), (8, 1, 'B'), (9, 1, 'C')])),
                         P(GREY, wlmdx=('#ff8070', '#d83838', '#a82030', '#781828', '#4a0e18'), ABC=GOLD))
    I['hamster_sack'] = (place(grid(["................",
                                     "......l..m......",
                                     ".....AlxxmB.....",
                                     "......xxxx......",
                                     ".....wllmmd.....",
                                     "....wlllmmmd....",
                                     "...wllllmmmmd...",
                                     "..wlllllmmmmmd..",
                                     "..lllSllmmmmmd..",
                                     "..llllllmmmSmd..",
                                     "..lllllmmmmmdd..",
                                     "...llllmmmmdd...",
                                     "....mmmmmddd....",
                                     "................"])),
                         P(SETS['hamster'], wlmdx=('#e8c898', '#c8a070', '#a07848', '#7a5430', '#4a3018'),
                           S='#e8924a'))
    for colour, cols in (('blue', ('#a0c8ff', '#3868e0', '#1a3090')), ('green', ('#b0f090', '#40b040', '#1a6a28')),
                         ('red', ('#ff9080', '#d83838', '#801828')), ('yellow', ('#fff8a0', '#f0c830', '#a07818'))):
        flag = place(grid(["................",
                           "................",
                           "...AAAAAAAAAB...",
                           "...AAAAAAAABB...",
                           "...ABBBBBBBC....",
                           "...ABBBBBC......",
                           "...ABBBC........",
                           "...ABC..........",
                           "...C............"]))
        polep = place([(2, y, 'E') for y in range(1, 15)] + [(2, 0, 'S')])
        I[f'pennant_{colour}'] = (comp(polep, flag), P(GREY, ABC=cols, E='#8a5a32', S='#e8b840'))
    qv = []
    for t in range(1, 9):
        x, y = D(t)
        qv += [(x, y, 'l'), (x + 1, y, 'm'), (x, y - 1, 'w'), (x + 1, y + 1, 'd'), (x + 2, y + 1, 'd')]
    arrows = [(10, 3, 'S'), (11, 2, 'S'), (12, 1, 'A'), (11, 4, 'S'), (12, 3, 'S'), (13, 2, 'B'), (9, 2, 'S'),
              (10, 1, 'A'), (13, 3, 'A'), (11, 1, 'B'), (14, 3, 'B')]
    I['quiver'] = (comp(place(arrows), part(qv), place([(4, 10, 'E'), (5, 11, 'E'), (7, 8, 'E'), (8, 9, 'E')])),
                   P(GREY, wlmdx=MAT['leather'][:1] + MAT['leather'] + ('#2e1a0e',), S='#c8a070',
                     AB=('#ffffff', '#d03030'), E='#e8b840'))
    return I


ALL = {**amulets(), **rings(), **potions(), **misc(), **back()}


def build(name):
    g, extra = ALL[name]
    s = set_of(name)
    return g, {**(SETS[s] if s else GREY), **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ALL], 'sheet_small.png', cols=13)
