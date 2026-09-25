# Tags reference

The one place that says what every tag means, so tags stay few and never
overlap. Before adding a tag, check that no existing one already covers it.
A tag says what a creature *is*. It never names a single creature: a timberwolf
or an arctic wolf is a minion id (a file), not a tag.

## How minion tags are written

Every tag has a **main** category and, optionally, a **secondary** one after a
dot: `undead.skeleton`, `beast.rodent`. Put the most specific one you have in
the minion's JSON (`game/entities/entities.antagonist/minions/<id>.json`, or `bosses/`):

```json
"tags": ["beast.canine", "demon"]
```

- A minion carries the full tag (`beast.canine`). It counts as `beast` too, so
  you never write both.
- A minion may carry several tags, one per main category it belongs to. A
  hellhound is a canine beast *and* a demon.
- A main category with no secondary yet is written plain (`beast`).
- Secondary tags are only added when a family has several genuinely different
  creatures, so a room can favor one kind (skeletons) without the other (ghosts).

## How a room favors a tag

In a room's JSON (`favored_minion`, see `game/rooms/README.md`):

```json
"favored_minion": { "tag": "undead.skeleton", "weight": 3 }
```

| Room asks for | Matches |
|---|---|
| a main tag, `undead` | every minion tagged `undead` or `undead.<anything>` |
| a full tag, `undead.skeleton` | only minions tagged `undead.skeleton` |
| a minion id, `wolf` | only that minion (every minion counts its own id as a tag) |

Matching minions get their weight in the biome's `monsters` table multiplied
by `weight` (default 3). It only boosts: a minion the biome table does not list
is never added.

## Every minion tag that exists

### `beast`: wild animals and animal-like vermin
Acts on instinct: no tools, no magic, not dead, not infernal.

| Tag | Meaning | Minions |
|---|---|---|
| `beast` (plain) | An animal that has no secondary category yet. | bat, bat_echo, cat, clam, crab, dragon, eagle, leech, leech_flesh, minotaur, octopus, owl, penguin, scorpion, snake, spider, spiderling, toad, turtle |
| `beast.rodent` | Rats and hamsters. | rat, rat_blind, rat_toothless, hamster, hamster_flying, hamster_demonic |
| `beast.canine` | Wolves and dogs. | wolf, wolf_hellhound |
| `beast.insect` | Insects: bees, ants, beetles, moths and the like. | ant, bee, beetle, butterfly, dragonfly, mantis, moth |

### `undead`: dead things that still move

| Tag | Meaning | Minions |
|---|---|---|
| `undead.skeleton` | Walking bones, whatever they carry or how big they are. A giant skeleton would be this too. | skeleton_archer, skeleton_warrior |
| `undead.ghostly` | Spirits with no body to speak of: wraiths and other ghosts. | ghost, wraith |
| `undead.ghoul` | Rotting flesh that walks: zombies, ghouls. | zombie |

### `giant`: huge humanoid brutes
Big, strong and dim, walks on two legs, uses crude weapons. Not an animal (that is `beast`).

| Tag | Meaning | Minions |
|---|---|---|
| `giant` (plain) | A giant with no secondary category yet. | ogre, yeti |

### `demon`: infernal or corrupted versions of ordinary things
Add it *on top of* the creature's own tag. A creature that is nothing but a demon (the imp)
carries it alone. It has no secondary category yet.

| Tag | Meaning | Minions |
|---|---|---|
| `demon` | Hellish or corrupted. | hamster_demonic, imp, wolf_hellhound |

### `humanoid`: people-sized folk
Walks on two legs, uses tools, weapons or magic, and is not huge (that is `giant`) or dead
(that is `undead`).

| Tag | Meaning | Minions |
|---|---|---|
| `humanoid` (plain) | A humanoid with no secondary category yet. | goblin, lizardman, orc, witch |

### `construct`: made things that move
Built or carved, then brought to life: not born, not dead.

| Tag | Meaning | Minions |
|---|---|---|
| `construct` (plain) | A construct with no secondary category yet. | gargoyle, mimic |

### `ooze`: living blobs
No bones, no fixed shape.

| Tag | Meaning | Minions |
|---|---|---|
| `ooze` (plain) | Slimes and the like. | slime |

### `plant`: walking plants and fungi

| Tag | Meaning | Minions |
|---|---|---|
| `plant` (plain) | Mushrooms, mandrakes and other things that grow. | mandrake, mushroom |

### `elemental`: living elements
A body made of fire (later maybe water, stone, air).

| Tag | Meaning | Minions |
|---|---|---|
| `elemental` (plain) | An elemental with no secondary category yet. | fire_spirit |

## Every minion and its tags

| Minion | Tags |
|---|---|
| ant | beast.insect |
| bat | beast |
| bat_echo | beast |
| bee | beast.insect |
| beetle | beast.insect |
| butterfly | beast.insect |
| cat | beast |
| clam | beast |
| crab | beast |
| dragon | beast |
| dragonfly | beast.insect |
| eagle | beast |
| fire_spirit | elemental |
| gargoyle | construct |
| ghost | undead.ghostly |
| goblin | humanoid |
| hamster | beast.rodent |
| hamster_demonic | beast.rodent, demon |
| hamster_flying | beast.rodent |
| imp | demon |
| leech | beast |
| leech_flesh | beast |
| lizardman | humanoid |
| mandrake | plant |
| mantis | beast.insect |
| mimic | construct |
| minotaur | beast |
| moth | beast.insect |
| mushroom | plant |
| octopus | beast |
| ogre | giant |
| orc | humanoid |
| owl | beast |
| penguin | beast |
| rat | beast.rodent |
| rat_blind | beast.rodent |
| rat_toothless | beast.rodent |
| scorpion | beast |
| skeleton_archer | undead.skeleton |
| skeleton_warrior | undead.skeleton |
| slime | ooze |
| snake | beast |
| spider | beast |
| spiderling | beast |
| toad | beast |
| turtle | beast |
| witch | humanoid |
| wolf | beast.canine |
| wolf_hellhound | beast.canine, demon |
| wraith | undead.ghostly |
| yeti | giant |
| zombie | undead.ghoul |

## Room tags

Set in a room's JSON (`"tags": [...]`). Different from minion tags. The biome's
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
   above, and list which minions carry it.
4. Update the "every minion" table.
