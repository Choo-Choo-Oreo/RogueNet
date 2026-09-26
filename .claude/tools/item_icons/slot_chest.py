"""Chest: no cookie cutter. Five cuts (tunic, breastplate, robe, vest, apron), and every set changes
its cut with its own collar, shoulders, trim and emblem."""
from kit import *

TUNIC = ["................",
         "................",
         "...wlll..mmmd...",
         ".wlllllxxmmmmdd.",
         ".llllllxmmmmmdd.",
         ".lllllllmmmmmdd.",
         ".llllllllmmmmdd.",
         ".ll.lllllmmm.dd.",
         ".CC.lllllmmm.CC.",
         "....xxxxxxxx....",
         "....lllllmmm....",
         "....lllllmmd....",
         "....llllmmmd....",
         "....CCCCCCCC....",
         "................",
         "................"]
BREAST = ["................",
          "................",
          "....wll..mmd....",
          "...wllllmmmmd...",
          "...lllllmmmmd...",
          "...llwllmmmmd...",
          "...lllldmmmmd...",
          "...lllldmmmmd...",
          "....llldmmmd....",
          "....llldmmmd....",
          "....xxxxxxxx....",
          "....lldmmmdd....",
          "....ldd.dmdd....",
          "................",
          "................",
          "................"]
ROBE = ["................",
        "................",
        "....wll..mmd....",
        "..wllllxxmmmmd..",
        ".wlllllxmmmmmmd.",
        ".lllllllmmmmmmd.",
        ".lll.llllmm.mmd.",
        ".lll.llllmm.mmd.",
        ".CCC.xxxxxx.CCC.",
        "....lllllmmm....",
        "....lllllmmm....",
        "...llllllmmmd...",
        "...llllllmmmd...",
        "...CCCCCCCCCC...",
        "................",
        "................"]
VEST = ["................",
        "................",
        "...wll....mmd...",
        "...lllSSSSmmd...",
        "...lllSSTTmmd...",
        "...lllSSTTmmd...",
        "...llllSTmmmd...",
        "...llllSTmmmd...",
        "...xxxxxxxxxx...",
        "...lllllmmmmd...",
        "...llllSTmmmd...",
        "...llll..mmmd...",
        "................",
        "................",
        "................",
        "................"]
APRON = ["................",
         "...x........x...",
         "....x......x....",
         ".....wllmmd.....",
         ".....lllmmd.....",
         "..xxxlllmmdxxx..",
         "...wllllmmmmd...",
         "...lllllmmmmd...",
         "...lllllmmmmd...",
         "...lllllmmmmd...",
         "...lllllmmmmd...",
         "...lllllmmmmd...",
         "...lllllmmmdd...",
         "....ddddddd.....",
         "................",
         "................"]
PAUL = [".wl.", "wllm", "lmmd"]


def body(base, changes=None, pauldrons=None, extra=()):
    layers = []
    if pauldrons:
        rowsp, (lx, ly), (rx, ry) = pauldrons
        layers += [place(grid(rowsp), rx, ry, mirror=True, dark=True), None, place(grid(rowsp), lx, ly)]
    main = place(edit(base, changes or {}))
    if pauldrons:
        layers[1] = main
        return comp(layers[0], layers[1], layers[2], *extra)
    return comp(main, *extra)


SHIRT_SLEEVES = [(1, 3, 'S'), (2, 3, 'S'), (1, 4, 'S'), (2, 4, 'T'), (1, 5, 'T'), (13, 3, 'T'), (14, 3, 'T'),
                 (13, 4, 'T'), (14, 4, 'U'), (14, 5, 'U')]


