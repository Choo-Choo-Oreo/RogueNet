# RogueNet folder structure (2026-09-24)

Folders only: the finished layout, with nothing left over from the old one. A few folders in
the tree are planned and do not exist yet (`game/biomes/`, `resources/sfx/entities/`, the
boss and protagonist `ai/` folders). A proposal for
where everything lives so new systems have an obvious home. Every step of the move order is done (see
below); what is left is splitting the minion controller by team and driver, the last hit
routing, and the open decisions at the bottom.

## Rules behind the layout

1. **Mirrored layout.** The content folders have the same path in `scenes/`, `scripts/`,
   `game/` and `resources/`. Find the sprite and you know where the data and the script are.
   Systems folders (the shared body code, actions) have no art or data, so they exist only
   under `scripts/`. It is a convention for content, not a law for every folder.
2. **It is a tree: stay within your family.** A folder may use its own files, its children,
   and the shared files of its parents. It does not reach into siblings or cousins. If two
   siblings need the same thing, it moves up to their parent. The exceptions are the
   foundation layers, which any script may call and which never call back:
   the autoloads in `singletons/` (global), and `scripts/cells/` (the map's data: what is
   in each cell). Bodies tell `cells` what they are; `cells` never goes looking through
   the bodies.
3. **Team first, driver inside.**
   - **Team** (protagonist or antagonist) says what a body can do and how it acts: its
     capabilities, its targets, its privileges. It is the outer folder, and it decides
     data, art, sound and scenes.
   - **Driver** (AI or player) says what controls the body. It is a folder inside the team.
     Either driver can drive either team: an AI protagonist (party fill-in, bot) and a
     player-driven antagonist (play the monster) both exist.
   - What two folders share sits in their parent. Shared by both drivers of one team: the
     team's root. Shared by both teams: the `entities` root.
4. **One body, many drivers.** Movement, health, stats, animation and gear are shared by
   every creature and sit at the `entities` root. A boss and a player-controlled antagonist
   are the same entity; only the driver differs.
5. **A driver sends intents, the body executes.** The driver asks for "step this way" or
   "use this action"; it never moves the body itself. Swapping the driver then changes one
   thing. The driver is a fixed part of the body that gets configured; it is not swapped by
   replacing a node at runtime, because RPC paths must match on every peer.
6. **Authority follows the driver, not the team.** A player-driven body is authoritative on
   its own peer; an AI-driven body is authoritative on the host. Targeting keys on team,
   never on "is a player" or "is a minion".
7. **Data describes, scripts execute.** Content is JSON in `game/`; a script only knows how
   to run a kind of thing.
8. **Host authority for shared state.** Damage, tiles, spawns and doors are decided on the
   host in one place and applied on every peer in another.
9. **Subject first, `<parent>.<family>` folder names** (`entities.antagonist`).
10. **Every folder in `game/` has its own README.** It is an explanation for anyone making
    content (including workshop users): what the folder's files do, the format, what can and
    cannot happen. It is documentation, not a tracker, so it describes how things work
    rather than what is left to do.
11. **Do not create a folder until it has enough in it.** A team's `ai/` and `player/`
    folders start as plain files in the team folder and become folders when they grow.

## The tree

```
RogueNet/
 ├── docs/
 ├── singletons/
 ├── addons/
 ├── build/
 │
 ├── scenes/
 │    ├── entities/
 │    ├── dungeon/
 │    └── ui/
 │         ├── protagonist/
 │         ├── antagonist/
 │         └── town/
 │
 ├── scripts/
 │    ├── entities/
 │    │    ├── entities.senses/
 │    │    ├── entities.projectiles/
 │    │    ├── entities.protagonist/
 │    │    │    ├── ai/
 │    │    │    └── player/
 │    │    └── entities.antagonist/
 │    │         ├── bosses/
 │    │         │    ├── ai/
 │    │         │    └── player/
 │    │         └── minions/
 │    │              └── ai/
 │    │
 │    ├── actions/
 │    │    └── verbs/
 │    │
 │    ├── cells/
 │    │    └── tiles/
 │    │
 │    ├── dungeon/
 │    ├── items/
 │    ├── ui/
 │    │    ├── protagonist/
 │    │    ├── antagonist/
 │    │    ├── inventory/
 │    │    └── town/
 │    ├── settings/
 │    ├── debug/
 │    └── util/
 │
 ├── game/
 │    ├── entities/
 │    │    ├── entities.protagonist/
 │    │    ├── entities.antagonist/
 │    │    │    ├── bosses/
 │    │    │    └── minions/
 │    │    └── entities.projectiles/
 │    ├── actions/
 │    ├── items/
 │    │    └── back, chest, feet, gloves, head, legs, main_hand, neck, off_hand
 │    ├── tiles/
 │    ├── rooms/
 │    │    └── acid, catacomb, cathedral, cave, dungeon, fallback, flesh, forest,
 │    │        manor, mine, ruins, sewer, void, volcano
 │    ├── doors/
 │    └── biomes/
 │
 └── resources/
      ├── gfx/
      │    ├── entities/
      │    │    ├── entities.protagonist/
      │    │    ├── entities.antagonist/
      │    │    │    ├── bosses/
      │    │    │    └── minions/
      │    │    └── entities.projectiles/
      │    ├── gear/
      │    │    └── one folder per slot
      │    ├── effects/
      │    ├── tileset/
      │    ├── doors/
      │    ├── objects/
      │    ├── ui/
      │    ├── placeholders/
      │    └── fallbacks/
      ├── sfx/
      │    ├── entities/
      │    │    ├── entities.protagonist/
      │    │    ├── entities.antagonist/
      │    │    │    ├── bosses/
      │    │    │    └── minions/
      │    │    └── entities.projectiles/
      │    ├── effects/
      │    ├── ambiance/
      │    └── music/
      └── shaders/
```

