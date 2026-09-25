# Combat sounds

Every sound a fight makes. `scripts/audio/CombatSounds.gd` decides which file plays and how
loud; `scripts/audio/SoundPlayer.gd` plays it and keeps crowds under control. No creature or
action JSON names a sound: the file is found from data that already exists, so adding a file
with the right name is all it takes.

**These are placeholders.** They were synthesised on 2026-09-25 (retro square/noise tones,
made by us, no licence needed) so the whole system works now. Swap any of them for a Pixabay
pick by saving the new clip under the same name (keep `.wav`, or change the extension in
`CombatSounds.gd`). Keep clips under about 0.3 s; anything over 0.7 s is faded out.

| Folder | Plays when | Picked by |
|---|---|---|
| `attacks/` | an attack starts (the swing, twang or zap), on every screen | the action id: `attacks/slash.wav` for `game/actions/slash.json`. An action with no file is silent. An action (or a creature's override of it) can name another file with `"sound"`. |
| `hurt/` | a player is hit | `hurt/<action id>` if it exists (`bite`), else the damage type, most specific first (`CombatSounds.HURT_BY_TYPE`, e.g. `Physical.Slashing` → `cut`), else `thump`. Pitch drops a little as health runs low. |
| `impact/` | a minion is hit | what it's made of, from its tags (`CombatSounds.MATERIAL_BY_TAG`): `bone`, `stone`, `organic`, `ethereal`, else `flesh`. `block` when resistances stopped the whole hit. |
| `death/` | a minion dies | the same material. |
| `voice/` | about one minion attack in 5, never the same species twice running | the species' tag (`CombatSounds.VOICE_BY_TAG`) or, for a few plain beasts, its id (`VOICE_BY_ID`). |
| `player/` | the hurt player's own machine: a grunt on about one hit in 3 (never twice running); the heartbeat under 25% health | fixed names |

Hurt sounds by damage type:

| Type | File |
|---|---|
| Physical | `thump` |
| Physical.Slashing | `cut` |
| Physical.Bludgeoning | `crunch` |
| Physical.Piercing | `stab` |
| Physical.Strangling | `choke` |
| Arcana (and Ordo, Entropia, Plenum) | `zap` |
| Arcana.Ordo.Frigid | `ice` |
| Arcana.Ordo.Solum | `rock` |
| Arcana.Entropia.Zeal | `burn` |
| Arcana.Entropia.Fluentia | `splash` |
| Arcana.Entropia.Inanis | `void` |
| Necrotic (and Perditio) | `hiss` |
| Necrotic.Perditio.Torpor | `drone` |
| Necrotic.Perditio.Virulentia | `poison` |
| Necrotic.Perditio.Ruina | `decay` |
| the `bite` action, any type | `bite` |

`burn` is ready for fire, but nothing deals fire damage yet: there is no fire type (Zeal may be
meant as one) and lava tiles slow you but don't hurt. That is a gameplay decision for Orea.

## Loudness and crowds

- Your own attacks and hits on you are loudest; your party's are 5 dB quieter, enemies' 8 dB,
  a hit landing on a minion 3 dB. A boss is 2 dB louder and skips every limit below.
- The same file at most 3 times at once; extras are dropped.
- The same file again within 50 ms plays once, a little louder, instead of twice.
- Off-screen sounds don't play; on-screen ones get quieter with distance from the camera.
- Every play is pitched ±6% at random.
- The SFX bus has a compressor (`resources/AudioBusLayout.tres`), so a busy fight gets
  squeezed instead of clipping. A big hit on you briefly muffles everything (a low-pass on
  Master, off the rest of the time).