def I_():
    I = {}
    I['abyssal_scale_mail'] = (body(BREAST, {**{(x, y): 'd' for y in (4, 6, 8) for x in (4, 6, 9, 11)},
                                             **{(x, y): 'd' for y in (5, 7, 9) for x in (5, 10)},
                                             (7, 5): 'A', (7, 6): 'B', **paint(10, "....EEEEEEEE....")},
                                    ([".S.", "SST", "STU"], (1, 1), (12, 1))), {})
    I['apprentice_robe'] = (body(ROBE, {**paint(8, ".BBB.EEFFEE.BBB."), **paint(13, "...BBBBBBBBBB..."),
                                        (4, 10): 'd', (5, 11): 'A'}), {})
    I['arcane_robe'] = (body(ROBE, {**{(7, y): 'A' for y in range(5, 13)}, **{(8, y): 'B' for y in range(4, 13)},
                                    **paint(13, "...BBBBBBBBBB..."), **paint(8, ".BBB.CCAACC.BBB."),
                                    (5, 5): 'S', (4, 11): 'S'}), {})
    I['archmage_robe'] = (body(ROBE, {**paint(2, "...SSS..TTU....."), **paint(3, "..wSllxxmmTmd.."),
                                      (7, 4): 'A', (7, 5): 'B', **paint(8, ".TTT.xxAAxx.TTT."),
                                      **paint(13, "...TTTTTTTTTTU.."), (5, 10): 'S', (10, 11): 'T'}), {})
    I['assassin_vest'] = (body(VEST, {**{(3 + i, 2 + i): 'B' for i in range(9)},
                                      **{(4 + i, 2 + i): 'C' for i in range(8)}, **paint(8, "...xxxxxxxxxx...")},
                               extra=[place([(1, 3, 'x'), (2, 3, 'x'), (1, 4, 'd'), (13, 3, 'x'), (14, 3, 'x'),
                                             (14, 4, 'd')]), place([(10, 6, 'S'), (11, 5, 'S'), (11, 7, 'T')])]), {})
    I['cleric_vestment'] = (body(TUNIC, {**{(x, y): ('w' if x < 8 else 'l') for y in range(3, 13) for x in range(5, 11)
                                            if TUNIC[y][x] != '.'},
                                         **{(x, y): 'S' for y in range(3, 14) for x in (4, 11)},
                                         (7, 5): 'B', (8, 5): 'C', (7, 6): 'B', (8, 6): 'C', (6, 6): 'B', (9, 6): 'C',
                                         (7, 7): 'B', (8, 7): 'C', (7, 8): 'B', (8, 8): 'C',
                                         **paint(13, "....TTTTTTTT....")}),
                            dict(zip('lmdx', ('#b8c0cc', '#949eae', '#6c7484', '#4a5060'))) | {'w': '#ffffff'})
    I['clockwork_apron'] = (body(APRON, {**paint(8, "....SSSSTTU....."), **paint(9, "....STTTTUU....."),
                                         (5, 5): 'E', (10, 5): 'E', (6, 11): 'A', (7, 11): 'B'},
                                 extra=[place([(9, 7, 'E'), (10, 6, 'E'), (11, 5, 'F'), (8, 8, 'F')])]),
                            {})
    I['cutpurse_ragged_tunic'] = (body(TUNIC, {**paint(13, "....C_CC_C_C....", "....x_x__x_x...."),
                                               (5, 4): 'F', (5, 5): 'G', (6, 5): 'F', (10, 10): 'A', (10, 11): 'B',
                                               **paint(8, ".C_.........._C.")}), {})
    I['frost_plate'] = (body(BREAST, {**paint(2, "....EEEEFFFF...."), **paint(3, "...wEEEFFFmd...."),
                                      (7, 5): 'A', (7, 6): 'w', (5, 8): 'w'},
                             (PAUL, (1, 3), (11, 3)),
                             extra=[place([(1, 1, 'w'), (2, 2, 'w'), (14, 1, 'l'), (13, 2, 'l')])]), {})
    I['hamster_plate'] = (body(BREAST, {**{(x, y): 'S' for y in range(5, 10) for x in range(5, 10)
                                           if BREAST[y][x] != '.'},
                                        (5, 5): '.', (9, 5): '.', (5, 9): 'T', (9, 9): 'T', (7, 7): 'T',
                                        **paint(10, "....TTTTTTTT....")},
                               ([".l.", "llm", "lmd"], (1, 2), (12, 2))), {})
    I['heavy_iron_cuirass'] = (body(BREAST, {**paint(10, "....BBBAABBB...."), (4, 3): 'B', (11, 3): 'C',
                                             (4, 9): 'B', (11, 8): 'C', **paint(6, "....d.....d.....")},
                                    (PAUL, (1, 2), (11, 2))), {})
    I['infernal_cuirass'] = (body(BREAST, {(7, 5): 'A', (6, 6): 'B', (7, 6): 'A', (8, 6): 'B', (7, 7): 'C',
                                           **paint(10, "....SSSSSSSS...."), **paint(2, "....SSS..SSS....")},
                                  (PAUL, (1, 3), (11, 3)),
                                  extra=[place([(1, 1, 'E'), (1, 2, 'F'), (2, 2, 'F'), (14, 1, 'F'), (14, 2, 'G'),
                                                (13, 2, 'G'), (3, 1, 'E'), (12, 1, 'F')])]), {})
    I['magma_cuirass'] = (body(BREAST, {(5, 4): 'B', (6, 5): 'A', (6, 6): 'B', (9, 7): 'B', (10, 8): 'C',
                                        (5, 9): 'C', (8, 3): 'C', **paint(10, "....CCBBBBCC....")},
                               (["wl.", "llm", "mdd"], (1, 2), (12, 2))), {})
    I['militia_gambeson'] = (body(TUNIC, {**{(x, y): 'd' for y in range(3, 13) for x in range(1, 15)
                                             if TUNIC[y][x] in 'lm' and (x + y) % 3 == 0},
                                          (5, 6): 'A', (5, 5): 'B', **paint(9, "....FFFFFFFF....")}),
                             mat('wood', 'EFG') | {'F': '#4a2a18'})
    I['necromancer_robe'] = (body(ROBE, {**paint(4, "......S.S......."), **paint(5, ".....STSTS......"),
                                         **paint(6, ".....SS.SS......"), **paint(7, ".....TTSTT......"),
                                         **paint(6, "......T.T......."),
                                         **paint(8, ".CCC.SSSSS..CCC."), (7, 3): 'A'}), {})
    I['poacher_hide_vest'] = (body(VEST, {**paint(2, "...SSS....TTU..."), **paint(3, "...STS....TTU..."),
                                          (4, 6): 'd', (5, 9): 'd', (11, 5): 'x', (10, 10): 'x',
                                          **paint(8, "...EEEEEEEEEE...")}, extra=[place(SHIRT_SLEEVES)]),
                              {'S': '#fff2d8', 'T': '#dcc8a4', 'U': '#a89478'} | {'S': '#fff2d8'})
    I['rogue_jerkin'] = (body(TUNIC, {**paint(2, "...wllTT.mmd...."), (7, 3): 'T', (8, 3): 'U',
                                      **{(7, y): 'x' for y in range(4, 9)},
                                      (6, 5): 'S', (8, 5): 'S', (6, 7): 'S', (8, 7): 'S',
                                      **paint(9, "....xxxEExxx....")}), {})
    I['scrapper_patched_vest'] = (body(VEST, {(4, 4): 'A', (5, 4): 'B', (4, 5): 'B', (11, 9): 'A',
                                              **paint(8, "...SSTSSTTSST..."), (10, 3): 'S', (11, 4): 'T'},
                                       extra=[place(SHIRT_SLEEVES)]), mat('paper', 'STU'))
    I['seraph_vestment'] = (body(ROBE, {**paint(8, ".BBB.BBAABB.BBB."), **paint(13, "...BBBBBBBBBB..."),
                                        (7, 5): 'A', (6, 6): 'B', (8, 6): 'B', (7, 6): 'A', (7, 7): 'B',
                                        **{(4, y): 'S' for y in range(9, 13)}, **{(11, y): 'T' for y in range(9, 13)}},
                            extra=[place([(0, 1, 'w'), (1, 1, 'w'), (0, 2, 'w'), (1, 2, 'l'), (0, 3, 'l'),
                                          (15, 1, 'l'), (14, 1, 'l'), (15, 2, 'l'), (14, 2, 'm'), (15, 3, 'm')])]),
                            {})
    I['sporecaller_moss_robe'] = (body(ROBE, {**paint(8, ".SSS.TTTTTT.SSS."), (6, 10): 'A', (9, 12): 'B',
                                              **paint(13, "...w_ll_mm_d_...")},
                                       extra=[place([(1, 1, 'A'), (2, 1, 'B'), (3, 1, 'B'), (2, 2, 'S')]),
                                              place([(12, 1, 'A'), (13, 1, 'B'), (13, 2, 'S')])]), {})
    I['starforged_robe'] = (body(ROBE, {**paint(8, ".SSS.TTTTTT.SSS."), **paint(13, "...SSSSSSSSSS..."),
                                        (6, 5): 'A', (5, 10): 'B', (10, 11): 'A', (12, 5): 'A', (2, 5): 'B',
                                        (7, 10): 'A', (8, 11): 'B', (8, 10): 'B'}), {})
    I['wraith_jerkin'] = (body(TUNIC, {**paint(13, "....C_Cd_C_C....", "....._x.._x....."), (7, 5): 'A',
                                       (7, 6): 'B', (6, 6): 'C', (8, 6): 'C', (7, 7): 'C',
                                       **paint(8, ".d_.........._d.")}), {})
    return I


ALL = I_()


def build(name):
    g, extra = ALL[name]
    return g, {**SETS[set_of(name)], **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ALL], 'sheet_chest.png')
