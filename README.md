# RogueNet

Multiplayer, procedurally-generated dungeon-crawler RPG with roguelite
elements (leveling, loot rarity, skill trees). See
[.claude/CLAUDE.md](.claude/CLAUDE.md) for project context and how Claude
Code should behave in this repo.

## Adding content (modding guide)

Most game content is data-driven JSON under `game/` (paired with art/audio
under `resources/`), loaded at runtime — no script changes needed to add a
new minion, room, or tile. This section documents those formats.

### Minions — `game/entities/entities.antagonist/minions/<id>.json` (or `bosses/`)

The filename (minus `.json`) is the minion's id, used everywhere else
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
	"actions": [{ "action": "bite", "interval": 1.2 }],
	"sprite_frames": {
		"frame_size": [16, 16],
		"animations": {
			"Front": { "texture": "res://resources/gfx/entities/entities.antagonist/minions/rat/rat/Rat-Down.png", "frame_count": 2, "speed": 20.0 },
			"Back": { "texture": "res://resources/gfx/entities/entities.antagonist/minions/rat/rat/Rat-Up.png", "frame_count": 2, "speed": 20.0 },
			"SideLeft": { "texture": "res://resources/gfx/entities/entities.antagonist/minions/rat/rat/Rat-Left.png", "frame_count": 2, "speed": 20.0 },
			"SideRight": { "texture": "res://resources/gfx/entities/entities.antagonist/minions/rat/rat/Rat-Right.png", "frame_count": 2, "speed": 20.0 }
		}
	}
}
```

Notes:
- `sprite_frames` may also have attack frames: an animation named `"Attack"` + a walk
  animation (`AttackFront`, `AttackSideRight`...), with `"loop": false`. It plays once, on
  every screen, when the creature attacks facing that way (`DirectionalAnimator.play_attack`);
  a direction without one just faces the target. The wolf has a full set.
- `resistances` maps a damage type (see `game/damage_types.json`) to a
  multiplier; omit a type for no resistance.
- `actions` is what the creature can do: a list of action ids, each a file in
  `game/actions/` (see its README). An entry is an id (`"bite"`) or an id with the numbers
  that differ for this creature (`{ "action": "bite", "interval": 1.2 }`). The first is the
  default attack (its `range_tiles` is how close the minion walks); later ones are used
  while it is chasing, whenever ready and in range. The attack's own fields (damage type,
  ranged effects, `destroy_tiles` shape) are described in `game/actions/README.md`.
- `senses` (optional) overrides which detection senses are enabled, e.g.
  `"senses": { "hearing": false }`, or sets a sense's numbers, e.g.
  `"senses": { "hearing": { "range_tiles": 8.0 } }`. `touch`, `sight` and `hearing` are
  implemented; `smell`/`taste` exist but always report no detection. Hearing is by event:
  a noise (a player's footstep, loudness 1.0; a thrown rock landing, 3.0) is heard within
  `range_tiles * loudness` tiles (default range 3, through walls), and the minion
  investigates the *spot* of the noise, not the player.
- `flying` (optional, default `false`) — set `true` for minions that fly
  (bat, flying hamsters). Terrain (water, lava, rough ground) never slows
  them, their routes ignore terrain cost, and their idle animation never
  freezes on a held frame (the wing-flap). Ground minions slow down on
  terrain and route around slow ground when a detour is cheaper.
- `tags` (optional) — what kind of creature it is (`["beast.rodent"]`).
  Rooms can favor a tag for spawns. The list of tags and what each means is
  in `game/TAGS.md`; reuse one before inventing another.
- Sprite PNGs and their animation JSON (if any, e.g. Aseprite exports) live
  together under `resources/gfx/entities/entities.antagonist/minions/<id>/`, not under
  `game/`.
- `idle` (optional, next to `sprite_frames`; only the player's `human.json` reads it so far)
  — life while standing still (`DirectionalAnimator.set_idle_life`). `"breath": true` sinks
  the body 1px for half of every 3 s. `"blink": { "texture": ..., "animations": [...] }`
  is a sheet of 16x16 eyelid-only cells, one per listed animation in that order
  (`Human-Blink.png`: Front, FrontRight, Side), shown for 0.2 s of every 3 s. Attack and
  death need no art: the whole body lunges or topples (see `DirectionalAnimator`).

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
`door`, `spawn_cells`, `favored_minion`, `objects`) is explained in
`game/rooms/README.md` under "Room JSON reference". Tile size is 16px.

A spawn cell may also name an exact minion, `{ "position": {...}, "minion": "rat" }`
(any id from `game/entities/entities.antagonist/`): that cell always spawns it
instead of rolling the biome table. The Dungeon Maker's minion spawner sets this.

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
  minion ids instead) consumed when rolling what spawns in each room's
  `spawn_cells`. Weights are relative, not percentages — they just need to
  be consistent within one table.
- `music` — path to the biome's background track.
- `ambience` (optional) — path to a sound that loops under the music for the
  whole dive (dripping water in a cave, wind through ruins), on the effects
  volume; biomes that sound alike name the same file. It fades in when the
  dungeon starts and out on leaving. The files are in
  `resources/sfx/ambiance/` (imported looping; see its README).
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
- Whether a minion opens doors is its own `"doors"` field in its minion json:
  `"none"` (default, can't), `"open"` (see-through doors any time, solid ones
  only while investigating or pursuing) or `"phase"` (passes through closed
  doors without opening them).
- `open_seconds` — how long the swing / slide takes.
- `passable_at` — how far through that swing (0..1) the door can be walked through; until then it still blocks walking and shots (not sight or light), for monsters too. `0.5` for wood (swings clear early), `1.0` for bars that have to lift fully. Default `1.0`.
- `min_width` / `max_width` — joint widths (in tiles) this door type can fill (`2`/`2` for a fixed-width door, `1`/`5` for a full set).
- `art` — the atlas manifest(s) for this door: one path when a single atlas covers every width the type allows (`Iron_W1-5.json`), or a map of width to path when each width has its own (`"1": Wood_W1.json`, `"2": Wood_W2.json`). Each manifest names its atlas `<Style>_W<n>.png` or `<Style>_W<min>-<max>.png`, the `_Normal.png` beside it, the `widths` it covers, its `frame_size` and `own_cell_row` (`[16, 32]` / `16` for the wood and iron doors: 16 rows over the cell north of the doorway, then the piece's own cell; `[16, 48]` / `32` for the `Dungeon` boss door, whose frame stands one more cell north). DoorManager draws a piece with its top-left at `(cell.x*16, cell.y*16 - own_cell_row)` and a region `frame_size` tall, and the piece rows with `atlas_y`. Styles so far: `Wood` (swinging leaves, widths 1-3), `Wood_Fold` (bi-fold panels on a rail, widths 3-5; the `wood` type borrows it for 4 and 5, and the `wood_fold` type offers it as a second look for 3-wide gaps), `Iron` and `IronSink` (gates, 1-5), `Dungeon` (placeholder boss-room door, 4-5: flat red/blue sliding leaves 16px tall between 24px stone posts, 16 frames, detail still to come; its manifest also names a one-frame `_Overlay.png` holding the lintel at 50% alpha, to be drawn above creatures so they walk under it; on vertical doors it is a bar along the seam, and each vertical overlay piece only carries its own cell's rows so the translucency never stacks where pieces overlap). A door 5 wide repeats a middle piece on each side, so the second one is named with a `_2` suffix (`h_middle_left_2`, `v_middle_top_2_left`); DoorPlacer produces those names and every atlas that covers width 5 has a row for them (the iron atlases reuse their plain middle art). Names: CamelCase style, `W` plus the width or width range, `_Normal` last.
- Boss doors live in `resources/gfx/doors/doors.boss/` and are LAYERED: one manifest per width (`Dungeon_W4.json`, `Dungeon_W5.json`) with a `layers` map and a `draw_order` of `frame` (`_Frame.png`, one frame, the posts), `leaves` (`_Leaves.png`, 16 frames, the sliding halves) and `overlay` (`_Overlay.png`, one frame, the lintel with 50% alpha baked in, drawn above creatures so they walk under it). All three share the manifest's `pieces` / `atlas_y`, `frame_size` `[16, 48]` and `own_cell_row` `32`, and their opaque pixels never overlap, so they are simply drawn at the same position. The flat red/blue `Dungeon` style is the placeholder template. The manifest's `frame_sets` map holds one real frame per wall tileset, keyed by the wall tile name (`wall_cobble_brick` -> `CobbleBrick_W4_Frame.png` + `CobbleBrick_W4_Overlay.png` + `_Frame_Normal.png`): same rows and geometry as the placeholder frame, cut 1:1 from that wall's own art (posts are three courses of the wall's face under a rimmed top, the lintel one course at 50%), using only that wall's colours, black only where the wall itself uses it (tops = unseen). The forest set is hand-drawn logs in the forest palette instead (no frame holding up trees). The manifest's `leaf_sets` map holds one leaves atlas per boss tier, keyed by tier (`wood` -> `Wood_W4_Leaves.png` + `_Leaves_Normal.png`, 16 frames): same rows, frames and opaque pixels as the placeholder leaves, drawn per width, never scaled, so the manager picks the tier's atlas instead of the placeholder. The tier tells the player how deadly the boss is and how good the loot: wood (a basic point-of-interest boss), then iron, bronze, silver, gold. Wood is the room doors' palette (planks, two iron straps with rivets, a rimmed meeting edge, brass handles). Each metal tier is a distinct design built on the tier below, one step back only, six colours each (three from the metal underneath, three from the metal on top). Iron replaces the wood door's cheap grey bands with an iron grid (two straps and vertical strips bolted at the crossings) over 8x8 squares of the wood planks. Bronze is an all-iron plated door (seams, rivets, no wood left) with bronze straps, edge plate and top cap. Silver is bronze plates inside a 2px silver border with a silver diamond boss on each plate. Gold is silver plates inside a 2px gold border with a riveted gold X brace across each leaf. The emblem is a separate small sign on the lintel that tells the player what the boss hits with. Emblems live in `resources/gfx/doors/doors.emblems/`, one 24x12 atlas per damage type (`Frigid_Emblem.png` + `_Emblem_Normal.png`): a 12x12 front view for horizontal doors and a 12x12 side view for vertical doors, where it sticks out of both faces of the 3px lintel bar. Each is a small raised carving drawn at the world's angle (lit top band above the face), in 8 colours ramped from that damage type's hit effect, with a motif taken from the effect: Arcana an unbroken gold ring standing on a slab (the substrate everything stands on), Necrotic a black void with fangs biting inward (an absence that has to keep feeding), Physical a sword; Ordo a cut crystal, Entropia a split ring spinning, Perditio the crystal emptied with its rim erased; Frigid a snowflake, Solum a boulder, Plenum a dense orb in a ring, Zeal a flame, Fluentia a drop, Inanis an open ring, Torpor a flat line in the void, Virulentia a solid shape eaten away to black with a few loose grains left, Ruina the ordered hex on one side of a rust threshold line and a dark angular wedge on the other (the same mass become something else). `emblems.json` maps each damage type id from `game/damage_types.json` to its atlas (fall back by dropping the last `.segment`, so `Physical.Slashing` uses Physical) and says where to draw the front and side frames on a door. Orea's separate boss-door manager reads these; the plain DoorManager does not.
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
  art is capped at 8 colors per tile (the black wall-top strip doesn't
  count toward that; older tiles were made under a 6-color cap) —
  regenerate normal maps after any wall/floor art edit.
- Naming is subject-first: `wall_forest_dense`, not `wall_dense_forest`.
- `footsteps` (floors, optional): the folder in `resources/sfx/effects/` whose
  `step_1.wav`, `step_2.wav`... play as a creature walks over the floor (`Wading`), so
  floors that sound alike share one: `floor_smooth_stone`, `floor_smooth_cave`, both
  cobblestones, `floor_gravel`, `floor_grate`, `floor_ice`, `floor_metal_plate` and `floor_brick` use
  `stone`, the five carpets `carpet`, `floor_wood_planks` and `floor_parquet` `wood`,
  `floor_moss`, `floor_leaves` and `floor_flowers` `grass`,
  `floor_sand` and `floor_snow` `dirt`, `floor_lava_crust` `lava`. Left out, it is the tile's
  name without `floor_` (`dirt`, `grass`, `flesh`, and the liquids' own folders). Every step
  on dry ground also puffs a little dust in the floor's colours.
- Variants: a tile's art can hold more than one 64x64 set, stacked top to bottom
  (animation frames run left to right). Each 8x8 quarter of the floor picks a set of its
  own, so a detail drawn in a variant set must fit inside one quarter and leave its edges
  as the first set has them. `variant_weights` (optional) says how often each set is picked:
  `[60, 1, 1, 1.5, 1.5]` on `floor_smooth_stone` keeps the clean first set nearly
  everywhere, with two cracked and two mossy sets turning up now and then. Without it every
  set is as likely (`floor_flesh`'s first four used to be); sets past the end of the list
  weigh 1. Now used by `floor_smooth_stone` (cracks, moss), `floor_flesh` (bits of bone:
  skulls, teeth, ribs) and `wall_rough_cave` (gold ore in the rock faces). The sets are
  drawn by script from the first one, so redraw the variants after changing it.
- A floor is a liquid when `resources/sfx/effects/<name without floor_>/enter.wav`
  exists (see that folder's README). Bodies wading in it sink, and below the surface
  take the tile art's most common colour, with a rim, droplets and rings in its lightest
  colour made paler (`scripts/entities/Wading.gd`). `see_through` (0-1, default 0.45)
  says how much of the legs shows below the surface: water 0.45, acid 0.3, lava 0.12.
- Wall/floor pairs share one 6-colour palette (`wall_smooth_cave` + `floor_smooth_cave`, added 2026-09-24: water-worn cave rock, a smooth sibling of `wall_rough_cave`; the wall reuses the rough cave's autotile mask, the floor reuses the dirt floor's rounded mask so both blend the same way).

### Items — `game/items/<folder>/<id>.json`

```json
{
	"name": "Heavy iron longsword",
	"slot": "main_hand",
	"set": "heavy_iron",
	"art": "res://resources/gfx/gear/main_hand/heavy_iron/HeavyIronLongsword"
}
```

- The file name is the item's id (`heavy_iron_longsword`), same rule as
  minions. The folder is only for tidiness; `slot` decides where it's worn.
- `slot` — one of `head`, `chest`, `gloves`, `legs`, `feet`, `neck`, `back`,
  `main_hand`, `off_hand`.
- `art` — the worn sheets' path minus the `-<Direction>.png` ending. The game
  adds `-Down`, `-DownRight`, `-Right`, `-UpRight` and `-Up`: 4 frames of
  16x16 each, lined up with the Human's walk cycle. In every direction frames
  1 and 3 are the steps: the body dips 1 px, so every piece sits 1 px lower
  there. The feet stay on the ground, so legs, feet, skirts and anything that
  reaches the bottom row lose a pixel of height in the middle instead (in
  `-Right`, legs and feet follow the stride pose). Left-facing views are the
  right-facing art mirrored. Which slots draw over or behind the body for
  each direction is `DRAW_ORDER` in `scripts/items/ItemDatabase.gd`.
  Held items (`main_hand`, `off_hand`) stay in their own hand facing left
  (`ItemDatabase.held_left`): facing left the main hand is the far hand
  (behind the body) and the off hand the near one (in front). Down-left and
  up-left use the plain `-Down` and `-Up` art. Facing left uses an optional
  `-Left` sheet when there is one (a shield showing its face in the near
  hand), else the `-Right` art mirrored.
- `set` — optional; storage lists items set by set (`heavy_iron`, `arcane`,
  `cleric`, `necromancer`, then everything else). Wearing a whole set (head,
  chest, gloves, legs and feet; weapons and amulet don't count) turns on its
  full-set bonus, if `game/sets/<set>.json` gives it one: an aura under the
  feet, a trail left on the floor, particles. See `game/sets/README.md`.
- `icon` — optional 16x16 PNG for inventory slots, kept in
  `resources/gfx/ui/icons/items/<item id>.png`. Without one, the slot
  shows the front view cropped to its pixels, which is too small to read for
  gloves and boots.
- `type` — instead of `slot`, for things that can't be worn: `potion`,
  `material` or `item` (folders `potion/`, `material/`, `misc/`).
- `rarity`, `sound`, `description` — optional; without them the item takes
  its set's (`game/sets/README.md`), then a default. `stack` — optional, how
  many fit in one cell (potions 10, materials 50, gear 1 by default).
- Items have no stats yet. The inventory lives in
  `singletons/PlayerInventory.gd`, in memory only: it starts over on every
  launch, with one of every item in the town storage (5 of anything that
  stacks). The storage screen (`scripts/ui/inventory/StoragePanel.gd`) has
  tabs by kind, search, sort, a set view, a lore page, and Ctrl+click to lock
  an item so sorting and "Store all" leave it alone.

## Tech stack

- Godot Engine, .NET-enabled build (supports C#, but the team mostly works
  in GDScript in practice).
- Build command: _(fill in once established)_
- Test command: _(fill in once established)_
