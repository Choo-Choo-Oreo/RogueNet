# Silvery Merge Tracker

Bringing `silvery/art-and-gear` into `main` piece by piece instead of one big merge.
Pick up whichever chunk matches what you are working on; the order does not matter
except where a chunk says **Needs**.

Legend: ✓ in main and committed, [~] partly in, ✗ not started.
**take** = main has not changed this file since the branch split, so the branch copy
can be copied over as-is. **MERGE** = both sides changed it; open both and combine by hand.

Last checked: 2026-09-25 against branch tip `7cabcd1` (31 commits since the split at
`d0b8a02`) and main `9a95060`. The take/MERGE labels compare against committed `main`: if you have
uncommitted edits in a "take" file, it has become a MERGE file for you.

## How to import a chunk

```
git fetch
git restore --source=origin/silvery/art-and-gear -- <path> <path> ...
```

- Only use `restore` on **take** files and folders. It overwrites the whole file with Silvery's version.
- For a **MERGE** file, compare the two versions and combine them by hand:
  `git diff main origin/silvery/art-and-gear -- <path>`
- Some files are in more than one chunk (for example `GearLayers.gd` and `PlayerController.gd`).
  Taking one of them brings every branch change to that file, including the other chunk's.
  The **Shared files** table at the bottom lists them.
- Commit each chunk on its own: `Import Silvery: <chunk name>`.

## Chunks

### AUDIO (sound files and buses) [~]
Your current area. The sound files only; the scripts that play them are in the other chunks.
- [✓] The 150 sound files in `resources/sfx/combat`, `effects/water`, `ui/inventory` and
  `ui/main_menu`, identical to the branch (committed in `9a95060`)
- [✓] Sound code, ported in `9a95060` into **different folders** than the branch uses:
  branch `scripts/audio/SoundPlayer.gd` is main's `scripts/util/SoundPlayer.gd`, and
  branch `scripts/audio/CombatSounds.gd` is main's `scripts/actions/CombatSounds.gd`
  (both identical). **Never take `scripts/audio/`**, or there will be two copies. Code uses
  the class names, so it works as-is. Only three branch files write out the old path and
  need it fixed when they come over: `test/sim/hit_feedback.gd`,
  `resources/sfx/combat/README.md`, `.claude/docs/combat-feedback.md`.
- [✗] New in the latest push: `resources/sfx/effects/acid/`, `lava/`, `doors/`,
  `resources/sfx/effects/README.md` (take)
- [✗] `resources/sfx/combat/README.md`, `resources/sfx/effects/water/README.md` (take)
- [✗] `resources/AudioBusLayout.tres` (MERGE). Main has a **VoiceChat** bus the branch
  lacks. The branch adds LowPassFilter and Compressor effects (used for the hurt muffle
  in COMBAT FEEDBACK). Keep VoiceChat and add the effects.
- Note: `SoundPlayer` is the one shared place sounds are started from. Creature, ambient
  and door sounds should go through it too, not through a second player.

### THINGS RESTORE (art and data main reverted) ✗
The "things" commit (`d0b8a02`) that `main` reverted in `102f4e9`. The branch is built on it.
- Minion sprite sheets for about 30 creatures, 34 minion JSONs in
  `game/entities/entities.antagonist/minions/`, item icons in `resources/gfx/ui/icons/items/`,
  the 12 rings in `game/items/ring/`, `scripts/entities/GearEffects.gd`
- Import: `git revert 102f4e9` (revert the revert), or `restore` the folders you want
- **Decision:** is `GearEffects.gd` still wanted?
- Needed by: STORAGE (rings, icons), MINION ART

### GEAR ART (held items and walk frames) ✗
No code. After importing, look at it in game.
- `0274c55` held items: fixes the main/off-hand art for the Up, Up-Right and Right facings (203 files)
- `ac0d592` side walk: strides with a 1px body bob, all `-Right` gear follows (374 files)
- `38c0a53`, `6727e9a` off-hand left-facing sheets and their import settings
- `29088d3` import files for the greatsword, codex, aegis and main menu fireball/scroll
- Import: `git cherry-pick` each commit, or `restore` `resources/gfx/gear/`

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
- Actions (take): `slash.json`, `arrow_shot.json`, `entropia_bolt.json`,
  `perditio_touch.json`, `scripts/actions/AttackEffect.gd`, `ParticleBurst.gd`,
  `verbs/HitVerb.gd`, `ProjectileVerb.gd`, `TauntVerb.gd`, `DestroyTilesVerb.gd`, `TileHit.gd`
- Actions (MERGE, changed in `9a95060`): `game/actions/README.md`, `verbs/ThrowVerb.gd`
- Other (take): `MouseFollowCamera.gd`, `scripts/ui/MenuBattle.gd`, `.claude/docs/combat-feedback.md`
- MERGE: `scripts/actions/ActionIndex.gd`, `scripts/entities/EntityStats.gd`,
  `singletons/NetworkSync.gd`, `PlayerController.gd`, `MinionController.gd`, `test/sim/README.md`
- **Decision:** `scenes/ui/HealthBar.tscn` and `scripts/ui/HealthBar.gd`. Main deleted
  them for the new UI, the branch changed them. Probably move whatever the branch added
  into your new UI.
- Needs: AUDIO (sounds and bus effects)

### SETTINGS ✗
Parchment scroll with candle sliders and wax seals.
- take: `scripts/settings/AudioControl.gd`, `FeedbackControl.gd`, `FullscreenControl.gd`,
  `VSyncControl.gd`, `scripts/ui/SettingsMenu.gd`, `scripts/ui/MenuScrollButton.gd`
