# RogueNet UI Audit

Date: 2026-09-25. Covers every screen a player sees, in the order they meet it, on
**keyboard + mouse** and on **controller**.

How it was made:
- All 15 UI scenes were rendered in Godot 4.7.2 at 1280×720 and screenshotted.
- The UI scripts, scenes and the input map were read end to end.
- **Nobody played the game for this audit**, so anything about feel still needs a playtest.

Tags:
- **[V]** verified in the files.
- **[L]** likely, but needs checking in-game.
- **(file:line)** where to look.

Rules this audit judges against (all already agreed):
- The HUD must work for keyboard + mouse **and** controller (controller map in the project memory / HUD mockup).
- Buttons stay on the same side of the screen across chained menus.
- No minimap, ever.
- No duplicated code or data.

---

## Contents

1. [The ten fixes that matter most](#the-ten-fixes-that-matter-most)
2. [Journey: launch to main menu](#1-launch-and-main-menu)
3. [Journey: characters](#2-character-select)
4. [Journey: multiplayer lobby](#3-multiplayer-lobby)
5. [Journey: town](#4-town)
6. [Journey: guild and mission party](#5-guild-and-mission-party)
7. [Journey: storage](#6-storage)
8. [Journey: in the dungeon (HUD)](#7-in-the-dungeon-hud)
9. [Journey: dying](#8-dying)
10. [Journey: ending the mission, leaving, quitting](#9-ending-the-mission-leaving-quitting)
11. [Journey: settings](#10-settings)
12. [Cross-cutting problems](#cross-cutting-problems)
13. [Suggested order of work](#suggested-order-of-work)
14. [Decisions needed from Orea](#decisions-needed-from-orea)
15. [Godot concepts worth learning for this](#godot-concepts-worth-learning-for-this)

---

## The ten fixes that matter most

Ranked by how badly a real player gets stuck or confused.

| # | Problem | Who it hurts | Size |
|---|---|---|---|
| 1 | **A controller can't get past the main menu.** No menu screen gives any button focus, so the D-pad and stick have nothing to move. | Controller players, completely | Small per screen |
| 2 | **"Paused" doesn't pause.** Monsters keep attacking behind the pause menu, even in singleplayer. | Everyone | Small |
| 3 | **Clicking a pause-menu button also swings your weapon**, and the HUD draws *on top of* the pause menu. | Keyboard + mouse | Small |
| 4 | **Keys and buttons that do two jobs at once**: Q = previous tab *and* consumable, E = next tab *and* interact, RT = next tab *and* attack, Space = attack *and* "press focused button", Tab = inventory *and* "next focus". | Both | Small to medium |
| 5 | **Back/Esc/B does something different on every screen** (nothing, opens pause, closes a menu, clears a search). | Both | Medium |
| 6 | **The guild/party flow is confusing**: "Back to Guild" leaves you in the party (you still get pulled into the dive), the host isn't in their own party, Ready doesn't gate anything, and the countdown only appears in chat. | Multiplayer | Medium |
| 7 | **Clients are never told what the host did**: start, end or leave all just teleport them, and a host leaving drops everyone to the main menu with no message. | Multiplayer clients | Small to medium |
| 8 | **Storage and inventory are mouse-only** (drag, right-click, double-click, hover tooltips), while the HUD shows controller prompts for them ("A Equip", "X Move") that do nothing. | Controller | Medium |
| 9 | **No death feedback**: when you die, your HUD simply vanishes. Nothing says "You died, spectating". | Everyone | Small |
| 10 | **Four different visual styles** (default grey menus, black lobby, purple inventory, grey/gold HUD) and developer text visible to players ("not built yet", "Dungeon Maker", "Player", an empty logo box). | Everyone (first impressions) | Medium |

---

## 1. Launch and main menu

**What the player sees** (screenshot): a grey button column pressed right against the
left edge of the screen, an empty grey box above it where a logo should be, and 80% of
the screen empty and near-black.

**What they want to do:** start playing (alone or with friends), pick an adventurer, change
settings.

### Keyboard + mouse
- [V] Buttons touch the screen edge (x = 0) with no margin, while every other screen has a
  16–20px gutter. It looks unfinished.
- [V] The **empty 220×220 logo box** (`MainMenu.tscn:41-43`).
- [V] **"Dungeon Maker"** is a main-menu button for every player (`MainMenu.tscn:65-68`). It is a
  team tool.
- [V] Esc does nothing here or in the sub-panels (Characters, Multiplayer, Options). Only the
  Back buttons work.
- [V] Sub-panels open *beside* the button column (at x = 280), and the column stays
  clickable. A player can open Options while Characters is showing.

### Controller
- [V] **Nothing has focus when the menu loads** (`MainMenu.gd:6-8`; the only `grab_focus`
  calls in all player UI are the two chat boxes and the inventory). A controller-only
  player can't select anything.

### Other
- [V] No warning that Steam is offline until you press Host/Join two screens later
  (`SteamManager.gd:15-16` only prints it).

### Direction
- Give Singleplayer focus when the menu loads.
- Add a margin, and a logo or title art.
- Hide Dungeon Maker outside debug builds.
- When a sub-panel is open, disable the main column (or take focus away from it).
- A small "Steam: offline" status line.

---

## 2. Character select

**What the player sees** (screenshot):
- A full-width, mostly empty list with one row, `Char1   (human, softcore)`.
- A name field with Create next to it.
- Play and Delete greyed out, then Back, along the bottom.

### Keyboard + mouse
- [V] **Play and Delete are greyed out with no hint why** (you must click a row first).
- [V] Row text shows raw ids: lower-case `human`, and `softcore`, which the game doesn't use
  yet (`CharacterSelect.gd:91`, `ProtagonistSave.gd:10`).
- ~~When opened from the main menu's Characters button, "Play" doesn't play.~~ Fixed 2026-09-25:
  the Characters button is gone; the screen opens from Singleplayer / Multiplayer and Swap Characters, and Play carries on.
- [V] The delete confirmation says the right thing (`:106`), but its buttons are Godot's
  defaults, "OK / Cancel". "OK" on a delete is risky wording.
- [V] It looks different from the other screens: title-case "Characters" at size 28 (others:
  capitals at 30), 120×40 buttons (others: 220×50), and buttons along the bottom instead of
  a left column.
- Nothing shows what the adventurer looks like.

### Controller
- [V] No focus on open, and **creating an adventurer needs typing** in a text field, which a
  controller can't do.

### Direction
- Focus the list.
- Pre-fill a default name, or use Steam's on-screen keyboard.
- Label the buttons for what they do ("Select" vs "Play", "Delete" on the dialog).
- Explain why a button is disabled, or pre-select the first adventurer.
- Show an adventurer preview (the inventory doll already exists).

---

## 3. Multiplayer lobby

**What the player sees** (screenshot):
- "MULTIPLAYER LOBBY" pressed against the left edge, on pure black (the main menu is dark grey).
- Your own 17-digit Steam ID in a grey text box, which reads like a disabled placeholder.
- A second box for the host's ID, then Host, Join and Back.

### What works
- [V] Error messages are good: offline Steam, bad IDs, your own ID, timeouts
  (`LobbyMenu.gd:61-67`, `:90-141`).

### Keyboard + mouse
- [V] **Joining means copying a 17-digit number** from a friend by hand. This is the single
  biggest friction point in multiplayer.
- [V] Info and errors share the same red colour.
- [V] Join isn't visibly disabled while a join is in progress; extra presses are silently ignored.
- [L] **Back while joining leaves the connection open.** The lobby node is freed but the peer
  isn't, so if the host answers, the player sits "connected" at the main menu and the host
  sees a nameless player (`:149-151`).
- [V] After you host, your Steam ID isn't shown anywhere else (town, pause). If you forgot to
  copy it, you have to leave.

### Controller
- [V] No focus on open, and joining needs typing.

### Direction
- Long term: Steam lobbies / "Join friend" through the Steam overlay, so nobody types an ID.
- Short term: show the Copy ID button in the town too.
- Make Back cancel a pending join.
- Grey out Join while joining.
- Use a neutral colour for info and red for errors.

---

## 4. Town

**What the player sees** (screenshot): a "TOWN" title with Guild, Swap Characters, Storage and
Leave. In multiplayer there's also a left sidebar (players, mute boxes, chat).

### Keyboard + mouse
- [V] **Esc opens Pause instead of going back.** On the Storage or Character panel, Esc puts
  Pause on top instead of returning to the town list.
- [V] **Leave is instant and unconfirmed. If the host presses it, everyone is dropped to the
  main menu with no message** (`MainTown.gd:92-95`, `NetworkSync.gd:61-64`).
- ~~"Swap Characters" opens a skin picker with one option.~~ Fixed 2026-09-25: it opens the same
  Characters screen (adventurers), so the word means one thing.
- [V] In singleplayer the sidebar hides but the buttons keep their 280px offset, so the left
  third of the screen is empty.

### Controller
- [V] No focus on any town panel.
- [V] The mute checkboxes are rebuilt every time someone starts or stops talking (`:75-76`),
  which would yank focus away mid-navigation.

### Direction
- Focus the first button on every panel.
- Esc/B goes back one panel, and opens Pause only from the main town list.
- Confirm Leave; the host's wording says it ends the session for everyone.
- Rename "Swap Characters" (e.g. "Appearance"), or hide it until there are more skins.
- Update mute boxes in place instead of rebuilding them.

---

## 5. Guild and mission party

**What the player sees** (screenshots):

The **Guild screen** (Create Mission on the left, Join Mission list on the right):
- [V] Players **never actually see it**. The game isn't in dedicated mode (`NetworkSync.gd:9`),
  so the Guild button jumps straight to the mission party screen (`MainTown.gd:79-84`).
  The button name promises a screen that never appears.
- If it ever comes back:
  - the empty list needs an empty-state message ("No missions yet: create one");
  - the password box shows even for public missions;
  - Join with nothing selected does nothing, silently.

The **mission party screen**:
- [V] The column order is upside down: "PICK LOCATION" + picker sit *above* the "GUILD MISSION" title.
- [V] **The host isn't in their own party.** The shared party is created with no members, and
  only whoever pressed Guild is added (`NetworkSync.gd:141-148`). A client who arrives first sees
  a list without the leader, and the host isn't told anyone is waiting.
- [V] **Ready doesn't gate the start.** Start begins a 10-second countdown that launches
  regardless; Ready only shortens it to 3 seconds (`:331-401`). Players will assume Ready matters.
- [V] **"Back to Guild" doesn't take you out of the party**, and it goes to the town, not the
  guild (`GuildMission.gd:73-83`). A player who backs out is still pulled into the dungeon at
  launch, **from whatever screen they're on, even Storage**.
- [V] Party updates force the mission panel open over whatever you're looking at
  (`NetworkSync.gd:821-823`). All town panels are transparent, so the two layouts overlap.
- [V] **The countdown, "cancelled" and "already started" messages only appear in chat.** The
  panel itself shows no countdown, and Start stays pressable (a second press does nothing).
- [V] Non-leaders see a greyed-out location picker with no explanation. Ready state is plain
  "(Ready)" text in a clickable list that does nothing when clicked.
- [V] A host who starts alone isn't warned that other players in town aren't in the party.

### Direction
- Rename the button to match what it does ("Party" / "Mission board"), or restore the Guild screen.
- Add the host to the party automatically.
- Make Back leave the party.
- Show the countdown in the panel, and turn Start into Cancel while counting.
- Either make Ready required, or label it "Ready (starts sooner)".
- "Only the leader picks the location" under the picker.
- Put all town panel switching in **one** MainTown function (see duplication below).

---

## 6. Storage

**What the player sees** (screenshot):
- A centred "STORAGE" title.
- Two purple panels: Inventory (doll, gear slots, 21-slot bag) and Storage (48 slots).
- A Back button centred at the bottom.

### Keyboard + mouse
- [V] Two hint lines say different things: "Drag, right-click or double-click to equip and
  unequip" vs "Drag gear onto your character, or right-click it" (`InventoryPanel.gd:196`,
  `StoragePanel.gd:66`). Pick one wording.
- [V] Item names only appear on mouse hover. You can't read what you're holding otherwise.
- [V] Back is centred, breaking the left-side button rule.
- [V] The "[debug] Populate…" buttons only show when run from the editor, which is correct.
  The doll's "< Human, front >" rotate control reads like a dev tool to players.
- The purple palette doesn't match any other screen.

### Controller
- [V] **Storage can't be used at all.** Moving items is drag / right-click / double-click only
  (`ItemSlot.gd:83-110`). Slots only become focusable inside the dungeon inventory, and the
  rotate arrows can't take focus.

### Direction
- A controller "pick up → move → place" flow: A picks up / places, X quick-moves between bag
  and storage.
- A details line under the grid for the selected slot, which also serves the mouse.
- One hint line.
- Back on the left.
- Decide the inventory's colours with Silvery Foxy (see Visual consistency).

---

## 7. In the dungeon (HUD)

**What the player sees** (screenshots):
- **Top-left:** player frame (empty portrait, the name "Player", "V Mic", red health bar).
- **Bottom-centre:** 10-slot hotbar with text names and an always-on "Space Attack · 1–0 Choose slot" hint.
- **Right of the hotbar:** a consumable box.
- **Bottom-right:** chat.
- **Bottom-left:** backpack / Character / Skills / Help / Menu buttons.
- Opening the inventory shows the tabbed game menu above them.

### Draw order and clicks (keyboard + mouse)
- [V] **The pause menu draws *under* the HUD.** It's the first child of `UILayer`
  (`Dungeon.tscn:312`), so the hotbar, health, chat and inventory draw over it and stay clickable.
  From Pause, Settings is partly covered by the chat box.
- [V] **Clicking a pause-menu or chat button also attacks.** The player script sees the click
  before the UI does, and only the inventory window is registered as "don't attack here"
  (`PlayerController.gd:284-305`).
- [V] **Pause doesn't pause.** There is no `get_tree().paused` anywhere.

### Game menu / inventory
- [V] **Only one tab is visible.** The tab bar is too narrow, so it shows "Inventory" plus two
  tiny scroll arrows; Character, Skills, Help and System are hidden (screenshot).
- [V] **Bug from Claude's HUD work: pressing LT/Q on the first tab wraps round to "System",
  which closes the menu and opens Pause** (`InventoryHud.gd:42-44,71-72`). Cycling forward past
  Help does the same.
- [V] Switching tabs with RT **also attacks**, and while the menu is open the right stick still
  walks and the left stick still aims (`InventoryHud.gd:71-74` doesn't mark the input as handled).
- [V] The controller prompts "A Equip / unequip" and "X Move" promise actions that don't exist yet.
- [V] The selected slot has no visible highlight on a controller, so you can't see where you are.
- [L] The stick can move focus from the bag into the chat box, and then the inventory ignores
  Y/B: a soft-lock.
- [V] The Character, Skills and Help buttons duplicate the tabs, and all three say "not built yet".
- [V] The consumable box has a brighter border than the active hotbar slot, so it reads as
  "selected" when it's actually the unbuilt placeholder.

### Player frame, hotbar, chat
- [V] The name is always "Player" (`set_player_name` is never called), and the portrait is empty.
- [V] The "V Mic" prompt shows in singleplayer, where voice chat does nothing.
- [V] HUD text is 10–14px (slot names 10px). That's fine at 1080p (scaled ×1.5) but small in a
  720p window. A UI-scale setting would cover it.
- [V] Hotbar slots show text names only, with no icons yet.
- [V] Chat: Enter opens it (not keypad Enter). **Clicking into the chat box freezes your
  character** until you press Enter, with no "typing" indicator. There's no way to chat on a
  controller.
- [V] **The debug menu ships in every build.** F4/F5 work in exports, and its overlay text
  (8,8) sits over the player frame (`Dungeon.gd:11`, `DebugMenu.gd:86-93`).

### Direction
- Move PauseMenu to the end of `UILayer` (or its own CanvasLayer), and register it and the chat
  as "no attack here".
- Pause the tree in singleplayer; in multiplayer call it "Menu" and block the player's input.
- Fix the tab bar width, and leave System out of LT/RT cycling.
- Hide unbuilt tabs and buttons.
- While the game menu is open, gameplay input stops (mark it handled).
- A focus border on slots, and keep focus inside the menu.
- Hide the mic prompt without voice chat, and call `set_player_name` with the adventurer's name.
- Only add DebugMenu when `OS.is_debug_build()`.

---

## 8. Dying

**What the player sees:** the health bar and hotbar disappear. That's all. The top-centre
countdown only appears once **every** player is dead.

- [V] A ghost among living teammates isn't told what happened or what they can do
  (`HealthBar.gd:34`, `Hotbar.gd:41-42`, `DeathCountdown.gd:26-36`).
- [V] On clients, the countdown can stall at "Returning to town in 0…" until the host's own
  timer fires.
- [V] The countdown is plain 18px red text with no panel behind it, and hard to read over bright tiles.

**Direction:**
- A "You died — spectating" banner (with what happens next).
- Give the countdown a HudPanel background.
- Clients show "Waiting for host…" at zero.

---

## 9. Ending the mission, leaving, quitting

- [V] **End Mission (host only) has no confirmation**, and clients are moved to town with no
  message.
- [V] A client's only way out of a dive is **"Main Menu", which leaves the whole session**,
  unconfirmed.
- [V] **A host pressing Main Menu ends the session for everyone**, silently.
- [V] Back in town there's no summary of the mission (what you found, who died).
- [V] There's no Quit to desktop except on the main menu.

**Direction:**
- Confirm destructive buttons, with host-specific wording ("This ends the mission / session for
  everyone").
- One reusable "notice" popup for clients: "The host ended the mission", "The host closed the
  session".
- Add Quit to the pause menu.
- A mission summary panel can come later with loot.

---

## 10. Settings

**What the player sees** (screenshot): five volume sliders with number boxes (0.5, 1.0…),
Fullscreen and VSync toggles pushed to the far right, and a full-width Back.

- [V] The "Voice Chat Volume" label is wider than the others, so its slider starts further
  right. The columns don't line up.
- [V] Volumes show as 0–1 decimals. **Typing 5 into a box boosts that sound bus to +14 dB**
  while the slider shows it maxed (`allow_greater = true`, `AudioControl.gd:25-30`).
- [V] The toggles sit 1100px away from their labels.
- [V] Esc from Settings closes the whole pause menu; Back doesn't return focus to where you came from.
- [V] No focus on open (controller can't use it).
- [V] Missing: key and controller bindings, UI scale, window size, and push-to-talk info.

**Direction:**
- A two-column grid (label | control) with a fixed label width.
- Show 0–100% and clamp it.
- Toggles next to their labels.
- Group into tabs (Audio / Video / Controls) when there's more.
- A read-only controls page is a cheap first step before rebinding.

---

## Cross-cutting problems

### A. Controller focus (the biggest gap)
- [V] No `grab_focus()` in MainMenu, Lobby, CharacterSelect, Settings, Pause, Town, Guild,
  GuildMission or Storage. No `focus_neighbor_*` anywhere.
- **Rule to adopt:** every screen and panel names its first-focus control, and when a sub-panel
  closes, focus returns to the button that opened it.

### B. One Back rule
The same Esc/B press today does different things:

| Screen | What Esc / B does |
|---|---|
| Main menu + sub-panels | nothing |
| Town panels | opens Pause |
| Dungeon game menu | closes it |
| Pause | toggles |
| Debug menu | clears the search |

**Rule to adopt:** Esc/B steps back one level; at the top level of a playable scene it
opens Pause; on the main menu it does nothing.

### C. Input bindings that clash

| Key / button | Actions bound to it | Clash |
|---|---|---|
| Q | `menu_tab_prev`, `use_consumable` | switching tabs could drink a potion |
| E | `menu_tab_next`, `interact` | switching tabs could open a door |
| X (pad) | `menu_move_item`, `use_consumable` | same, on controller |
| RT | `menu_tab_next`, `attack` | switching tabs attacks |
| Space | `attack`, Godot's `ui_accept` | attacking presses whichever button has focus |
| Tab | `inventory`, Godot's `ui_focus_next` | opening inventory also jumps focus |
| W A S D | `move_*`, and `ui_*` (arrow keys were removed) | walking moves menu focus; arrows no longer work in menus |
| Pad button 4 (View) / 5 (Guide) | also on `hotbar_prev` / `hotbar_next` | Guide is usually taken by the OS/Steam |

Also:
- [V] `move_*`/`ui_*` use the key's letter (`keycode`), while everything else uses the key's
  position (`physical_keycode`). On AZERTY that splits WASD from the rest.
- [V] `interact`, `use_consumable` and `menu_move_item` have **no code reading them yet**.
- [V] `debug_dungeon_layout` isn't read either (DebugMenu checks `KEY_F5` directly).

**Direction:**
- Gameplay and menu input shouldn't both fire: when a menu is open it marks input as handled,
  and gameplay ignores input while any menu is open.
- Put the arrow keys back into `ui_*`.
- Use `physical_keycode` everywhere.
- Drop the View/Guide buttons from the hotbar actions.

### D. Visual consistency
There are four styles today:
- Godot's default grey (menus, town, guild, settings);
- pure black (lobby, character select);
- purple (inventory, storage, hard-coded in `InventoryPanel.gd:18-21`);
- grey/gold (`resources/HudTheme.tres`, the HUD only).

Also:
- Titles vary: "MULTIPLAYER LOBBY" 30pt capitals, "Characters" 28pt title case, "Settings" centred,
  "TOWN" centred in its column.
- Error reds vary: `(1,.45,.4)`, `(1,.4,.4)`, `(1,.3,.3)`.

**Direction:**
- One project-wide Theme (set in Project Settings → GUI → Theme → Custom) that the HUD theme
  extends, so every screen gets it for free.
- Title, error and hint styles become type variations, not per-node overrides.
- The inventory colours are Silvery Foxy's call.

### E. Button placement
- Main menu: x 0–260.
- Lobby, Town, Guild, Mission: x 280–540.
- Storage and Pause: centred.
- Character select: along the bottom.

The agreed "keep buttons on the same side" rule isn't met. Either move everything to one left
column position, or write the exceptions (Pause and Storage centred?) into the rule.

### F. Duplication found
Per the no-duplication rule, these copies exist now:

- `_close_settings_panel` in both `MainMenu.gd:68-71` and `PauseMenu.gd:64-67`.
- The "hide parent + free self" Back pattern in `LobbyMenu.gd:149-151`, `SettingsMenu.gd:21-23`
  and `CharacterSelect.gd:137-139`.
- **Two chat implementations:** `MainTown.gd:37-46` (Send button, escapes `[`) and `ChatBox.gd`
  (no Send, bbcode off). They behave differently.
- `StoragePanel.gd:14-20` copies the purple frame style instead of calling
  `InventoryPanel.frame_style()`.
- Town panel switching by string node path in `MainTown.gd`, `GuildTown.gd:48-50`,
  `GuildMission.gd:79-91` and `NetworkSync.gd:821-823,877-880`. This is why party updates can pop
  panels over each other.
- The "is this the dungeon?" check in `PauseMenu.gd` and `VoiceChat.gd` (already in `docs/TODO.md`).
- `MainTown.gd:88-90` `_on_back_button_pressed` is dead code (nothing connects to it).

### G. Developer content visible to players
- "Dungeon Maker" on the main menu.
- The empty logo box.
- The "not built yet" tabs, buttons and pages.
- "Player" as the name.
- The debug menu (F4/F5) in exports.
- A developer tooltip on the town root (`MainTown.tscn:18`).
- The doll's "front" rotate label.

### H. Host vs client

| Action | Host | Client |
|---|---|---|
| Start mission | yes | no |
| Choose location | yes | picker disabled, no reason shown |
| End mission | yes, unconfirmed | no button, no explanation |
| Leave | ends the session for everyone, silently | "Main Menu" leaves everything |
| Told when the host starts / ends / leaves | — | no (teleported); only joins, leaves and the countdown reach them, as chat lines |

**Direction:** one small "notice" popup that NetworkSync can call on clients, and host-aware
wording on the buttons.

---

## Suggested order of work

Sizes: small = an hour or two, medium = a session, large = several sessions.

### S: blocks or breaks play
1. First focus on every screen + a focus border on buttons and slots (A). Small each, a
   good first task for learning Control focus.
2. Pause menu last in `UILayer`; pause and chat block attacks; real pause in singleplayer (§7). Small.
3. Menu input stops gameplay input; fix the LT/Q → System wrap and the tab bar width (§7, C). Small.
4. Fix the key clashes and put the arrow keys back into `ui_*` (C). Small, but it's Orea's input map.
5. Confirmations and client notices for Leave / End Mission / Main Menu (§4, §9, H). Medium.

### A: makes the core loop understandable
6. Party flow: host in the party, Back leaves it, countdown in the panel, Ready meaning (§5). Medium.
7. Death banner and countdown panel (§8). Small.
8. One Back rule (B). Medium, touches every screen.
9. Hide developer content (G). Small.
10. Player name on the HUD, mic prompt only with voice chat (§7). Small.

### B: polish and consistency
11. One project Theme; the HUD theme extends it (D). Medium, with Silvery Foxy for colours.
12. Button placement rule applied (E). Small once the rule is decided.
13. Settings layout, percentages, clamping; a read-only controls page (§10). Medium.
14. Merge the duplicated chat and panel-switching code (F). Medium.

### C: later, depends on other systems
15. Controller item handling in storage and inventory (§6). Medium to large; wait for the item system.
16. Steam lobby / overlay invites instead of typing IDs (§3). Large, touches the Steam layer.
17. Adventurer preview, icons in the hotbar, mission summary, UI scale. Each waits on art or systems.

---

## Decisions needed from Orea

1. **Pause in singleplayer:** freeze the game (recommended), or keep it running like multiplayer?
2. **What B does in play** (currently it opens Pause through Godot's default `ui_cancel`).
3. **Keyboard keys for interact and consumable:** E and Q both clash with tab switching. Move the
   tab keys (e.g. to `[` / `]`, or Ctrl+Tab), or move interact/consumable?
4. **Ready:** required for start, or just "starts sooner"?
5. **"Guild" screen:** bring the Create/Join screen back, or rename the button to what it does now?
6. **Button placement rule:** everything in one left column, or are Pause and Storage allowed centred?
7. **One colour scheme:** grey/gold HUD, purple inventory, or something new (with Silvery Foxy).
8. **Dungeon Maker in release builds:** hidden, or kept as a player feature?

---

## Godot concepts worth learning for this

Most fixes above are small once these ideas click. The official docs pages:

- **Control focus**, `grab_focus()`, `focus_mode`, `focus_neighbor_*`:
  https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html
- **Themes and type variations** (one look for every screen):
  https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html
- **Input order**, `_input` vs `_unhandled_input`, `set_input_as_handled()` (fixes the "menu
  input also attacks" problems):
  https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html
- **Pausing**, `get_tree().paused` and `process_mode`:
  https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html
- **CanvasLayer** (draw order of the HUD vs the pause menu):
  https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html
- **Size and anchors / multiple resolutions**:
  https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
  (RogueNet's own resolution / pixel-perfect notes: `docs/PIXEL_RESOLUTION_RESEARCH.md`.)
