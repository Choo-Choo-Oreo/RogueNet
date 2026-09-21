# RogueNet Art To-Do

Legend: ✓ done, ✗ not done. Statuses were checked against the files (not by
running the game), so anything about how it looks or plays is unconfirmed.

Written 2026-09-21 from what is actually in `resources/gfx/` and `game/rooms/`.
It is a draft. **Silvery Foxy has the final say on style**, and anything marked
**(decide first)** needs a design answer from Orea before anyone draws it.

How to use it: put your name next to a line before you start (`- [✗] Barrel — Foxy`),
tick it when the PNG is in the repo. Small finished things beat big unfinished things.

## Where to start

Two artists, two tracks that don't collide:

- **Track A, objects.** Every room in the game is bare: the only objects that exist are
  one torch and one chest. Section 2, "Everywhere" then "Dungeon". This is the biggest
  visible win for the least work, and each object is one small 16x16 sprite.
- **Track B, tiles.** The eleven existing tiles are done, so start on what's missing:
  doors per biome, then new floors. Section 1 lists the palettes to stay consistent with.

Enemies (section 4) come next, but the enemy roster isn't designed yet, so check with Orea first.

## House style, as the art stands today

| Thing | Rule |
|---|---|
| Tile size | 16x16 pixels. The camera is top-down, and walls show a front face on their south side. |
| Tile colors | At most 6 colors per tile. For walls the pure black top doesn't count. |
| Edges | Hard pixels only. No soft brushes, no semi-transparent pixels, no anti-aliasing. |
| Shades | No two shades that are nearly the same. If you can't tell them apart at 1x, merge them. |
| Wall tops | Pure black `#000000`. This is what makes walls merge into the void. |
| Characters, objects | 16x16 per frame. The 6-color limit does not apply (the knight uses up to 17). |
| Files | PNG in the repo, keep the `.aseprite` next to it. |
| Normal maps | Not your job. They are generated from your PNG by a script. Tell Orea when a tile changes. |

Naming: floors are `floor_<name>.png`, walls are `wall_<name>.png`, all lowercase with
underscores. The name matters, the game sorts tiles into floor and wall by that prefix.

### How a tile sheet is laid out

A floor or wall is **not** one 16x16 picture. It is a 64x64 sheet: a 4x4 grid of 16x16
cells, one cell for each way the tile can meet its neighbours (the "dual grid").

- Start from `resources/gfx/tileset/tmp_dual_grid_example.psd`. It labels every piece.
- The middle of the tile must be one pattern that tiles seamlessly every 16 pixels, and
  that same pattern has to appear in every cell of the sheet.
- Floors may spill a little past their edge (dirt and grass do). Walls may not: keep wall
  pixels inside their own 8x8 quarter, or they get cut off.
- Don't leave see-through holes in a wall. Use black or a very dark color instead.
- Easiest way to learn it: open `wall_cobble_brick.png` next to the template.

Getting a new tile into the game is a few minutes of editor work for Orea. You only need
to deliver the PNG.

## 1. Tiles

### Doors

One door sprite exists (`objects/Door.png`, 3 frames of 16x16: closed, half, open) and a
friend of Orea's is already reworking it. It is drawn for a door in the bottom wall of a
room and the game rotates it for the other three sides.

- [✗] Dungeon door (in progress elsewhere, check before starting)
- [✗] Cave door: a rough opening or hanging roots, not carpentry
- [✗] Mine door: timber frame, maybe a plank gate
- [✗] Flesh door: a sphincter or a membrane. Frames: closed, half, open
- [✗] Locked or sealed look for a door that doesn't open **(decide first)**

### New floors

Each biome has two floors today. A third gives room builders something to make paths,
rugs and hazards with.

- [✗] Carpet or rug (dungeon, cathedral). Red runner with a trim edge.
- [✗] Cobblestone floor (dungeon). Rougher than smooth stone.
- [✗] Cracked or mossy smooth stone (dungeon, cave)
- [✗] Rail track on dirt (mine). Rooms already have plank "tracks" waiting for this.
- [✗] Gravel or rubble (mine, cave)
- [✗] Shallow water (cave). Could later slow movement the way flesh does.
- [✗] Mushroom or moss ground (cave), a stranger cousin of grass
- [✗] Bone or tooth floor (flesh). Pale, to break up all the red.
- [✗] Pulsing or wet flesh variant (flesh)

### New walls

- [✗] Mossy or damp stone wall (cave meets dungeon)
- [✗] Ore vein wall (mine): rough cave rock with a metal or crystal streak
- [✗] Bookshelf wall (dungeon)
- [✗] Window or stained glass wall (cathedral)
- [✗] Iron bars (dungeon). Special: you should see the floor through it **(decide first)**
- [✗] Bone wall (flesh)

### A whole new biome (later)

The four biomes are dungeon (grey), cave (brown and green), mine (brown) and flesh (red).
The next one should be a color none of them has. **(decide first)**, pick one:

- [✗] Sewer or flooded ruin: teal water, slimy brick
- [✗] Ice cavern: pale blue, white
- [✗] Lava forge: black rock, orange glow
- [✗] Crypt: bone white, purple

A biome is at least: 1 wall, 2 floors, 1 door, about 6 objects.

## 2. Objects

16x16, transparent background, placed freely in a room (not locked to the grid). Only
`torch` and `chest` exist. Objects aren't spawned in a live dive yet (that's a code job),
but they show up in the Dungeon Maker as soon as Orea registers them, so art can run ahead.

If something should animate, put the frames side by side in one PNG like `Tortch.png` does.

### Everywhere

