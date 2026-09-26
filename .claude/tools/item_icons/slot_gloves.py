"""Gloves: always a pair, cuffs up, the back one darker and partly hidden."""
from kit import *

# one right glove, 8x14; row 0 is for things sticking up off the cuff
GLOVE = ["........",
         ".wwllmm.",
         ".llllmmd",
         ".llllmmd",
         ".CCCCCCC",
         "..llmmd.",
         "wlllmmmd",
         "lllllmmd",
         ".llllmmd",
         ".lllmmmd",
         ".lldlmdd",
         ".lldlmdd",
         "..ldlmd.",
         "........"]
GAUNT = ["........",
         "wwwlllmd",
         "wllllmmd",
         ".llllmmd",
         ".CCCCCCC",
         "..llmmd.",
         "wlllmmmd",
         "lllllmmd",
         ".xxxxxxd",
         ".wlllmmd",
         ".lldlmdd",
         ".lldlmdd",
         "..ldlmd.",
         "........"]
WRAPS = ["........",
         ".wllmmd.",
         ".mmdddd.",
         ".lllmmd.",
         ".dddddd.",
         "..llmd..",
         "wllmmmd.",
         "lddddd..",
         ".llmmmd.",
         ".dddddd.",
         ".SSTSTT.",
         ".SSTSTT.",
         "..STST..",
         "........"]
MITT = ["........",
        ".wwllmm.",
        ".llllmmd",
        ".CCCCCCC",
        "..llmmd.",
        ".wllmmmd",
        "wllllmmd",
        "llllmdmd",
        ".lllmdmd",
        ".lllmdmd",
        ".llllmmd",
        ".llllmmd",
        "..llmmd.",
        "........"]
BRACER = ["........",
          ".wllmmd.",
          ".CCCCCC.",
          ".llllmd.",
          ".llllmd.",
          ".CCCCCC.",
          ".llllmd.",
          ".llllmd.",
          ".CCCCCC.",
          ".llllmd.",
          "..llmd..",
          "........",
          "........",
          "........"]

SPREAD = {'overlap': ((1, 2), (6, 0)), 'spread': ((0, 2), (8, 1)), 'tight': ((2, 2), (6, 1))}


def pair(base, changes=None, spread='overlap'):
    g = edit(base, changes or {})
    front, back = SPREAD[spread]
    return comp(place(g, *back, mirror=True, dark=True), place(g, *front))


BARK = {'w': '#dcae80', 'l': '#a87a4c', 'm': '#8a5c34', 'd': '#664020', 'x': '#40260e'}
MOSS = {'S': '#b0e888', 'T': '#70ae48', 'U': '#2e6a24'}

