# Dynamic Monster Scaling: Design Summary

Status: design draft. All numbers are placeholders to be tuned by playtesting.

## 1. Goal

Scale dungeon monster spawns to the party's strength without reusing the same sprite at higher stats. The game is hardcore: characters are deleted on death in normal difficulty, so the system must protect weak parties without making the game trivial.

## 2. Fixed constraints

- Biome defines files (`defines*.json`) hold room count range, tag weights, monster spawn weights, and music. They stay as they are.
- Monster `monsters` values are **spawn weights**, not counts.
- Each monster is a JSON file that points to a sprite JSON and holds its own behavior data.
- Parties are 1-8 players.
- The dungeon is **generated once at mission start**. Leaving clears the scene.
- Sprites are greyscale with color IDs applied later. Recolors are biome flavor, not stronger variants.
- Crafting exists.
- Player stats are not finalized.

## 3. Core idea

A **performance-adjusted power rating** steers which monsters spawn. Nothing in the biome tables changes. Weights are modified at generation time.

```
party_power   = base_power x performance_multiplier
effective_wt  = base_weight x band_multiplier(monster.power, party_power)
```

Level is an input to base power only. It is not a performance tracker (that would count it twice).

## 4. Components

### 4.1 Base power
Built from character capability (level, or better a gear-and-stats rating once stats exist).

```
base_power = 0.4 x mean + 0.3 x median + 0.3 x weakest_quarter_avg
```

- Weakest-quarter average replaces plain `min`. With 8 players, `min` is nearly always the newest player and is noisy. For 1-3 players it reduces to the weakest member, so no special case is needed.
- Weights are placeholders.

### 4.2 Performance trackers
Tracked per character, per encounter:

| Tracker | Weight | Notes |
|---|---|---|
| HP lost per encounter (fraction of max HP) | ~0.40 | Hard to game, measures pressure directly |
| Lowest HP reached | ~0.35 | Catches near-deaths that averages hide |
| Resources spent per room | ~0.15 | Depends on consumable balance |
| Kill time vs expected | ~0.10 | Most biased toward damage builds |

Not tracked: damage dealt, kill count, total clear time (they measure playstyle and invite exploitation).

### 4.3 Normalization to one number
1. Convert each tracker to a 0-1 strain score:
   `strain = clamp((value - comfortable) / (dangerous - comfortable), 0, 1)`
   Example anchors: HP lost 10% -> 0, 60% -> 1. Lowest HP 80% -> 0, 15% -> 1.
2. Combine with weights summing to 1. If a tracker has no data, drop it and rescale the rest.
3. Roll up to the party using the worst-strained quarter of players (for 1-3 players, the worst member), blended with the mean: `party_strain = 0.5 x mean + 0.5 x worst_quarter_avg`.
4. Exclude boss fights and fled rooms. Smooth over a rolling window of 5-8 encounters.

### 4.4 Strain to multiplier
Strain is inverted relative to power (high strain means struggling), so map it to a multiplier centered on 1.0 at the target strain:

```
multiplier = lerp(1.15, 0.70, strain)   # calibrated so target strain (~0.4-0.5) = x1.0
```

- Asymmetric range: a struggling party can drop further than a cruising party can rise.
- A percentage multiplier scales with the party's own power, so a strong party that plays badly gets a real reprieve.
- Caveat: requires `power` on a rating scale where percentages are meaningful. If power is a raw level number, an additive tier shift is cleaner at low levels.

### 4.5 Difficulty strength setting
One knob scales the whole adjustment:

```
effective_multiplier = 1 + strength x (multiplier - 1)
```

- `0.0`: purely level/depth based, no adaptation (clean baseline).
- `0.25`: mild adaptation.
- Hard mode uses the hidden scaling. Recommended default for normal mode: `0.0` (opt-in), so you can measure whether players like it before it affects permadeath runs.

### 4.6 Soft bands (spawn selection)
Each monster JSON gets a `power` field. Compare it to party power:

| Distance | Multiplier |
|---|---|
| In band (within +-1 tier) | x1.0 |
| Adjacent (2 tiers off) | x0.3 |
| Far (3+ tiers off) | x0.05 |

- Soft bands are preferred over a Gaussian falloff because biomes have few monsters; a Gaussian can give one monster nearly all the weight.
- Normalize after applying multipliers.
- Guarantee every biome always has at least one spawnable monster.
- The rare far spawns keep the hardcore threat alive and allow a trivial mob occasionally.

### 4.7 Party size
- Treat each biome's `room_count` as the value for a **reference party size** (e.g. 4), not for solo.
- Scale rooms and enemies per room separately. Solo: fewer rooms, normal density. Large parties: more rooms and denser rooms, so they do not just walk long empty dungeons.
- Design target by **enemy count**, not rooms. 50 rooms at ~1.7 enemies per room is about 85 fights plus a boss, which is too much for one character. A solo mission of roughly 25-35 fights plus a boss is a plausible target; derive rooms from that.
- A linear `1 + 0.5 x (n - 1)` room multiplier gives 4.5x at 8 players and is likely too steep. Use a smaller coefficient or a cap, and check the map generator at large room counts.