## What each folder is for

**`docs/`** Trackers, research notes, this file, the to-do list. Nothing the game loads.

**`singletons/`** Autoloads only: things that must exist before any scene and survive scene
changes. Networking is mostly their job: `NetworkSync` is the single door for multiplayer
and holds every RPC (an autoload exists at the same path on every peer, which an RPC
needs). Systems keep their own "host decides" and "everyone applies" functions in their own
scripts and `NetworkSync` only carries the messages, so there are no per-script networking
files. If it grows too big, it splits by domain into a few autoloads. A singleton that
starts holding game rules belongs in `scripts/`.

**`scenes/entities/`** Node layout. One shared creature scene, so a boss, a player and a
player-driven antagonist are literally the same scene, configured with a different driver.
Projectile and effect scenes live here too. Wiring only, no rules.

**`scenes/dungeon/`, `scenes/ui/`** The dive and room-maker scenes; menus, HUD, and the
`town/` screens; the HUD split by team as in `scripts/ui/`.

**`scripts/entities/` (its root)** The body every creature shares: stepping on the grid,
footprint, health, stats (including stamina), animation, worn gear, the effect of the
terrain it stands on, the small position relay and player lookup, and the shared
mechanisms the drivers use (reading input, turning senses and pathing into intents). They
sit at the root because everything else calls them most. A change here affects players,
rats and the Minotaur alike, so the collision rule ("can this body stand on this tile",
including no floor = blocked) lives here once, and so do the rules that belong to the body
itself, such as a boss walking through minions. Sprinting is movement, so it lives here too.
The character save (`CharacterSave`: files, listing, the fields every character has) is here
as well; each team's own save sits in its folder (`ProtagonistSave`, `AntagonistSave`).

**`scripts/entities/entities.senses/`** How an AI notices things. Only AI drivers use it.

**`scripts/entities/entities.projectiles/`** What a projectile does in flight.

**`scripts/entities/entities.protagonist/`** What a protagonist can do and how it acts:
its capabilities, who it targets. Its root holds what both drivers share. `ai/` holds what
an AI-driven protagonist decides on its own (a bot, a party fill-in); `player/` holds what
input-driven play needs.

**`scripts/entities/entities.antagonist/`** The same for antagonists. Its root holds what
every antagonist shares. `bosses/` holds what bosses share (phases, the boss zone, walking
through minions), with `ai/` for an AI boss and `player/` for a player-driven one.
`minions/` holds what minions share (swarming, surrounding, yielding to a boss). Minions
are not expected to be player-driven, so there is only `ai/`; a `player/` can be added if
that changes.

**`scripts/actions/`** Everything a creature can do on purpose. An action has a
**category** (melee, ranged, spell, skill) that decides how it is paid for: melee is free,
ranged costs ammunition, spell costs magic (the magic system comes last), skill costs
stamina. The category is a data field on the action, not a folder, so one projectile verb
can be a bow shot (ammo), a wand shot (magic) or a minion's free attack. The shapes an
action can cover (circle, line, later cone and ring) are one shared file at the root of this
folder, since a shape is only math. Costs are not laid out yet: an area can carry a cost of
its own, so where it belongs is undecided.

**`scripts/actions/verbs/`** One small script per verb: melee hit, projectile, destroy
tiles, heal, summon. A verb takes a caster, a target and the numbers from data, and does
one job. Host decides, every peer shows it. The Minotaur's wall smash is a verb here; it
changes tiles but it is not tile code.

**`scripts/cells/`** The map's data: what each cell holds and knows. That is what is in it
(a creature, a door, a wall, floor or no floor), the scent trail, and the light. Because it
is the data that spreads from cell to cell, the flooding lives here (light flood, sound
spread, flow fields, pathfinding, line of sight), and later ongoing spreading
(liquid, fire) would join it. It is a foundation layer: entities and dungeon code ask it
questions ("what blocks a step here?", "who is standing here?"), and it never calls back
into them. Bodies register themselves into it, so it does not scan the creature groups.
This is where the one "can this body stand here" answer is meant to sit.

