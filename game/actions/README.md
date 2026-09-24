# Actions

One JSON file per action: something a creature can do on purpose (a bite, an arrow shot,
a wall smash, a taunt). The file name minus `.json` is the action's **id**. Every creature
(a minion, a boss, the player) lists action ids in its own JSON under `"actions"`; nothing
here belongs to one team. Files are found in this folder and every folder under it, so ids
must be unique. This file is the reference for what exists; keep it in step when one is
added or changed.

## Using an action

```
"actions": ["bite"]
"actions": [{ "action": "bite", "amount": 3 }, "wall_smash"]
```

An entry is an id, or an object with `"action"` and any keys that should differ **for that
creature only** (they replace the action's own values). Put a number in the action file
when every user shares it, and override it only where a creature is different. Never copy
an action's whole block into a creature: that is what this folder exists to stop.

The order matters for minions (the first is the default attack that decides how close it
walks) and for the player (the order is the hotbar slot).

## Fields

| Field | Meaning |
|---|---|
| `verb` | What it does: `hit` (an instant hit on a tile, next to the caster or at range), `projectile` (a shot that flies and hits the first creature in its path), `destroy_tiles`, `taunt`. Required; the code for each is in `scripts/actions/verbs/`. |
| `amount`, `type` | Damage and its type id from `game/damage_types.json`. |
| `interval` | Seconds before it can be used again. |
| `range_tiles` | How far it reaches for a minion (default 1, adjacent). |
| `target_mode` | `"melee"` (default) or `"ranged"`; how the player aims it. |
| `effect` | A picture played when it is used: `texture`, `frame_count`, `speed`, `anchor`. A `projectile` adds `projectile` (a flying sprite) plus `attacker` and `target` animations. |
| `shape` | For `destroy_tiles`: breaks the walls inside it (`line` with `length` and `width`, or `circle` with `radius`), leaving floor. Never breaks `barrier_*` tiles. |
| `radius_tiles`, `duration`, `max_targets` | For `taunt`: forces minions within the radius (nearest `max_targets`) onto the user for `duration` seconds. |
| `needs_sight`, `only_through_walls` | Minion firing rules. The second fires only while a wall is between it and its target. |

## Every action

| Id | What it does | Used by |
|---|---|---|
| `bite` | 1 Physical, 1.0 s, adjacent. | most minions (interval or amount overridden) |
| `slash` | 3 Physical, 0.5 s, adjacent. | the player |
| `bludgeon` | 6 Physical.Bludgeoning, 1.5 s. | minotaur |
| `perditio_touch` | 2 Perditio, 1.4 s. | wraith |
| `arrow_shot` | 2 Physical, projectile, ranged, 4 tiles. | skeleton_archer, the player |
| `entropia_bolt` | 2 Entropia, ranged, 4 tiles. | hamster_demonic, the player |
| `wall_smash` | Breaks walls in a 3x2 line, 6 s, only through walls. | minotaur |
| `taunt` | Pulls minions within 6 tiles for 4 s, 12 s cooldown. | the player |

Costs (ammo, magic, stamina) are not built.
