# Steam Integration — Open Questions & Notes

Reference material, not a rules file — same deal as `design-goals.md`.
Read this when Steam/netcode work comes up; point Claude at it directly
if needed. This is a *living* doc: update it as decisions get made
instead of leaving stale entries.

## Status: Steam Sockets prototype validated
Host → Join → bidirectional chat over `SteamMultiplayerPeer` (GodotSteam)
has been tested successfully between two separate machines, using
AppID 480 ("Spacewar") and a manual paste-your-SteamID flow (no lobby).
Confirmed working:
- `Steam.steamInit(480)` + `Steam.run_callbacks()` in a `SteamManager`
  autoload (`singletons/SteamManager.gd`)
- Hosting via `SteamMultiplayerPeer.create_host(0)`
- Joining via `SteamMultiplayerPeer.create_client(steam_id, 0)`
- `multiplayer.peer_connected` firing correctly on both ends (host sees
  the joiner's real peer ID, joiner sees ID `1` for the host, as expected
  by Godot's multiplayer convention)
- A basic `@rpc("any_peer", "call_local")` chat message reaching both
  peers

This was built as a throwaway prototype in `scenes/ui/MainMenu-tmp.tscn`
/ `scripts/MainMenu.Lobby.gd`, separate from the real `MainMenu.tscn`
(which a teammate was building UI for concurrently). Transport choice is
no longer purely theoretical — Steam Sockets is now a proven option, not
just a plan.

## What's confirmed so far
- The game will be published on Steam eventually.
- Steam does **not** require any specific netcode to publish — using
  Steam's own networking is a choice, not a store requirement.
- Two separate integration layers exist and shouldn't be conflated:
  1. **Netcode/transport** — ENet vs. Steam Networking Sockets vs. WebRTC.
     Optional which one you pick.
  2. **Steamworks baseline** (AppID, `SteamAPI_Init` equivalent,
     `run_callbacks` every frame) — needed for *any* Steam-facing feature
     (overlay, friends list, achievements, lobbies), effectively required
     if the multiplayer flow leans on Steam friend invites.
- Steam Workshop (mod/UGC distribution) is a **separate, unrelated**
  system from netcode. Not currently planned per `CLAUDE.md` (no mod
  support mentioned) — don't assume it's needed unless someone confirms
  it.

## Testing plan (no publishing required)
- Use Valve's shared test AppID `480` ("Spacewar") for early prototyping
  of Steam Sockets/lobbies — free, no Steamworks partner account needed.
  Caveat: it's a shared ID used by every dev worldwide testing
  Steamworks, so test lobbies aren't private to just the team.
- Registering our own AppID (Steamworks partner account, one-time fee)
  is only needed once we want features tied specifically to our app
  (real achievements, our own persistent lobby data, etc.), and can
  still be done long before any public release — an app can sit
  unlisted indefinitely with zero store obligations.
- Confirmed: staying unpublished/in-house does not create any Steam
  distribution/store requirements. Those only start applying once a
  store page or public build goes out.

## Open decisions (not yet made)
- **Transport**: Steam Networking Sockets (via GodotSteam or
  `steam-multiplayer-peer`) vs. plain ENet + relay. Leaning toward Steam
  Sockets to sidestep NAT/port-forwarding, but not locked in.
- **GodotSteam vs. lighter alternative**: full GodotSteam (adds lobbies,
  matchmaking, achievements, etc.) vs. `steam-multiplayer-peer`
  (Steam Sockets only, no lobby dependency, smaller surface area).
- How this interacts with the still-unresolved "local-or-server,
  Terraria-style" hosting model in `design-goals.md` — whichever
  transport is picked needs to fit that model, not the other way around.
- Whether/when to register a real Steamworks AppID vs. continuing on the
  shared test AppID.

## Next steps
- Decide whether to keep the prototype logic in the throwaway scene or
  merge the host/join flow into the real `MainMenu` once its UI settles.
- Still open: GodotSteam (full) vs. the lighter peer-only wrapper — the
  prototype didn't need lobbies at all, so that decision remains
  unforced either way.
- Still open: how this fits the "local-or-server, Terraria-style"
  hosting model from `design-goals.md`.
- Register a real Steamworks AppID once ready to move past AppID 480.
