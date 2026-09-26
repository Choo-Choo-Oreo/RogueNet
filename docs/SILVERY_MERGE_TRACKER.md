# Silvery Merge Tracker

Bringing `silvery/art-and-gear` into `main` piece by piece instead of one big merge.
Pick up whichever chunk matches what you are working on; the order does not matter
except where a chunk says **Needs**.

Legend: ✓ in main and committed, [~] partly in, ✗ not started.
**take** = only Silvery changed this file since the branch split, so his copy can be
copied over as-is. **MERGE** = you both changed it; open both and combine by hand.
**MERGE (easy)** = you both changed it, but in different lines, so nothing overlaps.
Still combine it by hand: copying his file over would wipe out your changes.

Last checked: 2026-09-25 against branch tip `8771fd9` (36 commits since the split at
`d0b8a02`) and main `90b7f2d`. **Checked again 2026-09-26** against tip `94900e2` (41 commits)
and main `3bd9586`: the 5 new commits are sorted into the chunks marked "new 2026-09-26" below.
**Checked again 2026-09-26 (morning)** against tip `4a3854d` (43 commits) and main `f0e0966`: two new
commits, in BARD PERFORMANCE and MORE MAPS below. **Checked again 2026-09-26 (evening)** against tip
`e755904` (44 commits) and main `fdfd884`: one new commit "re", sorted into GEAR FOR OTHER BODIES,
ELF AND DWARF REDRAW, ITEM ICONS REDRAW and STORAGE below. Labels compare against committed `main`: if you have
uncommitted edits in a "take" file, treat it as MERGE.

## How to import a chunk

```
git fetch
git restore --source=origin/silvery/art-and-gear -- <path> <path> ...
```

- Only use `restore` on **take** files and folders. It overwrites the whole file with Silvery's version.
- For a **MERGE** file, see what differs and combine by hand:
  `git diff main origin/silvery/art-and-gear -- <path>`
- Some files are in more than one chunk (for example `GearLayers.gd` and `PlayerController.gd`).
  Taking one of them brings every branch change to that file, including the other chunk's.
  The **Shared files** table at the bottom lists them.
- Commit each chunk on its own: `Import Silvery: <chunk name>`.

- **The branch reverts your "Pack AI Tweaks" (`6a09959` undoes `3baf9d4`).** So a
  `git diff main <branch>` on these files shows your pack AI being removed; keep main's side:
  `MinionController.gd`, `RoomGraph.gd`, `test_room_graph.gd`, `test/sim/dev_sim.gd`,
  `dev_cells.json`, `test/lab/development/*`, `docs/AGGRO_AI_TRACKER.md`, `docs/TODO.md`. For a
  MERGE file, read his own commits' changes (`git log -p d0b8a02..origin/silvery/art-and-gear -- <path>`,
  skipping `6a09959`) rather than the tip diff.

## Import plan (2026-09-26)
Phases in order. Each chunk is its own commit (`Import Silvery: <chunk>`), and after each one:
`--import` if it brings a new `class_name`, then GUT and the sims (character_select,
debug_senses, throw_rock, vision_torch, dev_sim), then a look in game where the chunk says so.
Claude does the steps and reports; Orea commits.

**Sound placement (decided 2026-09-26):** `resources/sfx/` mirrors `resources/gfx/`.
`sfx/effects/` stays damage families only (`effects.<family>/`).
- Door sounds: `resources/sfx/doors/` (like `gfx/doors/`). His names stay: `<door type>_open.wav`,
  `_close.wav` (`wood`, `iron`, `iron_sink`, `dungeon`); his `DoorManager.SFX_DIR` points there.
- Floor sounds (liquids and footsteps): `resources/sfx/tileset/<footsteps>/` (like `gfx/tileset/`),
  the folder named by the floor's `footsteps` value (`TileType.footsteps`, the same key as
  `game/sounds.json` `footstep_db`): `water`, `lava`, `acid`, `carpet`, `dirt`, `flesh`, `grass`,
  `stone`, `wood`. His `Wading.SFX_ROOT` points there. **Orea to confirm the `tileset` name.**
- Main's `resources/sfx/effects/water/` (5 sounds + README, nothing in code reads the path yet)
  moves to `sfx/tileset/water/` in phase 3 (a move: confirm first).
- `docs/STRUCTURE.md` tree and `resources/sfx/README.md` get the two new folders.

### Phase 0: decisions still open (Orea)
- `GearEffects.gd` (particles on gear): still wanted? Blocks the code half of THINGS RESTORE only.
- Main menu battle: bring back the weapon-and-scrolls menu your Pack AI Tweaks deleted? Blocks
  MAIN MENU only.
- Smaller, decided when their chunk comes up: `DeathCountdown` (PARTY WIPE), props key (PROPS),
  bard song as a noise (BARD), liquid flag in the tile JSON vs "has a sound folder" (WADING).

### Phase 1: files only, no code
Nothing here runs new code, so it's the safest start and shows the git steps.
1. **APP ICON.** `restore` `resources/gfx/ui/app_icon/`. Add `config/icon` and
   `config/windows_native_icon` to `project.godot` by hand (needs a grant). Check: the window
   and taskbar icon.
