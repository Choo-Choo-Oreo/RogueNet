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
    # Infernal: a closed great-helm, gold brow band, T-slit with glowing eyes, bone horns sweeping up
    inf_helm = ["................",
                "................",
                "................",
                "......wlll......",
                "....wwlllllm....",
                "...wllllllmmd...",
                "...wllllllmmd...",
                "...ABBBBBBBBC...",
                "...lxxBxxBxxd...",
                "...llllxxmmmd...",
                "...llllxxmmmd...",
                "...wlllxxmmmd...",
                "....lllxxmmd....",
                ".....llmmmd.....",
                "................",
                "................"]
    horn = ["................",
            ".E..............",
            ".EF.............",
            ".EF.............",
            "..FG............",
            "..FGG...........",
            "...GG...........",
            "................"]
    infernal = comp(place(horn), place(horn, mirror=True), place(inf_helm))

    # Magma: a pointed bascinet of dark rock, Y-shaped face opening, lava cracks, jagged crest
    mag = ["................",
           ".......w........",
           "......wll.......",
           ".....wllmm......",
           "....wllllmd.....",
           "...wlllCllmd....",
           "...llllBlmmd....",
           "..wlllBlllmmd...",
           "..llxxxlxxxmd...",
           "..llBxxlxxBmd...",
           "..lllxxxxmmmd...",
           "..llllxxmmCmd...",
           "..wlllxxmmBmmd..",
           ".wllllxxmmmmmd..",
           "..dddd..ddddd...",
           "................"]
    rock = ["................",
            "................",
            ".B..............",
            ".CS.............",
            ".TSS............",
            "..TSS...........",
            "...TT...........",
            "................"]
    magma = comp(place(rock), place(rock, mirror=True), place(mag))

    # Abyssal: a sea-helm, fin crest front to back, gill cheek plates, a narrow visor, side fins
    aby = ["................",
           "................",
           "................",
           ".....wwlll......",
           "....wlllllmm....",
           "...wlllllllmd...",
           "...lllllllmmd...",
           "...xxBxxxxBxd...",
           "...lxxxxxxxmd...",
           "...wTlllllTmd...",
           "...lTllxllTmd...",
           "...lTlxxxlTmd...",
           "....llllllmd....",
           ".....dddddd.....",
           "................"]
    fin = ["....S...........",
           "....SS..S.......",
           "....STS.SS.S....",
           ".....STSTSSS....",
           ".....TTUTTUU....",
           "................"]
    sidefin = ["................",
               "................",
               "................",
               "................",
               "................",
               "................",
               "................",
               "S...............",
               "SS..............",
               "STS.............",
               ".TT.............",
               "..U.............",
               "................"]
    abyssal = comp(place(sidefin), place(sidefin, mirror=True), place(aby, 0, 1), place(fin, 0, 0))

    # Hamster: a nasal helm in fur colours, round ears, puffy cream cheek guards, pink nose
    ham = ["................",
           "................",
           "................",
           "......wSSl......",
           ".....wlSTlm.....",
           "....wllSTlmm....",
           "...wlllSTllmd...",
           "...llllSTlmmd...",
           "...CCCCCCCCCC...",
           "...SxxxSTxxxU...",
           "..SSTxxSTxxTUU..",
           "..STTTxSTxTTUU..",
           "..STTTxABxTTUU..",
           "..STTUxxxxTUUU..",
           "...TU......UU...",
           "................"]
    ham = [r[:16] for r in ham]
    ears = ["................",
            "................",
            "..lm............",
            ".wAm............",
            ".lBd............",
            "..d............."]
    hamster = comp(place(ears), place(ears, mirror=True), place(ham))

    # Clockwork: a leather aviator cap with long ear flaps, brass goggles pushed up on the brow
    cap = ["................",
           "................",
           "......SSST......",
           ".....SSSTTT.....",
           "....SSSSTTTU....",
           "...SSSSSTTTUU...",
           "...SSSSTTTTUU...",
           "...SSSTTTTTUU...",
           "...SSTTTTTTUU...",
           "..STTxxxxxxTUU..",
           "..STTxxxxxxTUU..",
           "..STTxxxxxxTUU..",
           "..STTx....xTUU..",
           "...TU......TU...",
           "................",
           "................"]
    gog = ["................",
           "................",
           "................",
           "................",
           "................",
           "................",
           "..EwlF....wlFG..",
           ".GwABFGFFGwABFG.",
           ".GlBCFGGGGlBCFG.",
           "..FFFG....FFGG..",
           "................"]
    clock = comp(place(cap), place(gog))
    I['infernal_horned_helm'] = (infernal, {})
    I['magma_horned_helm'] = (magma, {})
    I['abyssal_fin_helm'] = (abyssal, {})
    I['hamster_helm'] = (hamster, {'x': '#3a1a12'})
    I['clockwork_goggle_cap'] = (clock, {'x': '#1e1210'})

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
