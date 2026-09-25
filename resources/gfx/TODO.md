# Pixel perfect to-do

2026-09-25: research only, nothing decided or built. Detail and reasoning:
`docs/PIXEL_RESOLUTION_RESEARCH.md`.

- [✗] Pick the setup. Favoured: dungeon in a 320×180 SubViewport, UI at 640×360 (2× the game grid), debug at full screen resolution so it stays sharp
- [✗] Before any UI redo: a pixel font, and move the hardcoded font sizes into the theme
- [✗] Texture packs (later): one standalone JSON in this folder holding only `texel_scale`; view size is never a pack setting (it would be a cheat)