2. **REAL SOUNDS (files).** Copy the 60 re-cut sounds to main's names (table in REAL SOUNDS), the
   7 attack variants next to their base sound in `effects.melee/`, the 5 voices into
   `entities/entities.antagonist/voice/`, and take `resources/sfx/SOURCES.md` (fix its paths to
   main's). Existing names are only replaced, so the game plays the new sounds at once; the variants
   and voices wait for phase 3's code. Check: a swing, a hit, a death in the dev sim.
3. **GEAR ART.** `restore` `resources/gfx/gear/` and `human/`, except `human.json` (MERGE, main's
   10 fps). This also brings about 11,500 other-body gear files, unused until phase 6. Check:
   walk in every direction with a full set on; the 1px bob and the held items.

### Phase 2: base data
4. **THINGS RESTORE + ITEM ICONS REDRAW + MINION ART.** `restore` (not `git revert`, since main
   changed 394 of the icons since): the ~30 minion sheets and 34 JSONs, the 12 rings, the 205 redrawn
   icons (newest, `e755904`), the minion `.aseprite` sources. MERGE the minion JSONs main has
   (e.g. `wolf.json`) and keep main's `size_tiles`, stats and senses: they are Orea's numbers.
   `GearEffects.gd` per phase 0. Check: `MinionIndex` loads them all; a room of each biome spawns.
5. **NEW TILE SETS + TILE VARIANTS.** The 22 new tile JSONs, `floor_water.json`, `tile_registry.json`,
   their art and overlays; the variant leftovers (`floor_flesh`, `floor_smooth_stone`,
   `wall_rough_cave`, 4 lines of `TileInitialize.gd`); regenerate normal maps. Before committing,
   give each new wall a `muffle` and each new footstep material a `footstep_db` row (Orea's numbers:
   Claude proposes, Orea sets). Check: the Dungeon Maker palette; one room per new floor.

### Phase 3: sound systems (placement above)
6. **AUDIO leftovers.** Create `sfx/doors/` and `sfx/tileset/`, move main's water folder, take
   acid, lava, doors and the footstep folders into them. Update STRUCTURE.md and the sfx README.
7. **BIOME AMBIENCE.** `MusicManager.gd` (take; BARD needs the same file later), 12 loops in
   `sfx/ambiance/`, one `"ambience"` line per `defines.json`. Check: walk between two biomes.
8. **FOOTSTEPS AND DUST.** His dust and step sound, but played from main's one step event
   (`PlayerController._on_stepped`, which already reports the noise), not a second one.
   `ParticleBurst.gd` and `GridMover.gd` (MERGE, also takes the FIXES speed cache).
9. **WADING AND LIQUIDS.** `Wading.gd`, the shader, acid/lava floors; MERGE `TileType.gd`,
   `PlayerController`, `MinionController` (his part only). Check: the 529-rat room for speed.
10. **LIQUID AMBIENCE** (needs `SoundPlayer.numbered`, already on main) and **DOOR SOUNDS**
    (MERGE `DoorManager.gd`, 30 lines).
11. **REAL SOUNDS code.** Port `attack_variants`, the 9 voices and `attack_sound` into main's
    `CombatSounds.gd`; MERGE `ItemDatabase.weapon_kind`.

### Phase 4: combat and bodies
12. **COMBAT FEEDBACK.** His flash, recoil, numbers, spray, shake and hit-stop go into main's
    `HitFeedback.gd`; take `DamageNumber.gd`, `HurtOverlay.gd` (drop its heartbeat), the
    `hit_feedback` sim (fix paths). Fix the non-whole scales (Pixel-perfect checks) and the
    `current_scene` reads (GameView section) as they come in.
13. **ANIMATIONS + WOLF BITE.** `DirectionalAnimator.gd` once for both, `human.json` (lunge + main's
    fps), the wolf sheets and JSON entries, `AttackEffect.play_attack` onto main's version.

### Phase 5: interface (640x360: half his sizes, whole numbers, UiTheme fonts)
14. **SETTINGS.** His parchment page, main's voice rows on it (one audio page).
15. **MAIN MENU** (per phase 0): `MenuWeapon`, `MenuScrollButton`, `MenuBattle`, menu art; merge
    `MainMenu.gd/.tscn` onto `MenuPanel` and the character pick.
16. **STORAGE AND INVENTORY**, its four parts; merge onto main's UiTheme variations.
17. **PARTY WIPE.** `RunLog`, `PartyWipeScreen` into `MissionHud.tscn`, headstones.

### Phase 6: adventurer looks
18. **SKINS + ELF AND DWARF REDRAW**, renamed to main's words (`skins/`, `skin_id`), the picker in
    `CharacterSelect`; remove the old `dwarf/` and `knight/` folders (confirm first).
19. **GEAR FOR OTHER BODIES.** `GearLayers.set_body`, `ItemDatabase` by body, `DollStage.gd`.

### Phase 7: content
20. **NEW BIOMES** then **MORE MAPS**: strip `"biome"` from every room; test the 81×81 room.
21. **PROPS**, then **NEON OUTLAW** and **BARD PERFORMANCE** (`ask_host`, a controller button).

`PlayerController.gd`, `NetworkSync.gd`, `ItemDatabase.gd` and `MinionController.gd` are in
many chunks: merge only that chunk's part each time, from his commits (see above).

### Pixel-perfect checks (2026-09-26)
One grid, unit = one UI pixel (640×360), world art pixel = 2 units (`resources/gfx/TODO.md`).
Anything scaled by a non-whole number still lands on it with uneven blocks, so **only whole-number scales**. Found on
the branch (Silvery's work: tell Orea, don't edit):
- `scripts/ui/MenuWeapon.gd` (MAIN MENU SOUNDS): weapon pop scale 0.6 → 1 (about line 70),
  fireball scale tween 0 → 1 (about line 145)
- `scripts/entities/DamageNumber.gd` (COMBAT FEEDBACK): pop from scale 1.6 → 1 (about line 61)
- `scripts/entities/GearEffects.gd` (THINGS RESTORE): particle scale from the item JSON `"size"`;
  all `[1, 1]` today, but any value is accepted, so it needs a whole-number check
- Not a grid problem, but alpha fades blend colours off the palette: `GearEffects._fade_ramp`,
  `Wading.gd` (about line 241), `ParticleBurst.gd` (about line 183), `DamageNumber.gd` (about line 68)

### GameView: the world is no longer `current_scene` (main 2026-09-26)
The dungeon now loads into `GameView` (`scripts/util/GameView.gd`, a 322×182 SubViewport), and
the GameView is the current scene. So in world code, on import:
- `get_tree().current_scene` / `tree.current_scene` → `GameView.world_scene(get_tree())` /
  `GameView.world_scene(tree)` (town code keeps `current_scene`: `main_town`, GuildMission, GuildTown)
- `get_tree().reload_current_scene()` → `GameView.reload(get_tree())`
- loading `Dungeon.tscn` → `GameView.change_to(get_tree(), "res://scenes/dungeon/Dungeon.tscn")`

Main changed these files; Silvery's branch changes them too, so MERGE (keep main's swapped line):
- `scripts/actions/ParticleBurst.gd` (his line 79 is a new `current_scene` read: swap it too)
- `scripts/actions/verbs/ProjectileVerb.gd`, `ThrowVerb.gd`
- `scripts/dungeon/DungeonPainter.gd` (also calls `tile_initialize.refresh_all()` after painting),
  `scripts/dungeon/MinionSpawning.gd`
- `scripts/entities/GridMover.gd`, `scripts/entities/entities.antagonist/minions/ai/MinionController.gd`
- `singletons/NetworkSync.gd`: his branch has about 15 dungeon-side reads (lines 93-859 there); swap
  each, leave the `main_town` ones
- `scripts/cells/tiles/DualGridRender.gd` (performance fix, not GameView: wall renderers scan own
  cells only, `changed` listened to in the editor only)
- `project.godot` `[display]`: 640×360 base, window 1280×720, `scale_mode="integer"`; keep main's

Files only on his branch that read `current_scene` (swap when taking them):
`scripts/actions/AttackEffect.gd:41`, `scripts/entities/DamageNumber.gd:32`,
`scripts/entities/Wading.gd:199`, `scripts/ui/HurtOverlay.gd:28`, `test/sim/hit_feedback.gd`.

**HUD split (main 2026-09-26):** the dive HUD moved out of `Dungeon.tscn` (its `UILayer` is gone)
into `scenes/ui/protagonist/MissionHud.tscn` (script `scripts/ui/protagonist/MissionHud.gd`), which
GameView puts next to the viewport. On import:
- **HUD pieces his branch adds to `Dungeon.tscn`'s `UILayer` go into `MissionHud.tscn` instead**
  (PARTY WIPE: `PartyWipeScreen`)
