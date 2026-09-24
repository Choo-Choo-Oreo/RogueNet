# Protagonist

`player.json` is the player body: stats, resistances and its `actions` in slot order (the
order is the hotbar slot). It has no sprite data: the player's look is chosen at runtime from the art in
`resources/gfx/entities/entities.protagonist/` (`human`, `ghost` and the temporary `knight` and
`dwarf`). Actions are shared with every other creature; see
[`../../actions/README.md`](../../actions/README.md).
