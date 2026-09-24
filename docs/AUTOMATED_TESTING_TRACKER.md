# Automated Testing Tracker

Ranked from three independent agent reviews (2026-09-24), each read-only and
checked against the files, nothing run. Background, terms and sources live in
the sister file `AUTOMATED_TESTING_RESEARCH.md`. Mark items here as they land
and update the date.

Last updated: 2026-09-24. GUT 9.7.1 is installed (`addons/gut/`), `test/` exists
with one example test file (7 tests, all pass, run 2026-09-24 on Godot 4.7.2 mono) and `test/README.md` as the
how-to. No `.github/` folder yet.

Status key: [ ] todo, [x] done, [~] built / needs verification, [-] on hold

Tier meaning (same as `TODO.md`):
- **S** = do first, everything else stands on it.
- **A** = high value, do soon.
- **B** = worth it, after A.
- **C** = parked, waiting on a prerequisite.
- **Skip** = not worth it for RogueNet now.

Sizes: small (an hour or two), medium (a session), large (several sessions).

The three reviewer lenses:
- **Risk**: which tests catch the bugs this repo actually has (from git history, `TODO.md`, `BodySweep.gd`).
- **Cost**: setup risk, maintenance, CI minutes, infrastructure.
- **Team**: can a beginner team understand, write and keep it; does it teach good habits.

The final tier is the majority vote. Where a lens disagreed, the reason is
noted. Items marked ✚ were proposed by a reviewer rather than taken from the
original list.

---

