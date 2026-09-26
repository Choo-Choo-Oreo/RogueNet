# Pixel perfect to-do

**The rule (Orea 2026-09-26):** one mathematical grid. The unit is one UI pixel of the 640×360
layer; one world art pixel (the 320×180 layer) is exactly 2 units. Every drawn pixel is a whole
multiple of the unit and sits on the grid. Sizes that divide evenly are fine (8 and 16 -> 1 and
2); non-whole ratios never are (0.6×, 1.6×, a scale tween from 0 to 1, any rotation but 90° steps).
The 320×180 SubViewport enforces the grid for the world and stays, but a non-whole scale inside
it still gives uneven blocks, so whole-number scales only, everywhere. The camera is the only
exception (below). Debug drawing stays sharp at full screen resolution, outside the grid. Cases on Silvery's branch: `docs/SILVERY_MERGE_TRACKER.md`.

2026-09-25: research. 2026-09-26: setup picked (below), nothing built yet; done before pulling Silvery's art/UI chunks so they land in it. Detail and reasoning:
`docs/PIXEL_RESOLUTION_RESEARCH.md`.

- [✓] Pick the setup (Orea 2026-09-26): two layers. Dungeon in a 320×180 SubViewport, UI at 640×360 (2× the game grid), debug at full screen resolution so it stays sharp
- [✗] Non-16:9 screens: undecided, Orea leans to resizing the game viewport (more world on the long side; vision is limited anyway) over black bars
- [✓] Camera (Orea 2026-09-26): the camera is never meant to be pixel perfect, it looks over the world. The world is one pixel grid; the camera slides over it at screen resolution (1 px margin + camera fraction offset), no steppy camera and no switch for it. Sprites still move in whole art pixels within the world
- [✗] Before any UI redo: a pixel font, and move the hardcoded font sizes into the theme
- [✗] Texture packs (later): one standalone JSON in this folder holding only `texel_scale`; view size is never a pack setting (it would be a cheat)
