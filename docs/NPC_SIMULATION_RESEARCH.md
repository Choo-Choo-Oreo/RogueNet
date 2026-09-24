# Large-Scale NPC Simulation in a Multiplayer Godot Game — Research Notes

## The problem
The team settled on real-time combat (2026-09-16), and the current idea on the
table is up to ~100 monsters per map, with only ~20 "active" (AI-enabled,
networked) near players at once and ~80 dormant. RogueNet's networking today
is hand-rolled RPCs (`report_position`/`receive_position` over
`unreliable_ordered`, plus a move-state relay) — it does **not** use Godot's
built-in `MultiplayerSpawner`/`MultiplayerSynchronizer` nodes for players yet.
This doc asks: for ~100 networked NPCs, should we adopt those built-in
replication nodes, and what patterns exist for only simulating/syncing the
NPCs near players?

Everything below is either a claim from a source I actually fetched (cited
inline with a URL) or my own reasoning applying general engine-architecture
principles to RogueNet's situation — those are explicitly labeled **(reasoning,
not sourced)** so it isn't mistaken for verified research.

## 1. `MultiplayerSpawner` / `MultiplayerSynchronizer` at scale

**Bandwidth doesn't stay flat just because you configure "spawn only."** A
confirmed Godot engine bug report shows `MultiplayerSynchronizer` bandwidth
"skyrocket[ing] as more 'static' scenes are replicated, despite not needing
any syncing" — even with a `SceneReplicationConfig` that only replicates
spawn variables. It was confirmed by a Godot core dev (Faless) as a real
performance bug, with a temporary workaround of bumping the replication
interval way up (e.g. to 5s), and a since-merged PR (#62144) addressing part
of it.
([github.com/godotengine/godot/issues/62127](https://github.com/godotengine/godot/issues/62127))

**The tunable knobs are `replication_interval` and `delta_interval`.** Per the
official class docs: `replication_interval` controls how often "Always"
properties push (0.0 = every network tick), `delta_interval` does the same
for "on-change" properties. Reducing these is the direct lever for cutting
per-NPC bandwidth if you have many synchronizers running.
([docs.godotengine.org — MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html))

**`MultiplayerSpawner` has one explicit scale-relevant property:**
`spawn_limit` — "Maximum number of nodes allowed to be spawned by this
spawner," unlimited (0) by default, covering both spawnable scenes and custom
`spawn()` calls combined. The docs don't otherwise document a bandwidth cost
model or per-peer spawn-rate limits.
([docs.godotengine.org — MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html))

**General node-tree overhead** (reasoning, not sourced from a specific
benchmark, but consistent with community commentary surfaced in search):
Godot's scene tree is built for a moderate number of complex nodes, not a
large number of trivial ones — each `MultiplayerSynchronizer`/`Spawner` is a
real node with per-node overhead, so 100 of them is a different cost profile
than one system managing 100 logical entities. This is the generic
"ECS vs scene-tree" tradeoff, not something unique to Godot's networking.

**Takeaway for RogueNet:** built-in replication nodes are usable at
~100-entity scale, but not free-by-default — the interval knobs need to
actually be tuned down from their "as fast as possible" defaults, and
`spawn_limit` is the only hard guard rail Godot gives you against runaway
spawn counts.

## 2. Interest management / spatial partitioning — is there a built-in pattern?

Yes — **this is a real, shipped Godot 4 feature**, not something the
community has to hand-roll from scratch, though you still have to wire it up
yourself. It's built directly into `MultiplayerSynchronizer`:

- `public_visibility` (default `true`) — when set `false`, the node isn't
  synced to a peer unless explicitly made visible to them.
- `set_visibility_for(peer, visible)` / `get_visibility_for(peer)` — manual
  per-peer visibility control.
- `add_visibility_filter(callable)` — register a filter function
  `(peer_id) -> bool` for dynamic, rule-based visibility.
- `update_visibility(for_peer)` — apply filters, either for one peer or all.
([docs.godotengine.org — MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html))

A community writeup (Something Like Games, 2023) demonstrates the intended
pattern concretely: set `public_visibility = false` on the synchronizer, use
an `Area3D` (e.g. a cylinder trigger) with `body_entered`/`body_exited`
signals as the "area of interest," and call `set_visibility_for(peer_id,
true/false)` as players enter/leave range. The author explicitly credits this
as a real engine feature (implemented per a 2022 Godot proposal by Fabio
Alessandrelli, one of Godot's networking maintainers), not a workaround, and
notes it scales to WoW-style "sharding/layering" use cases. Caveat they flag:
their demo skips proper `CollisionLayer`/`CollisionMask` filtering "for
simplicity" — production use needs that configured correctly.
([somethinglikegames.de](https://www.somethinglikegames.de/en/blog/2023/interest-management-with-multiplayersynchronizer/))

The originating Godot proposal itself (status: **Implemented**, targeted at
the 4.0 milestone) frames the two standard approaches at a design level:
**distance/radius-based** filtering (simple, doesn't scale well with many
actors) vs. **grid-based** filtering (divide the world into cells, sync only
same/adjacent cells — more setup, scales much better). It doesn't mandate
either; Godot just gives you the visibility-filter hook and leaves the
spatial logic to you.
([github.com/godotengine/godot-proposals/issues/3904](https://github.com/godotengine/godot-proposals/issues/3904))

**Takeaway for RogueNet:** the "20 active near players / 80 dormant"
room-based idea maps cleanly onto `add_visibility_filter` + a room/proximity
check, using the grid- or room-based approach rather than raw per-NPC
distance checks against every player (cheaper as player count grows). This
would be new wiring work, not a missing engine feature.

## 3. AI LOD (reduced simulation for distant/dormant NPCs)

I could not find a Godot-specific, networked-multiplayer source describing
AI LOD directly — what's below is a single-player Godot forum thread, plus
my own extension of it to RogueNet's networked case (labeled).

A Godot forum thread on large 2D worlds with many NPCs is a real, concrete
data point on cost: one poster measured **400 fps down to 75 fps with 100
NPCs**, and identified `AnimationPlayer`s as the single biggest cost, ahead
of physics and state machines. Suggested mitigations from responders:
- A three-tier system: **visible** (simulate + render), **close** (simulate,
  don't render), **far** (don't simulate, don't render).
- Staggered/throttled updates for off-screen NPCs — e.g. update distant NPCs
  once per second instead of every frame, applying accumulated delta time
  rather than per-frame ticking.
- The OP built a "Simulation" manager node that tracks last-update time per
  NPC and drives the throttling.
([forum.godotengine.org — "Large 2D game world and npcs"](https://forum.godotengine.org/t/large-2d-game-world-and-npcs/81792))

This thread is explicitly single-player — no networking is discussed. **My
own extension (reasoning, not sourced):** in a networked context this same
three-tier idea maps onto §2's visibility filters almost directly — "far"
tier = not simulated *and* not networked at all (no synchronizer traffic,
no AI tick), "close" tier = simulated (cheap logic, maybe just idle/patrol)
but not necessarily synced if no player has visibility yet, "visible/active"
tier = full behavior logic + full sync rate. The throttled-update technique
(accumulate real time, tick occasionally) is a reasonable way to keep the 80
"dormant" NPCs cheap without literally freezing them (e.g. still patrolling
slowly, so they don't all look frozen mid-animation when a player wanders
into range) — but this is game-design/architecture reasoning on my part, not
something I found documented for a multiplayer Godot game specifically.

## 4. Concrete precedent: a shipped/in-progress Godot multiplayer game with networked enemies

I found one directly relevant, real precedent: **Blastronaut**, a
co-op mining game built in Godot with GodotSteam networking. Their devlog
"Networking Synchronization for Enemies" describes:

- **Host-authoritative, not dedicated-server**: "One of the players who
  hosts the game is the only one who actually generates all the enemies and
  sends corresponding packets to other players" — i.e. exactly RogueNet's
  local-or-server model, not a separate always-on process.
- **ID-indexed array, not per-entity scene nodes for sync**: enemies are
  tracked by array index (enemy ID = array position), with missing/delayed
  entries represented as zero rather than causing desyncs.
- **Non-deterministic movement + periodic reconciliation, not full-tick
  replication**: "the host sends periodic update messages... while the
  enemies are allowed to move by themselves, they are still periodically
  corrected" — roughly once per second, rather than every physics frame.
- **Explicitly hand-rolled over raw packets, not `MultiplayerSynchronizer`**:
  the dev describes GodotSteam's networking as "quite limited — I can just
  send packets between the connected players and that is all," implying
  this was built on raw RPC/packet relay rather than the high-level
  replication nodes.
- No entity-count figures, no interest-management/culling system, and no
  bandwidth numbers are given in the devlog — it's a solo/small-team
  cooperative game, and the author explicitly notes they're sidestepping
  anti-cheat concerns "common in competitive games" since it's co-op only.
([perfoon.itch.io — Blastronaut DevLog 10](https://perfoon.itch.io/blastronaut/devlog/336932/devlog-10-networking-synchronization-for-enemies))

This is a fairly good precedent for RogueNet specifically *because* it's the
same non-dedicated, host-is-a-player model and the same "periodic correction
over raw RPCs" shape RogueNet's existing `report_position`/`receive_position`
code already uses for players — it's evidence that hand-rolled periodic-sync
is a workable, shipped-adjacent pattern at this model, not just a stopgap.
I did not find a GDC talk, postmortem, or larger-scale (50-100+ concurrent
networked NPC) writeup for any Godot game — that specific precedent search
came up empty.

## 5. Interaction with RogueNet's non-dedicated ("local-or-server") model

This is the point worth being most careful about, since most Godot
networking material defaults to a generic "the server" framing that reads as
dedicated-server-shaped even when it isn't.

**Confirmed: Godot's high-level multiplayer API is not dedicated-server-only
by design.** The official networking docs state "the server's ID is always
1, and clients are assigned a random positive integer," and explicitly cover
the case where "the server is also a player" (`call_local` guidance for that
case), plus running a server and client in one Godot instance
simultaneously. Dedicated/headless server export is presented as an optional
deployment choice on top of this, not a requirement.
([docs.godotengine.org — High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html))

That means `MultiplayerSpawner`/`MultiplayerSynchronizer` and the
visibility-filter interest-management pattern in §2 aren't blocked by
RogueNet's local-or-server model — "the authority" for NPC spawning/sync
just needs to be *whichever peer is acting as peer 1 that session* (the
Steam P2P host, or the up-to-50-player "dedicated" mode's host process),
same as it already is for players today. Nothing in what I read assumes a
separate always-on machine.

**Flagging a real mismatch, not glossing over it:** most tutorials and the
interest-management blog in §2 are written and demonstrated against a
conventional client/server topology where "the server" is implicitly
long-lived and trusted. Blastronaut (§4) is the one source that actually
matches RogueNet's shape — host-is-a-player, non-deterministic movement,
periodic correction — and notably, they did *not* use the built-in
replication nodes, they hand-rolled it, similar to RogueNet's current
approach. I don't have a source confirming *why* they chose that, so I'm not
going to claim it proves built-in replication is unsuitable for
host-as-player setups — the docs in this same section confirm the nodes do
support that topology. It may simply be that Blastronaut predates broad
adoption of those nodes, or the dev preferred manual control. Worth noting
as an open question rather than resolved either way.

## Where this leaves us

- **`MultiplayerSynchronizer`'s built-in visibility-filter system is real and
  fits the "20 active / 80 dormant" idea well** — this is the most
  actionable finding. It's not automatic; RogueNet would still need to
  build the room/proximity logic that drives `add_visibility_filter`, but
  the engine hook already exists and doesn't require a dedicated server.
- **Bandwidth is not automatically fine even for "static" spawn-only data**
  — a confirmed engine bug/behavior means the interval settings need
  deliberate tuning rather than trusting the defaults, especially once ~100
  entities are in play.
- **AI LOD (reduced-tick dormant NPCs) has no networked-Godot source** — the
  single-player forum thread's three-tier pattern is a reasonable design to
  adapt, but treat that adaptation as our own design work, not "engine best
  practice," when discussing it with the team.
- **Blastronaut is the one real precedent for RogueNet's exact hosting
  shape** (host-is-a-player, periodic correction, hand-rolled over raw
  packets) — but it's a single small-team devlog, not a rigorous
  case study, and it doesn't give entity-count or performance numbers to
  benchmark against.
- **No source answers the actual scaling question at RogueNet's target
  numbers** (~100 NPCs, up to 50 players in "dedicated" mode) — nothing
  found tests or reports on that combination specifically. That gap should
  be closed by prototyping, not more searching: a small test scene with
  MultiplayerSynchronizer + visibility filters driving, say, 100 dummy NPCs
  and a handful of simulated peers would tell us more than further research
  would at this point.

**Suggested next concrete step:** prototype `MultiplayerSynchronizer`
visibility filters on a small NPC count first (proves the interest-management
wiring works and is cheap to build), independent of deciding whether to
migrate player position sync off the current RPC relay — those are separable
decisions, and the visibility-filter pattern works the same way regardless of
which one players end up using.
