# Protagonist

`adventurer.json` is the adventurer body: stats, resistances and its own `actions` (taunt,
throw rock), which go on the hotbar after the actions of the gear worn (item `actions`, see
the root README under "Items"). It is the same for a player and a future AI adventurer;
each gets its own controller (the player's is `PlayerController`).

`starter_kits.json` is kit name -> item ids. A new adventurer (ProtagonistSave) starts with every
kit in the bag, kits in file order, so all of them together must fit the 21-cell bag. It has no sprite data: the player's look is chosen at runtime from the art in
`resources/gfx/entities/entities.protagonist/` (`human`, `ghost` and the temporary `knight` and
`dwarf`). Actions are shared with every other creature; see
[`../../actions/README.md`](../../actions/README.md).
