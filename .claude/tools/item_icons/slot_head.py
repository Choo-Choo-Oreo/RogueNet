"""Head: hoods (dark face opening, mantle, eyes and clasp), helms, hats and crowns, each its own shape."""
from kit import *

HOOD = ["................",
        "......wllm......",
        ".....wlllmm.....",
        "....wllllmmd....",
        "....llxxxxmd....",
        "....lxxxxxxd....",
        "...wlxxxxxxmd...",
        "...llxxxxxxmd...",
        "...llxxxxxxmd...",
        "...lllxxxxmmd...",
        "..wlllllmmmmmd..",
        ".wlllllllmmmmdd.",
        ".llllllllmmmmdd.",
        "................"]


def hood(trim=None, eyes=None, clasp=None, extra=None):
    g = grid(HOOD, 16, 16)
    if trim:   # a band around the face opening
        for y in range(16):
            for x in range(16):
                if g[y, x] in 'wlmd' and any(0 <= y + dy < 16 and 0 <= x + dx < 16 and g[y + dy, x + dx] == 'x'
                                              for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    g[y, x] = trim
    if eyes:
        g[7, 6] = eyes; g[7, 9] = eyes
    if clasp:
        g[10, 7] = clasp[0]; g[10, 8] = clasp[1]
    return place(edit(g, extra or {}))


def dome(cx=7.5, cy=8.5, r=6.0, top=1, bottom=13):
    y, x = np.mgrid[0:16, 0:16]
    return mask_circle(cx, cy, r) & (y >= top) & (y <= bottom)


def I_():
    I = {}
    I['arcane_hood'] = (hood('A', None, ('A', 'B'), {(7, 3): 'S', (8, 3): 'T', (7, 2): 'S'}), {})
    I['archmage_hood'] = (hood('S', 'A', ('A', 'B'), {**rows(0, "........wlm....."), (10, 1): 'm',
                                                      (7, 3): 'A', (8, 3): 'B'}), {})
    I['assassin_cowl'] = (hood(None, 'w', None, {**rows(8, "...llBBBBBBmd...", "...llCBBBBCmd...",
                                                         "...lllCCCCmmd...")}), {})
    I['necromancer_hood'] = (hood(None, 'A', ('S', 'T'), {(6, 8): 'C', (9, 8): 'C'}), {})
    I['rogue_hood'] = (hood('T', None, ('E', 'F'), {(12, 3): 'S', (13, 2): 'S', (13, 4): 'T', (14, 3): 'T'}),
                       dict(zip('wlmdx', ('#a8d880', '#6aa048', '#487a30', '#2e5a22', '#1a3a14'))))
    I['wraith_hood'] = (hood(None, 'A', None, {**rows(12, ".l.llll.mm.m.d..", "..........m....."),
                                               (6, 8): 'C', (9, 8): 'C'}), {})

    I['heavy_iron_helm'] = (place(grid(["................",
                                        "................",
                                        "....wllAlmmd....",
                                        "...wlllAlmmmd...",
                                        "...lllAAAmmmd...",
                                        "...llllAlmmmd...",
                                        "...llllAlmmmd...",
                                        "...xxxxxxxxxd...",
                                        "...lllllmmmmd...",
                                        "...llllAmmxmd...",
                                        "...llllAmmmxd...",
                                        "...llllAmmxmd...",
                                        "...lllllmmmmd...",
                                        "....ddddddddd...",
                                        "................",
                                        "................"])), {})
    I['militia_bucket_helm'] = (place(grid(["................",
                                            "................",
                                            "................",
                                            "......wllm......",
                                            "....wllllmmd....",
                                            "...wlllllmmmd...",
                                            "...llllllmmmd...",
                                            "...lAllAlmAmd...",
                                            "...llllllmmmd...",
                                            ".wwlllllllmmmdd.",
                                            ".llllllllmmmmmd.",
                                            "..dddddddddddd..",
                                            "................"])), mat('copper', 'ABC') | SETS['militia'] |
                                {**dict(zip('wlmd', MAT['iron'] + ('#343a44',))), 'x': '#242830',
                                 **dict(zip('ABC', MAT['copper']))})
    I['scrapper_pot_helm'] = (place(grid(["................",
                                          "................",
                                          "................",
                                          "....SSSSSTT.....",
                                          "...STTTTTTTU....",
                                          "...STTTTUTTU....",
                                          "...STTTTTTTUEEF.",
                                          "...STUTTTTTUFG..",
                                          "...STTTTTTTU....",
                                          "...STTTTTUTU....",
                                          "..SSSSSSTTTUU...",
                                          "..UUUUUUUUUUU...",
                                          "................"])), {})
    inf = place(over(shade(dome(), 'wlmdx', rim='STU'),
                     [(5, 8, 'A'), (6, 8, 'B'), (9, 8, 'B'), (10, 8, 'A'), (4, 8, 'x'), (7, 8, 'x'), (8, 8, 'x'),
                      (11, 8, 'x'), (7, 10, 'x'), (8, 10, 'x'), (7, 11, 'x'), (8, 11, 'x')]))
    horns = place([(0, 1, 'E'), (0, 2, 'E'), (1, 3, 'E'), (1, 4, 'F'), (2, 5, 'F'), (2, 6, 'G'), (1, 2, 'F'),
                   (15, 1, 'E'), (15, 2, 'F'), (14, 3, 'E'), (14, 4, 'F'), (13, 5, 'F'), (13, 6, 'G'), (14, 2, 'G')])
    I['infernal_horned_helm'] = (comp(horns, inf), {})
    mg = shade(dome(r=5.8, top=3), 'wlmdx')
    mg = over(mg, [(4, 8, 'B'), (5, 9, 'A'), (6, 9, 'B'), (10, 7, 'C'), (11, 8, 'B'), (7, 5, 'C'),
                   (5, 11, 'x'), (6, 11, 'x'), (9, 11, 'x'), (10, 11, 'x')])
    spikes = place([(4, 0, 'B'), (4, 1, 'l'), (4, 2, 'm'), (5, 2, 'l'), (7, 0, 'A'), (7, 1, 'l'), (8, 1, 'm'),
                    (7, 2, 'l'), (8, 2, 'm'), (11, 0, 'B'), (11, 1, 'm'), (11, 2, 'd'), (10, 2, 'm')])
    I['magma_horned_helm'] = (comp(spikes, place(mg)), {})
    ab = shade(dome(r=5.6, top=5, cy=9.5), 'wlmdx')
    ab = over(ab, [(x, 10, 'x') for x in range(4, 12)] + [(6, 10, 'C'), (9, 10, 'C'), (7, 12, 'x'), (8, 12, 'x')])
    fin = place(canvas_pts([(p[0], p[1], p[2]) for p in at(4, 0, ["..S.....",
                                                                   "..SS.S..",
                                                                   ".STSSS.S",
                                                                   ".STUSTSS",
                                                                   "..TUTUTU",
                                                                   "...UUUU."])]))
    sidefins = place([(1, 9, 'S'), (1, 10, 'T'), (2, 10, 'S'), (2, 11, 'T'), (14, 9, 'T'), (14, 10, 'U'),
                      (13, 10, 'T'), (13, 11, 'U')])
    I['abyssal_fin_helm'] = (comp(fin, sidefins, place(ab)), {})
    hm = shade(dome(r=5.7, top=3), 'wlmdx')
    hm = over(hm, [(x, 11, 'S') for x in range(4, 12)] + [(x, 12, 'T') for x in range(5, 11)] +
              [(5, 9, 'x'), (10, 9, 'x'), (7, 10, 'A'), (8, 10, 'A')])
    ears = place([(3, 2, 'l'), (4, 2, 'l'), (3, 3, 'A'), (4, 3, 'm'), (11, 2, 'l'), (12, 2, 'm'),
                  (11, 3, 'm'), (12, 3, 'B')])
    I['hamster_helm'] = (comp(ears, place(hm)), {})

    I['apprentice_floppy_hat'] = (place(grid(["................",
                                              "......wll.......",
                                              ".....wllmmd.....",
                                              ".....llllmmdd...",
                                              "....wlllmmm.dd..",
                                              "....lllllmm..d..",
                                              "...wllllmmmd....",
                                              "...lllSllmmd....",
                                              "..wllllllmmmd...",
                                              "..CCCCCCCCCCC...",
                                              ".wlllllllmmmmmd.",
                                              "..dddddddddddd..",
                                              "................"]), 0, 1),
                                  {**dict(zip('wlmdx', ('#b0c4f8', '#7a90d8', '#5e70b0', '#44528a', '#2a3460'))),
                                   'S': '#fff0a0', 'C': '#8a5a32'})
    ts = shade(dome(cy=9.5, r=7.0, top=2, bottom=9), 'wAABC')
    ts = over(ts, [(4, 5, 'w'), (5, 5, 'w'), (9, 4, 'w'), (10, 6, 'w'), (11, 6, 'w'), (7, 7, 'w'), (3, 8, 'w'),
                   (12, 8, 'w')])
    gills = place([(x, 10, 'S' if x % 2 else 'T') for x in range(2, 14)] + [(x, 11, 'U') for x in range(4, 12)])
    I['sporecaller_toadstool_hat'] = (comp(gills, place(ts)), {'w': '#ffffff'})
    fur = shade(dome(cy=9, r=6.0, top=3, bottom=9), 'wlmdx')
    fur = over(fur, [(5, 5, 'w'), (8, 4, 'l'), (6, 7, 'd'), (9, 6, 'd'), (4, 7, 'l')])
    band = place([(x, 10, 'S' if x % 2 else 'T') for x in range(1, 13)] + [(x, 11, 'T' if x % 2 else 'U') for x in range(1, 13)])
    tail = place([(12, 7, 'd'), (13, 7, 'S'), (13, 8, 'x'), (14, 8, 'd'), (13, 9, 'S'), (14, 9, 'S'), (13, 10, 'x'),
                  (14, 10, 'd'), (13, 11, 'S'), (14, 11, 'S'), (13, 12, 'x'), (14, 12, 'd'), (13, 13, 'S'), (14, 13, 'T')])
    I['poacher_fur_cap'] = (comp(tail, place(fur), band), {})
    cap = shade(dome(r=5.8, top=3, bottom=12), 'STTUU')
    cap = over(cap, [(x, 7, 'x') for x in range(2, 14)])
    lenses = place([(4, 6, 'l'), (5, 6, 'l'), (6, 6, 'm'), (4, 7, 'l'), (5, 7, 'A'), (6, 7, 'd'), (4, 8, 'm'),
                    (5, 8, 'B'), (6, 8, 'd'), (5, 9, 'd'),
                    (9, 6, 'l'), (10, 6, 'l'), (11, 6, 'm'), (9, 7, 'l'), (10, 7, 'A'), (11, 7, 'd'), (9, 8, 'm'),
                    (10, 8, 'B'), (11, 8, 'd'), (10, 9, 'd'), (7, 7, 'd'), (8, 7, 'd')])
    I['clockwork_goggle_cap'] = (comp(place(cap), lenses), {})
    bd = shade(dome(r=5.8, top=3, bottom=11), 'AABCC')
    bd = over(bd, [(5, 5, 'w'), (8, 4, 'w'), (10, 6, 'w'), (6, 8, 'w'), (9, 9, 'w'), (4, 9, 'w')])
    knot = place([(13, 8, 'B'), (14, 9, 'A'), (14, 10, 'B'), (13, 11, 'C'), (14, 12, 'C'), (12, 9, 'C')])
    I['cutpurse_bandana'] = (comp(knot, place(bd)), {'w': '#ffffff'})
    I['cleric_coif'] = (place(grid(["................",
                                    "................",
                                    "......wllm......",
                                    "....wllllmmd....",
                                    "...wSSSBSSTTd...",
                                    "...lllxxxxmmd...",
                                    "...llxxxxxxmd...",
                                    "...llxxxxxxmd...",
                                    "...llxxxxxxmd...",
                                    "...lllxxxxmmd...",
                                    "..wllllllmmmmd..",
                                    "..BBBBBBBBBBCC..",
                                    "................"])), {})

    I['frost_crown'] = (place(grid(["................",
                                    "................",
                                    ".......w........",
                                    "...w...wl...w...",
                                    "...wl.wlll.wl...",
                                    "..wll.wllm.wlm..",
                                    "..lllwlllmmlmm..",
                                    "..llllllmmmmmd..",
                                    "..ASlSAmSmAmSd..",
                                    "..lllllmmmmmdd..",
                                    "...dddddddddd...",
                                    "................"]), 0, 2), {})
    I['seraph_winged_circlet'] = (place(grid(["................",
                                              "................",
                                              "................",
                                              "w..............w",
                                              "ww............ww",
                                              "lww..........wwl",
                                              ".lww...SS...wwl.",
                                              "..lwABBSTBBCwl..",
                                              "...ABBBBBBBBC...",
                                              "....CCCCCCCC....",
                                              "................"]), 0, 1), {})
    y, x = np.mgrid[0:16, 0:16]
    ring = (((x - 7.5) / 6.6) ** 2 + ((y - 8.5) / 3.6) ** 2 <= 1) & ~(((x - 7.5) / 4.2) ** 2 + ((y - 8.5) / 1.6) ** 2 <= 1)
    I['starforged_halo'] = (comp(place(shade(ring, 'AABCC')),
                                 place([(7, 1, 'A'), (6, 2, 'B'), (7, 2, 'A'), (8, 2, 'B'), (7, 3, 'B')]),
                                 canvas_pts([(2, 3, 'A'), (13, 3, 'B'), (12, 14, 'A'), (3, 13, 'B')])), {})
    return I


def canvas_pts(pts):
    g = np.full((16, 16), '.', dtype='<U1')
    for x, y, c in pts:
        g[y, x] = c
    return g


ALL = I_()


def build(name):
    g, extra = ALL[name]
    return g, {**SETS[set_of(name)], **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ALL], 'sheet_head.png')
