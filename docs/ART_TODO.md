# RogueNet Art To-Do

Legend: ✓ done, ~ partly done or in progress, ✗ not done. Statuses were checked against the files (not by
running the game), so anything about how it looks or plays is unconfirmed.

Written 2026-09-21 from what is actually in `resources/gfx/` and `game/rooms/`.
Re-checked against the files 2026-09-24 (ten biomes, the 5 door types, the boss door
layers and emblems, 14 enemy files); the sections below say what changed. It is a draft. **Silvery Foxy has the final say on style**, and anything marked
**(decide first)** needs a design answer from Orea before anyone draws it.

How to use it: put your name next to a line before you start (`- [✗] Barrel — Foxy`),
tick it when the PNG is in the repo. Small finished things beat big unfinished things.

## Where to start

Two artists, two tracks that don't collide:

- **Track A, objects.** Every room in the game is bare: the only objects that exist are
  one torch, one chest and the graves. Section 2, "Everywhere" then "Dungeon". This is the biggest
  visible win for the least work, and each object is one small 16x16 sprite.
- **Track B, tiles.** The 24 existing tiles (15 floors, 7 walls, 2 barriers) are done, so start on what's missing:
  doors per biome, then new floors. Section 1 lists the palettes to stay consistent with.

Enemies (section 4) come next: 14 enemy files exist already, but bosses, attack and death frames don't, so check with Orea first.

## Who does what

Grouped by owner. The section numbers below still hold everything; this is only the split.
Put a name on a line before you start.

- **Silvery Foxy (art director):** has the final say on style. Owns monsters (enemies and
  bosses, section 4), player and class art (section 3), the interface (section 5), effects
  (section 6) and the Steam art (section 8). Reviews everything else.
- **Orea (dungeon art):** tiles, doors, boss door parts and emblems (section 1), and the
  dungeon-side objects (section 2). Orea does not draw monsters or generic art.
- **HamsterMan4949crypto (generalist):** fills gaps: the generic objects (section 2,
  "Everywhere"), interface pieces, the app icon, and sound (section 9). Can also help the
  teammate on the human equipment-slot map and the eight-direction walk set.

Open work per owner, from the audit:

- Foxy: player idle, attack, hurt, death; enemy attack and death frames; boss sprites; UI; town art.
- Orea: new floors and walls, treasure door, cave and flesh doors, boss frame for smooth cave.
- Hamster: objects, sound, app icon.

## House style, as the art stands today

