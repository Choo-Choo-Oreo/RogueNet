# RogueNet UI Improvement Guide

Sep 23, 2026 · @Someone

## Overview

The 11 videos boil down to three habits RogueNet's UI can adopt: animate through one reusable component, style through one shared Theme, and manage scenes through one persistent controller.

The videos fall into four groups:

- **Animation (5 videos):** entrance animations, delaying them, animating several properties at once, and a simple hover-animation setup. Together they build one reusable component.
- **Layout and theming (1 video):** a Control node and Container crash course covering anchors, containers, and themes.
- **Tools (2 videos):** a lesser-known `_draw()` function for custom drawing, and a simple debug overlay built on an autoload.
- **Scene flow (3 videos):** a persistent scene-container setup, fade transitions, and custom splash screens.

For RogueNet this maps onto the town hub menu, the guild queue, the lobby, the in-dungeon HUD, and the boot-to-town flow. Nothing here requires touching netcode, and every idea can be adopted in small steps.

## Reusable UI animation component

One small script, added as a child node, can give any button or panel hover and entrance animations without writing a new script per node.

The five animation videos build the same idea in stages:

1. **A Tween moves a property over time.** `create_tween()` then `tween_property(node, "scale", Vector2(1.1, 1.1), 0.1)`. Add `set_trans()` and `set_ease()` to change how the motion feels.
2. **Make it a component.** A script with `class_name AnimationComponent extends Node` uses `get_parent()` as its target. Drop it under any Control and it works.
3. **Expose settings with `@export`.** Duration, scale, and the transition and ease enums show up as dropdowns in the Inspector, so artists can tune feel without code.
4. **Connect signals.** The parent's `mouse_entered` and `mouse_exited` signals trigger the grow and shrink tweens.
5. **Delay and chain.** Multiple properties (scale, rotation, modulate) tween in parallel with `set_parallel(true)`. A staggered entrance delays each element in turn.

### Where it fits in RogueNet

- Town hub and guild menu buttons: a subtle hover grow and a click response.
- Lobby and party lists: entries slide or fade in one after another as players join.
- Loot and level-up popups: a scale-in with overshoot.

### Gotchas the videos ran into

- **Containers fight tweens.** A Container sets its children's size and position. Tweening `scale` is safe, but tweening `position` inside a Container may get overwritten.
- **Scale pivots from the top-left** by default. Set `pivot_offset = size / 2`, and do it with `call_deferred` because size is not final until layout runs.
- **Delays were unreliable** with `tween_interval` in the tutorial author's setup. His workaround: pause the tween, `await get_tree().create_timer(delay).timeout`, then play it.
- **Overshoot transitions** (back, elastic) need a plain linear tween to reset, or the node ends up slightly off-size.

### Teaching note

Introduce this one step at a time: first a single tween on one button by hand, then the component, then the exports. The component is short, but signals, exports, and `get_parent()` are three new ideas at once.

## Layout and theming

Build menus from Containers and style them with one saved Theme resource; per-node overrides are what make a UI hard to change later.

### Layout

- **Anchors:** use the Full Rect preset for a root Control that fills the screen, so menus survive resolution changes.
- **Containers do the math.** A `CenterContainer` centers content, a `PanelContainer` draws a background, and `VBoxContainer` / `HBoxContainer` stack children. Nest them instead of positioning by hand.
- **Sizing:** set Custom Minimum Size on a node and Container theme constants (such as VBox `separation`) instead of pixel positions.

### Theming

1. Create a Theme resource once and save it as a file. Assign it to the root Control of a menu; every child inherits it.
2. Set styles per class (Button, Label, Panel) in the Theme, not on each node.
3. Use a `StyleBoxFlat` for buttons and panels: content margins, border, corner radius, shadow. Use `StyleBoxEmpty` to remove the default focus outline.
4. Use theme type variations (a new type with a base type) for special cases such as a "danger" button or a "rare item" panel.

### Where it fits in RogueNet

- Town, Host, Guild and lobby screens all share one look, so a single Theme file keeps them consistent.
- Rarity colors for loot and the damage-type palette (Ordo, Entropia, Perditio) are natural theme type variations.
- The mouse-ergonomics rule (buttons on the same screen side across chained menus) is easiest to hold if every menu is built from the same container pattern.

### Gotchas

- Changing a Theme changes every menu at once, so make changes deliberately and check each screen.
- A Container overrides the size and position you set by hand. Change the container settings instead.
- Agree the UI palette with the art director (Silvery Foxy) before the Theme is built, so colors are chosen once.

## Scene management and transitions

Instead of calling `change_scene_to_file()` everywhere, keep one persistent scene that loads and unloads screens inside it, and hide the swap behind a fade.

### The persistent-container setup

- A main scene holds three containers: one for the 3D world, one for the 2D world, and one for the GUI.
- An autoload (for example `Global.game_controller`) has functions like "load this GUI scene" and "load this 2D world scene".
- When switching, the old scene is removed. The video compares three options: `queue_free()` (delete it), `hide()` (keep it running), or `remove_child()` (keep it in memory but detached). Pick per scene.

### Fade transitions

1. A top-layer scene holds a full-screen `ColorRect` and an `AnimationPlayer` with a fade-in and a fade-out.
2. Set `speed_scale = 1 / length` so one function can fade over any duration you pass.
3. Sequence: fade to black, `await` its finish, swap the scene, fade back.

### Where it fits in RogueNet

