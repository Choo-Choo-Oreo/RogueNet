"""Feet: a pair seen from the side, toes to the right, the back one darker, up and to the right."""
from kit import *

BOOT = [".wllmmd...",
        ".CCCCCC...",
        ".llllmd...",
        ".llllmd...",
        ".llllmd...",
        ".lllllmd..",
        ".llllllmmd",
        ".lllllllmd",
        ".xxxxxxxxx"]
SHOE = [".wllmd....",
        ".lllllmd..",
        ".llllllmmd",
        ".lllllllmd",
        ".xxxxxxxxx"]
SLIPPER = ["..........",
           ".wlld....d",
           ".llllmd.md",
           ".lllllmmmd",
           ".xxxxxxxx."]
SABATON = [".wllmmd....",
           ".CCCCCC....",
           ".llllmd....",
           ".llllmd....",
           ".lllddmd...",
           ".llllllmd..",
           ".lllldlmmd.",
           ".llllldlmmd",
           ".xxxxxxxxxx"]
TABI = [".wllmmd...",
        ".CCCCCC...",
        ".llllmd...",
        ".llllmd...",
        ".lllllmd..",
        ".llllllxmd",
        ".lllllmxmd",
        ".xxxxxxxxx"]
WRAPS = [".wlmd.....",
         ".dddd.....",
         ".llmd.....",
         ".ddddd....",
         ".lllmmd...",
         ".dddddddd.",
         ".llllSSTT.",
         ".xxxxxxxx."]


def pair(base, changes=None, front=None, back=None, extra=()):
    g = edit(base, changes or {})
    h = g.shape[0]
    front = front or (1, 15 - h)
    back = back or (5, 15 - h - 4)
    return comp(place(g, *back, dark=True), place(g, *front), *extra)


SKIN = mat('skin', 'STU')


def I_():
    I = {}
    I['abyssal_fin_boots'] = (pair(BOOT, {(0, 1): 'S', (0, 2): 'S', (0, 3): 'T', (3, 4): 'd', (2, 6): 'd',
                                          (4, 6): 'd', **rows(1, ".EEEEEE")}), {})
    I['apprentice_sandals'] = (pair(SHOE, {**rows(0, ".SST....", ".SESSST..", ".SSESSETU", ".SSSESSTU",
                                                  ".FFFFFFFFF")}), SKIN)
    I['arcane_slippers'] = (pair(SLIPPER, {(9, 0): 'A', **rows(4, ".BBBBBBBB."), (3, 2): 'S'}), {})
    I['archmage_slippers'] = (pair(SLIPPER, {(9, 0): 'A', (9, 1): 'B', **rows(4, ".TTTTTTTT."), (3, 2): 'A'}), {})
    I['assassin_tabi'] = (pair(TABI, {**rows(1, ".BBBBBB..."), (2, 3): 'B', (3, 4): 'B', (2, 5): 'B'}), {})
    I['cleric_boots'] = (pair(BOOT, {**rows(1, ".TTTTTT..."), **rows(8, ".GGGGGGGGG"), (3, 4): 'B'}), {})
    I['clockwork_boots'] = (pair(BOOT, {**rows(8, ".EEEEFFFFG"), (2, 3): 'x', (3, 3): 'A', (2, 4): 'x',
                                        (4, 4): 'x', (3, 5): 'x', **rows(1, ".TTTTTT...")}),
                            dict(zip('wlmdx', ('#c89868', '#a07044', '#7a4e28', '#56341a', '#34200e'))) |
                            {'T': '#d5a148'})
    I['cutpurse_holey_shoes'] = (pair(SHOE, {(3, 2): 'S', (6, 3): 'S', (8, 2): 'T', **rows(4, ".xxxxxx.xx")}), {})
    I['frost_fur_boots'] = (pair(BOOT, {**rows(0, "EEEEEEEF..", "EEFEEFFG..")}), {})
    I['hamster_boots'] = (pair(BOOT, {**rows(0, ".SSSSST...", ".TTTTTT..."), **rows(8, ".AAAAAABBB"),
                                      (8, 6): 'A'}), {})
    I['heavy_iron_sabatons'] = (pair(SABATON, {(2, 1): 'B', (5, 1): 'B'}, front=(1, 6), back=(4, 2)), {})
    I['infernal_sabatons'] = (pair(SABATON, {**rows(1, ".CCCCCC...."), **rows(8, ".SSSSSSSSSS")}, front=(1, 6),
                                   back=(4, 2), extra=[place([(13, 13, 'E'), (14, 12, 'E'), (14, 13, 'F')])]), {})
    I['magma_sabatons'] = (pair(SABATON, {(3, 3): 'B', (4, 5): 'A', (6, 6): 'B', (8, 7): 'C', (2, 6): 'C',
                                          **rows(1, ".CCCCCC....")}, front=(1, 6), back=(4, 2)), {})
    I['militia_boots'] = (pair(BOOT, {(3, 2): 'S', (4, 3): 'S', (3, 4): 'S', (4, 5): 'S', **rows(1, ".xxxxxx...")}),
                          mat('iron', 'STU') | {'S': '#e0d0b0'})
    I['necromancer_wraps'] = (pair(WRAPS, {**rows(6, ".llllSSTT.")}), {})
    I['poacher_turnshoes'] = (pair(SHOE, {**rows(0, ".SSST....."), (5, 2): 'd'}), {})
    I['rogue_boots'] = (pair(BOOT, {**rows(0, "wwlllmd...", "SSSSSST..."), (5, 3): 'E', (4, 3): 'x',
                                    (6, 3): 'x'}), {})
    I['scrapper_foot_rags'] = (pair(WRAPS, {**rows(0, ".wlm......"), (2, 4): 'A', (3, 4): 'B'}),
                               mat('skin', 'STU'))
    I['seraph_boots'] = (pair(BOOT, {**rows(1, ".BBBBBB..."), **rows(8, ".CCCCCCCCC")},
                              extra=[place([(0, 5, 'w'), (0, 6, 'w'), (1, 6, 'l'), (0, 7, 'l')])]), {})
    I['sporecaller_root_wraps'] = (pair(WRAPS, {**rows(0, ".SSTT.....")},
                                   extra=[place([(2, 15, 'U'), (6, 15, 'U'), (4, 15, 'T')], line=False)]),
                                   dict(zip('wlmdx', ('#dcae80', '#a87a4c', '#8a5c34', '#664020', '#40260e'))) |
                                   {'S': '#b0e888', 'T': '#70ae48', 'U': '#2e6a24'})
    I['starforged_slippers'] = (pair(SLIPPER, {(9, 0): 'A', **rows(4, ".SSSSSSSS."), (3, 2): 'A', (6, 3): 'B'}),
                                {})
    I['wraith_boots'] = (pair(BOOT, {**rows(0, ".w.l.m....", ".C.C.C..."), (3, 4): 'C', (7, 7): 'B'}), {})
    return I


ALL = I_()


def build(name):
    g, extra = ALL[name]
    return g, {**SETS[set_of(name)], **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ALL], 'sheet_feet.png')