- **640x360 grid (2026-09-26):** MissionHud and its pieces are at half the old 1280x720 sizes.
  His HUD pieces (`PartyWipeScreen`) go in at half his sizes, whole numbers only, no 0.5 anchors
  (centre with a CenterContainer), fonts only from `UiTheme.tres` (8 / `MenuHeading` 11 /
  `MenuTitle` 15), and `theme = UiTheme` on each root Control (a theme does not pass through the
  CanvasLayer). `HudTheme.tres` is merged into `UiTheme.tres`: point anything of his at UiTheme.
- `HealthBar.gd` / `Hotbar.gd`: MERGE. Main sizes the health fill and cooldown cover in whole
  pixels (`_size_fill`, `set_cooldown`) instead of fractional anchors; keep main's.
- `scenes/dungeon/Dungeon.tscn`: MERGE, never take (main has no `UILayer`)
- `scripts/dungeon/Dungeon.gd`: MERGE (main removed its chat forwarding; the HUD does it now; and
  adds DebugDraw through `GameView.debug_parent(self)`, the full-resolution debug layer; since
  2026-09-26 DebugMenu goes there too, drawing at real screen pixels)
- `PlayerController.gd`: main asks `get_tree().root` for the chat focus (line ~294) and the
  click blockers (`_attack_blocked`), since the HUD is no longer in the player's viewport; keep
  that when merging his changes
- Any new HUD code of his that reaches the world through `get_viewport()` or `current_scene`
  needs the same check

## Chunks

### AUDIO (sound files and buses) [~]
Your current area. The sound files only; the scripts that play them are in the other chunks.
- [✓] The 150 sound files in `resources/sfx/combat`, `effects/water`, `ui/inventory` and
  `ui/main_menu`, identical to the branch (committed in `68c02b4`). `8771fd9` replaced the five
  `effects/water` sounds (enter, exit, step_1..3) with longer ones: taken 2026-09-26, same paths
- [✓] Sound code, ported in `68c02b4` into **different folders** than the branch uses:
  branch `scripts/audio/SoundPlayer.gd` is main's `scripts/util/SoundPlayer.gd`, and
  branch `scripts/audio/CombatSounds.gd` is main's `scripts/actions/CombatSounds.gd`.
  **Never take `scripts/audio/`**, or there will be two copies. Code uses the class
  names, so it works as-is. Only three branch files write out the old path and need it
  fixed when they come over: `test/sim/hit_feedback.gd`, `resources/sfx/combat/README.md`,
  `.claude/docs/combat-feedback.md`.
- [✓] (2026-09-25) **New `d300b27`:** Silvery added `SoundPlayer.numbered(start)` (finds `pop_1.wav`,
  `pop_2.wav`… until one is missing). Copy that function by hand into
  `scripts/util/SoundPlayer.gd`. You changed that file too, in `c66e72c`. LIQUID AMBIENCE,
  FOOTSTEPS and DOOR SOUNDS need it.
- [✗] `resources/sfx/effects/acid/`, `lava/` (4 more lava sounds in `d300b27`), `doors/`,
  `resources/sfx/effects/README.md` (take)
- [~] `resources/sfx/combat/README.md` taken, now `resources/sfx/README.md`;
  `resources/sfx/effects/water/README.md` (take) still to do
- **`resources/sfx/combat/` is gone on main (2026-09-25):** its files moved into the STRUCTURE
  tree (`sfx/effects/effects.<family>/`, `sfx/entities/`; the table in `resources/sfx/README.md`).
  Branch code that writes a `sfx/combat/` path (HurtOverlay's `HEARTBEAT`, the `hit_feedback`
  sim) needs the new path when it comes over.
- **Hit sounds are on main (2026-09-25):** `scripts/entities/HitFeedback.gd` exists with the
  sound part only (hurt, impact, block, death, grunts via `SoundPlayer.numbered`, heartbeat on the
  game tick), heard through walls (`Sound.play_heard`). `EntityStats.damaged(amount, type, cause)`,
  `TileHit.apply(..., cause)` and the `cause` in the hit RPCs are in; the branch's `attacker`
  (RunLog) is not. When COMBAT FEEDBACK comes over, add the looks to main's HitFeedback (flash,
  recoil, numbers, spray, shake, hit-stop) instead of taking the branch file, and drop
  HurtOverlay's heartbeat (HitFeedback plays it). Main reads a minion's tags from its json and
  uses `is_boss`, not the branch's `tags` field and `is_boss` meta.
- [✓] (2026-09-25) `resources/AudioBusLayout.tres` (MERGE): Master has the branch's LowPass in
  slot 0 (HurtOverlay uses slot 0) then main's HardLimiter; SFX has the Compressor. Main has a **VoiceChat** bus the branch
  lacks. The branch adds LowPassFilter and Compressor effects (used for the hurt muffle
  in COMBAT FEEDBACK). Keep VoiceChat and add the effects.
- Note: `SoundPlayer` is the one shared place sounds are started from. Creature, ambient
  and door sounds should go through it too, not through a second player.

### REAL SOUNDS (new, `8771fd9`) ✗
Silvery swapped his synthesised placeholders for sounds cut from Pixabay recordings (sources and
licences listed in `resources/sfx/SOURCES.md`). Taunt, hurt/drone and lava steps are still placeholders.
**He saved them under the old `sfx/combat/` paths and names**, which main moved in `1fb3956`. So
don't `restore` the folders. Copy each file to its main name:

| Branch (`resources/sfx/…`) | Main (`resources/sfx/…`) |
|---|---|
| `combat/death/*`, `combat/impact/*` | `entities/death/*`, `entities/impact/*` (same names) |
| `combat/player/*` (grunts, heartbeat) | `entities/entities.protagonist/*` (same names) |
| `combat/voice/*` | `entities/entities.antagonist/voice/*` (same names) |
| `combat/attacks/slash`, `bite`, `bludgeon`, `wall_smash` | `effects/effects.melee/<same>.wav` |
| `combat/attacks/arrow_shot`, `throw_rock` | `effects/effects.range/<same>.wav` |
| `combat/attacks/entropia_bolt` / `perditio_touch` | `effects/effects.arcana/` / `effects/effects.necrotic/` |
| `combat/hurt/thump`, `cut`, `stab`, `crunch`, `choke`, `bite` | `effects.melee/physical`, `physical.slashing`, `physical.piercing`, `physical.bludgeoning`, `physical.strangling`, `bite_hurt` |
| `combat/hurt/zap`, `ice`, `rock`, `burn`, `splash`, `void` | `effects.arcana/arcana`, `arcana.ordo.frigid`, `arcana.ordo.solum`, `arcana.entropia.zeal`, `arcana.entropia.fluentia`, `arcana.entropia.inanis` |
| `combat/hurt/hiss`, `poison`, `decay` | `effects.necrotic/necrotic`, `necrotic.perditio.virulentia`, `necrotic.perditio.ruina` |
| `effects/water/*` | same path |

