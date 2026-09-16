# Dungeon Room Format + Dungeon Maker Tool

**Status:** scoped, not started. This file is staged at the repo root
temporarily — it belongs at `scripts/dungeon/README.md` once that folder
exists (Orea will move it).

## What this is

A JSON-based format for a single dungeon room, plus an in-game tool
("the Dungeon Maker") that lets a non-programmer paint a room's tiles,
place objects, mark connectors, and export it to that format.

**Dungeon Maker is its own scene, separate from `scenes/rooms/Dungeon.tscn`.**
`Dungeon.tscn` is where a room gets *loaded and played* at runtime (part
of the town → dive → dungeon flow). Dungeon Maker is the *authoring*
scene — reached from the main menu, not from gameplay — where a room
gets *created*. They share the room JSON format but are otherwise
unrelated scenes.

Dungeon Maker should be a `Node2D` scene (not `Control`), using the same
`data_layer`/`display_layer` `TileMapLayer` pattern `HubMPTest.tscn`
already uses for its floor/wall visuals, driven by
[`DualGridRender.gd`](scripts/cells/tiles/DualGridRender.gd). That script
already listens for `data_layer.changed` and re-renders automatically —
so painting a tile onto the data layer already gets the "update live as
you paint" behavior for free, no new code needed for that part.

A **"Dungeon Maker" button already exists in `scenes/ui/MainMenu.tscn`**
(added, not yet wired to anything) — once this scene exists, connect its
`pressed` signal to a handler that calls
`get_tree().change_scene_to_file(...)` to it, the same way Singleplayer/
Multiplayer already work in `scripts/ui/MainMenu.gd`. Dungeon Maker needs
its own way back to the main menu too (same pattern as `LobbyMenu.gd`'s
`_on_back_pressed`).

This fulfills the "Later idea: room storage format + editor" section of
`.claude/docs/dungeon-assembly-plan.md` — see that file for the broader
dungeon-generation context (seed-synced determinism, why rooms need a
stable ID, open questions about the assembler that reads these files).

**Two deliberate departures from that draft doc**, decided 2026-09-16:
- Rooms are **arbitrary width × height**, not sized in multiples of a
  16-tile base unit. Less constraint on room authoring for now.
- Connectors store only a **tile position**, not an explicit
  `{ side, offset }`. Which edge a connector sits on (and therefore which
  direction it faces) is inferred from that position relative to the
  room's bounding box whenever the room is placed — this stays correct
  automatically under rotation, instead of needing to be kept in sync.

Both were open/undecided in the draft doc, so this isn't overriding a
settled decision — just resolving them.

## Why this exists right now

RogueNet's netcode is actively being reworked in another track of work.
This tool and format are intentionally a **separate, parallel track** —
no shared files with `scripts/network/`, `singletons/NetworkSync.gd`, or
`scripts/player/PlayerController.gd`. If you're picking this up, you
should not need to touch anything in those folders.

## Room JSON format

```json
{
  "format": 1,
  "id": "bandit_camp_small",
  "tags": ["combat", "brick"],
  "width": 5,
  "height": 5,
  "floor": [
    ["dirt", "dirt", "dirt", "dirt", "dirt"],
    ["dirt", "dirt", "dirt", "dirt", "dirt"],
    ["dirt", "dirt", "dirt", "dirt", "dirt"],
    ["dirt", "dirt", "dirt", "dirt", "dirt"],
    ["dirt", "dirt", "dirt", "dirt", "dirt"]
  ],
  "walls": [
    ["cobble_brick", "cobble_brick", "cobble_brick", "cobble_brick", "cobble_brick"],
    ["cobble_brick", null, null, null, "cobble_brick"],
    ["door", null, null, null, "cobble_brick"],
    ["cobble_brick", null, null, null, "cobble_brick"],
    ["cobble_brick", "cobble_brick", "cobble_brick", "cobble_brick", "cobble_brick"]
  ],
  "objects": [
    { "type": "torch", "position": { "x": 1.0, "y": 1.0 } },
    { "type": "chest", "position": { "x": 3.5, "y": 2.25 } }
  ],
  "connectors": [
    { "position": { "x": 0, "y": 2 } }
  ]
}
```

### Field reference

