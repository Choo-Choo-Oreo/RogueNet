# Party Wipe Screen (graves)

**Status: built on `silvery/art-and-gear` (2026-09-25), waiting on Orea's
review before it merges.** Asked for by Silvery Foxy on 2026-09-24. The
original mockup is at https://claude.ai/artifact/T51A9sLsAMb7q1DtheLS3Z.

## What was built

- `scripts/ui/PartyWipeScreen.gd` (+ `scenes/ui/PartyWipeScreen.tscn`)
  replaces `DeathCountdown` in `Dungeon.tscn`. It fades to a coloured
  graveyard, raises one headstone per adventurer (the stone matches the
  dive's biome), and carves the name and cause of death on it. Clicking a
  stone opens a parchment page with that adventurer's history.
- `scripts/dungeon/RunLog.gd` keeps the history: time alive, rooms walked
  into, damage dealt and taken, biggest hit, kills per creature, and the
  killing blow. It isn't sent anywhere. Every peer fills in its own copy
  from the hit messages, which all peers already receive.
- **Attacker on every hit:** `TileHit.attacker_of(caster)` goes through
  NetworkSync's hit messages to `take_damage(..., attacker)`. For a hit on
  a player it's the minion's type id; for a hit on a minion it's the
  player's peer id. On the host, a client's hit on a minion is credited to
  whoever sent it, not to what the client claims.
- **End votes:** `NetworkSync.vote_end()` goes to the host, which counts
  presses (`end_votes`) and tells the divers. A candle lights on each
  grave. Once every diver still connected has pressed, `end_mission()`
  runs. A diver who leaves counts as pressed.
- **Art** in `resources/gfx/ui/party_wipe/`: `Graveyard.png` (320x180),
  `Headstone<Biome>.png` (13 biomes, 56x56), `Candle.png`.
- Rooms explored uses `DebugState.room_index_at`, the only room lookup
  there is. It lives in a debug class, so it may want a proper home.

## The idea

This replaces the 10-second "Returning to town in 10..." countdown
(`scripts/ui/DeathCountdown.gd`) with a full screen that shows up once the
whole party is dead:

- One headstone per adventurer along the bottom, with their name and
  cause of death engraved on it. A solo run shows one headstone.
- Hovering over a headstone highlights it. Clicking it opens that
  character's history: time alive, floor reached, rooms explored, damage
  dealt and taken, kills by creature, and the killing blow.
- There is no timer. An **End** button sits above the graves, and each
  player must press it. When everyone has, the party returns to town, where
  they make a new character.

## What existed before (for reference)

- **Party death is already detected:** `DeathCountdown._all_players_dead()`,
  plus `PlayerController._on_died()` for the ghost swap.
- **Returning to town is already there:** `NetworkSync.end_mission()`
  (host only) sends the divers back.
- **Names are already known:** `NetworkSync.peer_names` holds Steam names.
  Characters have no names of their own.
- **Art:** the grave set in `resources/gfx/objects/objects.graves/` (used as
  distant graves in the backdrop). The new headstone and backdrop from the
  mockup are greyscale value passes, not added to the project yet.

## What was missing (all built now, see above)

1. **Cause of death.** `take_damage(amount, type)` doesn't say who hit, so
   the killer is unknown. It would need an optional attacker (id and name,
   or the minion's json id) passed along to `EntityStats`, stored as the
   last hit before `died` fires. This touches combat, which is Orea's area.
2. **Run stats per character.** Time alive, kills per creature, damage
   dealt and taken, rooms and floor reached. This could be one small
   dictionary on the player that counts up. The same place would suit
   `dynamic-monster-scaling.md`'s trackers later, so they aren't built
   twice.
3. **Sharing them.** Each player's stats and cause of death have to reach
   everyone, so every grave shows the same thing. Health isn't networked
   yet (see the comment in `DeathCountdown.gd`), so a host and a client can
   disagree about who is dead. That already needs fixing for this screen to
   be trusted. This lives in `NetworkSync.gd`.
4. **End votes.** Each player's press goes to the host. The host counts
   them, tells everyone the count (the "2/3 ready" and a candle lighting on
   each grave), and calls `end_mission()` once everyone has pressed. Also in
   `NetworkSync.gd`.
5. **The screen.** A new scene replacing `DeathCountdown` in
   `Dungeon.tscn`, built from items 1 to 4. This is UI only.

## Open questions (Orea's calls)

- **Someone never presses End** (AFK or disconnected). Proposed: a player
  who leaves counts as having pressed. Maybe the host can end it for
  everyone. Without a rule like this, one player can trap the party.
- **Difficulty tiers** (`docs/TODO.md`). Softcore has no permadeath, so
  "make a new character" shouldn't apply there. Does softcore see this
  screen with different wording, or skip it?
- **Death demotion** (`death-demotion-mechanic.md`). Dead adventurers come
  back as chumps until the dive ends. Is the grave the adventurer's or the
  chump's? Should chump deaths count toward the wipe?
- **Character creation doesn't exist yet.** Until it does, "End" just goes
  back to town as today.
- **Where the history is kept.** For this screen only, or kept afterwards (a
  hall of the fallen in town)? Keeping it means saving it to disk.
- **Font.** The game has none yet. The mockup uses Pixelify Sans as a
  stand-in; Foxy's call.

## Words

The docs call player characters "adventurers", never "heroes".
