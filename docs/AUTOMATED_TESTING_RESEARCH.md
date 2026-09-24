# Automated Testing for RogueNet — Research Notes

Written 2026-09-24. Nothing here has been built yet. Sister file:
`AUTOMATED_TESTING_TRACKER.md` (the ranked to-do list and what is done).

## Why this document exists
Orea asked whether RogueNet could use automated testing to stop bugs from
coming back, the way Factorio does. This document collects the research: what
Factorio actually does, what Godot 4.7 offers, which parts fit RogueNet's code
as it is today, and what is hard or impossible. It is meant as a reference
for later, so it is long on purpose.

Sourcing rule, the same as `NPC_SIMULATION_RESEARCH.md`: claims from a page
that was actually fetched cite its URL (full list in section 14). Claims about
RogueNet cite a file and line, checked against the files on 2026-09-24 without
running the game. Anything that is my own judgement is marked **(reasoning)**.

---

## 1. The problem, in one paragraph
Programming bugs tend to come back. Someone fixes a bug, and weeks later a
different change reintroduces it, often in a file the fixer never touched.
RogueNet's git history already shows this happening. Several commits only fix
renamed or broken asset paths (`c090cca` Tortch→Torch, `f840ae3`, `c53457d`,
`1a2d75b`, `1a7d763`). There is also a continuing effort against creatures
ending up inside walls, which is why `scripts/debug/BodySweep.gd` exists.
Automated tests are small programs that check the game still behaves, and
they can run without a human after every change. Tests don't stop bugs from
being *written*. They stop the *same* bug from being *shipped twice*.

---