| Thing | Rule |
|---|---|
| Tile size | 16x16 pixels. The camera is top-down, and walls show a front face on their south side. |
| Tile colors | At most 8 colors per tile (was 6 until 2026-09-24; older tiles still use 4-6). For walls the pure black top doesn't count. |
| No 3D | **NEVER use 3D rigging** or anything built from it: no posed 3D models, skeletons or rendered-then-downscaled frames, not even as a base to paint over. Sprites are drawn in 2D. (Orea, 2026-09-24. The current boss sheets are 3D renders and are the reason for this rule.) |
| Edges | Hard pixels only. No soft brushes, no semi-transparent pixels, no anti-aliasing. |
| Shades | No two shades that are nearly the same. If you can't tell them apart at 1x, merge them. |
| Wall tops | Pure black `#000000`. This is what makes walls merge into the void. |
| Characters, objects | 16x16 per frame; bosses are bigger (the frame is `size_tiles` x 16). |
| Sprite colors | **At most 8 colors per sprite**, shared by all of its directions (one palette, so it doesn't change colour when it turns). Set 2026-09-24; older sprites such as the knight (up to 17) are over it. |
| Animation | **8 frames per animation, played at 10 fps** (100 ms per frame, so one loop is 0.8 s). Same for everything that animates. |
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

Updated 2026-09-24: `doors/Door.png` is gone, replaced by the door families in
`resources/gfx/doors/`, described by `game/doors/*.json`. There are 5 door types: `wood`
(`Wood_W1`-`W3`), `wood_fold` (`Wood_Fold_W3`-`W5`), `iron` (`Iron_W1-5`), `iron_sink`
(`IronSink_W1-5`) and `dungeon` (`Dungeon_W4`/`W5`, the boss door template). A door is drawn
for the bottom wall of a room and the game rotates it for the other three sides.

- [✓] Dungeon door: `Dungeon_W4`/`Dungeon_W5` plus overlays (base boss door template, approved; keep it)
- [~] Cave door: a rough opening or hanging roots, not carpentry (the cave and volcano biomes have no doors today, so low priority)
- [~] Mine door: timber frame, maybe a plank gate (the wood door types cover it for now; a dedicated mine look is not drawn)
- [✗] Flesh door: a sphincter or a membrane. Frames: closed, half, open
- [✗] Locked or sealed look for a door that doesn't open **(decide first)** (`doors/doors.treasure` is an empty folder: the treasure door is not drawn)
- [✓] Boss door layers in `doors/doors.boss/`: frame, leaves and overlay, split per wall (CobbleBrick, Flesh, Forest, Marble, RoughCave, SmoothStone, WoodPlank frames, W4 and W5)
- [✓] Boss door leaf tiers: Wood, Iron, Bronze, Silver, Gold, each W4 and W5
- [✓] Boss door emblems in `doors/doors.emblems/`: 15 damage types (Arcana, Entropia, Fluentia, Frigid, Inanis, Necrotic, Ordo, Perditio, Physical, Plenum, Ruina, Solum, Torpor, Virulentia, Zeal), listed in `emblems.json`
- [✗] Boss door frame for smooth cave (`wall_smooth_cave` has no `SmoothCave_W4/W5_Frame` yet)
- [✗] Treasure door (the locked-door item above, once items and keys exist)
- [✗] `wood_fold` at widths 1 and 2 (`Wood_Fold_W1`/`W2`), **or decide it stays 3-5 wide**: manor rooms ask for it on 3-wide connectors, but where the room next door only overlaps 1-2 tiles of the opening, no `wood_fold` fits and the game falls back to an iron door (found 2026-09-25)

### New floors

Ten biomes exist as room pools (see below). Existing floors: acid, carpet (crimson, gold,
indigo, verdigris, violet), dirt, flesh, grass, lava, smooth cave, smooth stone, void, water,
wood planks, plus the overlays `overlay_acid_bubbles` and `overlay_lava_embers`. A new floor
gives room builders something to make paths, rugs and hazards with.

- [✓] Carpet or rug (dungeon, cathedral). Five colours exist, `floor_carpet_*`; a red runner with a trim edge is not separate
- [✗] Cobblestone floor (dungeon). Rougher than smooth stone.
- [✗] Cracked or mossy smooth stone (dungeon, cave)
- [✗] Rail track on dirt (mine). Rooms already have plank "tracks" waiting for this.
- [✗] Gravel or rubble (mine, cave)
- [✓] Shallow water (cave): `floor_water` exists. Could later slow movement the way flesh does.
- [~] Mushroom or moss ground (cave), a stranger cousin of grass (the cave uses `floor_grass` as moss; no dedicated tile)
- [✗] Bone or tooth floor (flesh). Pale, to break up all the red.
- [✗] Pulsing or wet flesh variant (flesh)

### New walls

Existing walls: cobble brick, flesh, forest, rough cave, smooth cave, smooth stone, wood plank.
Barriers: bedrock, dense forest. The catacomb, manor and sewer stand in for missing walls
with these, so each item below removes a workaround.

- [✗] Mossy or damp stone wall (cave meets dungeon)
- [✗] Ore vein wall (mine): rough cave rock with a metal or crystal streak
- [✗] Bookshelf wall (dungeon)
- [✗] Window or stained glass wall (cathedral)
- [✗] Iron bars (dungeon). Special: you should see the floor through it **(decide first)**
- [✗] Bone wall (flesh)

### A whole new biome (later)

The ten biomes are catacomb, cathedral, cave, dungeon, fallback (the safety net, never picked),
flesh, forest, mine, sewer and volcano (`game/rooms/`; a manor folder was added too, so check
`BIOMES.md`). All of them reuse the shared tile set, so none has its own palette yet. The
last new one should be a color none of them has. **(decide first)**, pick one:

- [~] Sewer or flooded ruin: teal water, slimy brick (the sewer rooms exist, drawn with cobble brick and `floor_water`; no teal or slime art)
- [✗] Ice cavern: pale blue, white
- [~] Lava forge: black rock, orange glow (the volcano rooms exist, using rough cave, smooth cave and `floor_lava`; no forge art)
- [~] Crypt: bone white, purple (the catacomb rooms exist, using smooth stone and violet carpet; no bone or purple wall)

A biome is at least: 1 wall, 2 floors, 1 door, about 6 objects.

## 2. Objects

16x16, transparent background, placed freely in a room (not locked to the grid). Only
`Torch.png`, `Chest_Wood.png`, `sign.png` and the grave set exist. Objects aren't spawned in a live dive yet (that's a code job),
but they show up in the Dungeon Maker as soon as Orea registers them, so art can run ahead.

