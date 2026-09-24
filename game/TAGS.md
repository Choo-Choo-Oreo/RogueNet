# Tags reference

The one place that says what every tag means, so tags stay few and never
overlap. Before adding a tag, check that no existing one already covers it.
A tag says what a creature *is*. It never names a single creature: a timberwolf
or an arctic wolf is an enemy id (a file), not a tag.

## How enemy tags are written

Every tag has a **main** category and, optionally, a **secondary** one after a
dot: `undead.skeleton`, `beast.rodent`. Put the most specific one you have in
the enemy's JSON (`game/entities/entities.antagonist/<id>.json`):

```json
"tags": ["beast.canine", "demon"]
```

- An enemy carries the full tag (`beast.canine`). It counts as `beast` too, so
  you never write both.
- An enemy may carry several tags, one per main category it belongs to. A
  hellhound is a canine beast *and* a demon.
- A main category with no secondary yet is written plain (`beast`).
- Secondary tags are only added when a family has several genuinely different
  creatures, so a room can favor one kind (skeletons) without the other (ghosts).

## How a room favors a tag

In a room's JSON (`favored_enemy`, see `game/rooms/README.md`):

```json
"favored_enemy": { "tag": "undead.skeleton", "weight": 3 }
```

| Room asks for | Matches |
|---|---|
| a main tag, `undead` | every enemy tagged `undead` or `undead.<anything>` |
| a full tag, `undead.skeleton` | only enemies tagged `undead.skeleton` |
| an enemy id, `wolf` | only that enemy (every enemy counts its own id as a tag) |

Matching enemies get their weight in the biome's `monsters` table multiplied
by `weight` (default 3). It only boosts: an enemy the biome table does not list
is never added.

## Every enemy tag that exists

### `beast`: wild animals and animal-like vermin
Acts on instinct: no tools, no magic, not dead, not infernal.

| Tag | Meaning | Enemies |
|---|---|---|
| `beast` (plain) | An animal that has no secondary category yet. | bat, bat_echo, leech, leech_flesh |
| `beast.rodent` | Rats and hamsters. | rat, rat_blind, rat_toothless, hamster, hamster_flying, hamster_demonic |
| `beast.canine` | Wolves and dogs. | wolf, wolf_hellhound |

### `undead`: dead things that still move

| Tag | Meaning | Enemies |
|---|---|---|
| `undead.skeleton` | Walking bones, whatever they carry or how big they are. A giant skeleton would be this too. | skeleton_archer |
| `undead.ghostly` | Spirits with no body to speak of: wraiths and other ghosts. | wraith |
| `undead.ghoul` | Rotting flesh that walks. Reserved, no enemy uses it yet. | none |

### `demon`: infernal or corrupted versions of ordinary things
Add it *on top of* the creature's own tag. It has no secondary category yet.

| Tag | Meaning | Enemies |
|---|---|---|
| `demon` | Hellish or corrupted. | hamster_demonic, wolf_hellhound |

## Every enemy and its tags

| Enemy | Tags |
|---|---|
| bat | beast |
| bat_echo | beast |
| hamster | beast.rodent |
| hamster_demonic | beast.rodent, demon |
| hamster_flying | beast.rodent |
| leech | beast |
| leech_flesh | beast |
| rat | beast.rodent |
| rat_blind | beast.rodent |
| rat_toothless | beast.rodent |
| skeleton_archer | undead.skeleton |
| wolf | beast.canine |
| wolf_hellhound | beast.canine, demon |
| wraith | undead.ghostly |

## Room tags

Set in a room's JSON (`"tags": [...]`). Different from enemy tags. The biome's
`tag_weights` in `defines.json` reads them to make a kind of room more or less
common.

| Tag | Meaning |
|---|---|
| `maze` | Maze pieces. Down-weighted so they do not crowd out other rooms. |
| `corridor` | Connecting passages. Down-weighted for the same reason. |
| `treasure` | Kept out of the random pool; placed on a dead end after the layout is done. |
| `combat`, `peaceful`, `stone`, `brick`, `wood`, `dungeon`, `cave`, `flesh`, `forest`, `mine`, `cathedral` | Describe the room. Not read by any code yet. |

(A room's `role`: `entrance`, `boss`, `corridor` or `normal`, is separate from
tags and can also be used in `tag_weights`.)

## Adding a new tag

1. Does an existing main or secondary tag already fit? Use it.
2. New creature of an existing family that a room should be able to single out
   (a giant skeleton is still `undead.skeleton`; an undead that is not a
   skeleton or a ghost needs a new secondary)? Add the secondary under its main
   category in the tables above.
3. New main category? Only for a genuinely different kind of creature. Add it
   above, and list which enemies carry it.
4. Update the "every enemy" table.
