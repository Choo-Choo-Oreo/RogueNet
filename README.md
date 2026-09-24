# RogueNet

Multiplayer, procedurally-generated dungeon-crawler RPG with roguelite
elements (leveling, loot rarity, skill trees). See
[.claude/CLAUDE.md](.claude/CLAUDE.md) for project context and how Claude
Code should behave in this repo.

## Adding content (modding guide)

Most game content is data-driven JSON under `game/` (paired with art/audio
under `resources/`), loaded at runtime — no script changes needed to add a
new enemy, room, or tile. This section documents those formats.

### Enemies — `game/entities/entities.enemies/<id>.json`

The filename (minus `.json`) is the enemy's id, used everywhere else
(biome `monsters` weights, etc). Example (`rat.json`):

```json
{
	"size_tiles": 1,
	"max_health": 5,
	"strength": 0,
	"dexterity": 1,
	"constitution": 0,
	"cognitive": 0,
	"resistances": {},
	"speed_tiles_per_second": 6.0,
	"attack": {
		"amount": 1,
		"type": "Physical",
		"interval": 1.2,
		"effect": {
			"texture": "res://resources/gfx/effects/effects.melee/physical.biting.png",
			"frame_count": 10,
			"speed": 20.0
		}
	},
	"sprite_frames": {
		"frame_size": [16, 16],
		"animations": {
			"Front": { "texture": "res://resources/gfx/entities/entities.enemies/rat/rat/Rat-Down.png", "frame_count": 2, "speed": 20.0 },
			"Back": { "texture": "res://resources/gfx/entities/entities.enemies/rat/rat/Rat-Up.png", "frame_count": 2, "speed": 20.0 },
			"SideLeft": { "texture": "res://resources/gfx/entities/entities.enemies/rat/rat/Rat-Left.png", "frame_count": 2, "speed": 20.0 },
			"SideRight": { "texture": "res://resources/gfx/entities/entities.enemies/rat/rat/Rat-Right.png", "frame_count": 2, "speed": 20.0 }
		}
	}
}
```

Notes:
- `resistances` maps a damage type (see `game/damage_types.json`) to a
  multiplier; omit a type for no resistance.
- `attack.type` must be one of the ids in `game/damage_types.json`.
- Ranged attacks add `attack.range_tiles` and swap `attack.effect` for
  `effect.projectile` (a texture path) plus `effect.attacker`/`effect.target`
  wind-up/impact animations, each with an `anchor` of `"attacker"` or
  `"target"`. See `skeleton_archer.json` for a full example.
- `senses` (optional) overrides which detection senses are enabled, e.g.
  `"senses": { "hearing": false }`. Only `sight` and `touch` are actually
  implemented right now — `hearing`/`smell`/`taste` exist but always report
  no detection.
- `flying` (optional, default `false`) — set `true` for enemies that fly
  (bat, flying hamsters). Terrain (water, lava, rough ground) never slows
  them, their routes ignore terrain cost, and their idle animation never
  freezes on a held frame (the wing-flap). Ground enemies slow down on
  terrain and route around slow ground when a detour is cheaper.
- `tags` (optional) — what kind of creature it is (`["beast.rodent"]`).
  Rooms can favor a tag for spawns. The list of tags and what each means is
  in `game/TAGS.md`; reuse one before inventing another.
- Sprite PNGs and their animation JSON (if any, e.g. Aseprite exports) live
  together under `resources/gfx/entities/entities.enemies/<id>/`, not under
  `game/`.

### Rooms — `game/rooms/<biome>/<id>.json`

Each biome is a folder name (`dungeon`, `cave`, `mine`, `flesh`, `forest`,
`cathedral`, `fallback`) — biome discovery is folder-driven, so a new
folder here is automatically a new biome once it has a `defines.json` (see
below). Each biome should have at least one `role: "entrance"` room and one
`role: "boss"` room; everything else is normally `role: "normal"`.

Example (`Dungeon_Brick_Arena_9x9.json`, trimmed):

```json
{
	"format": 2,
	"biome": "dungeon",
	"id": "Dungeon_Brick_Arena_9x9",
	"width": 9,
	"height": 9,
	"role": "normal",
	"tags": ["combat", "brick"],
	"connectors": [
		{ "a": { "x": 4, "y": 0 }, "b": { "x": 4, "y": 0 } },
		{ "a": { "x": 4, "y": 8 }, "b": { "x": 4, "y": 8 } }
	],
	"spawn_cells": [
		{ "position": { "x": 7, "y": 4 } },
		{ "position": { "x": 1, "y": 4 } }
	],
	"objects": [
		{ "type": "torch", "position": { "x": 40.0, "y": 24.0 }, "rotation": 0.0 }
	],
	"floor": [ /* height rows x width cols, each cell a tile id string or null */ ],
	"walls": [ /* same shape; leave connector cells null (no wall) */ ]
}
```

