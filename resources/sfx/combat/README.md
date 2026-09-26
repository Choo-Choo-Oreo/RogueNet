# Combat sounds

Every sound a fight makes. `scripts/audio/CombatSounds.gd` decides which file plays and how
loud; `scripts/audio/SoundPlayer.gd` plays it and keeps crowds under control. No creature or
action JSON names a sound: the file is found from data that already exists, so adding a file
with the right name is all it takes.

They are cut from Pixabay recordings (2026-09-25, picked without listening; where each came
from is in [../SOURCES.md](../SOURCES.md)), except `attacks/taunt.wav` and `hurt/drone.wav`,
which are still synthesised placeholders. Swap any of them by saving the new clip under the
same name (keep `.wav`, or change the extension in `CombatSounds.gd`). Keep clips under about
0.3 s; anything over 0.7 s is faded out. Swings are cut bright (nothing under 160 Hz) and a
little louder than the hits, so they carry over a busy fight instead of turning to mud.

| Folder | Plays when | Picked by |
|---|---|---|
| `attacks/` | an attack starts (the swing, twang or zap), on every screen | the action id: `attacks/slash.wav` for `game/actions/slash.json`, or a variant of it for who attacks (below). An action with no file is silent. An action (or a creature's override of it) can name another file with `"sound"`. |
| `hurt/` | a player is hit | `hurt/<action id>` if it exists (`bite`), else the damage type, most specific first (`CombatSounds.HURT_BY_TYPE`, e.g. `Physical.Slashing` → `cut`), else `thump`. Pitch drops a little as health runs low. |
| `impact/` | a minion is hit | what it's made of, from its tags (`CombatSounds.MATERIAL_BY_TAG`): `bone`, `stone`, `organic`, `ethereal`, else `flesh`. `block` when resistances stopped the whole hit. |
| `death/` | a minion dies | the same material. |
| `voice/` | about one minion attack in 5, never the same species twice running | the species' id (`CombatSounds.VOICE_BY_ID`) or its tag (`VOICE_BY_TAG`). Every minion has one (a test checks). |
| `player/` | the hurt player's own machine: a grunt on about one hit in 3 (never twice running); the heartbeat under 25% health | fixed names |

## Attack variants

`attacks/<action>_<variant>.wav` plays instead of `attacks/<action>.wav` when it exists; the
first variant with a file wins (`CombatSounds.attack_variants`), else the plain one.

- **A player:** the kind of weapon in their main hand, from a word in its id
  (`ItemDatabase.weapon_kind`: sword, knife, blunt, spear, staff, bow; an item can say its
  own with `"weapon"`). The actions are the same for every weapon, only the sound changes.
  `slash.wav` is the sword (a swing with a steel ring on it); `slash_knife` a quick flick,
  `slash_blunt` a heavy whoosh, `slash_spear` a sharp thrust, `slash_staff` a wooden swish.
  No weapon, or a kind with no file: the plain one.
- **A minion:** `big` when it is more than one tile across (`bite_big`, `bludgeon_big`: the
  same sound, slower and deeper), then the top of each of its tags (`slash_beast`: claws, not
  steel).

A new variant is only a file: `bite_undead.wav` would be heard from every undead biter.

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