- [✗] The re-cut sounds above (60 files, table)
- [✗] New attack variants (7): `slash_knife`, `slash_blunt`, `slash_spear`, `slash_staff`,
  `slash_beast`, `bite_big`, `bludgeon_big` → next to their base sound in `effects.melee/`
- [✗] New voices (5): `cat`, `clack`, `click`, `grind`, `squawk` → `entities/entities.antagonist/voice/`.
  The "ten silent monsters" now have one each (cat, penguin, crab, clam, mimic, gargoyle,
  leech, octopus, turtle).
- [✗] Code, ported by hand into main's `scripts/actions/CombatSounds.gd` (you changed it in
  `90b7f2d`), because his copy is in `scripts/audio/`: `attack_variants()` (a player's swing
  by the weapon in hand; a minion's by being big, or by its tag, e.g. `beast` gives claws),
  the 9 new entries in `VOICE_BY_ID`, and `attack_sound(attack, caster)`. Build his
  `attacks/<id>_<variant>` paths the same way main builds `effects.<family>/<id>`.
- [✗] `ItemDatabase.weapon_kind()` + `WEAPON_WORDS` (MERGE; guesses the weapon kind from a
  word in the item id, and an item's own `"weapon"` field overrides it),
  `scripts/ui/MenuBattle.gd` (take; the menu battle uses the same `weapon_kind`),
  `test/unit/test_combat_sounds.gd` (MERGE)
- [✗] `resources/sfx/SOURCES.md` (take). Keep it: it's the licence record for every Pixabay clip.
- Re-cut sounds for chunks not imported yet: `effects/acid/`, `lava/`, `doors/` (take with
  AUDIO/WADING/DOOR SOUNDS; the whole folder is the latest version).
- New footsteps and ambience files: see FOOTSTEPS and BIOME AMBIENCE.
- `resources/sfx/combat/README.md` changed again. Main deleted it (now `resources/sfx/README.md`), so copy the new lines across.

### BIOME AMBIENCE (new, `d300b27`; files in `8771fd9`) ✗
Your current area. A biome's `"ambience"` loop plays quietly under the music on the SFX bus
and fades between biomes.
- take: `singletons/MusicManager.gd`, `test/unit/test_biome_ambience.gd`
- take (new `8771fd9`): 12 loops in `resources/sfx/ambiance/` (acid, catacomb, cave, dungeon,
  flesh, forest, manor, mine, ruins, sewer, void, volcano) + its README. Main's `ambiance/` is empty.
- MERGE (easy, one line each): `"ambience": "res://resources/sfx/ambiance/<biome>.mp3"` in
  `game/rooms/*/defines.json` for those 12 biomes (`flesh` is take). `cathedral` reuses `dungeon.mp3`.
- Also: the SFX slider text in `scripts/ui/SettingsMenu.gd` now says "…minions, ambience."
  (one line; see SETTINGS)

### LIQUID AMBIENCE (new, `d300b27`) ✗
Lava loops and pops near players (players only, not minions).
- `scripts/audio/LiquidAmbience.gd` (take, but **put it in the folder where your sound
  code lives**, not `scripts/audio/`), `test/unit/test_liquid_ambience.gd` (take)
- Sounds: the new `resources/sfx/effects/lava/` files (in AUDIO)
- Needs: `SoundPlayer.numbered()` (AUDIO), WADING AND LIQUIDS

### FOOTSTEPS AND DUST (new, `d300b27`) ✗
Steps on dry ground play the floor's `footsteps` sound folder and puff dust in the
floor's colours. **Sound files arrived in `8771fd9`:** `step_1..3.wav` in
`resources/sfx/effects/carpet|dirt|flesh|grass|stone|wood/` (take).
- **Folder placement:** on main, `sfx/effects/` now holds damage families
  (`effects.<family>/`, `docs/STRUCTURE.md`). Floor footsteps and liquids go in
  `sfx/tileset/<footsteps>/` (Import plan, sound placement); point his `SFX_ROOT` (in `Wading.gd`)
  there, and his `DoorManager.SFX_DIR` at `sfx/doors/`. His liquid check looks for
  `<folder>/enter.wav`, so footstep folders are never mistaken for liquids.
- MERGE: `scripts/entities/GridMover.gd` (it also has the FIXES speed cache)
- take: `scripts/actions/ParticleBurst.gd` (also changed in COMBAT FEEDBACK), `test/unit/test_footsteps.gd`
- **Main has the `footsteps` key (2026-09-26):** `TileType.footsteps` (same line as the branch:
  JSON `footsteps`, else the tile name without `floor_`) and the branch's `footsteps` values on
  main's carpet, smooth stone, smooth cave and wood floors. Main uses it for how loud a step is
  (`game/sounds.json` `footstep_db`, `PlayerController.footstep_db`). When this chunk comes
  over, `Wading`'s step sound should read the same `tile.footsteps` and play from the same
  step event as `PlayerController._on_stepped`, not a second one. The new floor JSONs in
  `34f1e4f` already carry `footsteps`; its new **walls** need a `muffle` (main's walls all set one now,
  wood 20 to bedrock 60).
- **Check against your hearing work:** Silvery's steps are only a sound you hear. Your
  `SoundSpread`/`SenseHearing` decides who can hear noise in the game. A step should
  come from one place and do both, not have two separate step events.
- Needs: `SoundPlayer.numbered()` (AUDIO)

### TILE VARIANTS (new, `d300b27`) ✗
Rarer tile variants picked by weight: cracked or mossy stone, bone flecks in flesh, gold ore in rough cave.
- take: `scripts/cells/tiles/TileInitialize.gd`, `scripts/cells/tiles/DualGridRender.gd`,
  the 10 tile JSONs (`floor_carpet_*` ×5, `floor_flesh`, `floor_smooth_cave`,
  `floor_smooth_stone`, `floor_wood_planks`, `wall_rough_cave`), 6 tileset PNGs in
  `resources/gfx/tileset/`, `test/unit/test_tile_variants.gd`, `.claude/tools/normal_maps.py`
- MERGE: `scripts/cells/tiles/TileType.gd` (also in WADING)
- **Now MERGE (easy), not take** (main `f911627` added a `footsteps` or `muffle` line to each): the
  tile JSONs above except `floor_flesh`. His change to each is the variant list; keep main's line too.
  **2026-09-26:** the 5 carpets, `floor_smooth_cave` and `floor_wood_planks` are already identical
  to the branch; left: `floor_flesh`, `floor_smooth_stone`, `wall_rough_cave`, and 4 lines of
  `TileInitialize.gd`.
  `TileInitialize.gd` and `DualGridRender.gd` stay as the GameView section says.
- Regenerate the normal maps after importing the tileset PNGs.

### APP ICON (new, `de59911`) ✗
- take: `resources/gfx/ui/app_icon/` (`.aseprite`, 2 PNGs, `AppIcon.ico`)
- MERGE (easy): `project.godot`. Two lines: `config/icon` and `config/windows_native_icon`.
  You also changed `project.godot` in `c66e72c`, so add the two lines by hand.

### SKINS (new, `1b46e21` "re") ✗
Seven new looks for the adventurer: `human_female`, plus a male and a female elf, dwarf
and kemono (a fox with ears and a tail). They're made by a script
(`.claude/tools/character_skins.py`), and there are no `.aseprite` files yet.
- take (art): `resources/gfx/entities/entities.protagonist/variants/` (7 folders, each with
  PNGs and an `<id>.json` like `{"like": "human", "art": ...}`), its README,
  `.claude/tools/character_skins.py`, `test/unit/test_character_skins.gd`
- MERGE: `PlayerController.gd`, `scripts/ui/town/MainTown.gd`, `scenes/ui/town/MainTown.tscn`
- **Built on the old code, so it clashes with your adventurer/skin work (`0e7a9c8`,
  `bc78339`):**
  - The names are old: his code says `CHARACTERS` and `character_id` (and adds
    `character_ids()`/`character_data()`), where main now says `SKINS`, `skin_id` and `set_skin`.
    His folder is `variants/`; by main's naming it should be `skins/`.
  - The picker is in the wrong place. He builds a 4-column picker grid on the town's old
    "Human" button panel. Main no longer uses that panel: the skin is chosen per adventurer
    in `CharacterSelect`, saved, and shared through `NetworkSync.report_skin`. Keep his
    art and his `like`/`art` loading; put the choice into `CharacterSelect` and don't take
    his `MainTown` changes. `CharacterSelect` is at 640x360 now (2026-09-26): his picker
    goes in at half his sizes, fonts only through `UiTheme.tres`, whole numbers only.
  - `MainTown` (2026-09-26) is at 640x360 too, and its own chat log/input/Send button is
    replaced by the shared `ChatBox` scene (`add_chat_line` forwards to it). Merge his town
    changes onto that; don't bring the old chat nodes back.
  - Main's `SKINS` comment says only the Human is left because gear only fits its body.
    His `"fits_gear": false` answers that: gear is hidden on the elf, dwarf and kemono
    (the items still count). **Decision:** do you want skins that show no gear yet?
- `human_female` is the Human's sheets plus long hair. Re-run his script after the Human's
  art changes (GEAR ART `be05007` changed it).
- Main still has old `entities.protagonist/dwarf/` and `knight/` folders, which the `SKINS`
  comment calls temporary. The new `dwarf_male` makes them a second dwarf; remove them
  when this lands.

### THINGS RESTORE (art and data main reverted) ✗
The "things" commit (`d0b8a02`) that `main` reverted in `102f4e9`. The branch is built on it.
- Minion sprite sheets for about 30 creatures, 34 minion JSONs in
  `game/entities/entities.antagonist/minions/`, item icons in `resources/gfx/ui/icons/items/`,
  the 12 rings in `game/items/ring/`, `scripts/entities/GearEffects.gd`
- Import: `git revert 102f4e9` (revert the revert), or `restore` the folders you want
- **Decision:** is `GearEffects.gd` still wanted?
- Needed by: STORAGE (rings, icons), MINION ART

### GEAR ART (held items, walk frames and bob) ✗
No code. After importing, look at it in game.
- `0274c55` held items: fixes the main/off-hand art for the Up, Up-Right and Right facings (203 files)
- `ac0d592` side walk: strides with a 1px body bob, all `-Right` gear follows (374 files)
- **New `be05007`:** the Human bobs in every direction and all gear follows (1399 files:
  human, amulets, back, chest, gloves, helmets, legs, main_hand, off_hand)
- `38c0a53`, `6727e9a` off-hand left-facing sheets and their import settings
- `29088d3` import files for the greatsword, codex, aegis and main menu fireball/scroll
- Import: `restore` `resources/gfx/gear/` and `resources/gfx/entities/entities.protagonist/human/`
  (all take; the latest version already includes every earlier commit), **except `human.json`**:
  MERGE, main changed its frame speeds in `04a93d5` (10 fps)
- `resources/gfx/gear/` on the branch also holds the other-body copies (GEAR FOR OTHER BODIES,
  about 11,500 files since `e755904`). Restoring the whole folder brings them in unused until SKINS.

### MINION ART ✗
- `2c67188` minion `.aseprite` sources and updated sprite sheets (112 files, no code)
- `resources/gfx/entities/entities.antagonist/minions/skeleton/skeleton.warrior/` (8 files):
  main deleted these, the branch changed them
- Needs: THINGS RESTORE

### MAIN MENU SOUNDS ✗
- `scripts/ui/MenuWeapon.gd` (take): hover, sword cut, staff charge, burn
- Sounds: `resources/sfx/ui/main_menu/` (in AUDIO; already identical on main)
- **Found 2026-09-26:** the scrolls-and-weapon menu itself comes from his revert `6a09959`:
  `MenuBattle.gd`, `MenuScrollButton.gd`, `MenuWeapon.gd` and 7 PNGs in `resources/gfx/ui/main_menu/`
  (none on main), plus MERGE `scripts/ui/MainMenu.gd` and `scenes/ui/MainMenu.tscn`. Main's MainMenu
  is now 640x360, uses `MenuPanel.open()` and picks the character first (`_pick_character`); his
  wires the buttons to the weapon. Decision 0c.
- ⚠️ Leave out `.claude/settings.json`. That commit removes the team-wide block on Claude
  running `git commit` and `git push`.

### COMBAT FEEDBACK ✗
Hit sounds, damage numbers, hurt overlay. Close to your sound work.
- Sound code: already in main (see AUDIO). Take `test/unit/test_combat_sounds.gd` and fix its paths
- Numbers and hits: `scripts/entities/DamageNumber.gd` (take), `test/sim/hit_feedback.gd` (take, fix
  its paths); `scripts/entities/HitFeedback.gd` is now on main with the sound part only: MERGE, add
  his looks to main's file (see AUDIO)
- Hurt overlay (take): `scripts/ui/HurtOverlay.gd`
- Actions, **MERGE now** (2026-09-26; main changed them for the sound work: attack noise, `cause`):
  `scripts/actions/AttackEffect.gd`, `ProjectileVerb.gd`, `TileHit.gd`. (`HitVerb.gd`,
  `TauntVerb.gd`, `DestroyTilesVerb.gd` are already identical to the branch, 2026-09-26.) Take: `ParticleBurst.gd`, `scripts/ui/MenuBattle.gd`,
  `.claude/docs/combat-feedback.md`
- MERGE (easy): `game/actions/slash.json`, `arrow_shot.json`, `entropia_bolt.json`,
  `perditio_touch.json`, `MouseFollowCamera.gd`
- MERGE: `game/actions/README.md`, `verbs/ThrowVerb.gd`, `scripts/actions/ActionIndex.gd`,
  `scripts/entities/EntityStats.gd`, `singletons/NetworkSync.gd`, `PlayerController.gd`,
  `MinionController.gd`, `test/sim/README.md`
- **Decision:** `scenes/ui/HealthBar.tscn` and `scripts/ui/HealthBar.gd`. Main deleted
  them for the new UI, the branch changed them. Probably move whatever the branch added
  into your new UI.
- Needs: AUDIO (sounds and bus effects)

### SETTINGS ✗
Parchment scroll with candle sliders and wax seals. **You have also been working here**
(`c66e72c` Audio Settings, `70d972c` voice controls, `VoiceSettings.gd`), so do this
one while you know that code.
- take: `scripts/settings/AudioControl.gd`, `FeedbackControl.gd`, `FullscreenControl.gd`,
  `VSyncControl.gd`, `scripts/ui/MenuScrollButton.gd`
- MERGE: `scripts/ui/SettingsMenu.gd` (you changed it in `c66e72c`; Silvery changed it in
  `3bad3b3` and `d300b27`), `scenes/ui/SettingsMenu.tscn` (175-line conflict, and you
  changed it again in `70d972c`), `singletons/ConfigFileHandler.gd`
- Art: settings textures from `3bad3b3`
- Make sure your voice settings end up on the same parchment page as his volume rows, not a second audio page.
- 640x360 (2026-09-26): main halved every size in `SettingsMenu.tscn` and `VoiceSettings.gd`
  and moved its font sizes to `resources/UiTheme.tres` (`MenuTitle` 15, `MenuHeading` 11; the
  root sets `theme`). His parchment layout comes in at half his sizes, fonts only through the
  theme, whole numbers only (see Pixel-perfect checks).
- Needs: COMBAT FEEDBACK (the feedback settings in `FeedbackControl.gd`)

### PARTY WIPE ✗
Graves, dive history and End votes.
- take: `scripts/dungeon/RunLog.gd`, `scripts/ui/PartyWipeScreen.gd`,
  `scenes/ui/PartyWipeScreen.tscn`, `test/unit/test_run_log.gd`,
  `.claude/docs/party-wipe-screen.md`, background art (`f7d1984`, church on a hill)
- MERGE (easy): `scripts/entities/SpriteFramesLoader.gd`
- MERGE: `scripts/dungeon/Dungeon.gd` (2026-09-26, was take: add only his `RunLog.begin()`; main
  removed the chat forwarding for the HUD split)
- MERGE: `scenes/dungeon/Dungeon.tscn` (Hotbar path moved to `ui/protagonist/`; since 2026-09-26
  the HUD is in `scenes/ui/protagonist/MissionHud.tscn`, so `PartyWipeScreen` goes there, not in
  `Dungeon.tscn`),
  `scripts/entities/entities.antagonist/MinionIndex.gd`
- **Decision:** `DeathCountdown`. Main moved it to `ui/protagonist/` and changed it, the branch deleted it.

### STORAGE AND INVENTORY ✗
The biggest chunk. Do it in these four parts.
- [✗] Item data (take): all changed JSON in `game/items/` (back, main_hand, off_hand, neck),
  new `material/`, `misc/`, `potion/` folders, `game/sets/` (21 new sets). MERGE:
  `game/items/README.md`, `off_hand/poacher_torch.json` (your torch light and vision work)
- [✗] Art: storage panel art (`76f21ea`) and item sounds (`resources/sfx/ui/inventory/`, in AUDIO)
- [✗] Logic. take: `ItemSounds.gd`, `CapacityBar.gd`, `DollStage.gd`, `scripts/ui/Parchment.gd`,
  `scripts/ui/town/TownStorage.gd`, `test/unit/test_storage_organise.gd`,
  `test/unit/test_shift_sweep.gd`. MERGE (easy): `scripts/ui/inventory/ItemSlot.gd`,
  `scenes/ui/town/TownStorage.tscn`. MERGE: `StoragePanel.gd` (233 lines),
  `InventoryPanel.gd` (182), `singletons/PlayerInventory.gd` (150),
  `scripts/items/ItemDatabase.gd` (117)
- [✗] Later fixes, already in the files above: scroll jump fix (`2e36c02`) and shift-sweep (`5f22889`)
- `DollStage.gd` changed again in `e755904` (35 lines, the other-body gear on the doll); still take
- Needs: THINGS RESTORE (rings, icons)

### ANIMATIONS ✗
Idle blink and breath, attack lunge, death topple for players and minions.
- take: `scripts/entities/DirectionalAnimator.gd`, `test/unit/test_body_poses.gd`
- MERGE (easy): `scripts/entities/GearLayers.gd`, `resources/gfx/entities/entities.protagonist/human/human.json`
- MERGE: `PlayerController.gd`, `MinionController.gd`

### WADING AND LIQUIDS ✗
Bodies sink in water, lava and acid and take on the liquid's look. **New `d300b27`:**
minions wade too (`MinionController.gd` adds a `Wading` node; fliers skip it, big bodies wade by their middle).
- take: `scripts/entities/Wading.gd`, `resources/shaders/wading.gdshader`,
  `game/tiles/floor_acid.json`, `floor_lava.json` (new `see_through`), `game/tiles/README.md`,
  `test/unit/test_wading_looks.gd`, `test/unit/test_held_hands.gd`
- MERGE: `scripts/cells/tiles/TileType.gd`, `PlayerController.gd`, `MinionController.gd`, `ItemDatabase.gd`
- Sounds: `resources/sfx/effects/water|lava|acid/` (in AUDIO)
- **Review:** a floor counts as a liquid if it has a sound folder under `resources/sfx/effects/`.
  If a sound folder is missing, the game stops treating that floor as a liquid. A flag on
  the tile JSON may be safer; discuss with Silvery.
- **Performance:** every wading minion gets its own `Wading` node. Check a room with hundreds of rats.

### DOOR SOUNDS ✗
Close to your sound work.
- MERGE: `scripts/dungeon/DoorManager.gd` (30 lines added: open/close sound per door type)
- Sounds: `resources/sfx/effects/doors/` (in AUDIO)
- Test: `test/unit/test_liquid_door_sounds.gd` covers both this and WADING

### FIXES (the "h" commit, `8e7b86b`) ✗
Unrelated fixes bundled into one commit. Take each one with the chunk it belongs to, or on its own.
- `scripts/entities/GridMover.gd`: floor speeds read once and shared by every mover
  (was thousands of file reads while a dungeon with hundreds of minions loaded). Good for
  the pathfinding performance work. MERGE (also has FOOTSTEPS)
- `singletons/NetworkSync.gd`: new `dive_peers()` so dungeon-only messages go only to
  players in the dive. MERGE, check it against your own host-check refactor (`8fde56b`)
- `scripts/dungeon/MinionSpawning.gd`: roll and fit minion together. MERGE
- `scripts/ui/LobbyMenu.gd` (MERGE easy), `scripts/ui/MenuScrollButton.gd` (take): timers no
  longer resume on a freed menu (a crash fix). Main's `_build_toast` changed for 640x360
  (2026-09-26: halved, centred by a container column, font from `UiTheme.tres`): keep main's.
- `HurtOverlay.gd`, `PartyWipeScreen.gd`, `RunLog.gd`, `PlayerInventory.gd`,
  `AudioBusLayout.tres`: already covered by their chunks

### WOLF BITE AND ATTACK POSES (new 2026-09-26, `c12af26`) ✗
An attack plays the caster's "Attack"+facing animation once on every peer (the wolf and
hellhound crouch-bite-stand); players lunge when their body JSON says `"lunge"`.
- take: the 8 wolf attack sheets (`Wolf-Attack-Down|Up|Left|Right`, `.png` + `.aseprite`) in
  `resources/gfx/entities/entities.antagonist/minions/wolf/wolf/` and `wolf.hellhound/`,
  `test/unit/test_body_poses.gd`
- `scripts/entities/DirectionalAnimator.gd`: take (main has not changed it; also in ANIMATIONS)
- MERGE: `wolf.json`, `wolf_hellhound.json` (add the 4 `Attack*` entries; main edited their
  comments), `human.json` (`"lunge": true`; also in ANIMATIONS), `PlayerController.gd` (`set_lunge`),
  `singletons/NetworkSync.gd` (one line)
- **MERGE with care, `AttackEffect.gd`:** his `play_attack` is written on the old one. Keep main's
  lines (the attack's noise, `report_noise`, and nothing sent for an attack with no picture and no
  sound) and add only his `tagged["caster"]` path.
- **`ThrowVerb.gd`:** take only his "turn toward the landing" line (`play_attack(caster,
  landing_global, attack, {"anchor": "attacker"})`). His `loudness` is the old sound model; main's
  throw uses the action's `db`.
- Main has `scripts/entities/HitFeedback.gd` and the `cause` in hits; check the pose still plays
  when the attack's effect has no picture.

### PROPS (new 2026-09-26, `c12af26`) ✗
Any PNG in `resources/gfx/objects/props/` is a prop: listed in the Dungeon Maker, drawn in dives,
turned with its room. Cosmetic only (no collision, no sound). Barrel and Crate to start.
- take: `scripts/dungeon/Props.gd`, `test/unit/test_props.gd`, `resources/gfx/objects/props/`
  (`Barrel`, `Crate`, `.png` + `.aseprite`)
- MERGE: `scripts/dungeon/DungeonAssembler.gd`, `DungeonMaker.gd`, `DungeonPainter.gd`,
  `game/rooms/README.md`
- **Check:** main's to-do says room `"objects"` is editor-only data until decoration is built.
  Props are that decoration: decide whether they use `"objects"` or a key of their own.

### NEW TILE SETS (new 2026-09-26, `34f1e4f`) ✗
Fourteen floors (brick, cobblestone, flowers, grate, gravel, ice, lava crust, leaves, metal plate,
moss, mossy cobblestone, parquet, sand, snow) and eight walls (bookshelf, brick, ice, iron, mine
ore, mossy stone, sandstone, stained glass), floor overlays (little animations), a redrawn
`wall_smooth_stone` and `floor_water`.
- take: the 22 new tile JSONs in `game/tiles/`, `game/tiles/floor_water.json` (adds its ripple
  overlay), `game/tile_registry.json` (main has not changed it), their art in
  `resources/gfx/tileset/` (`.png`, `_normal.png`, `.aseprite`, 7 `overlay_*.png`),
  `.claude/tools/normal_maps.py` (also in TILE VARIANTS)
- MERGE: `game/tiles/README.md`, `README.md` (Tiles section; main added `muffle` and `footsteps`
  there), `docs/ART_TODO.md`
- **Sound, before taking:** the new floors already carry `footsteps`; give each new wall a
  `muffle` like main's walls (wood 20 to bedrock 60: bookshelf about 20, ice and brick about 35,
  iron and sandstone about 40, stained glass about 15). Add any new `footsteps` material
  (e.g. `sand`, `snow`, `metal`) to `game/sounds.json` `footstep_db`, or it uses the default.