### 4.8 Dead players and soldiers
- A dead player returns as a placeholder soldier who helps at the low end of the party for the rest of the mission.
- The soldier is temporary. When the party leaves the dungeon, the player creates a new character.
- The soldier is excluded from base power, trackers, and party-size counts.
- Because dungeons generate once, the soldier cannot affect spawns in the current mission anyway.
- Soldier stats can stay placeholder until player stats are defined. Define it as a unit in JSON with fixed weak stats.

### 4.9 Loot and crafting
- Scale loot with the tier of the monster killed relative to party level, so sandbagging yields worse loot.
- Do **not** scale loot by strain. A struggling party would get easier monsters, then worse loot, then become weaker (death spiral). Keep a loot floor.
- Crafting is the safety net for weak loot, but only if crafting materials drop by biome or depth, not by monster tier. Otherwise sandbagging also starves crafting.

## 5. Data flow (generate-once)

Because monsters are placed at generation, trackers cannot adjust a dungeon in progress.

1. Log raw per-encounter values during a mission.
2. Carry the rolling window between missions.
3. At the next mission start, compute party power and generate spawns.

Alternative (not chosen for v1): roll monsters lazily when a room is first entered. Gives live adaptation but weakens the "dungeon is fixed" guarantee and changes generation.

## 6. Example data sketch

Monster JSON addition:
```json
{ "id": "wolf", "power": 4, "sprite": "res://.../wolf_sprite.json" }
```

Global tuning defines (kept out of code):
```json
{
  "adaptation_strength": 0.0,
  "base_power_weights": { "mean": 0.4, "median": 0.3, "weakest_quarter": 0.3 },
  "tracker_weights": { "hp_lost": 0.5, "lowest_hp": 0.5 },
  "multiplier_range": { "cruising": 1.15, "struggling": 0.70 },
  "target_strain": 0.45,
  "window_encounters": 6,
  "bands": { "in": 1.0, "adjacent": 0.3, "far": 0.05 }
}
```

## 7. Upsides

- Biome tables and sprites are untouched; only weights change at generation.
- Fights stay tense at any strength, while level and gear still drive progression.
- Weakest-link terms protect the most vulnerable member under permadeath.
- The strength setting answers distrust of hidden scaling and gives a clean 0.0 baseline.
- Everything is data-driven, so tuning needs no code changes.
- Works with few sprites, since variety comes from re-weighting existing monsters.
- Carrying data between missions avoids in-run lag and in-run sandbagging.

## 8. Downsides and risks

| Risk | Detail | Mitigation |
|---|---|---|
| Tuning burden | Anchors, weights, target strain, and multiplier range are all guesses | Log raw values; stage the rollout (section 9) |
| Sprite variety | In-band monsters dominate; few sprites may make the shift invisible | Spread monster `power` values across each biome |
| Sandbagging | Players may play badly for easier fights | Asymmetric range, slow decay, reduced rewards from weak monsters |
| Death spiral | Worse loot on top of easier monsters | Loot by monster tier, loot floor, crafting by biome/depth |
| Lag | Rolling window delays relief | Acceptable by design; carried-over data improves it |
| Hidden scaling distrust | Hardcore players dislike silent adaptation | Opt-in strength setting; depth-based floor per biome |
| Party-size edge cases | Mean/min/max behave badly at 8 players | Quarter-based roll-ups |
| Long missions | Large room multipliers create very long runs | Scale enemy count, cap rooms, verify generator limits |
| Undefined stats | Base power depends on a rating that does not exist yet | Start with level; swap in the rating later |

## 9. Staged rollout

1. **v1:** base power (weakest-quarter blend) plus soft bands, adaptation strength `0.0`. This alone gives level-scaled monsters.
2. Log raw per-encounter tracker values from the start, but do not act on them.
3. **v2:** enable adaptation with two trackers only (HP lost, lowest HP). Set anchors from logged data.
4. **v3:** add resources and kill time only if the data shows they add signal.

## 9b. Later: reuse enemy tags

Enemies now carry `tags` (`game/TAGS.md`) and rooms can set `favored_enemy`.
Once player data exists, the same tags can steer scaling, for example
weighting a whole family (`beast`, `undead`) up or down by band. Not built;
a to-do for when the power rating is real.

## 10. Open questions

- Is `power` a level number or a gear-and-stats rating (decides multiplier vs additive shift)?
- Solo target enemy count, and the reference party size for `room_count`.
- Default `adaptation_strength` for hard mode (`0.25` vs `0.0`).
- How crafting materials are sourced.
- Final soldier stats, once player stats are defined.
