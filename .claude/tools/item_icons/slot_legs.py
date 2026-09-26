"""Legs: belted pants (concepts 3a + 3c), plate greaves, and flared robe-skirts for the mage sets."""
from kit import *

PANTS = ["................",
         "..xxxxxAAxxxxx..",
         "..wlllllllmmmd..",
         "..lllllllmmmmd..",
         "..llllllmmmmmd..",
         "..lllll..mmmmd..",
         "..llllm..lmmmd..",
         "..llllm..lmmmd..",
         "..llllm..lmmmd..",
         "..lwllm..wlmmd..",
         "..llllm..lmmmd..",
         "..llllm..lmmmd..",
         "..llllm..lmmmd..",
         "..xxxxx..xxxxx..",
         "................",
         "................"]
SKIRT = ["................",
         "....xxxAAxxx....",
         "....wlllmmmd....",
         "...wlllllmmmd...",
         "...lllllmmmmd...",
         "...llllmlmmmd...",
         "..wllllmlmmmmd..",
         "..lllldllmdmmd..",
         "..llllmllmmmmd..",
         ".wllldlllmdmmmd.",
         ".llllmllmmmmmmd.",
         ".lllldllmmdmmmd.",
         ".llllllmmmmmmdd.",
         ".CCCCCCCCCCCCCC.",
         "................",
         "................"]
# plate: bands across the legs and knee guards
PLATE = {**paint(4, "..dddddddddddd.."), **paint(7, "..dddd....dddd.."), **paint(11, "..dddd....dddd.."),
         **paint(8, "..wwl......wlm.."), **paint(9, "..lmd......lmd..")}


def pants(changes=None, pouch=None, extra=()):
    g = place(edit(PANTS, changes or {}))
    layers = [g]
    if pouch:
        layers.append(place(grid(pouch[2]), pouch[0], pouch[1]))
    return comp(*layers, *extra)


def skirt(changes=None, extra=()):
    return comp(place(edit(SKIRT, changes or {})), *extra)


POUCH = ["STT", "TTU", "TUU"]