- Needed by: NEW BIOMES

### ELF AND DWARF REDRAW (new 2026-09-26, `fd552b8`) ✗
Part of SKINS: the elf and dwarf sheets in `resources/gfx/entities/entities.protagonist/variants/`
redrawn (slim elves in green and gold, stocky dwarves in blue) and `.claude/tools/character_skins.py`.
Take with SKINS; nothing on main to merge.

### ITEM ICONS REDRAW (new 2026-09-26, `6bcacf0`) ✗
All 205 item icons in `resources/gfx/ui/icons/items/` redrawn, made by the new scripts in
`.claude/tools/item_icons/`. Main deleted those icons in the revert (THINGS RESTORE), so take them
with THINGS RESTORE, from this newer commit. MERGE: `docs/ART_TODO.md` (one line). `e755904`
redrew five helmet icons again (abyssal fin, clockwork goggle cap, hamster, infernal horned, magma
horned) and `item_icons/slot_head.py`; taking the folder gets them.

### NEW BIOMES (new 2026-09-26, `94900e2` "r") ✗
Five new biomes, 45 rooms each with a `defines.json`: `foundry`, `garden`, `glacier`, `library`,
`tomb` in `game/rooms/`.
- take: the five folders, **then remove `"biome"` from every room** (main dropped that field from
  all rooms on 2026-09-25; the folder decides)
