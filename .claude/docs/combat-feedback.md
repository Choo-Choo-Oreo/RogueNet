# Combat feedback: attack sounds and taking damage

**Status: built 2026-09-25**, all 33 ideas plus hurt sounds by damage type.
Asked for by Silvery Foxy, who picked every idea; Orea's approval was relayed by
Foxy the same day. The sounds are synthesised placeholders until Pixabay picks are
approved (see `resources/sfx/combat/README.md`).

Where it lives: `scripts/audio/SoundPlayer.gd` (shared one-shot player, crowd
rules; ItemSounds now uses it), `scripts/audio/CombatSounds.gd` (which sound),
`scripts/entities/HitFeedback.gd` (flash, recoil, numbers, spray, shake, grunt,
hit-stop), `scripts/entities/DamageNumber.gd`, `scripts/ui/HurtOverlay.gd` (red
edge, low-health pulse, heartbeat, muffle), `HealthBar` (trail, jolt, blink),
`MouseFollowCamera.shake`, `ParticleBurst.hit_spray`, settings in
`ConfigFileHandler.FEEDBACK_DEFAULTS` + `scripts/settings/FeedbackControl.gd`.
Damage now carries `cause` (the action id) from TileHit through NetworkSync to
`EntityStats.damaged(amount, type, cause)`. Check: `test/sim/hit_feedback.gd`,
`test/unit/test_combat_sounds.gd`.

Differences from the plan below: no `"hurt_sound"` field (a file named after the
action is enough), and no `"sound"` needed on each action (the file is named
after it). i-frames (23) were **not** added: that changes combat; the blink has
nothing to show until Orea adds them. Hit-stop (29) freezes only sprite
animation near the player, never game time.

The original proposal follows.

## What exists already

- `EntityStats.health_changed(current, max)` fires on every hit, on every peer.
  `EntityStats._apply_health` already knows the damage `type` and applies
  resistances; `ParticleBurst.blood` plays on the killing blow.
- Damage reaches players only through `NetworkSync.receive_player_damage`
  (host decides, everyone applies) and minions through
  `receive_minion_damage`. Both carry `amount` and `type`, not the attacker.
- `ItemSounds.gd` (inventory) is a one-shot player with a repeat gap, a max
  length and a fade. **Generalise it into one shared sound player** rather than
  writing a second one for combat (CLAUDE.md, no duplication).
- Audio buses: Master, Music, SFX, UI (`resources/AudioBusLayout.tres`).
- HealthBar (top left, local player) and HealthPixelBar (under every entity)
  both redraw on `health_changed`. Nothing flashes, shakes or pops up.
- The settings menu has volume sliders per bus; no shake/flash options.

## Data issues found while looking (not fixed, Orea's call)

- `entropia_bolt.json` uses `"type": "Entropia"` and `perditio_touch.json`
  `"Perditio"`, but `game/damage_types.json` only lists `Arcana.Entropia` and
  `Necrotic.Perditio`. Resistances keyed by the full name won't match.
- `slash`, `bite` and `arrow_shot` are all plain `Physical`, although
  `Physical.Slashing` and `Physical.Piercing` exist. Per-type hurt sounds
  (below) can't tell a cut from a bite from an arrow until they're split, or
  unless the attack's id travels with the damage.
- There is no fire/burning type and nothing deals damage over time or from
  terrain: lava and magma rooms exist (`game/rooms/cave`, `volcano`) but are
  only tiles. `Arcana.Entropia.Zeal` may be meant as fire.

## Attack sounds (1-14)

1. One sound per action: a `"sound"` field in each `game/actions/*.json`
   (slash swoosh, bite chomp, bludgeon thud, arrow twang, rock whoosh,
   entropia zap, perditio hiss, wall_smash crumble, taunt shout).
2. Two parts: a soft swing when the attack starts, the impact only if it lands.
3. Impact sounds like the target's material, derived from its tags
   (undead -> bone, ooze/plant -> organic, construct -> stone/metal, beast ->
   flesh), reusing `ItemSounds.MATERIALS` names. No new field.
4. A distinct heavier "you got hit" sound (see 24 and the per-type table).
5. Occasional monster voice on attack (~1 in 5, never twice in a row per species).
6. Death sound per enemy (pop/crumble, material-based like 3).
7. Bosses (`MinionController.bosses`) skip the crowd limits and play heavier sounds.
8. Priority/volume: own attacks and hits on you loudest, party medium,
   enemies quieter, enemy-on-enemy silent.
