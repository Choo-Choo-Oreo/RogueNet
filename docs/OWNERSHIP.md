# Who owns what

Read by everyone, and by Claude in every session (linked from `.claude/CLAUDE.md`). It exists
because a change in someone's area, made without telling them, breaks what they are building.
Example (2026-09-24): the Minotaur's `size_tiles` went from 2 to 3 in a commit that was really
about new art. Four test cells failed and the owner of the numbers did not know.

## Owners

| Area | Owner | Files |
|---|---|---|
| Core systems | Orea | `scripts/`, `singletons/`, `project.godot`, `addons/` |
| Scenes | anyone | `scenes/` (`.tscn`): open to everyone. Keep to the other rules: no gameplay numbers changed through a scene, and do not edit a script to make a scene work |
| Gameplay numbers | Orea | everything in `game/` except art: sizes, stats, speeds, senses, actions, tiles, biomes, rooms' rules |
| Tests and tooling | Orea | `test/`, the Test Lab, `docs/` trackers and STRUCTURE |
| Art | Silvery Foxy | `resources/gfx/`: PNGs, `.aseprite`, sprite/animation JSON that sits beside them, and the `sprite_frames` block of a creature JSON |
| Content and text | HamsterMan4949crypto (as Orea assigns it) | to be listed here when Orea hands an area over |

A creature JSON in `game/entities/` is shared: its `sprite_frames` block is art, everything else
in it is a gameplay number.

## Rules

1. **Stay in your area.** Editing a file in someone else's area needs them to say yes first,
   in person or in chat. "Claude said it was needed" is not a yes.
2. **Art never changes gameplay numbers.** New art with a different frame size does not change
   `size_tiles`, hitboxes, speeds or actions. The body size is decided first and the art is
   drawn to fit it. If the art and the number disagree, say so to the number's owner and stop.
3. **Gameplay changes tell the art owner** when they change how something must be drawn
   (a size, a new direction, a new state).
4. **One thing per commit, named for what it does.** "thing" hides a size change inside an
   art commit. If a commit touches two areas, say both in the message.
5. **The tests are the alarm.** Before pushing anything under `game/` or `scripts/`, run the
   headless sim (`test/sim/README.md`). A failing cell means something changed that someone
   else built on. Do not edit the cell to make it pass; ask the owner.
6. **Do not commit for someone else and do not push to `main` with unreviewed changes in
   another area.**

## For Claude

- Before editing a file, check the table above. If the file is in another person's area than
  the one asking, do not edit it. Say whose it is and what you would change, and stop.
- If a task needs a gameplay number changed for art (or the reverse), ask the owner of that
  number instead of choosing a value.
- If you notice a change in someone's area that looks accidental (a number that moved in an
  art commit, a test that now fails because of data), tell the user and the area's owner. Do
  not "fix" it silently and do not adapt the tests to it.
- Orea can override any of this for a scoped task by saying so.
