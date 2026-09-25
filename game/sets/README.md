# Sets

`<set>.json`, one file per item set. The file name is the set's id, the same word the items use
in their `"set"` (`game/items/`). Every set has a file; only some have a `bonus`.

What every set file gives its items (an item can override any of them):
- `rarity`: `common`, `uncommon`, `rare`, `epic` or `legendary` (`ItemDatabase.RARITIES`). It
  picks the storage frame; epic and legendary items float and spark.
- `sound`: the material it's made of, one of the names in `ItemSounds.MATERIALS` (`metal`,
  `stone`, `wood`, `leather`, `bone`, `organic`, `cloth`, `glass`, `paper`, `jewel`). It picks
  the pick-up / put-down sound in `resources/sfx/ui/inventory/` and how hard the icon lands.
- `description`: a line or two of lore, shown on the storage's lore page under the item's own.

The rarities, sounds and lore written so far are placeholders, to be tuned.

## Full-set bonus

A body gets the bonus when its `head`, `chest`, `gloves`, `legs` and `feet` all come from that
set (`ItemDatabase.FULL_SET_SLOTS`). The weapons and the amulet don't count, so any weapon can
be used with a set bonus. Nothing is stored about this: it is worked out from the worn gear
every time the gear changes. The worn gear is already sent to every player, so everyone sees
the same bonus. `scripts/entities/GearEffects.gd` draws it.

For now a bonus is only looks: effects that play around the body. It gives no stats.

```json
{
	"bonus": {
		"aura": {
			"texture": "res://resources/gfx/effects/effects.sets/ArchmagePentagram.png",
			"frame_size": [32, 32],
			"frame_count": 8,
			"speed": 10.0,
			"offset": [0, 4]
		},
		"trail": {
			"texture": "res://resources/gfx/effects/effects.sets/InfernalLava.png",
			"frame_count": 4,
			"speed": 6.0,
			"lifetime": 2.5,
			"fade": 1.5
		},
		"particles": {
			"amount": 10,
			"lifetime": 1.2,
			"colors": ["fff8c0", "ffd040", "ff6020", "8a2020"],
			"area": [10, 6],
			"offset": [0, 4],
			"direction": [0, -1],
			"spread": 25.0,
			"speed": [6, 14],
			"gravity": [0, -4],
			"size": [1, 2]
		}
	}
}
```

All three parts are optional; use any mix. Positions are in pixels from the centre of the
body's tile, with +y pointing down. The animations use the same format as an attack's
`"effect"` block (`texture` strip, `frame_count`, `speed` in frames per second, `loop`), plus
`frame_size` (default `[16, 16]`).

- **`aura`**: one looping animation that stays under the body's feet and moves with it. It
  draws on the floor: above floor tiles, under walls and under every body. It can be bigger
  than a tile (the pentagram is 32x32).
- **`trail`**: every time the body steps onto a tile it leaves one copy of the animation
  there, on the floor. The copy stays for `lifetime` seconds, then fades out over `fade`
  seconds. Stepping back onto a tile replaces its old copy, so a tile never piles up
  copies. `"loop": false` plays the animation once and keeps its last frame, which suits
  something that grows (the Seraph's flowers). `"rotate": true` turns the art towards
  the step, in quarter turns. Draw it walking up the screen (the Wraith's footprints).
- **`particles`**: small squares that keep drifting off the body (Godot's `CPUParticles2D`).
  They start at a random spot in the `area` box (width, height) around `offset`. Each flies
  off along `direction` at a random `speed` between the two numbers (pixels per second),
  up to `spread` degrees off that line, pushed by `gravity`. Over its `lifetime` (seconds)
  a particle goes through `colors` from first to last, then fades out. `amount` is how
  many are alive at once. `size` is the square's side in pixels, picked between the two
  numbers. They are left behind in the world when the body walks on. `"behind": true`
  draws them under the body instead of over it.

What cannot happen:
- The effects are hidden while the gear is hidden (a dead player's ghost), and they come
  back with it.
- A bonus can't need the amulet or a weapon, and two sets can't be mixed for one bonus.
- The effect art lives in `resources/gfx/effects/effects.sets/`.