- Main menu to Host to Town to Guild is a chain of GUI screens. A GUI container replaces each `change_scene` call and lets the fade hide loading.
- Town and Dungeon are natural World2D scenes swapped inside the same main scene.
- Menus that should keep their state (settings, lobby) are candidates for `hide()` or `remove_child()` instead of deletion.

### Gotchas specific to RogueNet

- The netcode model is undecided, and so is town persistence and per-party dungeon instancing. A persistent container tree could fight or help those plans, so check with whoever owns the lobby and networking work before restructuring.
- Multiplayer-first: which scene is loaded, and when, may need to be host-controlled. Keep "which scene is next" as a decision that can come from the host, not only from local input.
- This changes how the whole game boots, so it is a bigger change than the animation or theme work. Treat it as its own scoped task.

## Splash and boot sequence

A custom splash scene gives the game a polished first ten seconds and costs very little: a few images, a few tweens, and a skip key.

The two splash videos cover this flow:

1. Turn off the default boot splash in Project Settings so it does not show first.
2. Make a splash scene the project's main scene.
3. For each logo, chain tweens: fade in, hold, fade out. Each step is awaited before the next starts.
4. Let players skip with `_unhandled_input` (any key or click).
5. When finished, call `change_scene_to_packed()` to load the main menu.

### Where it fits in RogueNet

- Studio or team logo, then the RogueNet title, then the main menu.
- If the scene manager from the previous section is adopted, the splash can hand off through the same fade controller.

### Gotchas

- Always allow skipping. Repeat launches during development will otherwise be annoying.
- Loading the menu while the splash plays (background loading) is a later refinement; the videos do not need it.
- Logos and title art are the art director's to supply, so this is a good task to stage after art exists.

## In-game debug overlay

An autoload debug overlay lets any script print live values on screen with one line, which is useful for the enemy AI and pathfinding work already underway.

How the video builds it:

1. An autoload scene (for example `Global.debug`) holds a `CanvasLayer` with a `PanelContainer` and a `VBoxContainer` of labels.
2. Any script calls a function such as `Global.debug.add_property("Alert state", state, 1)`. The overlay creates a label the first time and updates it after that.
3. A `debug` input action (the `~` key) toggles it. `set_input_as_handled()` stops the key from also reaching the game.
4. Updates are throttled with `Time.get_ticks_msec()` so labels do not rewrite every frame.

### Where it fits in RogueNet

- Enemy senses and alert state (Sight and Touch first), pathfinding cost per room, and flow-field status.
- The 529-rat room: show enemy count and frame time next to each other while tuning performance.
- Networking: show host or client role and the current sync state once netcode exists.

### Gotchas

- The overlay reads values but should never change shared game state. In multiplayer, only the host's values are authoritative, so label them as local.
- Turn it off in release builds, or restrict it to the host, so players cannot see values they should not.
- This is a small, safe first project for a new team member because it does not touch gameplay code.

## Custom drawing with `_draw()`

Any Control can draw its own shapes, lines, and text by overriding `_draw()`, which suits HUD pieces that have no ready-made node.

The key points from the video:

- Override `_draw()` and call functions like `draw_rect`, `draw_line`, `draw_circle`, `draw_arc`, and `draw_string`.
- `_draw()` runs once, not every frame. Call `queue_redraw()` whenever the data changes, such as health going down.
- Drawing happens in the node's local coordinates, so it moves and scales with the node.

### Where it fits in RogueNet

- Health, mana, and cooldown arcs around a skill icon.
- A minimap of the assembled dungeon rooms, drawn from the room graph.
- Enemy alert indicators or detection-range circles, which pair with the enemy-senses design.

### Gotchas

- Only call `queue_redraw()` on change. Redrawing every frame across many nodes costs performance, and the dungeon already has performance pressure.
- For simple bars, a `TextureProgressBar` or `ProgressBar` with a themed StyleBox is easier to teach and maintain. Reach for `_draw()` when those cannot do the shape.

## Suggested order of work

Start with the smallest, safest changes (theme, animation, debug overlay) and leave scene restructuring for last, since it touches boot flow and netcode plans.

| Order | Task | Size | Risk | Good for |
| --- | --- | --- | --- | --- |
| 1 | One shared Theme for all menus | Small | Low | Anyone; needs art director palette |
| 2 | Hover animation on menu buttons (by hand, then as a component) | Small | Low | New team members |
| 3 | Debug overlay autoload | Small | Low | Enemy AI and pathfinding tuning |
| 4 | Staggered entrance animations for lists and popups | Medium | Low | After step 2 |
| 5 | Fade transition between menu screens | Medium | Medium | After step 2 |
| 6 | Custom splash sequence | Small | Low | After art exists |
| 7 | `_draw()` HUD pieces, minimap | Medium | Low | After the HUD design exists |
| 8 | Persistent scene-container controller | Large | High | Technical lead; wait for netcode decisions |

### Team-learning notes

- Each task above can be done as a paste-in walkthrough in small steps, following the project's teach-don't-implement approach. Nothing here should be built in bulk.
- Steps 1 to 3 introduce resources, signals, and autoloads, which are core Godot ideas the team will reuse everywhere.

### Open questions

- [ ] Should the persistent scene controller wait until the netcode and town-persistence approach is decided?
- [ ] Who owns the UI palette and Theme file: art director or technical lead?
- [ ] Should the debug overlay be host-only in multiplayer, or local per player?
- [ ] Does the lobby UI backlog (Single/Multiplayer split, dead PanelLobby cleanup) come before or after the Theme work?
