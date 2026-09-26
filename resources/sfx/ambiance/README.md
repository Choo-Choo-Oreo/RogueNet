# Biome ambience

One looping background per biome, played by `singletons/MusicManager.gd` under the music on
the SFX bus (-10 dB), fading in over 2 s when a dive starts and out when it ends. A biome
picks its file with `"ambience"` in `game/rooms/<biome>/defines.json`; a biome without one
has none (`fallback`). Cathedral shares `dungeon.mp3`.

Each is the first 90 s of a Pixabay recording (2026-09-25, cut at an MP3 frame, not
re-encoded; sources in [../SOURCES.md](../SOURCES.md)), not yet listened to. The `.import`
files have `loop=true`; a file imported without it is restarted when it ends, with a gap.