## Decisions needed before starting
- [x] **Pick a framework: GUT** (Orea, 2026-09-24). Original note: GUT (Risk + Team: pure GDScript, simplest for
  beginners) or gdUnit4 (Cost: 4.7 support on the main branch, an official
  GitHub Action with JUnit reports, scene runner and C# ready). Choose one,
  never both. If GUT, take it from the `godot_4_7` branch (GUT 9.7.1).
- [x] **Where tests live: `test/`** (Orea said yes, 2026-09-24). A `test/` folder at the repo root is the usual
  convention. Creating it needs Orea's go-ahead.
- [ ] **Script changes need a per-change yes.** Seedable RNG, the test-mode
  guard and similar fixes touch `scripts/` or `singletons/`.
- [ ] **CI: report or block?** Team says report only, because only Orea
  commits and there are no pull requests. Use a Linux runner.

---

## S tier: foundation (do first)

- [~] **Install the chosen framework** (done 2026-09-24: `addons/gut/`, `.gutconfig.json`; plugin not enabled in project.godot, the command line does not need it) (small, owner: tech lead). One vendored
  `addons/` folder plus a config file. Votes: Risk S · Cost S · Team S.
- [~] ✚ **How-to page plus one fully commented example test** (`test/README.md`, `test/unit/test_action_shapes.gd`, 7 tests, pass) (small, owner:
  tech lead). A one-page "how to write and run a test" guide and an example
  to copy. Team: "without this, a mostly beginner team won't adopt tests."
  Good first example: the `Vector2i(pos / tile_size)` vs `floori()`
  negative-origin bug noted in `TODO.md`. Votes: Team S (proposed).
- [ ] **Import + headless boot smoke** (small, owner: tech lead). Merges the
  original list item with Cost's ✚ import check.
  - `godot --headless --import` must finish with no "Unrecognized UID"
    errors (three autoloads use `uid://`, and `.godot/` is gitignored).
  - The project must boot headless, all 5 autoloads must load, and no script
    may fail to parse.
  - `SteamManager` already survives Steam being absent.
  - This also fills the empty `Test command:` line in `CLAUDE.md`.
  - Votes: Risk S · Cost S · Team S.
- [ ] ✚ **`res://` reference resolver** (small, owner: any programmer). Scan
  every JSON, `.tscn` and `.gd` for `res://` paths, plus sprite and texture
  paths in `game/**` and `resources/gfx/**` JSON, and fail on missing
  files. Aimed at the repeated rename-bug commits (`c090cca`, `f840ae3`,
  `c53457d`, `1a2d75b`, `1a7d763`); about 199 `res://` strings are in `game/`
  JSON alone. Votes: Risk S (proposed) · Team A (proposed as "asset
  reference check").
- [ ] **Room JSON validation** (small–medium, owner: any programmer; results
  readable by non-programmers). Every room in `game/rooms/<biome>/` (about
  960 files, 13 biomes plus `fallback/`) loads and passes
  `Connector.validate`. Required fields (`spawn_cells`, `base_floor`,
  `favored_minion`) survive DungeonMaker re-saves. Failure messages name the
  file and field in plain English. Reuse the DungeonMaker "Validate All"
  logic. Votes: Risk S · Cost A · Team S.
- [ ] **Dungeon generation invariants, seeds × every biome** (medium, owner:
  tech lead, then any programmer). For about 50 seeds × every biome from
  `list_biomes()`, check:
  - `generate_with_retry` returns rooms;
  - no rooms overlap and every connector matches;
  - exactly one boss room, plus a treasure room where the biome has one;
  - room count is within `defines.room_count`;
  - retries **never** silently fall back to a broken attempt (today that
    is only a warning).

  `generate()` is static and seeded (`DungeonAssembler.gd:262`). Keep it
  fast. Votes: Risk S · Cost A · Team S.

## A tier: high value, do soon

- [ ] **Other content validation** (small–medium, owner: any programmer).
  Merges in Team's ✚ biome `defines.json` checks.
  - Enemy attack types exist in `game/damage_types.json` (today it is
    "only referenced in docs").
  - Enemy resistance keys are valid; item slots are valid.
  - Every biome's `defines.json` names real enemies in `monsters` and a real
    `default_door`, and has at least one entrance and one boss room.
  - Also covers the emblems, tile registry and manifests.
  - Votes: Risk A · Cost A · Team A.
- [ ] **Make MinionSpawning / TileDestruction randomness seedable** (small,
  owner: tech lead, **script change, needs a yes**). Pass a seeded RNG in
  instead of calling `rng.randomize()` (`MinionSpawning.gd:35-36`, `:93-94`)
  or the global `randi()` (`TileDestruction.gd:105`, `:126`). This unlocks
  reproducible soak runs and destruction tests, and teaches "pass the RNG
  in." Votes: Risk A · Cost B (only needed once those tests exist) · Team A.
- [ ] **Pure-logic unit tests** (small each, owner: any programmer; the best
  first tests for beginners). `EntityStats.take_damage` and health clamping,
  `PlayerInventory` place/move/swap in the slots, bag and storage, and
  `ItemDatabase` lookups. Build fresh instances instead of using the
  autoload singleton, so state doesn't leak between tests. Votes: Risk B
  (damage and stats are barely wired yet) · Cost A · Team A.
- [ ] **Scene smoke: instance every `.tscn` and free it** (small, owner: any
  programmer). About 20 scenes. Catches missing ExtResources after renames.
  Skip scenes that open Steam lobbies. Votes: Risk A · Cost A · Team A.
- [ ] **Regression-test habit** (small, owner: everyone). Every fixed bug gets
  a test named after it, and the test must fail before the fix. Uses the
  S-tier how-to page. Votes: Risk A · Cost A · Team A.
- [ ] **GitHub Actions CI on every push** (small–medium, owner: tech lead).
  - Linux runner: the repo is private, so the free plan gives 2,000
    min/month, and Windows minutes cost 1.67×.
  - The `linux64` GodotSteam binaries are already in the repo.
  - Use the standard Godot build with `use-dotnet: false`, since there is
    no C# yet.
  - Steps: import, then run the tests; cache the Godot install and `.godot/`.
  - Report, don't block.
  - Votes: Risk A · Cost S · Team A.
- [ ] ✚ **Room rotation round-trip** (small, owner: any programmer). Four
  quarter turns of `rotate_room` give back the original room, and connectors,
  doors and `spawn_cells` survive. Rotated boss rooms (Throne, Pit) are still
  unplaytested. Votes: Risk A (proposed).
- [ ] ✚ **Full-map reachability** (medium, owner: tech lead). After painting,
  a flood fill from the entrance reaches the boss and treasure rooms, with
  doors and barriers accounted for. This guards against a connector gap
  silently sealing a room (see `63cf7fb`). Votes: Risk A (proposed).
- [ ] ✚ **TileDestruction rules** (small, owner: tech lead; needs seedable
  RNG). `barrier_*` and door cells never break, void exposed by destruction
  gets covered, and applying the host's change list on a second map gives
  the same result. Votes: Risk A (proposed).
- [ ] ✚ **Content report button for non-programmers** (small–medium, owner:
  any programmer). A DungeonMaker or menu button that runs the content
  validators and shows plain-English results, so Silvery Foxy and HamsterMan
  get feedback without a terminal. Votes: Team A (proposed).
- [ ] ✚ **Test-mode guard on autoload side effects** (small, owner: tech lead,
  **script change**). A command-line flag so test runs don't overwrite the
  developer's `user://settings.ini` or change the window mode
  (`ConfigFileHandler.gd:19, 37, 41, 45`). Votes: Cost A (proposed).
- [ ] ✚ **Pin the Godot version in one place** (small, owner: tech lead). The
  CI install and the framework branch must move together, because 4.7 → 4.8
  breaks both. Votes: Cost A (proposed).

## B tier: worth it, after A

- [ ] **Golden-seed snapshot, on a frozen fixture set only** (small, owner:
  tech lead; after the invariants). About 5 test rooms, a fixed seed and an
  exact expected placement list. **Not** on the live room folders, which
  change daily; beginners would learn to "just re-baseline". Re-baseline on
  every Godot upgrade (the RNG algorithm isn't guaranteed). Votes: Risk B ·
  Cost B · Team B.
- [ ] ✚ **Generation determinism across processes** (small, owner: tech
  lead). The same seed gives identical placements in two fresh runs. This
  protects the netcode, because every peer builds its own map from
  `mission_seed` (`NetworkSync.gd:416, 429-434`). Lower risk than it sounds:
  file and room order are already sorted (`DungeonAssembler.gd:95`).
  Votes: Risk B (proposed).
- [ ] **GridMover movement and collision** (medium, owner: tech lead). A
  fixture map: no stepping into walls, void or floorless cells, 2×2
  footprints respected, walls created by destruction block movement. This is
  the bodies-in-walls bug class. Votes: Risk **A** (targets a known bug
  class) · Cost B · Team B (tile map fixtures are too tangled for
  beginners).
- [ ] ✚ **Pathfinding / LineOfSight / FlowField on ASCII grids** (small–medium,
  owner: any programmer). 5×5 string maps: "path goes around this wall",
  "sight blocked here". Easy to read, and they teach grid thinking. The
  `scripts/cells/*` helpers are mostly static. Votes: Team B (proposed).
- [ ] **Host-authority logic with `OfflineMultiplayerPeer` or no peer**
  (medium, owner: tech lead). The host spawns, damage applies once, doors
  change state. `MinionSpawning.gd:33` already acts as host when there is no
  peer. Only the host side can be tested. Votes: Risk B · Cost B · Team B.
- [~] **Headless soak run with BodySweep-style asserts** (first version 2026-09-24: `test/sim/dev_sim.gd`, `run_sim.bat`; runs the development biome per cell, no game-code changes needed; it does not use the seedable RNG yet, dungeon layout is fixed by the entrance-role hub) (medium, owner: tech
  lead; needs the seedable RNG, and `BodySweep.gd` committed, since it is
  untracked today). Run a dungeon with enemies for N minutes at
  `--fixed-fps`, and **fail** instead of logging. Run it nightly or by hand,
  not on every push. Votes: Risk **A** (turns existing debug work into an
  automatic detector) · Cost B · Team B.
- [ ] **Export build smoke** (medium, owner: tech lead; needs a committed
  `export_presets.cfg`, which is gitignored today). Checks that JSON loading
  and `DirAccess` work inside an exported `.pck`, which `TODO.md` already
  flags as untested. Votes: Risk **A** · Cost C (preset, export templates,
  about 1 GB of downloads) · Team B.
- [~] **Local `run_tests` script** (`run_tests.bat` written; uses the gitignored Godot copy in `.godot-local/`) (small, owner: tech lead). A `.bat` or
  `.sh` wrapper, **not** a blocking git hook: hooks are fragile on Windows
  and only Orea commits. Votes: Risk B · Cost B · Team B.
- [ ] ✚ **Orphan/leak check in the scene smoke** (small, owner: any
  programmer). `print_orphan_nodes()`, or gdUnit4's orphan detection.
  Votes: Cost B (proposed).

## C tier: parked, waiting on a prerequisite

- [-] **Save/load round-trip** (small). Waits for the character save (A tier
  in `TODO.md`). **Promote to A the day the save is written**: it is a
  textbook first test and guards the difficulty-tier field. Votes: Risk C ·
  Cost C · Team C.
- [-] **UI and input-simulation tests** (medium–large). Wait until the menus
  stop changing (see the lobby UI backlog). Votes: Risk C · Cost C · Team C.
- [-] **JUnit/HTML reports and PR status checks** (small). The team doesn't
  use pull requests. It is free if gdUnit4's action is used. Votes: Risk C ·
  Cost **A** (built into gdunit4-action) · Team C.
- [-] **Performance benchmark (many-rat pursuit pathfinding)** (medium).
  Parked alongside enemy flanking; timing on shared CI machines is noisy,
  so measure locally first. Votes: Risk B · Cost C · Team C.

## Skip for now

- [-] **Real two-instance multiplayer test** (large). There is no ENet code,
  and Steam can't run on CI. It would need test-only netcode while the
  netcode approach is still undecided (`CLAUDE.md`). Revisit after that
  decision. Votes: Risk Skip · Cost C · Team Skip.
- [-] **C# tests via gdUnit4Net** (medium). There is no C# code to test.
  Revisit when Orea starts writing C#; it's a good personal learning project
  then. Votes: Risk Skip · Cost Skip · Team C.
- [-] **Screenshot / visual comparison** (large). Art changes daily, and
  `--headless` renders nothing without xvfb and software OpenGL. Art is
  already reviewed by hand. Votes: Risk Skip · Cost Skip · Team Skip.

---

## Suggested order
Where all three reviewers' orders agree:

1. Framework and how-to page
2. Import + boot smoke
3. Reference resolver and room validation
4. Generation invariants
5. Scene smoke and pure-logic tests
6. Regression habit from here on
7. Seedable RNG, then TileDestruction rules
8. CI (reporting only)
9. Everything in B

Steps 1–4 are roughly two sessions of work and cover the bug classes the
git history shows most often.

## Where the reviewers disagreed most
- **Framework:** GUT 2, gdUnit4 1. See "Decisions needed".
- **CI timing:** Cost wants it in S, because it is cheap. Risk and Team want
  it in A, because local runs come first and CI only reports.
- **GridMover, soak and export tests:** Risk ranks them higher, because
  they target real, recurring bugs. Cost and Team rank them lower, because
  fixtures and export setup are fiddly. The majority (B) stands; promote any
  of them if the bug it targets happens again.