## 2. What Factorio actually does
Wube (Factorio's developer) described their setup in Friday Facts #60 and #62,
and developer Rseding91 added detail in a 2020 technical AMA.

### 2.1 Three kinds of test (FFF #60)
- **Unit tests** check one internal function in isolation, using stand-in
  "mock" objects. They are "really fast to run" because they "don't load any
  graphics nor any prototypes."
- **Integration tests** run the whole game with the base content. A typical
  test "creates a small map, places couple of objects on the map, runs
  updates and then verifies that expected conditions are met". The example
  they give is a belt layout where items should end up blocked.
- **Black-box tests** treat the finished game program as a sealed box and
  drive it from outside. They do this for multiplayer edge cases and GUI
  interaction, coordinating **several game instances at once**.

### 2.2 The determinism trick (FFF #60, AMA)
Factorio's whole simulation is deterministic: the same inputs always give the
same result, on every machine. Integration tests save a **CRC checksum** (a
short fingerprint of the game state) at key moments and compare it with a
saved value. As FFF #60 puts it, "if a bug is introduced that would break
determinism … we will find out just by running the test suite." Rseding91:
*"A given test makes an instance of the game and then we feed commands into
it and check to see what it did. The entire simulation is deterministic so
when we say 'update once' it updates once and then sits there doing nothing
until a future time where we tell it to do something."*

### 2.3 The build server (FFF #62)
Every build runs the suites "in all the systems and possible configurations".
The server tracks "the changes that broke the tests and email[s] the people
to fix it automatically", and release packaging is automated as well.

### 2.4 The habit
FFF #60 says their testing started from a "ridiculous" state (almost none),
and they switched to "writing tests for any new functionality we add to the
game." They say plainly that tests won't eliminate bugs but will "help us
avoid same bugs in the future." **This habit matters more than any tool.**

### 2.5 What Factorio has that RogueNet does not **(reasoning)**
- A custom C++ engine built for determinism from day one. RogueNet uses
  Godot's floating-point physics and real-time frame timing.
- A lockstep multiplayer model, where every client runs the same simulation,
  so a checksum mismatch *means* a bug. RogueNet uses a host-authoritative
  listen server where clients receive results over the network, so clients
  are allowed to differ slightly.
- A full-time team with its own build servers.

So the Factorio *ideas* carry over. The *exact* technique ("record a whole
game and compare checksums on every OS") does not, except for dungeon
generation (see section 6).

---

## 3. Vocabulary (so the tracker makes sense)
| Term | Meaning |
|---|---|
| **Test** | A function that sets something up, does something, and **asserts** (checks) the result. It passes or fails. |
| **Assert** | One check, e.g. `assert_eq(hp, 0)`. A failing assert fails the test and prints what it expected and what it got. |
| **Unit test** | Tests one function or class alone. Fast: milliseconds. |
| **Integration test** | Tests several systems together, e.g. load rooms → generate → paint a map → check it. |
| **Smoke test** | The cheapest check that something doesn't instantly break, e.g. "every scene loads without errors". |
| **Invariant** | A rule that must *always* hold, e.g. "no body stands in a wall" or "no two rooms overlap". Great for procedural generation because you don't need to know the exact output, only the rules. |
| **Golden / snapshot test** | Saves an exact known-good output (the "golden" copy) and fails if the output changes at all. Precise but brittle. |
| **Regression test** | A test written *because of* a bug, so that bug can't return. Named after the bug. |
| **Fuzz / soak test** | Throw lots of random input at the game (fuzz) or let it run for a long time (soak) while invariants are checked. |
| **Fixture** | The prepared setup a test runs on, e.g. a tiny 5×5 hand-made map. |
| **Double / mock / stub / spy** | A stand-in object that replaces a real dependency (e.g. a fake network peer) so one piece can be tested alone. |
| **Headless** | Running Godot without a window or sound, which is what servers and test machines do. |
| **CI (continuous integration)** | A server (here GitHub Actions) that runs the tests automatically on every push. |
| **Flaky test** | A test that sometimes passes and sometimes fails with no code change. Poison for trust; fix or delete. |
| **Red → green** | Write the test first, watch it fail (red), fix the code, watch it pass (green). Proves the test actually tests the bug. |

---

## 4. Godot's built-in pieces
Godot has no test framework of its own, but its command line provides
everything a framework needs. Quotes are from the official command line docs:

| Flag | What it does (quoted) | Why tests need it |
|---|---|---|
| `--headless` | "Enable headless mode (`--display-driver headless --audio-driver Dummy`). Useful for servers and with `--script`." | No window on a CI machine. |
| `--script` / `-s` | "Run a script." | This is how GUT's and gdUnit4's command-line runners start. |
| `--check-only` | "Only parse for errors and quit (use with `--script`)." | Cheapest possible "does this script even compile" check. |
| `--import` | "Starts the editor, waits for any resources to be imported, and then quits." | **Required on a fresh checkout**: RogueNet's `.gitignore` ignores `.godot/`, so a CI machine has no import cache until this runs. **(reasoning)** |
| `--build-solutions` | "Build the scripting solutions (e.g. for C# projects)." | Only needed once C# code exists (there is no `.csproj` today). |
| `--quit-after` | "Quit after the given number of iterations." | Timed smoke or soak runs. |
| `--fixed-fps` | "Force a fixed number of frames per second. This setting disables real-time synchronization." | Makes frame-counted tests less timing-dependent: each frame gets the same delta regardless of machine speed. |
| `--path` | "Path to a project." | Run from any folder. |
| `-d` / `--debug` | "Debug (local stdout debugger)." | Better error output. |
| `--log-file` | "Write output/error log to the specified path." | Keep logs as CI artifacts. |

**Exit codes are the key.** A test runner that exits with 0 on success and
non-zero on failure is all CI needs to mark a commit green or red. GUT
documents exactly this: 0 when everything passes, 1 when anything fails.

---

## 5. Test frameworks for Godot 4.7

### 5.1 The candidates
| | **GUT** | **gdUnit4** | **gdUnit4Net** | **GoDotTest + GodotTestDriver** (Chickensoft) |
|---|---|---|---|---|
| Language | GDScript only | GDScript (C# via gdUnit4Net) | C# | C# |
| Godot 4.7 | Yes: GUT **9.7.1** on the `godot_4_7` branch (the version table in the repo) | v6.x+ requires Godot ≥ 4.5 | Yes (separate NuGet package) | Yes |
| Editor panel | Yes | Yes (test inspector, right-click to run) | Via VS/Rider test adapter | IDE |
| Doubles / mocks | Full and partial doubles, stubs, spies | Mocks, spies | Yes | Via other libs |
| Parameterized tests | Yes | Yes, plus **fuzzers** (generated random inputs) | Yes | — |
| Scene / input simulation | Input sender utility | **Scene runner**: mouse, keyboard, touch, input actions, "wait for signal" | Scene runner | GodotTestDriver: simulated input, node drivers |
| CLI / CI | `gut_cmdln.gd`, `.gutconfig.json`, JUnit XML | Command-line tool, HTML + JUnit reports, **`gdunit4-action`** on the GitHub Marketplace | `dotnet test` | Command line + code coverage |
| Learning curve | Lowest. Most tutorials, reads like normal GDScript | Moderate | Needs C# plus .NET tooling | Needs C# |

Typical GUT headless command (from GUT's docs):
`godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit`

### 5.2 Recommendation **(reasoning; the pick is Orea's)**
Two of the three reviewers independently picked **GUT**:
- It is pure GDScript, which the whole team writes.
- It has the gentlest learning curve and the most beginner tutorials.
- Nothing RogueNet needs today requires C# or a scene runner (there is no
  C# code yet).

The third reviewer (cost/infrastructure) picked **gdUnit4**, for three
reasons:
- Its *main* branch (v6.2.1 at the time of review) supports Godot 4.5 to
  4.7.1, while GUT's 4.7 support lives on a side branch (`godot_4_7`).
- Its official GitHub Action installs Godot, runs the tests and publishes a
  JUnit report in one step.
- It already covers the scene runner and C# if those are ever needed.

If the team goes with GUT, vendor it from the `godot_4_7` branch, not the
Asset Library default.

Pick **gdUnit4** if Orea wants C# tests soon (for their own C#
learning) or UI input simulation. The important rule is to **choose one**,
because running two frameworks side by side doubles what the team has to
learn. Chickensoft's tools only make sense if a large part of the game moves
to C#.

---

## 6. Determinism: what can be checksummed and what can't

### 6.1 Seeded randomness *is* reproducible (within one Godot version)
Godot's `RandomNumberGenerator` currently uses **PCG32**. A given seed gives a
reproducible sequence. **However**, the official docs say "The underlying
algorithm is an implementation detail and should not be depended upon."
Consequence: an exact "seed 12345 always gives this layout" test can break
on a **Godot upgrade** even when the game code didn't change. That is fine,
but it has to be expected: re-baseline the golden values as part of each
engine upgrade, and note it in the commit.

### 6.2 Floating-point maths and physics are *not* reproducible
Floating-point results "can be slightly different on different CPUs,
operating systems or versions", and Godot's built-in physics "is also not
deterministic" (Snopek Games, who wrote the deterministic SG Physics 2D add-on
because of this). Real-time combat therefore can't be recorded and replayed
to an identical checksum across machines.

### 6.3 What this means for RogueNet **(reasoning)**
- **Dungeon generation already depends on determinism.** The host picks
  `mission_seed := randi()` (`NetworkSync.gd:416`) and sends only the seed and
  biome to every member (`receive_start_mission`, `NetworkSync.gd:429-434`).
  **Each peer then builds the dungeon locally.** If generation ever gives
  different results on two machines, host and client get different maps and
  multiplayer silently breaks. So a determinism test is protecting *real
  netcode*, not just tidiness.
- Generation is written well for this. `_read_folder` sorts file names
  before loading (`DungeonAssembler.gd:95`), and `generate` sorts room ids
  before iterating, so filesystem order can't change the result. It uses its
  own seeded RNG (`DungeonAssembler.gd:262-264`) and integer grid
  coordinates. That makes it the one part of RogueNet where a Factorio-style
  checksum really works.
- **Enemy spawning and tile destruction are not reproducible today.**
  `MinionSpawning.gd:35-36` and `:93-94` call `rng.randomize()` (a fresh random
  seed every time), and `TileDestruction.gd:105` and `:126` use the global
  `randi()`. A test can check *rules* about them ("no enemy spawns on a lit
  tile") but can't pin an exact outcome, and a failure found by a soak run
  can't be replayed. The fix is small and a good lesson: **pass a seeded RNG
  in instead of creating a random one inside.** Both reviewers who looked at
  it ranked this A tier. It is a script change, so it needs Orea's go-ahead.
- Movement is grid-based (`GridMover.gd`), which helps: grid cells are
  integers. Anything involving `delta`, animation timing or physics bodies
  should be tested by **rules**, not exact values.

### 6.4 Rules vs exact values, a rule of thumb **(reasoning)**
| Test by exact value (golden) | Test by rule (invariant) |
|---|---|
| Output of `generate()` for a frozen fixture set of rooms | Generated maps across hundreds of seeds and every biome |
| A pure function with integer maths (`LineOfSight`, `Pathfinding` on a 5×5 grid) | Anything touched by `delta`, physics or network timing |
| Room rotation: four quarter turns gives back the original | Enemy behaviour, combat, soak runs |

The team-fit reviewer's warning: golden tests over the *live* room folders
break every time someone edits a room (there are ~960 room JSONs and they
change almost daily), and beginners learn to "just re-baseline" without
looking. **Keep golden tests on a small frozen fixture set** and use
invariants for the live content.

---

## 7. RogueNet today: what's testable and what isn't
Checked 2026-09-24. There are no tests, no `.github/` folder, no test
add-on in `addons/` (only `godotsteam`), and no `.csproj`.

### 7.1 Already easy to test (pure static helpers, no scene needed)
| File | Shape | Test idea |
|---|---|---|
| `scripts/dungeon/DungeonAssembler.gd` | `RefCounted`, static: `generate`, `generate_with_retry`, `rotate_room`, `with_rotations`, `load_rooms`, `load_defines`, `pick_biome`, `collect_*` | Invariants across seeds and biomes; rotation round-trip; golden on fixtures |
| `scripts/cells/Pathfinding.gd`, `FlowField.gd`, `LineOfSight.gd`, `LightFlood.gd`, `ActionShapes.gd`, `SurroundSectors.gd`, `RoomGraph.gd` | `RefCounted`, almost all static | Tiny hand-drawn ASCII grids: "path goes around this wall", "sight blocked here" |
| `scripts/JsonOnloading.gd` | static `load_dict` | Loads every content JSON; malformed files fail |
| `Connector.validate` (already called for every room in `_read_folder`) | returns a list of problems | Room validation already half exists: turn "problems printed" into "test fails" |

### 7.2 Testable with a little setup
- `EntityStats.gd` (a `Node`: add to a test scene first): `take_damage`,
  health clamping.
- `PlayerInventory.gd` (autoload): place / move / swap rules in the
  9 slots, the 21-cell bag and 48-cell storage.
- Every `.tscn`: load, instance, free, no errors (about 19 scenes).
- `MinionSpawning.gd:33` already "fails open (acts as host) when no peer is
  assigned", so host-side spawning can be tested with no network at all.

### 7.3 Hard to test as written
- `MinionSpawning.gd` and `TileDestruction.gd` randomness (section 6.3).
- `GridMover.gd` collision needs a tile map fixture and the shared occupancy
  index. It is high value (the bodies-in-walls bug class) but fiddly.
- Anything in the Steam lobby layer (it came from a template the team
  doesn't know well; see `CLAUDE.md`).
- `generate_with_retry` falls back to "attempt 0 anyway" when every retry
  fails, so a broken biome produces a *warning*, not an error. A test is the
  natural place to turn that into a hard failure.

### 7.4 Autoload side effects when tests boot **(reasoning)**
Godot starts every autoload before any test runs: `SteamManager`,
`ConfigFileHandler`, `MusicManager`, `NetworkSync`, `PlayerInventory`.
`SteamManager.gd` already handles Steam being absent ("only singleplayer will
work"), so a machine without Steam boots. The remaining risks: the GodotSteam
GDExtension library has to exist for the CI machine's OS, `MusicManager` may
try to play audio (the Dummy audio driver absorbs this), and
`ConfigFileHandler` may write a settings file to `user://`.

### 7.5 Existing runtime checks that can become tests
`BodySweep.gd` already checks an invariant twice a second: no creature
overlaps a wall, void or floorless cell. It writes a `DebugLog` line with the
tile and how the body last moved. A headless soak test could reuse the same
check but **fail the run** instead of logging, which turns existing debug work
into an automatic detector. The `DungeonMaker` "Validate All" logic is
similar: it is room validation that only runs when someone clicks it.

---

## 8. Catalogue: kinds of test that fit RogueNet
Each has a matching row in the tracker. These are ordered roughly from
cheapest to most expensive.

1. **Parse / boot smoke.** Run headless with `--check-only` or a quick
   boot-and-quit. Catches script syntax errors and broken autoloads, the
   failure that confuses beginners most.
2. **Reference resolver.** Scan every JSON, `.tscn` and `.gd` for `res://`
   strings and fail on paths that don't exist. Aimed squarely at the
   rename-bug commits; about 199 `res://` strings sit in `game/` JSON alone
   (bug-risk reviewer's count).
3. **Content validation.** Every room loads and passes
   `Connector.validate`. Every biome's `defines.json` names real enemies and
   door types and has at least one entrance and one boss room. Enemy attack
   types exist in `game/damage_types.json`. Item slots are valid.
   **Failure messages must name the file and field in plain English**, so
   Silvery Foxy and HamsterMan can fix their own content.
4. **Generation invariants.** For N seeds × all 13 biomes: `generate`
   returns rooms, nothing overlaps, every connector matches, the boss room
   exists, room count is within `defines.room_count`, the boss room can be
   reached from the entrance (flood fill), and retries never fall back to a
   broken attempt.
5. **Generation determinism.** The same seed gives identical placements when
   run twice in a row, and (in CI) in a fresh process. This protects the
   "every peer builds its own map" netcode in section 6.3.
6. **Golden snapshot on fixtures.** A frozen set of about 5 test rooms, a
   fixed seed and an exact expected placement list. Re-baseline on engine
   upgrades.
7. **Pure-logic units.** Line of sight, pathfinding and flow fields on ASCII
   grids; `rotate_room` round-trip; `EntityStats` damage; `PlayerInventory`
   rules.
8. **Scene smoke.** Instance every `.tscn` and free it.
9. **Movement / collision.** `GridMover` on a small fixture map: can't step
   into walls or void, 2×2 footprints respected, walls created by
   `destroy_tiles` block movement.
10. **Host-authority logic.** With `OfflineMultiplayerPeer` or no peer: the
    host spawns, damage applies once, doors change state.
11. **Soak / fuzz.** Headless dungeon with enemies for N minutes (use
    `--fixed-fps`), BodySweep-style asserts, seeded so failures replay.
12. **Export smoke.** Export a Windows build and run it once. Checks JSON
    loading inside a `.pck` (`DirAccess` on `res://` in an export is a known
    source of surprises), which `TODO.md` already flags as untested.
13. **Performance benchmark.** For example, a many-rat room must finish
    pursuit pathfinding within a time budget. Noisy on shared machines, so
    run it locally rather than as a hard CI gate.
14. **UI input simulation.** Open the inventory with I or Tab, click
    through menus. Only worth it once the UI stops changing.
15. **Visual / screenshot comparison.** Pixel-compare renders. Poor fit for
    RogueNet: art changes daily. `--headless` also uses a dummy renderer, so
    screenshots come out empty without xvfb and software OpenGL.

---

## 9. Testing multiplayer: a ladder **(reasoning, grounded in the files)**
From cheapest to most expensive:
1. **No network at all.** Test the host-side code path directly, relying on
   `MinionSpawning`'s fail-open behaviour. Most host-authority *logic* can be
   checked here.
2. **`OfflineMultiplayerPeer`.** The same peer singleplayer already uses, so
   `is_server()` is true and RPC-shaped code runs.
3. **Determinism tests** (section 8 item 5). They cover the one thing both
   peers must agree on without talking: the map.
4. **Two instances on one machine.** This is Factorio's "black box" style
   (FFF #60). RogueNet has **no ENet code**; Steam's peer needs a logged-in
   Steam client and has no headless mode, so CI can't do this over Steam.
   It would need a test-only ENet path, which pulls in a netcode choice that
   `CLAUDE.md` says is still open. All three reviewers put this at Skip or C
   for now.
5. **Manual two-player playtest.** Remains the real multiplayer check for
   now. A written checklist (like the one in `TODO.md`'s S tier) is itself a
   form of testing.

---

## 10. Running tests automatically (CI)

### 10.1 Shape of a GitHub Actions job **(reasoning)**
Every push to `Choo-Choo-Oreo/RogueNet` would:
1. check out the repo;
2. install Godot 4.7 .NET (`chickensoft-games/setup-godot` supports
   Windows, macOS and Linux runners and has a `use-dotnet` option, on by
   default);
3. run `godot --headless --import` to build the `.godot/` cache;
4. run the test runner headless; the job goes red on a non-zero exit code;
5. save the log and JUnit report as downloadable artifacts.

gdUnit4 has a ready-made `gdunit4-action`. GUT is usually run with a few
lines of shell.

### 10.2 Gotchas specific to RogueNet
- `.godot/` is gitignored and three autoloads are referenced by `uid://`
  (`SteamManager`, `MusicManager`, `NetworkSync` in `project.godot`), so the
  import step is mandatory. Without it, uids and `class_name`s don't resolve.
  A clean import with no "Unrecognized UID" errors is a useful check in its
  own right.
- **GodotSteam on Linux is fine.** `addons/godotsteam/linux64/` holds the
  debug and release `.so` files plus `libsteam_api.so`, and
  `godotsteam.gdextension` maps to them. On a runner without Steam,
  `steamInit` fails quietly and `online` stays false. Any new code that calls
  `Steam.*` must stay behind that flag, as `_process` already does.
- **Runner cost.** The repo is private, so GitHub Free gives 2,000 Linux
  minutes a month. Windows minutes cost 1.67× and macOS about 10×
  (GitHub billing docs). **Use a Linux runner.**
- **.NET not needed in CI yet.** There are no `.cs`, `.csproj` or `.sln`
  files, so CI can use the standard Godot binary (`use-dotnet: false`) and
  skip the dotnet SDK and build step. Switch when C# code appears.
- **Settings file.** `ConfigFileHandler.gd` saves `user://settings.ini`
  (lines 19, 41, 45) and sets the window mode (line 37). That's harmless on
  CI, but a local test run could overwrite the developer's own settings. A
  small "test mode" guard (command-line flag) on autoload side effects is
  worth adding.
- **Singleton state leaks between tests.** `PlayerInventory` and
  `NetworkSync` are autoloads: whatever one test puts into them is still
  there for the next. Tests should build fresh instances or reset state.
- **Pin the Godot version in one place.** A 4.7 → 4.8 upgrade breaks both
  the framework branch and the CI install at once.
- **Cache** the Godot download and `.godot/` between CI runs to save minutes.
- `export_presets.cfg` is gitignored, so export smoke tests need a shared
  preset committed first (`TODO.md` S tier already wants this).
- Team fit: **report, don't block.** Only Orea commits, and the team doesn't
  use pull requests, so a red CI run should be information, not a wall
  (team-fit reviewer).

### 10.3 Local first
Before any CI exists, the same command run by hand (or from a small
`run_tests` script) gives most of the value. CI's job is making sure nobody
has to remember to run it.

---

## 11. The habit that makes it work
From Factorio (section 2.4) and the team-fit review:
- **Every fixed bug gets a regression test.** Name it after the bug, e.g.
  `test_negative_origin_uses_floori`. A ready-made first example is in
  `TODO.md`: the `Vector2i(pos / tile_size)` vs `floori()` negative-origin bug.
- **Red first.** Write the test, check it fails on the buggy code, then fix.
  A test that never failed may not be testing anything.
- **Fast tests run always; slow ones run on request.** Unit, content and
  generation tests every time; soak and benchmark tests nightly or by hand.
- **A flaky test gets fixed or deleted the same day.** Otherwise people
  learn to ignore red.
- **Tests are learning material.** A beginner can read a well-named test and
  learn what a function is *supposed* to do without reading its body. A
  commented example test plus a one-page "how to write and run a test" guide
  is what turns this into a learning tool (team-fit reviewer's top missing
  item).
- **Non-programmers need a button, not a terminal.** A DungeonMaker or menu
  button that runs the content validators and shows plain-English results
  helps artists and designers without teaching them the test runner.

---

## 12. What tests will *not* catch
- Whether the game is **fun**, looks right, or feels responsive. Playtests
  stay essential. `TODO.md`'s "written, not run" list is still the biggest
  risk.
- Real Steam lobby behaviour, NAT and relay issues, and late joins.
- Bugs in code nobody wrote a test for. Tests only protect what they check,
  which is why the regression habit matters more than coverage numbers.
- Art mistakes (the team already uses ASCII renders plus review for those).

---

## 13. Decisions this research leaves open
1. **Which framework:** GUT (2 of 3 reviewers: simplest for beginners) or
   gdUnit4 (1 of 3: main-branch 4.7 support, official CI action, C# later).
2. **Where tests live:** a `test/` folder at the repo root is the common
   convention for both frameworks. Creating it is a filesystem change and
   needs Orea's go-ahead.
3. **Seedable RNG refactor** in `MinionSpawning` and `TileDestruction`. This is
   a script change, so it needs Orea's go-ahead.
4. **CI: Linux or Windows runner**, and blocking vs reporting.
5. Whether to fill the `Build command` and `Test command` lines in
   `CLAUDE.md` once tests exist.

---

## 14. Sources
- Factorio Friday Facts #60, "Tests all around": https://factorio.com/blog/post/fff-60
- Factorio Friday Facts #62, "The automation of Factorio": https://www.factorio.com/blog/post/fff-62
- Rseding91 technical AMA: https://www.reddit.com/r/factorio/comments/in5d3i/developer_technicaloriented_ama/
- Godot command line tutorial: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Godot `RandomNumberGenerator`: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html
- GUT repository and version table: https://github.com/bitwes/Gut
- GUT command line docs: https://gut.readthedocs.io/en/latest/Command-Line.html
- GUT in CI (Kpicaza): https://medium.com/@kpicaza/ci-tested-gut-for-godot-4-fast-green-and-reliable-c56f16cde73d
- GUT Godot 4 headless issue #491: https://github.com/bitwes/Gut/issues/491
- gdUnit4: https://github.com/godot-gdunit-labs/gdUnit4 and docs https://godot-gdunit-labs.github.io/gdUnit4/latest/
- gdUnit4 scene runner actions: https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/scene_runner/actions/
- gdUnit4Net (C#): https://github.com/MikeSchulze/gdUnit4Net
- gdUnit4 GitHub Action: https://github.com/godot-gdunit-labs/gdUnit4-action
- GitHub Actions billing: https://docs.github.com/en/billing/concepts/product-billing/github-actions
- Chickensoft setup-godot: https://github.com/chickensoft-games/setup-godot
- Chickensoft GoDotTest / GodotTestDriver: https://github.com/chickensoft-games/GoDotTest , https://github.com/chickensoft-games/GodotTestDriver
- Running Godot tests on CI (David Saltares): https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
- Deterministic physics in Godot (Snopek Games): https://www.snopekgames.com/tutorial/2021/getting-started-sg-physics-2d-and-deterministic-physics-godot/