Every key (size, `role`, `tags`, `floor`/`walls`, `connectors` and their
`door`, `spawn_cells`, `favored_enemy`, `objects`) is explained in
`game/rooms/README.md` under "Room JSON reference". Tile size is 16px.

### Biome config — `game/rooms/<biome>/defines.json`

```json
{
	"room_count": { "min": 20, "max": 30 },
	"tag_weights": { "maze": 0.6, "corridor": 0.6 },
	"monsters": { "rat": 3, "rat_blind": 1, "skeleton_archer": 2, "wolf": 1 },
	"music": "res://resources/sfx/music/Groovy.mp3"
}
```

- `room_count` — how many rooms the generator places for this biome's dive.
- `tag_weights` — multiplies selection odds for rooms carrying a given
  `tags` entry; a room can match more than one.
- `monsters` — weighted random table (same shape as `tag_weights`, just for
  enemy ids instead) consumed when rolling what spawns in each room's
  `spawn_cells`. Weights are relative, not percentages — they just need to
  be consistent within one table.
- `music` — path to the biome's background track.
- `default_door` (optional) — a door type name (`"wood"`) or `"none"`; missing
  means `"none"`. It is what a joint gets when neither connector asks for
  anything specific (see below). A type that is too narrow for a joint is
  replaced by the first (by name) that fits, with a warning in the log.

A room connector may carry a `"door"` key: a door type (`"wood"`), `"none"`, or
`"any"` (the default, so it can be left out). The two connectors of a joint
resolve like this:

- a specific type always gets its door; if both sides ask for a type, the room
  being entered (the deeper one) wins
- otherwise `"none"` on either side means no door
- `"any"` + `"any"` uses the biome's `default_door`

E.g. a hallway's connectors stay `"none"`/`"any"` and the barracks entrance says
`"door": "wood"`: hallway-to-hallway joints stay open, the barracks gets a wood
door. (There is no editor field for it yet; add the key by hand in the room
JSON. DungeonMaker keeps it when re-saving.)

### Doors — `game/doors/<type>.json`

```json
{
	"name": "wood",
	"art": {
		"1": "res://resources/gfx/doors/Wood_W1.json",
		"2": "res://resources/gfx/doors/Wood_W2.json",
		"3": "res://resources/gfx/doors/Wood_W3.json",
		"4": "res://resources/gfx/doors/Wood_Fold_W4.json",
		"5": "res://resources/gfx/doors/Wood_Fold_W5.json"
	},
	"transparent": false,
	"min_width": 1,
	"max_width": 5,
	"open_seconds": 0.3
}
```

- `transparent` — see-through (bars / grate): a closed one still blocks
  walking and shots but not sight or light.
- Whether an enemy opens doors is its own `"doors"` field in its enemy json:
  `"none"` (default, can't), `"open"` (see-through doors any time, solid ones
  only while investigating or pursuing) or `"phase"` (passes through closed
  doors without opening them).
