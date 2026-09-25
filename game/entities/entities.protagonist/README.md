# Protagonist

`adventurer.json` is the adventurer body: stats, resistances and its own `actions` (taunt,
throw rock), which go on the hotbar after the actions of the gear worn (item `actions`, see
the root README under "Items"). It is the same for a player and a future AI adventurer;
each gets its own controller (the player's is `PlayerController`).

Its `senses` use the minions' format (`{"range_tiles": n}`, or `false` for a sense it doesn't
have). A player's vision is the sum of them (`scripts/cells/tiles/PlayerVision.gd`): `sight` is
how far they can see a lit tile, `touch` the tiles they feel even in the dark. `hearing` is a
dB threshold like the minions' (`threshold_db`, see the root README): the quietest sound (a teammate's voice, later combat) you hear through the dungeon; `smell` and `taste` are off. Light itself comes only from a held torch (the item's
`glow_radius`), never from the body.

`starter_kits.json` is a new adventurer's gear (ProtagonistSave). `worn` is the item ids they
start wearing (a sword and a torch), each in the slot its item names. `bag` is kit name -> item
ids; they start with every kit in the bag, kits in file order, so all of them together must fit the 21-cell bag. It has no sprite data: the player's look is chosen at runtime from the art in
`resources/gfx/entities/entities.protagonist/` (`human`, `ghost` and the temporary `knight` and
`dwarf`). Actions are shared with every other creature; see
[`../../actions/README.md`](../../actions/README.md).