| Field | Type | Notes |
|---|---|---|
| `format` | int | Schema version, same convention as Godot's own `.tscn` `format=` field. Bump this if the shape of the file ever changes. |
| `id` | string | Stable, explicit identifier for this room. Never derive identity from the filename, array position, or node name — those can differ across machines/load order. |
| `tags` | array of string | Free-form, but see **Tag conventions** below. |
| `width`, `height` | int | Room size in tiles. `floor`/`walls` arrays must be exactly `height` rows of `width` columns each. |
| `floor` | 2D array of string/null | Row-major (`floor[y][x]`). Each cell is a tile-palette name, or `null` if that cell isn't part of the room (for non-rectangular rooms). |
| `walls` | 2D array of string/null | Same shape and rules as `floor`. `"door"` is just a tile-palette name like any other — it renders as a wall-layer tile, and is also how a connector's cell is visually represented. |
| `objects` | array of object | `{ "type": string, "position": { "x": float, "y": float } }`. Free placement, not tile-locked — matches Godot's `Vector2`. |
| `connectors` | array of object | `{ "position": { "x": int, "y": int } }`. Tile-aligned — matches Godot's `Vector2i`. Must sit on a cell that's on the room's outer boundary (row/col 0 or the max row/col) so a facing can be inferred. |

### Tile palette (name → actual tile)

A separate lookup file (`game/tile_palette.json`) maps the human-readable
names used in `floor`/`walls` to Godot's actual tile addressing — `source_id` and
`atlas_coords`, exactly the arguments `TileMapLayer.set_cell()` expects:

```json
{
  "dirt":         { "source_id": 0, "atlas_coords": [0, 0] },
  "cobble_brick": { "source_id": 0, "atlas_coords": [2, 1] },
  "door":         { "source_id": 1, "atlas_coords": [0, 3] }
}
```

This keeps the room JSON friendly for a human to read/write while the
reader can translate a cell directly:
`tile_map_layer.set_cell(Vector2i(x, y), palette[name].source_id, Vector2i(palette[name].atlas_coords[0], palette[name].atlas_coords[1]))`.

### Tag conventions

Two loose categories, not enforced by the schema, just a convention so
tags stay meaningful instead of arbitrary:

- **Purpose** — what kind of room this is: `"combat"`, `"peaceful"`,
  `"trap"`, `"treasure"`, etc.
- **Style** — visual/thematic identity, to avoid mixing incompatible
  aesthetics when a dungeon is assembled from multiple rooms: `"brick"`,
  `"cave"`, `"wood"`, etc.

Don't tag size (`"small"`, `"large"`) — `width`/`height` already say
that exactly; a redundant tag can only go stale.

## What the Dungeon Maker needs to do

An in-editor Godot tool (not a runtime/in-game feature) that lets someone
without programming experience:

1. Set a room's `width`/`height` and `id`.
2. Paint `floor` and `walls` tiles by picking from the tile palette
   (palette entries should show by name, not raw `source_id`/
   `atlas_coords`).
3. Place `objects` freely (not snapped to the tile grid).
4. Mark `connectors` on boundary tiles.
5. Add/edit `tags`.
6. Export the result as a room JSON file conforming to the format above,
   plus maintain the shared tile palette file as new tile types are
   needed.

This is scoped as an editor tool, not a whole game system — it doesn't
need to know anything about how rooms get assembled into a dungeon at
runtime. That's separate, future work (the "reader/assembler"), and per
`dungeon-assembly-plan.md` needs to stay deterministic (seed-synced
across multiplayer peers) — something to keep in mind if this tool's
scope ever grows toward also *loading* rooms, but out of scope for now.

## Where this goes once moved

- `scripts/dungeon/` — Dungeon Maker script(s), this README, and (later)
  the reader/assembler.
- `scenes/dev/` or `scenes/ui/` — the Dungeon Maker scene itself (name
  TBD, e.g. `DungeonMaker.tscn`).
- `game/rooms/` — exported room JSON files. This already exists
  (`game/rooms/.gitkeep`).
- `game/tile_palette.json` — the shared tile-name lookup file. Per Orea:
  `game/` is where *all* non-animation JSON data lives, so this belongs
  there rather than under `resources/`.

## Explicitly out of scope for this tool

- Reading/assembling rooms into an actual dungeon at runtime.
- Room rotation logic (applied by the future assembler, not stored in
  the room file or handled by the creator).
- Anything in `scripts/network/`, `singletons/NetworkSync.gd`, or
  `scripts/player/`.
