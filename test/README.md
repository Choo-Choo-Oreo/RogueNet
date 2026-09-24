# Tests

Automated checks that run without the game open. Framework: [GUT](https://github.com/bitwes/Gut)
9.7.1 (branch `godot_4_7`), installed in `addons/gut/`. Why GUT and what else is planned:
`docs/AUTOMATED_TESTING_TRACKER.md`.

## Try things by hand: the Test Lab
`test/lab/TestLab.tscn`: right-click it in the editor and choose Run. It builds the development
biome and shows a panel telling you, cell by cell, what it is, what to do, what counts as a bug,
plus a button that copies a bug report to paste to Claude. See `test/lab/development/README.md`.

## Run them
Easiest: double-click or run `run_tests.bat` in the repo root. It uses a Godot copy you keep in
`.godot-local/` (gitignored; use the `_console.exe` build). Or by hand:

First time on a fresh checkout (builds the `.godot/` cache), from the repo root:

```
godot --headless --import
```

Then, every time:

```
godot --headless -s res://addons/gut/gut_cmdln.gd
```

Settings are in `.gutconfig.json` (which folders, exit code). Exit code 0 means all passed, 1 means
something failed. Use your own Godot executable path in place of `godot` if it is not on PATH.

You can also run them from the editor once the GUT plugin is enabled (Project Settings > Plugins).

## Write one
1. Make `test/unit/test_<thing>.gd`, starting `extends GutTest`.
2. Add functions named `test_<what it proves>()`. Set something up, call the code, `assert_eq(got, expected, "why")`.
3. Copy `unit/test_action_shapes.gd`; it is commented and only tests one pure function.

Habit that makes this worth it: **every fixed bug gets a test named after it, and the test must fail
before the fix** (run it first, watch it go red, fix, watch it go green).

## Folders
- `unit/`: tests of one script or function, no scene needed. More folders (content checks, generation)
  arrive when there are tests to put in them.
