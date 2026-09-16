# Dungeon Assembly — Draft Plan

**Status: draft, unreviewed.** Written at the end of a session on the
dual-grid tile work as a place to pick up from. Nothing here is decided —
the "Open questions" section is the real content. Same convention as
`design-goals.md`: reference material, not a rules file.

## Loose ends from the dual-grid session

Two GDScript changes were worked out but handed over as paste-in snippets
(Claude can't write to `scripts/` — see `.claude/settings.json`). Verify
these actually landed in `scripts/TileInitialize.gd` before moving on:

1. **Marker refresh** — `_apply_marker_appearance()` extracted out, and
   called on the `has_node()` early-return path as well as on creation.
   Makes `marker_color` edits on a `.tres` take effect on re-run instead
   of requiring manual node deletion. Also sets `source.resource_name` to
   the tile's real PNG filename so the editor's source list stops showing
   `flat-color.png` eight times.
2. **Draw ordering** — `pair.z_index = tile_type.sort_order`, set on both
   the creation and refresh paths. `sort_order` existed on `TileType` but
   nothing read it. Matters because dual-grid display tiles bleed half a
   cell into neighbors, so different floor types genuinely overlap at
   seams and something has to win.

Also unset: `sort_order` on `floor_dirt`, `wall_cobble_brick`,
`wall_smooth_stone` (all default to 0). Believed intentional — confirm.

## Where things stand

The dual-grid renderer works and is noticeably easier to author with than
the previous approach. Tile resources all carry `marker_color` now, so the
data layers are readable while painting. Textures are still placeholders;
this deliberately does **not** block the generation work below.

## Direction that feels settled

- **Rooms are rectangles on a coarse grid.** Not one uniform size, not
  freeform. Every room's width and height are multiples of one base unit
  (16 tiles, matching `x16y16HullSmall`), so a room occupies an integer
  W×H block of slots.
- **Doors live on slot boundaries**, expressed as `{ side, offset }` —
  which edge, and how far along it. Matching two rooms is then integer
  comparison, with no geometry involved.
- **Sync the seed, not the dungeon.** If generation is deterministic, the
  host sends one integer and every client builds an identical layout
  locally. Replicating placed tiles instead would cost orders of
  magnitude more traffic.
- **Every room resource needs an explicit stable ID** — a field in the
  `.tres`, not the filename, array index, or node name. Load order can
  differ between machines and platforms, and "room #3" has to mean the
  same room everywhere. This is the one thing determinism forces into the
  data model, and it is much cheaper to add now than to retrofit.

## Open questions — resolve before writing the generator

1. **Door granularity.** Is a door one slot wide (so a 16-tile edge is
   all-or-nothing), or can it be narrower/wider than the base unit? The
   simplest version says one slot; worth confirming that doesn't fight
   the art later.
2. **Do doors need types?** Locked, secret, one-way, boss-gate. Even if
   none are implemented now, knowing whether the field exists changes the
   struct.
3. **What breaks determinism at generation time.** Not yet discussed.
   Short version: use an explicit seeded `RandomNumberGenerator`, never
   global `randi()`; never let a random choice depend on iteration over
   something whose order can vary. This needs a proper pass.
4. **Content version mismatch.** Same seed plus *different* room
   resources equals different dungeons, so a client on a stale build
   silently desyncs. Some hash or version check at join time. Where does
   that live?
5. **Size classes.** Is there a fixed menu of footprints (1×1, 1×2, 2×2…)
   or can any W×H exist? Affects how placement searches for a fit.
6. **Room-set scope.** Does the generator pick from one flat pool, or are
   there roles (entrance, boss, treasure, filler)?

## Suggested order of work

1. Apply and verify the two paste-ins above.
2. Add the stable-ID field to the room/tile resource side. Cheap, and
   everything else assumes it.
3. Settle questions 1, 2, and 5 — they define the connection struct.
4. Build a throwaway placement test: **one** room, placed repeatedly on
   the coarse grid, checking door flags against neighbors. One room is
   genuinely enough to prove the stitching; it does not need to look like
   a dungeon.
5. Only then do the determinism pass (question 3) and re-run the same
   seed twice to confirm identical output.
6. Draw more rooms *after* the assembler exists — building it first tends
   to change what a good room looks like, so authoring a dozen now risks
   redoing them.

## Later idea: room storage format + editor (not started)

Floated in a design discussion: switch room storage from one `.tscn`
scene per room to a single data file the generator reads directly —
lighter to load, easier for procedural generation to reason about than
a scene tree. Genuinely useful, but it's two separate asks bundled
together:

1. **Storage format change** (scene → single data file). Smaller,
   mechanical, worth doing eventually.
2. **An in-game visual tool** to place tiles and author rooms with a
   live preview. A whole editor UI — its own project, not a follow-on
   task to #1.

Not blocked on anything else, but also not blocking anything else —
there's still only one hand-placed room, so `.tscn` storage isn't
actually hurting yet. Revisit once the assembler exists and more rooms
are being authored.

## Deliberately not now

- **Textures.** Real art is a time sink and placeholders are sufficient
  for all of the above. Art direction sits with Silvery Foxy anyway.
- **Antagonist/boss lobby role.** Already marked confirmed-but-deferred
  in `design-goals.md`; nothing here should be shaped around it yet.
- **Hosting specifics** (Linux vs. Windows). Seed-sync is the right call
  regardless of how hosting resolves, so this doesn't block.
