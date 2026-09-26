# Silvery Merge Tracker

Bringing `silvery/art-and-gear` into `main` piece by piece instead of one big merge.
Pick up whichever chunk matches what you are working on; the order does not matter
except where a chunk says **Needs**.

Legend: ✓ in main and committed, [~] partly in, ✗ not started.
**take** = only Silvery changed this file since the branch split, so his copy can be
copied over as-is. **MERGE** = you both changed it; open both and combine by hand.
**MERGE (easy)** = you both changed it, but in different lines, so nothing overlaps.
Still combine it by hand: copying his file over would wipe out your changes.

Last checked: 2026-09-25 against branch tip `1b46e21` (35 commits since the split at
`d0b8a02`) and main `7ee9de3`. Labels compare against committed `main`: if you have
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

## Chunks

### AUDIO (sound files and buses) [~]
Your current area. The sound files only; the scripts that play them are in the other chunks.
- [✓] The 150 sound files in `resources/sfx/combat`, `effects/water`, `ui/inventory` and
  `ui/main_menu`, identical to the branch (committed in `68c02b4`)
- [✓] Sound code, ported in `68c02b4` into **different folders** than the branch uses:
  branch `scripts/audio/SoundPlayer.gd` is main's `scripts/util/SoundPlayer.gd`, and
  branch `scripts/audio/CombatSounds.gd` is main's `scripts/actions/CombatSounds.gd`.
  **Never take `scripts/audio/`**, or there will be two copies. Code uses the class
  names, so it works as-is. Only three branch files write out the old path and need it
  fixed when they come over: `test/sim/hit_feedback.gd`, `resources/sfx/combat/README.md`,
  `.claude/docs/combat-feedback.md`.
- [✗] **New `d300b27`:** Silvery added `SoundPlayer.numbered(start)` (finds `pop_1.wav`,
  `pop_2.wav`… until one is missing). Copy that function by hand into
  `scripts/util/SoundPlayer.gd`. You changed that file too, in `c66e72c`. LIQUID AMBIENCE,
  FOOTSTEPS and DOOR SOUNDS need it.
- [✗] `resources/sfx/effects/acid/`, `lava/` (4 more lava sounds in `d300b27`), `doors/`,
  `resources/sfx/effects/README.md` (take)
- [✗] `resources/sfx/combat/README.md`, `resources/sfx/effects/water/README.md` (take)
- [✗] `resources/AudioBusLayout.tres` (MERGE). Main has a **VoiceChat** bus the branch
  lacks. The branch adds LowPassFilter and Compressor effects (used for the hurt muffle
  in COMBAT FEEDBACK). Keep VoiceChat and add the effects.
- Note: `SoundPlayer` is the one shared place sounds are started from. Creature, ambient
  and door sounds should go through it too, not through a second player.

### BIOME AMBIENCE (new, `d300b27`) ✗
Your current area. A biome's `"ambience"` loop plays quietly under the music on the SFX bus
and fades between biomes. There are no ambience files yet; this adds the player only.
- take: `singletons/MusicManager.gd`, `test/unit/test_biome_ambience.gd`
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
floor's colours. No footstep sound files exist yet.
- MERGE: `scripts/entities/GridMover.gd` (it also has the FIXES speed cache)
- take: `scripts/actions/ParticleBurst.gd` (also changed in COMBAT FEEDBACK), `test/unit/test_footsteps.gd`
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
    his `MainTown` changes.
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
  (all take; the latest version already includes every earlier commit)

### MINION ART ✗
- `2c67188` minion `.aseprite` sources and updated sprite sheets (112 files, no code)
- `resources/gfx/entities/entities.antagonist/minions/skeleton/skeleton.warrior/` (8 files):
  main deleted these, the branch changed them
- Needs: THINGS RESTORE

### MAIN MENU SOUNDS ✗
- `scripts/ui/MenuWeapon.gd` (take): hover, sword cut, staff charge, burn
- Sounds: `resources/sfx/ui/main_menu/` (in AUDIO)
- ⚠️ Leave out `.claude/settings.json`. That commit removes the team-wide block on Claude
  running `git commit` and `git push`.

### COMBAT FEEDBACK ✗
Hit sounds, damage numbers, hurt overlay. Close to your sound work.
- Sound code: already in main (see AUDIO). Take `test/unit/test_combat_sounds.gd` and fix its paths
- Numbers and hits (take): `scripts/entities/HitFeedback.gd`, `scripts/entities/DamageNumber.gd`, `test/sim/hit_feedback.gd`
- Hurt overlay (take): `scripts/ui/HurtOverlay.gd`
- Actions (take): `scripts/actions/AttackEffect.gd`, `ParticleBurst.gd`, `verbs/HitVerb.gd`,
  `ProjectileVerb.gd`, `TauntVerb.gd`, `DestroyTilesVerb.gd`, `TileHit.gd`, `scripts/ui/MenuBattle.gd`,
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
- Needs: COMBAT FEEDBACK (the feedback settings in `FeedbackControl.gd`)

### PARTY WIPE ✗
Graves, dive history and End votes.
- take: `scripts/dungeon/RunLog.gd`, `scripts/ui/PartyWipeScreen.gd`,
  `scenes/ui/PartyWipeScreen.tscn`, `scripts/dungeon/Dungeon.gd`, `test/unit/test_run_log.gd`,
  `.claude/docs/party-wipe-screen.md`, background art (`f7d1984`, church on a hill)
- MERGE (easy): `scripts/entities/SpriteFramesLoader.gd`
- MERGE: `scenes/dungeon/Dungeon.tscn` (Hotbar path moved to `ui/protagonist/`),
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
  longer resume on a freed menu (a crash fix)
- `HurtOverlay.gd`, `PartyWipeScreen.gd`, `RunLog.gd`, `PlayerInventory.gd`,
  `AudioBusLayout.tres`: already covered by their chunks

## Skip
- `6f0293b` / `5739548`: a scratch screenshot script added and then removed
- `ac7ed86`, `ac75de7`, `6f6d2c9`: restore and merge commits (THINGS RESTORE covers them)
- `6a09959` "Revert Pack AI Tweaks": **decision.** Skip it unless `main` should also lose
  the Pack AI Tweaks (`test/unit/test_room_graph.gd`, 29 lines of `RoomGraph.gd`)

## Shared files
Taking one of these brings in the other chunks' changes too.

| File | Chunks |
|---|---|
| `PlayerController.gd` | COMBAT FEEDBACK, ANIMATIONS, WADING, SKINS |
| `MinionController.gd` | COMBAT FEEDBACK, ANIMATIONS, WADING |
| `GridMover.gd` | FOOTSTEPS, FIXES |
| `TileType.gd` | WADING, TILE VARIANTS |
| `ParticleBurst.gd` | COMBAT FEEDBACK, FOOTSTEPS |
| `SettingsMenu.gd` | SETTINGS, BIOME AMBIENCE |
| `GearLayers.gd` | ANIMATIONS, WADING |
| `ItemDatabase.gd` | STORAGE, WADING |
| `DollStage.gd` | STORAGE, WADING |
| `NetworkSync.gd` | COMBAT FEEDBACK, FIXES |
| `ConfigFileHandler.gd`, `SettingsMenu.tscn` | COMBAT FEEDBACK, SETTINGS |
| `README.md`, `docs/ART_TODO.md` | almost every chunk; merge the text at the end |

## When everything is in
Silvery starts a fresh branch from `main` and stops using `silvery/art-and-gear`.
Otherwise a later full merge brings back the same 160+ conflicts.