- Needs: NEW TILE SETS (the rooms use its floors and walls), THINGS RESTORE (their monsters: only
  `wraith` and `skeleton_archer` are on main; goblin, orc, bee, yeti, penguin, scorpion and the rest
  are not), BIOME AMBIENCE (`defines.json` points at `resources/sfx/ambiance/*.mp3`)
- Check `game/rooms/BIOMES.md` and the Dungeon Maker's biome list know them.

### NEON OUTLAW SET AND BARD SONGS (new 2026-09-26, `94900e2` "r") ✗
A legendary bard set: 11 items (jacket, boots, gloves, visor, pants, pick pendant, amp backpack,
and four instruments: laser keytar, plasma guitar, holo drum gauntlets, theremin staff).
- take: the 11 item JSONs in `game/items/*/`, `game/sets/neon_outlaw.json`, their icons in
  `resources/gfx/ui/icons/items/`, gear art in `resources/gfx/gear/*/neon_outlaw/` and
  `back/amp_backpack/`, `.claude/tools/neon_outlaw.py`
- Sound: 4 whole songs in `resources/sfx/music/bard/` (Pixabay, credited in `SOURCES.md`). Each
  instrument's JSON names its `"song"`. BARD PERFORMANCE (`4c160c8`) is what plays them.
- Needs: THINGS RESTORE / STORAGE (main has no `game/sets/`)