If something should animate, put the frames side by side in one PNG like `Torch.png` does.

### Everywhere

- [✓] Graves (`objects/objects.graves/`): wooden crosses in 8 woods (Ash, Birch, Cedar, Chestnut, Oak, Redwood, Teak, Walnut) and `Grave_Pile_<Floor>` mounds for 14 floors

- [✓] Sign (`objects/sign.png`): wooden signpost, in the Dungeon Maker's object list as `sign` (placeable only, can't be read yet; readable signs are a later code job)
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
| Knight | 4 frames | 4 | 8 | 8 | none | none | none | none |
| Dwarf | 4 frames | 4 | 7 | 7 (placeholder, see below) | none | none | none | none |
| Ghost | 4 frames | 4 | 4 | 4 | none | none | none | none |
| Minotaur (antagonist boss, `entities.antagonist/bosses/minotaur`, 48x48) | 8 frames | 8 | 8 | 8 (mirrored), plus diagonals | none | none | none | none |
| Dragon, Spider, Ogre (antagonist bosses, 112 / 80 / 64 px) | 8 frames | 8 | 8 | 8 (mirrored), plus diagonals | none | none | none | none |

- [✓] Knight: walking west, 2026-09-22 (`Knight-Left.png`) — real art, confirmed by pixel diff to be an exact mirror of `Knight-Right.png`. Wired into `Knight.tres` as a proper `SideLeft` animation (was briefly using the flip trick instead, which Orea flagged as not actually hooked up correctly — fixed)
- [✗] Dwarf: even out the frame count (east/west have 7, the knight has 8)
- [✗] Dwarf: `Dwarf-Left.png` is still a placeholder — it was byte-for-byte identical to `Dwarf-Right.png` (confirmed by pixel diff) until Orea started manually flipping it frame by frame on 2026-09-22; not done as of this note
- [✓] Make file names match between the two, 2026-09-22: both are now `Knight-Up/Down/Left/Right.png` / `Dwarf-Up/Down/Left/Right.png`
- [~] Idle: the Human blinks (`Human-Blink.png`, eyelid pixels only) and breathes (a 1px sink), 2026-09-25. No blink facing away. Knight, dwarf, ghost and minotaur have none
- [~] Attack: the Human faces the target and the whole body lunges 1px back, 2px forward (0.4 s, 4 steps, because slash repeats every 0.5 s), gear with it; the slash effect plays on top. 2026-09-25. Only the attacker's own screen shows the lunge (other players see the slash)
- [✓] Hurt flash or flinch: `HitFeedback` (white then red flash, 2px jolt away from the attacker), players and enemies
- [~] Death: the Human topples sideways (45° then flat, inside its own tile), lies 1 s, fades, then the ghost appears, 2026-09-25. Gear topples with it
- Player motion (attack, death, breath) is pixel-stepped whole-body movement in `DirectionalAnimator`, chosen by Foxy (2026-09-25) so all existing gear works without new frames. Enemies got the same death topple on 2026-09-25 (`DirectionalAnimator.leave_corpse`: the enemy is removed at once, a corpse sprite falls and fades). Enemies already had hit flashes (`HitFeedback`); Foxy didn't want the lunge or idle life on them
- [~] The current knight and dwarf are TEMPORARY (2026-09-24, Orea). A teammate is building a new `human` character with EIGHT-direction movement (walking north, north+east, east, south+east, south, and so on) in `resources/gfx/entities/entities.protagonist/human/`; the flipped directions come from the right-facing art. It comes with an equipment slot map (head, neck, chest, back, gloves, legs, feet, main hand, off hand) that says, per direction, which worn pieces draw over or behind the body and where a held item's grip pixel sits. Do not draw more frames for the old knight and dwarf until that lands. Later on 2026-09-24 the Knight and Dwarf were taken off the character list (Foxy's request, Orea's OK): the Human is the only playable character. Their art files are kept, and `DungeonMaker` still uses `Knight-Down.png` as the player spawn marker
- [~] Human: walk cycles renamed to the `Name-Direction` pattern, 2026-09-24: `human/Human-Down/DownRight/Right/UpRight/Up` (`.png` + `.aseprite`). Left, Down-Left and Up-Left come from flipping the right-facing art. In-game since 2026-09-24 (not yet committed or reviewed): movement and `DirectionalAnimator` handle eight directions, and the Human's `FrontRight`/`BackRight` animations are used for diagonals (mirrored for left). Creatures with no diagonal art play their side animation when moving diagonally
- [~] Gear layer: `gear/helmets/heavy_iron/HeavyIronHelm-Down/DownRight/Right/UpRight/Up` is done for all 5 directions (checked against the Human walk cycle, 2026-09-24). Gear sheets use the same `Name-Direction` pattern as the body so code can pair them up. Drawn in-game since 2026-09-24: whatever the player wears in the inventory is drawn over (or behind) the body, in the order of the slot map
- [~] Example gear sets, 2026-09-24 (made by Claude, waiting on Foxy's review). Four sets, drawn on the Default Man for all 5 directions and all 4 walk frames. Each piece has a PNG plus an `.aseprite` copied from the HeavyIronHelm template (Default Man hidden, piece in its slot layer):
  - **Heavy Iron:** the existing helm, plus `HeavyIronCuirass`, `HeavyIronGauntlets`, `HeavyIronGreaves` and `HeavyIronSabatons`
  - **Arcane:** hood, robe, gloves, skirt, slippers
  - **Cleric:** coif, vestment, gloves, trousers, boots
  - **Necromancer:** hood, robe, gloves, skirt, wraps

  They live in the new folders `gear/chest/`, `gear/gloves/`, `gear/legs/` and `gear/feet/` (folder names not confirmed yet). No two pieces in a set share a pixel, so the draw order doesn't change the result
- [~] Main hand and off hand for the four sets, 2026-09-24 (made by Claude, waiting on Foxy's review). All 5 directions, 4 frames each (the frames are identical, because the Human's hands don't move in the walk cycle). Placed on the grip pixels from the equipment slot map, with `.aseprite` files built from the same HeavyIronHelm template (piece in the `Main Hand` / `Off Hand` layer):
  - **Heavy Iron:** `HeavyIronLongsword`, `HeavyIronShield`
  - **Arcane:** `ArcaneStaff`, `ArcaneOrb`
  - **Cleric:** `ClericMace`, `ClericBuckler`
  - **Necromancer:** `NecromancerBoneWand`, `NecromancerPhylactery`

  New folders: `gear/main_hand/<set>/` and `gear/off_hand/<set>/`. Where the slot map puts a held item behind the body (main hand facing Up; off hand facing Right, Up-Right and Up), the PNG already has the hidden pixels cut out (anything covered by the body or by any worn piece), so it can be drawn on top like the rest. Held items in front of the body must be drawn **above** the worn pieces (a code note for when gear drawing gets built)
- [~] Amulets and back items, 2026-09-24 (made by Claude, waiting on Foxy's review). All 5 directions, 4 frames each, with `.aseprite` files built from the same HeavyIronHelm template (piece in the `Amulet` / `Back/Cape` layer):
  - **Amulets**, one to go with each set (`gear/amulets/<set>/`): `WolfFangAmulet`, `ArcaneEyeAmulet`, `SunPendantAmulet`, `BoneSkullAmulet`. A chain from the neck to a small pendant on the chest; from behind only the chain at the back of the neck shows
  - **Back items** (`gear/back/<item>/`): `CrimsonCape` (the hem sways as you walk), `PennantRed`/`Blue`/`Green`/`Yellow` (one colour per party member; the flag flutters), `BackSword` (sheathed, crossing the middle of the back, hilt over the shoulder), `Backpack` (with a bedroll on top), `HamsterSack` (the hamster enemy poking out of a sack in the middle of the back; it faces backwards, so you see its face from behind, and it ducks in on each step)

  The sword and hamster sack are centred on the back, so from the front they mostly hide behind the body: only the sword's hilt peeks over the shoulder, and the sack only shows facing Down-Right (`HamsterSack-Down.png` is empty on purpose). The cape is still the first version for now: a narrower redesign looked like a gown, and its walk sway could still be improved later. The pennant sits on the shield-side shoulder, so it doesn't cross the weapon. Draw order (a code note for when gear drawing gets built): facing Down, Down-Right and Right, the back item goes **under** the body and everything else (its PNG already has the hidden pixels cut out); facing Up-Right and Up it goes **over** the body and armour. Held items behind the body go under the back item, held items in front of the body go over it. Amulets go over the chest and gloves, under the helmet. Folder names not confirmed yet
- [~] Rogue and Assassin sets, 2026-09-24 (made by Claude at Foxy's request, waiting on Foxy's review). Same build as the sets above: all 5 directions, 4 frames, a PNG and an `.aseprite` from the HeavyIronHelm template per piece. The legs and boots step with the walk cycle; everything else holds still, like the other sets. In the game: each piece has an item JSON in `game/items/` and an icon (storage grows by rows when there are more than 48 items)
  - **Rogue (archer):** `RogueHood`, `RogueJerkin`, `RogueBracers`, `RogueTrousers`, `RogueBoots`, `RogueLongbow` (main hand), `RogueHuntingKnife` (off hand), `ArrowheadAmulet`, `Quiver` (`gear/back/quiver/`)
  - **Assassin:** `AssassinCowl`, `AssassinVest`, `AssassinGloves`, `AssassinLegwraps`, `AssassinTabi`, `AssassinFang` (main hand, reverse grip), `AssassinStiletto` (off hand), `PoisonVialAmulet`

  The two amulets are recolours of `WolfFangAmulet`, so they fit exactly the same way
- [~] Eight more sets from the concept sheet, 2026-09-24 (made by Claude at Foxy's request, waiting on Foxy's review). Same build as the Rogue and Assassin sets, and all in the game with item JSON and icons. Each set is 8 pieces (head, chest, gloves, legs, feet, main hand, off hand, amulet) in a `<set>` folder under each gear folder, e.g. `helmets/magma/`. Many pieces reuse the shape of an existing piece with new colours and details (so they fit the same way); the helmets and the club, spear, wrench, trident and moon are drawn new. All amulets are recolours of `WolfFangAmulet`
  - **Scrapper (starter):** `ScrapperPotHelm`, `ScrapperPatchedVest`, `ScrapperRagWraps`, `ScrapperSackTrousers`, `ScrapperFootRags`, `ScrapperNailClub`, `ScrapperPlankShield`, `ScrapperSpoonCharm`
  - **Magma Warlord:** `MagmaHornedHelm`, `MagmaCuirass`, `MagmaGauntlets`, `MagmaGreaves`, `MagmaSabatons`, `MagmaLavaBlade`, `MagmaObsidianShield`, `MagmaEmberAmulet`
  - **Frost Warden:** `FrostCrown`, `FrostPlate`, `FrostGauntlets`, `FrostGreaves`, `FrostFurBoots`, `FrostIcicleSpear`, `FrostCrystalShield`, `FrostIcicleAmulet`
  - **Clockwork Tinker:** `ClockworkGoggleCap`, `ClockworkApron`, `ClockworkGloves`, `ClockworkTrousers`, `ClockworkBoots`, `ClockworkWrench`, `ClockworkCogShield`, `ClockworkKeyAmulet`
  - **Sporecaller:** `SporecallerToadstoolHat`, `SporecallerMossRobe`, `SporecallerBarkGloves`, `SporecallerMossSkirt`, `SporecallerRootWraps`, `SporecallerGlowcapStaff`, `SporecallerSporePod`, `SporecallerSeedCharm`
  - **Abyssal Tide:** `AbyssalFinHelm`, `AbyssalScaleMail`, `AbyssalWebbedGloves`, `AbyssalScaleGreaves`, `AbyssalFinBoots`, `AbyssalTrident`, `AbyssalShellShield`, `AbyssalPearlAmulet`
  - **Starforged:** `StarforgedHalo`, `StarforgedRobe`, `StarforgedGloves`, `StarforgedSkirt`, `StarforgedSlippers`, `StarforgedStaff`, `StarforgedMoon`, `StarforgedStarAmulet`
  - **Hamster Guard:** `HamsterHelm`, `HamsterPlate`, `HamsterPaws`, `HamsterGreaves`, `HamsterBoots`, `HamsterCarrotSword`, `HamsterSeedShield`, `HamsterBellCollar`

  Storage sorts these after the first four sets by slot, not grouped by set, until they're added to `SET_ORDER` in `ItemDatabase.gd` (a code change, Orea). Scrapper isn't the starting gear; that's a code decision too
- [~] Four cheap starter sets, 2026-09-24 (made by Claude at Foxy's request, waiting on Foxy's review). One per starting play style, same build as the sets above and all in the game with item JSON and icons. Helmets and held items are drawn new; body pieces reuse the shapes of the first four sets in cloth and leather colours. The floppy hat droops to the side instead of going up, so it fits under the frame's top row
  - **Militia (sword and shield):** `MilitiaBucketHelm`, `MilitiaGambeson`, `MilitiaMitts`, `MilitiaTrousers`, `MilitiaBoots`, `MilitiaRustySword`, `MilitiaWoodenShield`, `MilitiaCopperBadge`
  - **Poacher (bow):** `PoacherFurCap`, `PoacherHideVest`, `PoacherLeatherGloves`, `PoacherBreeches`, `PoacherTurnshoes`, `PoacherShortbow`, `PoacherTorch` (off hand), `PoacherRabbitFoot`
  - **Apprentice (magic):** `ApprenticeFloppyHat`, `ApprenticeRobe`, `ApprenticeWraps`, `ApprenticeRobeSkirt`, `ApprenticeSandals`, `ApprenticeCrookedStaff`, `ApprenticeTatteredBook` (off hand), `ApprenticeWoodenBeads`
  - **Cutpurse (knife):** `CutpurseBandana`, `CutpurseRaggedTunic`, `CutpurseFingerlessGloves`, `CutpursePatchedBreeches`, `CutpurseHoleyShoes`, `CutpurseChippedKnife`, `CutpurseBrokenBottle` (off hand), `CutpurseLuckyCoin`

  Like the eight sets above, these aren't grouped in storage until they're in `SET_ORDER`, and they aren't the starting gear (both code, Orea)
- [~] Four ultimate sets, 2026-09-24 (made by Claude at Foxy's request, code OK'd by Orea, waiting on Foxy's review). One per class, all in the game with item JSON and icons. Their glowing colours pulse while walking (frames 1-3; frame 0 is the standing look). Wearing all five armour pieces of one set (not the weapons or amulet) turns on a full-set bonus from `game/sets/<set>.json`, with its art in `resources/gfx/effects/effects.sets/`
  - **Infernal (melee sword):** `InfernalHornedHelm`, `InfernalCuirass`, `InfernalGauntlets`, `InfernalGreaves`, `InfernalSabatons`, `InfernalGreatsword`, `InfernalDemonShield`, `InfernalHeartAmulet`. Bonus: a lava puddle on every tile walked (`InfernalLava`, 4 frames) and rising embers
  - **Archmage (mage):** `ArchmageHood`, `ArchmageRobe`, `ArchmageGloves`, `ArchmageSkirt`, `ArchmageSlippers`, `ArchmageVoidStaff`, `ArchmageCodex` (off hand), `ArchmageSigilAmulet`. Bonus: a glowing pentagram under the feet (`ArchmagePentagram`, 32x32, 8 frames) and sparks
  - **Wraith (rogue, bow):** `WraithHood`, `WraithJerkin`, `WraithGloves`, `WraithLeggings`, `WraithBoots`, `WraithBonebow`, `WraithSpectralDagger` (off hand), `WraithSoulAmulet`. Bonus: glowing footprints turned to the walk direction (`WraithFootprints`) and wisps
  - **Seraph (support):** `SeraphWingedCirclet`, `SeraphVestment`, `SeraphGloves`, `SeraphTrousers`, `SeraphBoots`, `SeraphSunScepter`, `SeraphAegis` (off hand), `SeraphFeatherAmulet`. Bonus: flowers that sprout and bloom on every tile walked (`SeraphFlowers`, 6 frames) and golden motes
- [✗] Tall hats (wizard hat, mitre) don't fit: the Human's head touches the top row of the frame **(decide first:** taller frames are a code change, Orea)
- [✗] `Human-Down.aseprite` and `Human-DownRight.aseprite` differ from their PNGs by a few pixels. The PNGs match the Default Man in the gear templates, so decide which version is right
- [✗] More classes **(decide first)**. Don't draw new classes until Orea confirms what they are.

## 4. Minions and bosses

Updated 2026-09-24: 14 minion files in `game/entities/entities.antagonist/minions/` across 7 species, all
with four directions (Down, Up, Left, Right) and a walk cycle only: rat (plus blind and toothless), bat (plus echo),
hamster (plus demonic and flying), leech (plus flesh), wolf (plus hellhound), skeleton archer and wraith.
The rest of the roster isn't designed, so anything not listed is **(decide first)**. Orea does not draw
monsters, so this section is Silvery Foxy's or a teammate's. These are the obvious candidates per biome:

- [~] Rat: back view now exists (`Rat-Up`). Still missing: attack, death
- [✓] Species with a walk cycle in four directions: bat, hamster, leech, wolf, skeleton archer, wraith (variants: echo bat, demonic and flying hamster, flesh leech, hellhound)
- [~] Dungeon: skeleton, slime, bat (skeleton archer and bat exist; slime and a melee skeleton do not)
- [~] Cave: spider, bat, mushroom creature (bat exists; spider and mushroom do not)
- [✗] Mine: kobold or undead miner, rock golem
- [~] Flesh: blob, eye stalk, tooth worm (a flesh leech exists; the three listed do not)
- [✗] Attack and death frames for every enemy above
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
- [✗] Game logo
- [~] Main menu, 2026-09-24 (made by Claude, colour pass done, waiting on Foxy's review): parchment, brown wood with brass knobs, gold hover glow, orange fire and a steel-blue slash. The buttons are parchment scrolls that unroll, lift and glow on hover (`resources/gfx/ui/main_menu/`: `ScrollPaper`, `ScrollRoller`, `ScrollGlow`; 1x art shown at 3x). A random sword or staff (the items' own icons) points at the hovered scroll; clicking plays `ScrollSlash` (the sword cuts it in half) or `Fireball` + `ScrollBurn` + `ScrollBurnFlames` (the staff burns it). The background is a staged fight in a real room with random gear-set parties (`scripts/ui/MenuBattle.gd`), so it needs no art of its own.
- [~] Settings scroll, 2026-09-25 (made by Claude from the approved mockup, waiting on Foxy's review in game): the settings screen is a hanging parchment scroll, art in `resources/gfx/ui/settings/`: `Paper` (9-slice), `Roller` (long roller, gold caps, 9-slice), `Ribbon`/`RibbonActive` (red tab, notched end), `Candle` (the slider handle: 11x20, 6 levels x 2 flicker frames, out at 0 and brighter to the right), `Seal` (stamped / empty, for on-off settings), `InkBlot` (Restore defaults), `Tick`. Paper and ink at 2x like the menu scrolls; candles, seals and ribbons at 3x so they read and are easy to hit. Drawn by `settings_art.py` in the session scratchpad from the mockup's pixel maps, no `.aseprite` yet
- [~] Item icons, 16x16, 2026-09-24 (made by Claude, waiting on Foxy's review): all 40 gear pieces have one in `resources/gfx/ui/icons/items/<item id>.png` (an `.aseprite` next to each), hooked up through the `"icon"` field in each item's JSON. The Rogue and Assassin pieces have icons there too (17 more), not hooked up yet since those items aren't in the game. Drawn with a 1px outline in a dark shade of the item's own colour (changed from pure black on 2026-09-24, after Foxy's reference icons), light from the top left, and the same colours as the worn gear. New items: draw a 16x16 icon there and add `"icon"` to the JSON; without one, the slot falls back to the worn front view (fine for most gear, but gloves and boots are only dots)
- [~] Inventory UI, 2026-09-24 (made by Claude, waiting on Foxy's review): the inventory window and town storage follow the HTML mockup, with placeholder art in `resources/gfx/ui/inventory/`: `backpack.png` (the HUD button and window title) and `slot_<slot>.png`, nine white 16x16 silhouettes shown dimmed in empty equipment slots. The panel and slot colours are set in code (`InventoryPanel.gd`, `ItemSlot.gd`) until there's a window frame (see below)
- [~] Rarity frames, 2026-09-25 (made by Claude at Foxy's request, waiting on Foxy's review): five rarities (common, uncommon, rare, epic, legendary), `resources/gfx/ui/storage/frame_<rarity>.png`, 20x20 drawn at 2x. Rarer frames get a glow along the bottom; legendary has ember corners and pulses in the game. Rarity per set is in `game/sets/*.json` (placeholder picks)
- [~] Storage screen art, 2026-09-25 (made by Claude, waiting on Foxy's review): in `resources/gfx/ui/storage/`, 10x10 ink icons for the tabs (`tab_all`, `tab_armour`, `tab_weapons`, `tab_jewellery`, `tab_back`, `tab_potions`, `tab_items`, `tab_materials`) and the toolbar (`tool_search`, `tool_sort`, `tool_sets`, `tool_store_all`) and a 5x6 `lock` badge. The tabs and toolbar are parchment buttons
- [~] Storage and inventory look, 2026-09-25 (made by Claude after Orea found the old one plain, waiting on Foxy's review): in `resources/gfx/ui/storage/`, `Frame` (32x32 nine-patch: wood with brass corner plates, dark inside; every inventory/storage panel, shown at 2x), `Divider` (brass rule under section titles), `Arrow` (brass turn arrow), `Wall` (dark plank tile behind the storage screen, 3x) and `Stage` (52x58 candlelit stone alcove with a rug the character stands on, 4x). Made by `storeroom_art.py` in Claude's scratchpad, not kept
- [~] Potion, material and misc icons, 2026-09-25 (made by Claude, waiting on Foxy's review): 16x16 in `resources/gfx/ui/icons/items/` with `.aseprite` files: `health_potion`, `mana_potion`, `antidote` (one flask, three palettes), `iron_ore`, `monster_bone`, `glowcap`, `dungeon_key`, `old_map`
- [~] Inventory sounds, 2026-09-25 (picked by Claude from Pixabay without listening, waiting on Foxy's ears): `resources/sfx/ui/inventory/<name>.mp3`, one per material plus the storage screen's own. Pixabay Content License (free in games, no credit needed). The game fades any clip out after 0.7 s (`ItemSounds.MAX_LENGTH`), but `leather` (4.7 s) and `organic` (2.7 s) would be better trimmed. Sources: metal "Item Equip" 6904, glass "Glass Bottle Clink" 90671, cloth "ClothingEquip" 101251, leather "Leather Movement" 38737, jewel "Gem Release" 384932, wood "Wood Hit" 432148, bone "Bones 2" 88481, paper "pickup_paper" 96773, stone "Dropping Rocks" 41242, organic "Squish" 107555, tab "Turn a Page" 336933, sort "Page Turn" 305789, lock "Doorknob Click" 80055, refuse "Denied Sound" 39708 (the number is the end of the pixabay.com/sound-effects/ page address)
- [✗] Skill tree icons **(decide first)**
- [✗] Map icons: entrance, boss, treasure, you-are-here. There is no map yet, and a big dungeon badly needs one.
- [✗] A pixel font, or pick a free one

## 6. Effects

Small strips of frames, 16x16 unless noted. Updated 2026-09-24: per-damage-type hit strips
exist in `effects/` (`effects.melee`: physical biting, bludgeoning, piercing, slashing,
strangling; `effects.range` attacker and target; `effects.arcana`: arcana, ordo, entropia and
their sub-types; `effects.necrotic`: perditio, ruina, torpor, virulentia), plus `Alertness` and
`TileHover`. An arrow projectile is in `entities.projectiles/arrow`.

- [✓] Alertness marker, tile hover, arrow projectile

- [✓] Hit spark (per damage type, see above)
- [~] Weapon slash arc (`physical.slashing` exists; check it reads as an arc on a swing)
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

## 9. Sound

Not art, but nobody owns it yet. `resources/sfx/effects` and `resources/sfx/ambiance` are empty;
only three music tracks exist (Groovy, Menu-Music, The-Lone-Forest). Direction from Silvery Foxy.

- [~] Combat sounds, 2026-09-25: swings, hits by material, hurt by damage type, deaths, monster voices, grunts, heartbeat (`resources/sfx/combat/`, see its README). Synthesised placeholders, waiting on Foxy's ears and a Pixabay list. Also new art for it: damage digits and hurt vignette (`resources/gfx/ui/hud/`), bone/stone/goo/wisp chips (`effects.particles/Hit_Chips.png`)
- [✗] Sound effects: doors, footsteps
- [✗] Ambiance per biome
- [✗] More music (dungeon, boss, town)

