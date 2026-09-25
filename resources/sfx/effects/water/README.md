# Water sounds

Played by `scripts/entities/Wading.gd` when a creature wades through `floor_water`, about
10 dB quieter than combat sounds for the same creature (`CombatSounds.who_db`).

| File | When |
|---|---|
| `enter.wav` | stepping into water from dry ground (a splash) |
| `exit.wav` | stepping out of water (drips) |
| `step_1.wav` – `step_3.wav` | each step onto another water tile, taken in turn |

Synthesized (noise sloshes plus bubble chirps), not downloaded, so there is no licence to track.
Keep them short (under half a second) and quiet at the tail: several creatures can wade at once.
