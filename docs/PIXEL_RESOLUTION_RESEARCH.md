# Pixel-Perfect Rendering, Resolution and Texture Packs — Research Notes

Date: 2026-09-25. Written from a conversation between Orea and Claude. **Nothing
here is built or decided**: it records the goal, how the game renders today, the
options, and what each would change. `project.godot`, the camera and the scripts
are Orea's; nothing was edited.

Tags:
- **[V]** checked in the files on 2026-09-25.
- **(recall)** from memory of how other games work, not checked against a source.

---

## 1. The goal

- **Rendering rule, not a gameplay rule.** Positions stay floats; snapping only
  happens when drawing. Moving things may sit between art pixels (as today).
- **Snapshot test:** freeze the game with everyone standing still and the whole
  screen should read as one pixel-art image: every pixel the same size, on one grid.
- **UI on the map:** an opened UI should look placed on the map, its pixels lined up
  with the background.
- **No mixels** (mixed pixel sizes): don't scale sprites up to change their size
  (draw frames at the new size instead), no sub-pixel wiggle effects, no particles
  smaller than an art pixel.
- **Particles fade, not shrink.** Three pixel-safe ways, pick one so effects match:
  - opacity (blends into off-palette colours, which most games accept),
  - step down a palette ramp (bright, mid, dark, gone),
  - dither out (remove pixels in a checker pattern).
  `ParticleBurst.gd` already fits: frame-animated, palette-coloured, never scaled **[V]**.
- **Debug info must stay sharp** (full screen resolution).

## 2. How it renders today [V]

| Setting | Value | Where |
|---|---|---|
| Window base size | 1280×720 | `project.godot` `[display]` |
| Stretch | `canvas_items`, aspect `expand` | `project.godot` |
| Texture filter | Nearest (crisp) | `project.godot` `default_texture_filter=0` |
| 2D pixel snap | off | not set |
| Player camera zoom | 5× (world view 256×144) | `scenes/entities/PlayerController.tscn:28` |
| HUD font sizes | 8 (was 11 / 14; since 2026-09-26 one theme, three sizes 8 / 11 / 15) | `resources/UiTheme.tres` (`HudTheme.tres` merged in and deleted) |

What that means:
- Art is crisp but **not pixel-perfect**: sprites can sit between art pixels.
- **World and UI use different pixel sizes.** One world art pixel is 5×5 screen
  pixels; UI is drawn at 1×. A menu over the dungeon looks finer than the map.
- **1080p gets uneven pixels.** `canvas_items` scales 1280×720 by 1.5 on a 1080p
  screen, so the camera's 5× becomes 7.5 screen pixels per art pixel (pixels
  alternate 7 and 8 wide). 720p (×5) and 1440p (×10) are even.
- **Debug text** stays sharp through a trick in `DebugDraw._label()` (~line 494):
  it undoes the camera zoom and draws glyphs at screen resolution. `DebugDraw` is a
  child of the dungeon, drawn in world space; `DebugMenu` is a `CanvasLayer` (layer 100).

## 3. Pitfalls of pixel-perfect (general)

1. **Rounding real positions makes slow movement stutter** (0.6 px/frame becomes
   1, 0, 1, 1, 0...). Keep logic in floats; round at draw time only.
2. **Camera and sprites must snap the same way**, or sprites jitter one pixel
   against the background. `MouseFollowCamera` is where this would show.
3. **Only 90° rotations stay on the grid.** `AttackEffect.gd` rotates by ±90°, fine **[V]**.
4. **Never send rounded positions over the network** or into the game tick; clients drift.
5. **Window size must be a whole multiple of the base resolution.**

## 4. How Terraria does it (recall)

Not pixel-perfect: "crisp pixels, good enough".
- Renders at the monitor's full resolution, no low-res buffer.
- Art is pre-doubled in the files (2×2 blocks), so 100% zoom = 2 screen px per art px.
- Things move by screen pixels, so they can sit half an art pixel off-grid.
- Zoom slider (100–200%) and a separate UI-scale slider; non-whole zoom gives uneven pixels.
- Text is a smooth font (Andy Bold) at screen resolution.

RogueNet today is close to this. The Terraria-style fix for RogueNet is only to
keep the world scale a whole number at every window size (fixes 1080p).

## 5. Options compared

