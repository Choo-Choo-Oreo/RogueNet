"""Redraws every item icon in resources/gfx/ui/icons/items from the slot_*.py files.
Run from this folder: python build_all.py  (then re-save the .aseprite copies with Aseprite -b).
kit.py has the drawing helpers and the set palettes; each slot_*.py draws one equipment slot."""
import os, glob
import slot_gloves, slot_main, slot_off, slot_head, slot_legs, slot_chest, slot_feet, slot_small
from kit import render
MODS = [slot_gloves, slot_main, slot_off, slot_head, slot_legs, slot_chest, slot_feet, slot_small]
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'resources', 'gfx', 'ui', 'icons', 'items'))
names = sorted(os.path.basename(f)[:-4] for f in glob.glob(REPO + r'\*.png'))
which = {}
for m in MODS:
    for n in (m.ITEMS if hasattr(m, 'ITEMS') else m.ALL):
        assert n not in which, n
        which[n] = m
missing = [n for n in names if n not in which]
extra = [n for n in which if n not in names]
print('icons', len(names), 'drawn', len(which), 'missing', missing, 'extra', extra)
if not missing and not extra:
    items = []
    for n in names:
        g, p = which[n].build(n)
        im = render(g, p)
        im.save(os.path.join(REPO, n + '.png'))
        items.append((n, g, p))
    print('written')
