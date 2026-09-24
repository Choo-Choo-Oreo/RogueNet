# Headless playtests

`dev_sim.gd` plays the development biome (`game/rooms/development/`) without a window and reports
what the creatures did, so the AI bugs in `docs/TODO.md` ("Big bodies, movement, abilities") can be
checked by a command instead of by walking around. It is a script run by Godot, not a GUT test:
it takes real time (about `seconds` per cell) and prints a report.

```
godot --headless -s res://test/sim/dev_sim.gd -- [seconds=15] [natural] [cell_name ...]
```

(`run_sim.bat` does the same with the Godot copy in `.godot-local/`.)

- No cell names: runs the bug cells. Names come from `dev_cells.json`.
- Per cell it rebuilds the dungeon, puts an invincible player at the cell's entry, opens the cell's
  door and samples every 0.25 s.
- By default creatures are told where the player is (the call a taunt makes), so a wall in the way
  tests pathfinding, not eyesight. `natural` leaves them to their own senses.
- Per creature: how it was alerted, closest and final distance to the player, `STALLED` (alerted,
  more than 2.5 tiles away and not moving for 4 s; a ranged creature holding its range also shows
  this, so read it with the creature type in mind), and `BAD TILE` if it ever stood on a wall, void or
  no-floor tile. Exit code 1 if any creature did, or a cell spawned a different number of creatures
  than the room file pins.
- Each cell also has a verdict, `PASS` or `FAIL`, from what `generate_hub.py` records for it: which
  creatures must get within 3 tiles of the player (`REACH`), whether a creature may be skipped at spawn
  (`MAY_SKIP`), how often a standing boss's zone may change (`ZONE_CHANGES_MAX`), plus the always-on
  checks (no bad tile, no more creatures than pinned). The exit code is 1 if any cell fails.
- **A cell that fails means a bug is present or came back.** Cells stay after their bug is fixed; add
  the expectation first, watch it fail, then fix.
- `dev_cells.json` is written by `game/rooms/development/generate_hub.py`; do not edit it by hand.

Not covered: the smash telegraph is visual. The boss zone (bug 5) is sampled, but the flicker the audit
describes has not been reproduced yet.
