# Doors

One JSON per door type: its `art` by door width, whether it is `transparent`, the
`min_width` and `max_width` it fits, `open_seconds` and `passable_at` (how open it must be
to walk through). The door art and the boss-door layers are under `resources/gfx/doors/`.
The full format is in the root `README.md` under "Doors". Placing doors during generation
is `DoorPlacer`; the door registry that loads these files is in `scripts/cells/`.