- [✗] Torch: more flame frames (it has 2)
- [✗] Chest: open frame
- [✗] Chest rarity variants: iron, gold, something cursed **(decide first:** how many rarities)
- [✗] Barrel
- [✗] Crate
- [✗] Clay pot or urn, plus a broken version
- [✗] Stairs down or exit hatch
- [✗] Key
- [✗] Lever or floor switch, on and off
- [✗] Pressure plate
- [✗] Spike trap, in and out
- [✗] Rubble pile
- [✗] Bones or skeleton remains
- [✗] Cobweb (corner piece)
- [✗] Blood or stain decal

### Dungeon

- [✗] Wall banner
- [✗] Table
- [✗] Chair or stool
- [✗] Bunk bed (the barracks rooms are empty)
- [✗] Weapon rack
- [✗] Bookshelf (object version)
- [✗] Brazier (a bigger light than a torch)
- [✗] Shackles or chains
- [✗] Standing suit of armour

### Cave

- [✗] Stalagmite, 2 or 3 sizes
- [✗] Glowing mushroom cluster
- [✗] Crystal cluster
- [✗] Boulder
- [✗] Puddle
- [✗] Hanging roots
- [✗] Nest with eggs

### Mine

- [✗] Minecart, empty and full
- [✗] Ore pile
- [✗] Pickaxe and shovel, leaning
- [✗] Hanging lantern
- [✗] Support beam (top-down post with braces)
- [✗] Ladder or lift platform (the mine entrance room is built as a lift landing)
- [✗] Dynamite crate
- [✗] Cabin furniture: bed, stove, small table (`Mine_Cabin_Cavern` has a house in it)

### Flesh

Match `floor_flesh.png`: two reds, two dark reds, white glints, bone tan.

- [✗] Tooth cluster
- [✗] Eye, open and blinking
- [✗] Pustule or egg sac
- [✗] Tendril
- [✗] Rib bones arching out of the floor
- [✗] Half-digested adventurer gear
- [✗] Heart (centrepiece of the flesh boss room, can be bigger than 16x16)

### Cathedral and castle

- [✗] Pew
- [✗] Altar
- [✗] Candelabra
- [✗] Statue
- [✗] Throne
- [✗] Patch of coloured window light on the floor
- [✗] Pillar base detail

## 3. Player characters

Frames are 16x16, in strips. What exists:

| | North | South | East | West | Idle | Attack | Hurt | Death |
|---|---|---|---|---|---|---|---|---|
| Knight | 4 frames | 4 | 8 | missing | none | none | none | none |
| Dwarf | 4 frames | 4 | 7 (named "right") | 7 (named "left") | none | none | none | none |

- [✗] Knight: walking west (or confirm the game should just flip east)
- [✗] Dwarf: even out the frame count (east and west have 7, the knight has 8)
- [✗] Make file names match between the two (`walking east` vs `walking right`)
- [✗] Idle, all four directions, both characters
- [✗] Attack, all four directions. Combat is real-time, so this is the one players see most.
- [✗] Hurt flash or flinch
- [✗] Death
- [✗] More classes **(decide first)**. Don't draw new classes until Orea confirms what they are.

## 4. Enemies

Only a rat exists: front and side views, 2 frames each, 4 colors. No back view.
The roster isn't designed, so everything past the rat is **(decide first)**. These are
the obvious candidates per biome, to talk through with Orea:

- [✗] Rat: back view, attack, death
- [✗] Dungeon: skeleton, slime, bat
- [✗] Cave: spider, bat, mushroom creature
- [✗] Mine: kobold or undead miner, rock golem
- [✗] Flesh: blob, eye stalk, tooth worm
- [✗] One boss per biome, bigger than a tile (32x32 or 48x48). The boss rooms exist and are empty.

Each enemy needs what the rat has, plus an attack and a death.

## 5. Interface

These exist as plain Godot scenes with no art: health bar, hotbar, hotbar slot, death
screen, main menu, pause menu, settings.

- [✗] Health bar frame and fill
- [✗] Hotbar slot, normal and selected
- [✗] Button style: normal, hover, pressed
- [✗] Panel or window frame (a 9-slice piece: corners, edges, middle)
- [✗] Mouse cursor
- [✗] Death screen art
- [✗] Game logo and main menu background
- [✗] Item icons, 16x16 **(decide first:** the item list doesn't exist yet)
- [✗] Rarity frames or colors for loot **(decide first:** how many rarities)
- [✗] Skill tree icons **(decide first)**
- [✗] Map icons: entrance, boss, treasure, you-are-here. There is no map yet, and a big dungeon badly needs one.
- [✗] A pixel font, or pick a free one

## 6. Effects

Small strips of frames, 16x16 unless noted.

- [✗] Hit spark
- [✗] Weapon slash arc
- [✗] Footstep dust
- [✗] Flesh squish or splat
- [✗] Chest opening sparkle
- [✗] Enemy death puff
- [✗] Torch smoke or embers

## 7. Town hub (later)

The town is the menu hub where players gather before a dive. The scene is an empty stub
and nothing about its look is decided, so all of this is **(decide first)**.

- [✗] Outdoor ground: grass, path, plaza stone
- [✗] Building walls and roofs
- [✗] Guild hall interior (the dive is launched from here)
- [✗] Notice board, the thing you click to queue a dive
- [✗] NPCs: guild master, shopkeeper
- [✗] Props: well, fence, lamp post, market stall

## 8. Much later

- [✗] Steam store art: capsule, header, library images
- [✗] Trailer stills
- [✗] App icon (the project still has Godot's default `icon.svg`)
