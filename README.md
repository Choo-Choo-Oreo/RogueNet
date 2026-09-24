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
- `continuous_animation` (optional, default `false`) — set `true` for
  enemies whose idle animation shouldn't freeze on a held frame (e.g. a
  flying enemy's wing-flap).
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

Notes:
- `width`/`height` are in tiles; `floor`/`walls` are 2D arrays indexed
  `[y][x]`, each cell either a tile id from `game/tiles/` or `null`.
- `connectors` (format 2) are the openings on the room's edge: a straight
  run of cells from `a` to `b`, both included, `a` being the top/left end
  (`a` equal to `b` is a single-cell opening). Runs must sit on one edge and
  not include a corner. They only describe the opening -- doors are a separate
  idea, still to come (see CONNECTORS_TRACKER.md); there is no door tile now.
  Two connectors join at equal widths, or at any width if either has
  `"free": true`; cells of a wider run with no partner are sealed with wall.
  Leave the connector cells' `walls` entries `null`; the painter places floor.
  Old files with `{ "position": ... }` connectors (format 1) still load: they
  are upgraded in memory.
- `spawn_cells` are candidate enemy-spawn tiles for this room; skip cells
  in `entrance`/`boss` rooms and anything tagged `"treasure"` (the
  assembler enforces this, but keep it in mind when adding new rooms by
  hand). Placement doesn't need to be exact science — spread a handful
  around cover/corners rather than clustering them all in the open.
- `tags` feed the biome's `tag_weights` (below) to bias which rooms get
  picked more/less often.
- `objects` are decorative placements (`type` must be a known object id);
  `position` here is in **pixels**, not tiles, unlike everything else.
- Tile size is 16px.

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
- `doors` (optional) — `{ "density": 0..1, "types": ["wood", "iron"] }`. Each
  open joint between two rooms rolls `density` for a door; the type is picked
  from `types` among those whose width range fits the joint. No `doors` key =
  no doors in that biome.

### Doors — `game/doors/<type>.json`

```json
{
	"name": "wood",
	"art": "res://resources/gfx/doors/Wood",
	"transparent": false,
	"min_width": 1,
	"max_width": 2,
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
- `min_width` / `max_width` — joint widths (in tiles) this door type can fill.
- `art` — style prefix of the door art: `<prefix>_<Width>.json` describes the atlas `<prefix>_<Width>.png` for a door of that width (rows per piece, `atlas_y`), with `<prefix>_<Width>_Normal.png` beside it. Names are `<Style>_<Width>`, CamelCase style, plain digit width, e.g. `Wood_2`.
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