| | Pixel-perfect | Sharp debug | Sharp text before a pixel font | Extra work |
|---|---|---|---|---|
| Stay as-is | ✗ | ✓ | ✓ | none |
| Terraria-style (whole-number world scale) | ✗ (close) | ✓ | ✓ | small |
| **A:** whole window at 320×180 (`viewport` stretch) | ✓ | ✗ | ✗ | UI redo |
| **B:** game in a 320×180 SubViewport | ✓ | ✓ | ✓ if text sits outside it | UI redo + scene helper + move DebugDraw |
| **Two-layer** (section 6) | ✓ (UI at 2× density) | ✓ | ✓ | same as B |

**A rules out sharp debug**: no finer pixels exist, so `_label`'s trick draws a
6 px non-pixel font on a 320×180 canvas (unreadable), and the debug menu goes
low-res too.

## 6. Favoured direction: two layers plus debug

- **Game/dungeon:** 320×180 world units (25% more view than today's 256×144,
  larger enemies drawn cleanly).
- **UI:** 640×360, exactly 2× the game grid, so every game pixel is 2×2 UI pixels
  and UI always lines up with the map. To keep the UI feeling part of the map,
  draw frames/borders in 2×2 blocks and use the fine pixels for text and icons.
- **Debug:** native screen resolution.

Both grids divide every common screen:

| Screen | Game 320×180 | UI 640×360 |
|---|---|---|
| 720p | ×4 | ×2 |
| 1080p | ×6 | ×3 |
| 1440p | ×8 | ×4 |
| 4K | ×12 | ×6 |

How it would be built in Godot:
- Window stays at monitor resolution, `canvas_items` stretch, **base size 640×360,
  scale mode `integer`**. Normal fonts stay smooth until a pixel font exists.
- The dungeon is **one SubViewport** shown at 2× inside the 640×360 layout.
- `DebugDraw` moves out of the dungeon to a full-resolution overlay. Its draw calls
  can keep world coordinates if the overlay copies the game camera transform (times
  the scale) each frame; only `_visible_tiles()` and `_label()` ask for the viewport
  transform and would change. `DebugMenu` barely changes, except the
  teleport-to-mouse tool (~lines 314–333) needs screen → game image → world.

Snapping rule (Orea, 2026-09-25): **UI things snap to the UI grid (640×360), game
things snap to the game grid (320×180).** A draggable panel is UI, so it snaps to
whole UI units and may sit half a game pixel off the map; that is accepted.
Anything attached to the world (labels or bars over creatures, damage numbers)
is game, so it follows the game grid. Save panel positions in UI units and
clamp them on load (layout size changes with `aspect=expand`).

Known consequences:
- **Movement steps in whole art pixels** inside a 320×180 viewport (4 screen px per
  step at 720p), steppier than today. Standard fix: render the viewport 1 px larger
  and offset it by the camera's fraction. Or raise the viewport multiplier (section 7).
- **Non-16:9 screens:** with `aspect=expand`, 1920×1200 gives a 640×400 layout, so
  the game viewport must resize (320×200) or use black bars. Plan for it up front.

## 7. Texture packs / higher-resolution art

### The core idea: split one number into two
Today **16 means two things**: world units per tile (gameplay) and texture pixels
per tile (art). Supporting packs means:
- **World units stay 16 per tile, forever.** Gameplay, pathing, networking never learn about packs.
- **`texel_scale` (d)** = texture pixels per world unit: 1 for base art, 2 for a 32px
  pack. Declared **once in the pack manifest**, not per file, so a pack can't mix
  densities. (Don't call it `density`: `TileType` already has an `overlay_density`
  shader parameter.)

### The code does NOT support HD textures today [V]
The screen has room for detail, but loading assumes 16 px:
- `scripts/cells/tiles/TileInitialize.gd:175–193`: atlas cut into 8×8 / 16×16,
  `tile_set.tile_size` set to match; animation math assumes 16 px art
  (`get_width() / 64`, `get_height() / 8`).
- Godot draws atlas tiles at their **texture region size**, not `tile_size`, so a
  32 px tile in a 16 grid draws double and overlaps.
- `scripts/entities/SpriteFramesLoader.gd:10`: `frame_size` read in pixels from sprite JSON.
- `scripts/dungeon/DoorManager.gd:201`: door `region_rect` in pixels.
- `scripts/actions/ParticleBurst.gd`: builds images with `set_pixel`, fixed at 1×.
- Shaders hardcoding 8/16 break; ones using `TEXTURE_PIXEL_SIZE` adapt.
- `_Normal` maps must match their colour texture's resolution.