### BARD PERFORMANCE (new 2026-09-26, `4c160c8`) ✗
Press **B** while holding an instrument: its song loops. The performer hears it at full volume while
the music ducks (`MusicManager.duck()`), and everyone else hears it from where the performer stands.
Unequipping the instrument or dying ends it. The keytar, guitar and drums are now `"weapon": "blunt"`
(their swing sound, see REAL SOUNDS).
- take (new): `scripts/entities/entities.protagonist/player/BardPerformance.gd`
- take: `singletons/MusicManager.gd` (`duck()`, `DUCK_DB`/`DUCK_FADE`; also in BIOME AMBIENCE, which
  takes the same file)
- The 3 instrument JSONs (`laser_keytar`, `plasma_guitar`, `holo_drum_gauntlets`): take with NEON
  OUTLAW (not on main yet)
- MERGE: `PlayerController.gd` (`performance` node, `_toggle_performing`, `set_performing`, the
  held-song check when gear changes), `scripts/items/ItemDatabase.gd` (`song()`),
  `singletons/NetworkSync.gd` (`share_performing`, `report_performing`, `peer_songs`)
- MERGE (easy): `project.godot`: a new `perform` input on **B** (nothing on main uses B). Add a
  controller button too (the HUD must work on keyboard+mouse and controller).
