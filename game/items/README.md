# Items

`<folder>/<id>.json`. Wearable gear has one folder per equipment slot (`back`, `chest`, `feet`,
`gloves`, `head`, `legs`, `main_hand`, `neck`, `off_hand`, `ring`). Things you carry but can't
wear sit in `potion/`, `material/` and `misc/`. The folders have no README of their own: they
all work as described here, and repeating it thirteen times would only drift. The full format
is in the root `README.md` under "Items".

A file has a `name` and either a `slot` (gear) or a `type` (`potion`, `material`, `item`),
plus optional `set`, `art`, `icon`, `rarity`, `sound`, `description` and `stack`.

- `rarity`, `sound` and `description` fall back to the item's set (`game/sets/<set>.json`),
  then to a default (`common`; a sound picked by slot or type; no text). Only write them on an
  item when it differs from its set.
- The storage tab an item lands in is worked out from its slot or type
  (`ItemDatabase.category`); nothing is stored for it.
- Potions stack to 10 and materials to 50 (`ItemDatabase.STACK_SIZES`); `stack` on an item
  overrides that. Gear never stacks.

What cannot happen:
- An item with neither a valid `slot` nor a valid `type` is skipped when the game loads.
- A potion, material or misc item can't be worn.
- A set's full-set bonus (effects that play while every armour piece of the set is worn) is
  not here: it is in `game/sets/<set>.json`.