**`scripts/cells/tiles/`** The tile meshing and the two tile grids (the tile world grid
and the dual mesh grid): placing tiles, coordinating the two grids, and drawing them. That
is the tile types and registry, the renderers, and the shaders they use, including the
light map that draws the lighting onto the tiles. It focuses on placement and appearance,
not on storing data; anything a cell has to remember belongs in `cells/` itself.

**`scripts/dungeon/`** One dive: assembling and painting it, placing doors, minion spawning (`MinionSpawning`),
spawning the party into the dungeon (the player spawner, a small script with no RPC of its
own), and the Maker tool.

**`scripts/items/`, `scripts/ui/`, `scripts/settings/`, `scripts/debug/`, `scripts/util/`**
Item data lookup (loot and rarity later); menu and HUD scripts, including the lobby menu,
with `inventory/` and `town/`. A player-driven adventurer and a player-driven antagonist see
different screens, so a HUD piece only one side uses goes in `ui/protagonist/` or
`ui/antagonist/` (scripts and scenes alike); what both use (prompts, chat, pause menu)
stays in `ui/`. Options controls; developer tools; small helpers with no
game knowledge.

**`game/entities/`** One JSON per creature, same format for both teams. Under
`entities.antagonist`, `bosses/` holds the big ones and `minions/` the subordinate ones; the
folder decides whether a creature is a boss; there is no `boss` field.

**`game/actions/`** One JSON per action: its category, verb, range, shape, numbers. Two
creatures using wall smash share one entry.

**`game/tiles/`** One JSON per tile: category, terrain difficulty, breakable or not, and
what standing on it does (damage, damage type, other effects).

**`game/items/`, `game/rooms/`, `game/doors/`, `game/biomes/`** Equipment by slot; room
pieces by biome; door types; what each biome uses.

**`resources/gfx/entities/`, `resources/sfx/entities/`** Art and sound for every creature,
in the same folders as `game/entities/`. Animation JSON stays beside its PNGs.

**`resources/gfx/effects/`, `resources/sfx/effects/`** Hit and cast visuals and sounds,
grouped by damage family, so a damage type has both a look and a sound.

**`resources/gfx/gear/`** The sprites of worn equipment, one folder per slot, in the same
slots as `game/items/`.

**`resources/gfx/tileset/`, `doors/`, `objects/`, `ui/`** The art for the tile sheets, door
parts, placed objects (graves and so on) and the interface.

**`resources/gfx/placeholders/`, `fallbacks/`** Stand-in art for content that has none yet
and the image used when a real one fails to load. Nothing final lives here.

**`resources/sfx/ambiance/`, `music/`** Looping background sound per place, and the music
tracks. (Creature and effect sounds are under `sfx/entities/` and `sfx/effects/`.)

**`resources/shaders/`** Shader code; where it belongs is open.

**`addons/`** Third-party plugins (GodotSteam and others). Not edited by us.

**`build/`** Exported builds. Nothing in the game reads it.

**`scripts/debug/`** Also holds the body sweep: twice a second it checks that no creature
overlaps a wall, void or no-floor tile, and writes a log line saying how it got there.

## Known gaps this structure is meant to close

Found by a read-only scan of the code (three agents, 2026-09-24):

- **Collision is decided in at least seven places** (the grid mover, the light map, spawn
  fit, tile destruction, the painter and others), and they disagree: the grid mover blocks
  only wall and void, while the light map and spawn fit also block cells with no floor. That
  is the leading suspect for the Minotaur and the player walking into walls (not confirmed).
  It belongs at the `entities` root behind one "can this body stand here" question.
- ~~**The player and minion controllers were near-parallel copies**~~ CLOSED for attacks
  (2026-09-24): the shot, hit, taunt and wall-smash code is now in `scripts/actions/verbs/`,
  used by both. Movement and animation are still per controller.
- **Team-specific behaviour is mixed into `MinionController`** (boss yielding, surround,
  boss privileges), and bosses share it. Splitting it into the team and driver folders is
  still to do.
- **Flow fields are keyed by target only**; they need body size.
- **Damage effects are not defined yet:** neither the visuals nor the sounds for damage
  types, and creature sounds generally.
- Status effects (burning, poison) have no home yet.

## Problems the layout does not solve on its own