- **On merge:** his `share_performing` does its own `is_server()` / `rpc_id(1, …)`. Main has one
  helper for that, `NetworkSync.ask_host(...)` (`8fde56b`); use it instead of a second copy.
- **Check against your hearing work:** the song plays through a bare `AudioStreamPlayer2D` on the
  Music bus, not `SoundPlayer`/`Sound`. So walls don't muffle it and minions can't hear it.
  **Decision:** should a performance be a noise the hearing system knows about?
- Needs: NEON OUTLAW (the instruments and songs)

### MORE MAPS (new 2026-09-26, `4a3854d`) ✗
Sixteen new rooms in existing biomes, four of them huge and tagged `vast`: Dungeon Undercroft
70×70, Mine Grand Excavation 81×81, Cave Moss Cathedral 71×61, Sewer Great Cistern 71×71. Also
READMEs for the five new biomes and headstones for them.
- take: the 16 room JSONs (cave 4, dungeon 5, mine 4, sewer 3), **then remove `"biome"` from
  each** (all 16 have it; see NEW BIOMES)
- take: `game/rooms/cave|dungeon|mine/README.md`; the five new-biome READMEs (with NEW BIOMES);
  5 headstone PNGs in `resources/gfx/ui/party_wipe/` (with PARTY WIPE); `.claude/tools/room_maps/`
  (the seeded generators that made the rooms)
- MERGE (easy): `game/rooms/cave|dungeon|mine|sewer/defines.json` (adds `"vast": 0.35` to
  `tag_weights`; the same files get `ambience` from BIOME AMBIENCE), `game/rooms/sewer/README.md`
- MERGE: `game/rooms/BIOMES.md`, `game/rooms/README.md` (the `vast` tag), `docs/STRUCTURE.md`
- Needs: NEW TILE SETS. The new rooms use 11 floors and walls main doesn't have: `floor_brick`,
  `floor_cobblestone`, `floor_grate`, `floor_gravel`, `floor_ice`, `floor_moss`,
  `floor_mossy_cobblestone`, `wall_brick`, `wall_ice`, `wall_mine_ore`, `wall_mossy_stone`.
- **Check performance:** an 81×81 room is far bigger than anything on main. Test the pathfinding
  and minion count in the Grand Excavation before it goes into the normal room pool.

### GEAR FOR OTHER BODIES (new 2026-09-26, `94900e2` "r") ✗
Skins with a body of their own (`"fits_gear": false`: elf, dwarf) now wear their own copy of
each piece instead of none: `resources/gfx/gear/<slot>/<set>/<skin>/`, made by
`.claude/tools/character_gear.py`. So far militia (all slots) and a few weapons (poacher, rogue,
wraith). This answers most of SKINS' "skins that show no gear" decision. **New `e755904`:** every
set now has other-body copies (all 6 skins, every slot, plus `back/pennant/` and neon outlaw), about
11,500 files, and `dwarf_female` sheets redrawn (ELF AND DWARF REDRAW).
- take: the gear files (main has not changed `resources/gfx/gear/`),
  `.claude/tools/character_gear.py`, `test/unit/test_character_skins.gd`
- MERGE: `scripts/entities/GearLayers.gd` (`body_id`, `set_body`), `scripts/items/ItemDatabase.gd`
  (`sheet_path`/`sprite_frames`/`held_left` take a body), `PlayerController.gd` (`gear.set_body`;
  main calls it `set_skin`)
- Needs: SKINS

## Skip
- `6f0293b` / `5739548`: a scratch screenshot script added and then removed
- `ac7ed86`, `ac75de7`, `6f6d2c9`: restore and merge commits (THINGS RESTORE covers them)
- `6a09959` "Revert Pack AI Tweaks": skip the pack AI part (see "How to import"). The main menu
  battle and `GearEffects.gd` it brings back are in MAIN MENU SOUNDS and THINGS RESTORE.

## Shared files
Taking one of these brings in the other chunks' changes too.

| File | Chunks |
|---|---|
| `PlayerController.gd` | COMBAT FEEDBACK, ANIMATIONS, WADING, SKINS, WOLF BITE, GEAR FOR OTHER BODIES, BARD PERFORMANCE |
| `MusicManager.gd` | BIOME AMBIENCE, BARD PERFORMANCE |
| `project.godot` | APP ICON, BARD PERFORMANCE |
| `game/rooms/*/defines.json` | BIOME AMBIENCE, MORE MAPS |
| `MinionController.gd` | COMBAT FEEDBACK, ANIMATIONS, WADING |
| `GridMover.gd` | FOOTSTEPS, FIXES |
| `TileType.gd` | WADING, TILE VARIANTS |
| `ParticleBurst.gd` | COMBAT FEEDBACK, FOOTSTEPS |
| `SettingsMenu.gd` | SETTINGS, BIOME AMBIENCE |
| `GearLayers.gd` | ANIMATIONS, WADING, GEAR FOR OTHER BODIES |
| `ItemDatabase.gd` | STORAGE, WADING, GEAR FOR OTHER BODIES, REAL SOUNDS, BARD PERFORMANCE |
| `DollStage.gd` | STORAGE, WADING |
| `NetworkSync.gd` | COMBAT FEEDBACK, FIXES, WOLF BITE, BARD PERFORMANCE |
| `AttackEffect.gd` | COMBAT FEEDBACK, WOLF BITE |
| `DirectionalAnimator.gd` | ANIMATIONS, WOLF BITE |
| `human.json` | ANIMATIONS, WOLF BITE |
| `normal_maps.py` | TILE VARIANTS, NEW TILE SETS |
| `docs/ART_TODO.md` | NEW TILE SETS, ITEM ICONS REDRAW |
| `ConfigFileHandler.gd`, `SettingsMenu.tscn` | COMBAT FEEDBACK, SETTINGS |
| `README.md`, `docs/ART_TODO.md` | almost every chunk; merge the text at the end |

## When everything is in
Silvery starts a fresh branch from `main` and stops using `silvery/art-and-gear`.
Otherwise a later full merge brings back the same 160+ conflicts.