9. Voice cap: at most ~3 of the same sound at once, extras dropped.
10. Merge: the same sound several times in one ~50 ms window plays once, a bit louder.
11. Off-screen is silent; distance fades (AudioStreamPlayer2D attenuation).
12. Random pitch ±6%.
13. Clips trimmed to <0.3 s, faded (like `ItemSounds.MAX_LENGTH`).
14. A compressor on the SFX bus so crowds duck instead of clipping.

## Taking damage (15-33)

15. Sprite flash: white ~0.08 s then red ~0.1 s, on every peer, players and minions.
16. Recoil: sprite (not the tile position) nudged 1-2 px away from the hit.
17. Damage numbers: small pixel digits float up; hits within ~0.3 s on the same
    target add into one number. Red on you, white on enemies.
18. Blocked: a grey "0"/"block" when resistances reduce a hit to 0.
19. Trailing health bar: the lost part stays pale ~0.4 s, then drains; small jolt.
20. Screen-edge red vignette on big hits (>~15% max health), local player only.
21. Low health (<25%): slow faint red pulse on the edges, pixel bar blinks.
22. Small hit spray: a smaller `ParticleBurst` on every hit (blood; bone or stone
    chips by material, as in 3).
23. Invulnerability blink: **gameplay change** (i-frames), only if Orea adds them.
24. Hurt sound, pitch dropping slightly as health falls (per type, see table).
25. Grunt, ~1 in 3 hits, never back to back.
26. Heartbeat under 25% health, stops on heal.
27. Big hit muffles the mix ~0.3 s (low-pass on SFX/Music buses).
28. Camera shake scaled to damage, local camera only.
29. Hit-stop ~40 ms on big hits: **visual only**, never the simulation, or
    peers desync. Orea's call.
30. Controller rumble matched to 28.
31. Rate limits: shake/flash/grunt at most ~4 per second; extra hits fold in.
32. Settings: toggles for shake, screen flash, hit-stop, and a shake-strength
    slider (accessibility).
33. Teammates getting hit: their flash (15) and number (17) only; no shake or vignette.

## Hurt sound by how you were hurt (asked 2026-09-25)

The hurt sound (24) is picked by what hit you. Look-up order, most specific
first, the same fallback as tags (`Physical.Slashing` -> `Physical`):

1. the attack's own `hurt_sound`, if it has one (so `bite` can crunch even
   though its type is plain `Physical`), then
2. the damage type, walking up the dotted name, then
3. a generic thump.

| Damage type | Sound |
|---|---|
| Physical (generic) | dull thump |
| Physical.Slashing | cut / flesh slice |
| Physical.Bludgeoning | crunch / heavy thud |
| Physical.Piercing | stab / arrow thunk |
| Physical.Strangling | choke / squeeze |
| bite (attack) | chomp with a crunch |
| Arcana.Ordo.Frigid | ice crack |
| Arcana.Ordo.Solum | rock hit |
| Arcana.Entropia.Zeal (if fire) | burn / sizzle |
| Arcana.Entropia.Fluentia | splash |
| Arcana.Entropia.Inanis | hollow void whoosh |
| Arcana (generic) | magic zap |
| Necrotic.Perditio.Virulentia | poison bubble |
| Necrotic.Perditio.Torpor | slow drone |
| Necrotic.Perditio.Ruina | decay crumble |
| Necrotic (generic) | dark hiss |
| lava / burning (needs a type and a source first) | sizzle + flare |

"Burning" and "lava" need gameplay first: a fire type (or Zeal) and something
that deals it (a burning status, lava tiles that hurt). Until then they only
get a sound file waiting.

## Who does what

| Part | Owner | Can start now? |
|---|---|---|
| Sound clips in `resources/sfx/combat/` (Pixabay, license like the inventory) | nobody yet (Foxy listens) | yes |
| Damage-number font, edge vignette, bone/stone chips | Foxy (art) | yes |
| Shared sound player, flashes, numbers, shake, bars, settings | Orea (`scripts/`) | after sign-off |
| `"sound"` / `"hurt_sound"` in `game/actions/`, type fixes above | Orea (`game/`) | after sign-off |
| i-frames (23), hit-stop (29), fire type, lava damage | Orea (gameplay) | his decision |

Suggested build order once signed off: shared sound player with caps (8-14) ->
attack sounds (1-2) -> hurt sounds by type -> flash, numbers, shake, bars
(15-19, 28, 31-33) -> low health (21, 26) -> the rest.
