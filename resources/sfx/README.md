# Sounds

The folders follow `docs/STRUCTURE.md`: `effects/` holds hit and cast sounds by damage family
(the same `effects.<family>` folders and names as `resources/gfx/effects/`, so a damage type has
a look and a sound), `entities/` creature sounds in the same folders as `game/entities/`
(sounds every creature shares at its root), plus `ambiance/`, `music/` and `ui/`.

## Combat sounds

Every sound a fight makes. `scripts/actions/CombatSounds.gd` decides which file plays and how
loud; `scripts/util/SoundPlayer.gd` plays it and keeps crowds under control. No creature or
action JSON names a sound: the file is found from data that already exists, so adding a file
with the right name is all it takes.

**These are placeholders.** They were synthesised on 2026-09-25 (retro square/noise tones,
made by us, no licence needed) so the whole system works now. Swap any of them for a Pixabay
pick by saving the new clip under the same name (keep `.wav`, or change the extension in
`CombatSounds.gd`). Keep clips under about 0.3 s; anything over 0.7 s is faded out.

| File | Plays when | Picked by |
|---|---|---|
| `effects/effects.<family>/<action id>.wav` | an attack starts (the swing, twang or zap), on every screen | the action id: `effects.melee/slash.wav` for `game/actions/slash.json`, found in whichever family folder has it. An action with no file is silent. An action (or a creature's override of it) can name another file with `"sound"`. |
| `effects/effects.<family>/<damage type>.wav` | a player is hit | `<action id>_hurt` if it exists (`bite_hurt`), else the damage type in lower case, most specific first (`physical.slashing`, then `physical`), else `physical`. Pitch drops a little as health runs low. |
| `entities/impact/<material>.wav` | a minion is hit | what it's made of, from its tags (`CombatSounds.MATERIAL_BY_TAG`): `bone`, `stone`, `organic`, `ethereal`, else `flesh`. `block` when resistances stopped the whole hit. |
| `entities/death/<material>.wav` | a minion dies | the same material. |
| `entities/entities.antagonist/voice/` | about one minion attack in 5, never the same species twice running | the species' tag (`CombatSounds.VOICE_BY_TAG`) or, for a few plain beasts, its id (`VOICE_BY_ID`). |
| `entities/entities.protagonist/` | the hurt player's own machine: a grunt (`grunt_1..3`) on about one hit in 3 (never twice running); the heartbeat under 25% health | fixed names |

Hurt sounds there are (a type without its own file uses its parent's):

| Family folder | Files |
|---|---|
| `effects.melee` | `physical`, `physical.slashing`, `physical.bludgeoning`, `physical.piercing`, `physical.strangling`, `bite_hurt` (the `bite` action, any type) |
| `effects.arcana` | `arcana` (also Ordo, Entropia, Plenum), `arcana.ordo.frigid`, `arcana.ordo.solum`, `arcana.entropia.zeal`, `arcana.entropia.fluentia`, `arcana.entropia.inanis` |
| `effects.necrotic` | `necrotic` (also Perditio), `necrotic.perditio.torpor`, `necrotic.perditio.virulentia`, `necrotic.perditio.ruina` |

`arcana.entropia.zeal` (a burn) is ready for fire, but nothing deals fire damage yet: there is no fire type (Zeal may be
meant as one) and lava tiles slow you but don't hurt. That is a gameplay decision for Orea.

### Volume and crowds

- An attack's sound is a sound in the dungeon at its action's `db` (`game/actions/README.md`):
  walls, doors and distance take it down the same as voices, and one you can't hear doesn't play.
  An action of 60 dB heard beside you plays as recorded; each dB more or less is a dB louder
  or quieter (`CombatSounds.PLAYBACK_DB`). A thrown rock's sound plays where it lands.
- Hurt and impact sounds are heard the same way, at the dB of the action that landed the hit;
  a hit with no known action, and a death, use `game/sounds.json` (`hit_db`, `death_db`).
  `scripts/entities/HitFeedback.gd` plays them from `EntityStats.damaged` / `died`, on every
  machine. The grunts and heartbeat are only on the hurt player's own machine and are not
  positional (they are you).
- Your own attacks and hits on you are loudest; your party's are 5 dB quieter, enemies' 8 dB,
  a hit landing on a minion 3 dB. A boss is 2 dB louder and skips every limit below.
- The same file at most 3 times at once; extras are dropped.
- The same file again within 50 ms plays once, a little louder, instead of twice.
- Off-screen sounds don't play; on-screen ones get quieter with distance from the camera.
- Every play is pitched ±6% at random.
- The SFX bus has a compressor (`resources/AudioBusLayout.tres`), so a busy fight gets
  squeezed instead of clipping. A big hit on you briefly muffles everything (a low-pass on
  Master, off the rest of the time).