def I_():
    I = {}
    # ---- pants
    I['assassin_legwraps'] = (pants({**paint(1, "..BBBBBBBBBBBB.."), **paint(7, "..xxxx....xxxx.."),
                                     **paint(10, "..xxxx....xxxx.."), **paint(13, "..BBBBB..BBBBB..")},
                                    (11, 1, ["BC", "CC", "C."])), {})
    I['cleric_trousers'] = (pants({**paint(1, "..TTTTTSSTTTTT.."), **{(2, y): 'B' for y in range(2, 13)},
                                   **{(13, y): 'C' for y in range(2, 13)}, **paint(13, "..TTTTT..UUUUU..")}), {})
    I['clockwork_trousers'] = (pants({**paint(1, "..xxxxxBBxxxxx.."), **paint(8, "..EEF....EFG..."),
                                      **paint(9, "..FEG....FGG..."), (3, 8): 'E'}, (10, 1, ["lmm", "mAd", "ddd"])),
                               dict(zip('wlmdx', ('#b88c68', '#906444', '#6d4424', '#4e2c14', '#2c180a'))))
    I['cutpurse_patched_breeches'] = (pants({**paint(10, "..xxxxx..xxxxx..", "__________________",
                                                    "________________", "________________"),
                                             (3, 5): 'F', (4, 5): 'F', (3, 6): 'G', (4, 6): 'F',
                                             (11, 7): 'A', (12, 7): 'B', (11, 8): 'B', (12, 8): 'B'}), {})
    I['militia_trousers'] = (pants({**paint(1, "..FFFFFAAFFFFF.."), **paint(6, "..lmlm....mdmd.."),
                                    **paint(8, "..lmlm....mdmd.."), **paint(10, "..lmlm....mdmd..")},
                                   (11, 2, POUCH)), mat('leather', 'STU') | {'A': '#c8d0d8', 'F': '#5a3a24'})
    I['poacher_breeches'] = (pants({**paint(13, "..SSSSS..TTTTT.."), **paint(12, "..STSTS..TUTUT..")},
                                   (11, 2, ["EEF", "EFG", "FGG"])), {})
    I['rogue_trousers'] = (pants({**paint(1, "..xxxxxTTxxxxx.."), **paint(9, "..xxxx....xxxx..")},
                                 (11, 2, POUCH), [place([(3, 3, 'E'), (3, 4, 'E'), (3, 5, 'F'), (3, 6, 'F'),
                                                         (4, 2, 'x'), (3, 2, 'x')])]), {})
    I['scrapper_sack_trousers'] = (pants({**paint(1, "..SSTSSTTSSTST.."), (4, 4): 'A', (5, 4): 'B', (4, 5): 'B',
                                          (11, 9): 'A', (12, 9): 'B', **paint(13, "..x_xxx..xx_x_..")}), {})
    I['seraph_trousers'] = (pants({**paint(1, "..BBBBBAABBBBB.."), **{(2, y): 'S' for y in range(2, 13)},
                                   **{(13, y): 'T' for y in range(2, 13)}, **paint(13, "..BBBBB..CCCCC..")}), {})
    I['wraith_leggings'] = (pants({**paint(12, "..l_lm....m_md..", "..x_x......x_x.."), (3, 8): 'C', (11, 8): 'C',
                                   (3, 9): 'B', (11, 9): 'B', **paint(1, "..xxxxxxxxxxxx..")}), {})
    # ---- plate greaves
    I['abyssal_scale_greaves'] = (pants({**PLATE, **{(x, y): 'd' for y in (3, 6, 10, 12) for x in (3, 5, 10, 12)},
                                         **paint(1, "..xxxxxEExxxxx.."), (1, 8): 'S', (14, 8): 'T'}), {})
    I['frost_greaves'] = (pants({**PLATE, **paint(8, "..wwA......wAm.."), **paint(1, "..ddddddddddddd.")},
                                extra=[place([(1, 7, 'w'), (0, 8, 'w'), (14, 7, 'l'), (15, 8, 'l')])]), {})
    I['hamster_greaves'] = (pants({**PLATE, **paint(1, "..SSSSSSSSSSSS.."), **paint(13, "..SSSSS..TTTTT.."),
                                   **paint(8, "..AAl......lAB..")}), {})
    I['heavy_iron_greaves'] = (pants({**PLATE, **paint(1, "..xxxxxBBxxxxx.."), (3, 5): 'B', (12, 5): 'C',
                                      (3, 12): 'B', (12, 12): 'C'}), {})
    I['infernal_greaves'] = (pants({**PLATE, **paint(1, "..SSSSSBBSSSSS.."), **paint(4, "..CCCCCCCCCCCC..")},
                                   extra=[place([(1, 7, 'E'), (1, 8, 'F'), (0, 6, 'E'), (14, 7, 'F'), (14, 8, 'G'),
                                                 (15, 6, 'F')])]), {})
    I['magma_greaves'] = (pants({**PLATE, (3, 5): 'B', (4, 6): 'A', (5, 6): 'B', (11, 10): 'B', (10, 11): 'C',
                                 (12, 3): 'C', (4, 10): 'C', **paint(1, "..xxxxxBBxxxxx..")}), {})
    # ---- robe-skirts
    I['apprentice_robe_skirt'] = (skirt({**paint(1, "....EEEFFEEE...."), **paint(13, ".BBBBBBBBBBBBBB.")}), {})
    I['arcane_skirt'] = (skirt({**paint(13, ".BBBBBBBBBBBBBB."), **paint(1, "....CCCAACCC...."), (5, 9): 'S',
                                (10, 11): 'T', (8, 5): 'S'}), {})
    I['archmage_skirt'] = (skirt({**paint(13, ".TTTTTTTTTTTTTT."), **paint(12, ".SlllllmmmmmmdU."),
                                  **paint(1, "....TTTABTTT....")}), {})
    I['necromancer_skirt'] = (skirt({**paint(1, "....SSSTTSSS...."), (7, 1): 'x', (8, 1): 'x',
                                     **paint(12, ".llll_lmm_mmmd__", ".x_CC_C_C__C_x__")}), {})
    I['sporecaller_moss_skirt'] = (skirt({**paint(1, "....SSSTTSSS...."),
                                          **paint(12, ".lwll_llmmm_md__", ".w_l__l__m__d___"),
                                          (4, 8): 'A', (4, 9): 'B', (10, 5): 'A'}), {})
    I['starforged_skirt'] = (skirt({**paint(13, ".SSSSSSSSSSSSSS."), **paint(1, "....TTTAATTT...."),
                                    (5, 6): 'A', (9, 9): 'B', (4, 11): 'A', (11, 7): 'A', (7, 3): 'B'}), {})
    return I


ALL = I_()


def build(name):
    g, extra = ALL[name]
    return g, {**SETS[set_of(name)], **extra}


if __name__ == '__main__':
    sheet([(n, *build(n)) for n in ALL], 'sheet_legs.png')