ITEMS = {
    'abyssal_webbed_gloves': (GLOVE, {(2, 0): 'S', (3, 0): 'S', (5, 0): 'S', (3, 7): 'd', (5, 8): 'd',
                                      **rows(10, ".lBlBmBd", ".lBlBmBd", "..l.l.m.")}, 'overlap', {}),
    'apprentice_wraps': (WRAPS, {}, 'spread', mat('skin', 'STU')),
    'arcane_gloves': (GLOVE, {(3, 7): 'S', (4, 8): 'S', (4, 6): 'T', (2, 1): 'A', (5, 1): 'A'}, 'overlap', {}),
    'archmage_gloves': (GLOVE, {(1, 0): 'l', (6, 0): 'm', **rows(4, ".SSSSSSS"), (3, 7): 'A', (3, 8): 'B',
                                (4, 7): 'B'}, 'tight', {}),
    'assassin_gloves': (GLOVE, {**rows(4, ".BBBBBBB"), **rows(9, ".CCCCCCC"), **rows(12, "..xdxdx.")}, 'tight', {}),
    'cleric_gloves': (GLOVE, {**rows(4, ".TTTTTTT"), (3, 6): 'B', (3, 7): 'B', (3, 8): 'B', (2, 7): 'B',
                              (4, 7): 'B'}, 'spread', {}),
    'clockwork_gloves': (GLOVE, {(2, 2): 'x', (5, 2): 'x', (3, 6): 'x', (4, 6): 'x', (2, 7): 'x', (5, 7): 'x',
                                 (2, 8): 'x', (5, 8): 'x', (3, 9): 'x', (4, 9): 'x', (3, 7): 'A', (4, 7): 'A',
                                 (3, 8): 'B', (4, 8): 'B'}, 'overlap', {}),
    'cutpurse_fingerless_gloves': (GLOVE, {**rows(9, ".xxxxxxd", ".SSTSSTT", ".SSTSSTT", "..STSST."),
                                           (3, 7): 'S', (5, 3): 'x', **rows(4, ".FFFFFFF")}, 'spread', {}),
    'frost_gauntlets': (GAUNT, {(1, 0): 'w', (3, 0): 'l', (5, 0): 'w', (7, 0): 'l', (3, 6): 'A', (3, 7): 'A',
                                (4, 6): 'w', **rows(4, ".dddddd.")}, 'overlap', {}),
    'hamster_paws': (GLOVE, {**rows(1, ".SSSSSS.", ".SSSSTTU", ".SSSTTTU", ".TTTTTTT"), (2, 0): 'S', (5, 0): 'S',
                             **rows(10, ".llAlmmd", ".lllmAmd", "..llmm..")}, 'spread', {}),
    'heavy_iron_gauntlets': (GAUNT, {(2, 2): 'B', (5, 2): 'B', (1, 2): 'w', **rows(4, ".xxxxxxx")}, 'overlap', {}),
    'infernal_gauntlets': (GAUNT, {(1, 0): 'C', (4, 0): 'B', (7, 0): 'C', (3, 7): 'A', (4, 7): 'B',
                                   **rows(4, ".CCCCCCC"), **rows(12, "..AdAmB.", "..A.A.B.")}, 'overlap', {}),
    'magma_gauntlets': (GAUNT, {(2, 6): 'B', (3, 7): 'A', (4, 7): 'B', (5, 9): 'B', (2, 10): 'C', (6, 11): 'C',
                                (2, 2): 'B', **rows(4, ".CCCCCCC")}, 'tight', {}),
    'militia_mitts': (MITT, {**rows(3, ".xxxxxxx"), (4, 6): 'd', (4, 7): 'd', (4, 8): 'd'}, 'spread', {}),
    'necromancer_gloves': (GLOVE, {**rows(10, ".SxSxTxU", ".SxSxTxU", "..S.S.T."), (3, 7): 'A', (3, 6): 'B',
                                   **rows(4, ".EEEEEEE")}, 'tight', {}),
    'poacher_leather_gloves': (GLOVE, {**rows(1, ".SSSSTT.", ".TSTSTTU"), **rows(4, ".xxxxxxx"),
                                       (2, 7): 'd', (3, 8): 'd'}, 'overlap', {}),
    'rogue_bracers': (BRACER, {**rows(2, ".TTTTTT."), **rows(5, ".TTTTTT."), **rows(8, ".TTTTTT."),
                               (2, 3): 'E', (2, 6): 'E', (2, 9): 'E'}, 'spread', {}),
    'scrapper_rag_wraps': (WRAPS, {(2, 3): 'A', (3, 3): 'B', (4, 8): 'A', (5, 8): 'B', **rows(2, ".mdmddd.")},
                           'overlap', mat('skin', 'STU')),
    'seraph_gloves': (GLOVE, {**rows(1, ".AAAAAB."), **rows(4, ".BBBBBBB"), (0, 1): 'w', (0, 2): 'w', (0, 3): 'l',
                              (3, 7): 'A'}, 'spread', {}),
    'sporecaller_bark_gloves': (GLOVE, {**rows(1, ".SSTSTT.", ".TSSTTUd"), (2, 0): 'B', (3, 0): 'A',
                                        **rows(4, ".xxxxxxx"), (3, 7): 'd', (4, 8): 'd'}, 'overlap',
                                {**BARK, **MOSS}),
    'starforged_gloves': (GLOVE, {(2, 7): 'A', (5, 6): 'B', (4, 9): 'A', **rows(4, ".TTTTTTT"),
                                  (3, 2): 'B'}, 'overlap', {}),
    'wraith_gloves': (GLOVE, {**rows(1, ".w.l.m.."), (3, 7): 'C', **rows(12, "..BdBmC.")}, 'tight', {}),
}


def build(name):
    base, ch, spread, extra = ITEMS[name]
    return pair(base, ch, spread), {**SETS[set_of(name)], **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ITEMS], 'sheet_gloves.png')
