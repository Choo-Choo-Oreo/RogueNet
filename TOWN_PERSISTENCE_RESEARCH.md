# Town Persistence — Research Notes

## The problem
Right now RogueNet has exactly one `multiplayer_peer` per play session, hosted
by whoever clicked "Host" (always peer 1). Every player — town and dungeon
alike — rides on that one connection. If that host's game closes or crashes,
the whole session ends for everyone, town included. There's currently no
separate "town server" that outlives any individual player's game window.

## Does Godot support a real dedicated server, like Minecraft? (corrected)
Partially — and the gap is specifically on the Steam side, not Godot's.
Minecraft's "Open to LAN" mode is exactly RogueNet's current host model (a
player's own client also acting as server). Minecraft's *dedicated server*
is the same server code running headless, no player attached.

Plain Godot supports that pattern fine — you can export a **dedicated
server build** or run `--headless`, no problem. But we don't use plain
Godot networking, we use **GodotSteam's `SteamMultiplayerPeer`**, and its
own docs say directly: *"GodotSteam's server builds do not contain any
MultiplayerPeer functionality. It is in the works though."*
([godotsteam.com/tutorials/multiplayer_peer](https://godotsteam.com/tutorials/multiplayer_peer/))
The tutorial's whole framing assumes "the server is just another player."

There is a separate **GodotSteam-Server** build with a real dedicated-server
API (`SteamGameServer.logOn()` / `logOnAnonymous()`, matching Valve's
[Game Server Login Token](https://partner.steamgames.com/doc/webapi/IGameServersService)
system — a persistent, account-less server identity), but that's for
auth/matchmaking/server-browser plumbing. It doesn't currently wire into
`SteamMultiplayerPeer`, so it doesn't get us actual headless P2P gameplay
networking today. So: not a deployment problem we can solve with a spare
machine — it's an upstream feature GodotSteam hasn't shipped yet.

## The "one main scene, everyone's a branch" idea
This is worth taking seriously — it's actually the shape a persistent-world
server usually takes, and it's *not* what we're doing today. Currently,
starting a mission does `get_tree().change_scene_to_file(...)`, which
replaces the entire scene tree, including on the server if the host is a
mission member. That's a full swap, not a branch.

The alternative: the server keeps one root scene loaded permanently (the
town) and never calls `change_scene_to_file` itself. A dungeon run becomes
an *instanced sub-scene added as a child* of that persistent root, not a
scene replacement. Each client still locally decides what to *show* — town
UI vs. dungeon UI — but the authoritative game state on the server never
throws away the town to make room for a dungeon. This is closer to how
Minecraft, or any MMO-style server, actually works: the server's world never
"changes scenes," only individual clients' views do.

This pattern would also fix the `get_tree().current_scene.get_node_or_null(...)`
lookups sprinkled through `NetworkSync.gd` — those assume the server's
current scene is always the town, which is only true today because nothing
has broken it yet.

## Options, compared
1. **Stopgap (no new architecture)** — host simply can't start their own
   mission while acting as town host. Cheapest, but the host can never play.
2. **Dedicated headless server over Steam transport** — currently **not
   available**: `SteamMultiplayerPeer` has no headless/dedicated-server
   support yet (confirmed above). Not a "buy a VPS" problem, it's blocked
   until GodotSteam ships it. Worth periodically checking their changelog,
   not worth building around now.
3. **Dedicated server on a non-Steam transport** — run the persistent town
   process on plain `ENetMultiplayerPeer` instead of Steam's relay, using
   Steam only for identity/names/friends as we do now. This *is* achievable
   today, but it gives up Steam's automatic NAT traversal — whoever runs the
   box needs a forwarded port or a real reachable address, which is exactly
   the hosting hassle Steam's relay was originally picked to avoid.
4. **Persistent root + branch instancing** — server never swaps scenes;
   dungeons are instanced children under an always-on town root, instead of
   `change_scene_to_file` blowing away the tree. Fixes the underlying
   `current_scene`-lookup assumption everywhere in `NetworkSync.gd`, and is
   transport-agnostic — it helps regardless of which of the above we pick,
   including the current listen-server model. Biggest rewrite of the four.
5. **Host migration** — promote another peer to host if the original
   leaves. No engine support for this in Godot; would need to be hand-built,
   and only solves "host disappears," not "host wants to also dungeon-dive."

## Where this leaves us
(2) is off the table until GodotSteam catches up — that was the main thing
worth actually verifying instead of assuming. Of what's left, (4) is the
one worth doing regardless of the others, since it fixes a real bug pattern
today and doesn't lock us into a transport decision. (3) is the only path
to a truly host-independent town on Steam right now, but it trades away
the "no port forwarding" reason we're on Steam networking in the first
place, so it's worth being deliberate about before committing to it. (1)
remains the cheap holding pattern if we'd rather not decide yet.