- `open_seconds` — how long the swing / slide takes.
- `passable_at` — how far through that swing (0..1) the door can be walked through; until then it still blocks walking and shots (not sight or light), for monsters too. `0.5` for wood (swings clear early), `1.0` for bars that have to lift fully. Default `1.0`.
- `min_width` / `max_width` — joint widths (in tiles) this door type can fill (`2`/`2` for a fixed-width door, `1`/`5` for a full set).
- `art` — the atlas manifest(s) for this door: one path when a single atlas covers every width the type allows (`Iron_W1-5.json`), or a map of width to path when each width has its own (`"1": Wood_W1.json`, `"2": Wood_W2.json`). Each manifest names its atlas `<Style>_W<n>.png` or `<Style>_W<min>-<max>.png`, the `_Normal.png` beside it, the `widths` it covers, its `frame_size` and `own_cell_row` (`[16, 32]` / `16` for the wood and iron doors: 16 rows over the cell north of the doorway, then the piece's own cell; `[16, 48]` / `32` for the `Dungeon` boss door, whose frame stands one more cell north). DoorManager draws a piece with its top-left at `(cell.x*16, cell.y*16 - own_cell_row)` and a region `frame_size` tall, and the piece rows with `atlas_y`. Styles so far: `Wood` (swinging leaves, widths 1-3), `Wood_Fold` (bi-fold panels on a rail, widths 3-5; the `wood` type borrows it for 4 and 5, and the `wood_fold` type offers it as a second look for 3-wide gaps), `Iron` and `IronSink` (gates, 1-5), `Dungeon` (placeholder boss-room door, 4-5: flat red/blue sliding leaves 16px tall between 24px stone posts, 16 frames, detail still to come; its manifest also names a one-frame `_Overlay.png` holding the lintel at 50% alpha, to be drawn above creatures so they walk under it; on vertical doors it is a bar along the seam, and each vertical overlay piece only carries its own cell's rows so the translucency never stacks where pieces overlap). A door 5 wide repeats a middle piece on each side, so the second one is named with a `_2` suffix (`h_middle_left_2`, `v_middle_top_2_left`); DoorPlacer produces those names and every atlas that covers width 5 has a row for them (the iron atlases reuse their plain middle art). Names: CamelCase style, `W` plus the width or width range, `_Normal` last.
- Boss doors live in `resources/gfx/doors/doors.boss/` and are LAYERED: one manifest per width (`Dungeon_W4.json`, `Dungeon_W5.json`) with a `layers` map and a `draw_order` of `frame` (`_Frame.png`, one frame, the posts), `leaves` (`_Leaves.png`, 16 frames, the sliding halves) and `overlay` (`_Overlay.png`, one frame, the lintel with 50% alpha baked in, drawn above creatures so they walk under it). All three share the manifest's `pieces` / `atlas_y`, `frame_size` `[16, 48]` and `own_cell_row` `32`, and their opaque pixels never overlap, so they are simply drawn at the same position. The flat red/blue `Dungeon` style is the placeholder template. The manifest's `frame_sets` map holds one real frame per wall tileset, keyed by the wall tile name (`wall_cobble_brick` -> `CobbleBrick_W4_Frame.png` + `CobbleBrick_W4_Overlay.png` + `_Frame_Normal.png`): same rows and geometry as the placeholder frame, cut 1:1 from that wall's own art (posts are three courses of the wall's face under a rimmed top, the lintel one course at 50%), using only that wall's colours, black only where the wall itself uses it (tops = unseen). The forest set is hand-drawn logs in the forest palette instead (no frame holding up trees). The manifest's `leaf_sets` map holds one leaves atlas per boss tier, keyed by tier (`wood` -> `Wood_W4_Leaves.png` + `_Leaves_Normal.png`, 16 frames): same rows, frames and opaque pixels as the placeholder leaves, drawn per width, never scaled, so the manager picks the tier's atlas instead of the placeholder. The tier tells the player how deadly the boss is and how good the loot: wood (a basic point-of-interest boss), then iron, bronze, silver, gold. Wood is the room doors' palette (planks, two iron straps with rivets, a rimmed meeting edge, brass handles). Each metal tier is a distinct design built on the tier below, one step back only, six colours each (three from the metal underneath, three from the metal on top). Iron replaces the wood door's cheap grey bands with an iron grid (two straps and vertical strips bolted at the crossings) over 8x8 squares of the wood planks. Bronze is an all-iron plated door (seams, rivets, no wood left) with bronze straps, edge plate and top cap. Silver is bronze plates inside a 2px silver border with a silver diamond boss on each plate. Gold is silver plates inside a 2px gold border with a riveted gold X brace across each leaf. Still to come: a separate small emblem sprite on the lintel for the monster kind behind the door. Orea's separate boss-door manager reads these; the plain DoorManager does not.
- Players open a door by walking into it. It closes again a couple of
  seconds after everyone has moved away. Open/closed state is host-owned.

### Tiles — `game/tiles/<id>.json` + `game/tile_registry.json`

```json
{
	"tile_name": "floor_grass",
	"atlas_texture": "res://resources/gfx/tileset/floor_grass.png",
	"normal_texture": "res://resources/gfx/tileset/floor_grass_normal.png",
	"specular_color": [0.05, 0.05, 0.05, 1],
	"sort_order": 3,
	"marker_color": [0.356863, 0.54902, 0.227451, 1]
}
```

- A new tile still needs a matching entry added to `game/tile_registry.json`
  to actually be usable from room JSON.
- Tile art (and normal maps) live under `resources/gfx/tileset/`. Tileset
  art is capped at 6 colors per tile (the black wall-top strip doesn't
  count toward that) — regenerate normal maps after any wall/floor art
  edit.
- Naming is subject-first: `wall_forest_dense`, not `wall_dense_forest`.

## Tech stack

- Godot Engine, .NET-enabled build (supports C#, but the team mostly works
  in GDScript in practice).
- Build command: _(fill in once established)_
- Test command: _(fill in once established)_