- **The grid mover reaches into the door registry and tile types, and `cells` reads player
  ghost state and team groups.** With `cells` as the foundation layer, the direction is
  fixed (entities ask `cells`), but the reverse reach-ins have to go: ~~the light map's ghost
  check~~ (closed 2026-09-25: bodies register a `Viewer` in `scripts/cells/Viewer.gd`, which
  `LightMap` and `PlayerVision` read), ~~the surround sectors' group scan~~ (closed 2026-09-25:
  it is minion AI, moved to `entities.antagonist/minions/ai/`), and ~~the occupancy index in the grid mover~~ (closed
  2026-09-25: `scripts/cells/Occupancy.gd`, bodies register an entry and mark it not solid as
  a ghost). Still to move: the door registry (doors are interactables a
  cell knows about: position, open or closed); placing doors during generation stays in
  `dungeon`. Other placed objects (graves, chests) follow the same rule once they exist.
- **The network singleton finds bodies by node path** (`Player/<id>`, `Minions/<id>`) and
  the team groups double as "is a player". A player-driven antagonist needs an owner field
  (peer id) separate from the team, and bodies addressed by id. Undesigned.
- **Position from a peer is trusted** with no wall check (see the to-do list).

## Suggested order for the moves (from the dry scan)

Godot's editor rewrites `.tscn`, `.import` and `uid` references on a move, but not the
sprite paths inside JSON (about 121 of them) or path constants in scripts. Each step gets a
playtest of a dive (host, join, spawn, fight, use an ability) before the next:

Steps 1 to 6 are DONE (2026-09-24, not yet playtested in Godot): lobby menu and spawner,
single files, `scenes/entities/PlayerController.tscn`, player data and art under
`entities.protagonist`, recursive `MinionIndex`, enemy data and art in `bosses/` and
`minions/` (the boss is decided by the folder, the `"boss"` field is gone).

1. ~~Move the network scripts folder (the lobby menu and spawner).~~
2. ~~Move single files (the shapes file, the small helpers).~~
3. ~~Move `scenes/player`.~~
4. ~~Move the player art and data, with a script fixing the JSON sprite paths.~~
5. ~~Make enemy lookup recursive (an id-to-path index) with no moves yet.~~
6. ~~Move enemy data and art into `bosses/` and `minions/`.~~
7a. ~~Move the two controllers into their team folders~~ DONE 2026-09-24: `PlayerController`
    is in `entities.protagonist/player/`; `MinionController` is in
    `entities.antagonist/minions/ai/` and still serves bosses too, until the boss and
    minion behaviour is split. `scripts/player/` and `entities.enemies/` are gone.
7b. ~~Sort the loose files~~ DONE 2026-09-24: `ProjectileController` in `entities.projectiles/`,
    `AttackEffect` and `ActionShapes` (was `AbilityShapes`) in `scripts/actions/`,
    `MouseFollowCamera` in `entities.protagonist/player/`, `MinionIndex` in
    `entities.antagonist/`. The shared body scripts stay at the `entities` root.
7c. Actions. DATA DONE 2026-09-24: `game/actions/` has one JSON per action (8 of them) with a
    README; creatures list `"actions"` ids with per-creature overrides, resolved by
    `ActionIndex`; the copied attack blocks are gone from 16 creature files (bite was in 10).
    ALL VERB SLICES DONE 2026-09-24, in `scripts/actions/`: every action file has a `verb`
    (`hit`, `projectile`, `destroy_tiles`, `taunt`); `ActionRunner` maps it to `verbs/HitVerb`,
    `ProjectileVerb`, `DestroyTilesVerb`, `TauntVerb`; `verbs/TileHit` is the one "damage what
    stands on this tile" (team from the caster's group, footprint-aware, ghosts skipped) and
    `AttackEffect.play_between` the one way to show an effect. Players and minions both call
    `ActionRunner`; the controllers keep only when and at what. NOT DONE: `TileHit._damage`
    still picks the RPC by target team, and the player keeps a separate taunt cooldown.
8. ~~Rename "enemy" to "minion"~~ DONE 2026-09-24 as one scripted pass over scripts, scenes,
   singletons, game data and the root README (about 330 files): every `enemy`/`enemies`
   became `minion`/`minions`, including the room JSON keys (`"minion"`, `"favored_minion"`)
   and the file names (`MinionController`, `MinionIndex`, `MinionSenses`, `MinionSpawning`).
   `docs/` history files were left with the old words. The boss uses `MinionController`
   until the boss/minion behaviour is split.

## Decisions (2026-09-24)

1. **Rename "enemy" to "minion"** in code and data. DONE, as step 8.
2. **"Actions", plural**, is the name (`scripts/actions/`, `game/actions/`). Godot's input-map
   "action" is a different thing; the folder path keeps them apart.
3. **Shaders stay on their own** in `resources/shaders/` for now.
4. **One editor pass** for the remaining moves, not one family at a time.
5. **Neutral tile query and body-id addressing** (see "Problems the layout does not solve"):
   accepted, to be designed when the code needs it.

## Open decisions

1. Where costs live, given an area can carry one.
2. Where status effects live once they exist.