- MERGE: `scenes/ui/SettingsMenu.tscn` (175-line conflict), `singletons/ConfigFileHandler.gd`
- Art: settings textures from `3bad3b3`
- Needs: COMBAT FEEDBACK (the feedback settings in `FeedbackControl.gd`). If you are
  adding a voice chat volume slider, `AudioControl.gd` is the place.

### PARTY WIPE ✗
Graves, dive history and End votes.
- take: `scripts/dungeon/RunLog.gd`, `scripts/ui/PartyWipeScreen.gd`,
  `scenes/ui/PartyWipeScreen.tscn`, `scripts/dungeon/Dungeon.gd`,
  `scripts/entities/SpriteFramesLoader.gd`, `test/unit/test_run_log.gd`,
  `.claude/docs/party-wipe-screen.md`, background art (`f7d1984`, church on a hill)
- MERGE: `scenes/dungeon/Dungeon.tscn` (Hotbar path moved to `ui/protagonist/`),
  `scripts/entities/entities.antagonist/MinionIndex.gd`
- **Decision:** `DeathCountdown`. Main moved it to `ui/protagonist/` and changed it, the branch deleted it.

### STORAGE AND INVENTORY ✗
The biggest chunk. Do it in these four parts.
- [✗] Item data (take): all changed JSON in `game/items/` (back, main_hand, off_hand, neck),
  new `material/`, `misc/`, `potion/` folders, `game/sets/` (21 new sets). MERGE:
  `game/items/README.md`, `off_hand/poacher_torch.json` (your torch light and vision work)
- [✗] Art: storage panel art (`76f21ea`) and item sounds (`resources/sfx/ui/inventory/`, in AUDIO)
- [✗] Logic. take: `scripts/ui/inventory/ItemSlot.gd`, `ItemSounds.gd`, `CapacityBar.gd`,
  `DollStage.gd`, `scripts/ui/Parchment.gd`, `scripts/ui/town/TownStorage.gd`,
  `scenes/ui/town/TownStorage.tscn`, `test/unit/test_storage_organise.gd`,
  `test/unit/test_shift_sweep.gd`. MERGE: `StoragePanel.gd` (233 lines),
  `InventoryPanel.gd` (182), `singletons/PlayerInventory.gd` (150),
  `scripts/items/ItemDatabase.gd` (117)
- [✗] Later fixes, already in the files above: scroll jump fix (`2e36c02`) and shift-sweep (`5f22889`)
- Needs: THINGS RESTORE (rings, icons)

### ANIMATIONS ✗
Idle blink and breath, attack lunge, death topple for players and minions.
- take: `scripts/entities/DirectionalAnimator.gd`, `scripts/entities/GearLayers.gd`,
  `resources/gfx/entities/entities.protagonist/human/human.json`, `test/unit/test_body_poses.gd`
- MERGE: `PlayerController.gd`, `MinionController.gd`

### WADING AND LIQUIDS ✗
Updated by the new push. Bodies sink in water, lava and acid and take on the liquid's look.
- take: `scripts/entities/Wading.gd`, `resources/shaders/wading.gdshader`,
  `game/tiles/floor_acid.json`, `floor_lava.json` (new `see_through`), `game/tiles/README.md`,
  `test/unit/test_wading_looks.gd`, `test/unit/test_held_hands.gd`
- MERGE: `scripts/cells/tiles/TileType.gd`, `PlayerController.gd`, `ItemDatabase.gd`
- Sounds: `resources/sfx/effects/water|lava|acid/` (in AUDIO)
- **Review:** a floor counts as a liquid if it has a sound folder under `resources/sfx/effects/`.
  If a sound folder is missing, the game stops treating that floor as a liquid. A flag on
  the tile JSON may be safer; discuss with Silvery.

### DOOR SOUNDS ✗
New in the latest push. Close to your sound work.
- MERGE: `scripts/dungeon/DoorManager.gd` (30 lines added: open/close sound per door type)
- Sounds: `resources/sfx/effects/doors/` (in AUDIO)
- Test: `test/unit/test_liquid_door_sounds.gd` covers both this and WADING

### FIXES (the "h" commit, `8e7b86b`) ✗
Unrelated fixes bundled into one commit. Take each one with the chunk it belongs to, or on its own.
- `scripts/entities/GridMover.gd`: floor speeds read once and shared by every mover
  (was thousands of file reads while a dungeon with hundreds of minions loaded). Good for
  the pathfinding performance work. MERGE
- `singletons/NetworkSync.gd`: new `dive_peers()` so dungeon-only messages go only to
  players in the dive. MERGE, check it against your own host-check refactor (`8fde56b`)
- `scripts/dungeon/MinionSpawning.gd`: roll and fit minion together. MERGE
- `scripts/ui/LobbyMenu.gd`, `scripts/ui/MenuScrollButton.gd`: timers no longer resume on a freed menu (a crash fix). take
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
| `PlayerController.gd` | COMBAT FEEDBACK, ANIMATIONS, WADING |
| `MinionController.gd` | COMBAT FEEDBACK, ANIMATIONS |
| `GearLayers.gd` | ANIMATIONS, WADING |
| `ItemDatabase.gd` | STORAGE, WADING |
| `DollStage.gd` | STORAGE, WADING |
| `NetworkSync.gd` | COMBAT FEEDBACK, FIXES |
| `ConfigFileHandler.gd`, `SettingsMenu.tscn` | COMBAT FEEDBACK, SETTINGS |
| `README.md`, `docs/ART_TODO.md` | almost every chunk; merge the text at the end |

## When everything is in
Silvery starts a fresh branch from `main` and stops using `silvery/art-and-gear`.
Otherwise a later full merge brings back the same 150+ conflicts.