### Where d gets applied (loading and rendering only)
1. **Loaders multiply pixel sizes by d and scale the node by 1/d.** TileInitialize
   cuts `8d`/`16d` regions, display `TileMapLayer` gets `scale = 1/d` (display
   layers only; the data layer logic reads stays at 16). Same for
   SpriteFramesLoader and DoorManager.
2. **Game viewport = 320d × 180d, camera zoom d.** View range unchanged; Godot snaps
   drawing to 1/d world units by itself.
3. **Viewport shown on screen at S / d**, S = the screen's whole-number scale
   (720p 4, 1080p 6, 1440p 8, 4K 12).

### Rule for pack makers: d must divide S

| Pack | 720p (S=4) | 1080p (S=6) | 1440p (S=8) | 4K (S=12) |
|---|---|---|---|---|
| d=1 (16 px) | ✓ | ✓ | ✓ | ✓ |
| d=2 (32 px) | ✓ | ✓ | ✓ | ✓ |
| d=3 (48 px) | ✗ | ✓ | ✗ | ✓ |
| d=4 (64 px) | ✓ | ✗ | ✓ | ✓ |

**1× and 2× work everywhere**; denser packs only on some screens.

### Don't upscale the base art
Upscaling our own 16 px art ×2/×4 looks identical, costs 4×/16× memory, invites
mixels (people drawing on the finer grid), and makes art-pixel rules (8-colour
tiles, 40 px door rule, effect strips) harder to apply. Keep base art at d=1.

### Smooth motion as a setting
The viewport multiplier can go **above d, up to S**: then even 1× art moves in
sub-art-pixel steps (as smooth as today) while standing-still things still sit on
the art grid. Could be a player option (purists pick 1×).

### Pack loading (separate feature, later)
- `res://` is packed into the build; packs would load at runtime from a folder next
  to the game or `user://`.
- **Packs are client-side cosmetics only.** Anything that affects gameplay (stats,
  `size_tiles`, rooms) must match the host; a pack must never change it.

## 8. Cost of moving to the 320×180 / 640×360 setup [V counts]

- **Small:** `project.godot` settings (about 4 lines), camera zoom 5 → 1 (or d).
- **Scene changes:** 10 `change_scene` calls in 6 files (MainMenu, LobbyMenu,
  PauseMenu, MainTown, DungeonMaker, NetworkSync) would go through one helper that
  loads into the SubViewport.
- **Mouse:** 15 mouse-position reads; Godot converts them inside a SubViewport, but
  each needs a test (`MouseFollowCamera` first).
- **UI:** 13 scenes laid out for 1280×720 (MainMenu, MultiplayerMenu, SettingsMenu,
  PauseMenu, ChatBox, the 4 in `ui/protagonist/`, GuildMission, MainTown,
  TownStorage, DungeonMaker). Font sizes hardcoded in code should move into the
  theme: `LobbyMenu.gd:35` (20), `CharacterSelect.gd:36` (28),
  `InventoryPanel.gd:288`, `DebugMenu.gd`.
- **Pixel font** eventually (free ones: Daniel Linssen's m5x7 / m6x11), or drawn by
  Silvery (fonts are art).
- **Timing:** UI cost grows with every screen built at 1280×720; the HUD was just redone.

## 9. Open decisions (Orea)

- [x] Stay as-is, Terraria-style, or the two-layer setup? **Two-layer** (Orea 2026-09-26)
- [x] Accept steppier dungeon movement, or pay for the smoothing (1 px margin trick or a viewport multiplier)? **Smooth camera** (Orea 2026-09-26: the camera is never meant to be pixel perfect; 1 px margin trick)
- [ ] Non-16:9 screens: resize the game viewport or black bars? (Orea 2026-09-26 leans to resize: more world on the long side, vision is limited anyway)
- [ ] Are texture packs wanted? If so, allow only d=1/2, or denser with the screen caveat?
- [ ] Which pixel font, and who makes or picks it?

## Godot docs

- Multiple resolutions / stretch modes:
  https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- SubViewport:
  https://docs.godotengine.org/en/stable/classes/class_subviewport.html
