# Drawing Characters for Customization

This guide is for drawing a character that players can customize: change the hair
color and skin tone, and swap armor and weapons. You only need to handle the art.
The code is done separately.

It is based on a Godot character-creator tutorial series, rewritten for the artist.

---

## 1. The big idea: a character is a stack of layers

You don't draw one finished character. You draw it in **separate transparent
layers**, and the game stacks them on top of each other. Swapping one layer
(for example the armor) changes the character without redrawing the rest.

The game draws the layers **bottom to top** in this order:

| # | Layer   | What goes on it                                   | Recolored by the game? |
|---|---------|---------------------------------------------------|------------------------|
| 1 | Shadow  | A small shadow blob under the feet                | No                     |
| 2 | Body    | Bare body, arms, legs (skin only, no clothes)     | **Yes** (skin tone)    |
| 3 | Armor   | Clothing or armor worn over the body              | No                     |
| 4 | Head    | Bare head and face shape (skin only)              | **Yes** (skin tone)    |
| 5 | Hair    | Hair only                                         | **Yes** (hair color)   |
| 6 | Eyes    | Eyes only                                         | No                     |
| 7 | Weapon  | The held weapon                                   | No                     |

Tips:
- Each layer should hold **only its own part**. The body layer has no hair, the
  hair layer has no face, and so on.
- The armor layer is drawn **over the body but under the head**, so collars and
  necklines need to tuck under the chin correctly.
- Anything on a higher layer covers the layers below it. Test by stacking all the
  layers in your art program with the same order.

---

## 2. Canvas and alignment: the most important rule

Every layer is placed at the **same spot**. The game does not move them into
position, so:

- **All layers use the exact same frame size** (for example, every frame is
  32x32 on every layer).
- **The character stands in the same place in every frame of every layer.** If
  the head is 2 pixels off in frame 7, it will float off the neck in the game.
- The easiest way to do this: draw the whole character in **one file with one
  layer per part**, then export each layer as its own sheet.

The final frame size is Orea's call. Ask before you start.

---

## 3. Animations and sprite sheets

Each layer needs one sprite sheet **per animation**. The tutorial uses two
animations:

| Animation | Frames per direction | Speed         |
|-----------|----------------------|---------------|
| Idle      | 20                   | 10 frames/sec |
| Run       | 8                    | 10 frames/sec |

These numbers are only the tutorial's example. Check the real frame counts with
Orea before you start.

### Sheet layout

Each sheet is a grid:
- **One row per direction**, always in this order from top to bottom:
  1. Down (facing the camera)
  2. Left
  3. Right
  4. Up (facing away)
- **One column per frame**, from left to right.

So an idle sheet is 20 frames wide and 4 rows tall, and a run sheet is 8 frames
wide and 4 rows tall.

```
          frame 1  frame 2  frame 3 ... 
 Down   [  ]     [  ]     [  ]
 Left   [  ]     [  ]     [  ]
 Right  [  ]     [  ]     [  ]
 Up     [  ]     [  ]     [  ]
```

- **Frame counts must match across layers.** If the body's run has 8 frames,
  then the hair, eyes, armor and weapon runs must also have 8, lined up with the
  same motion. Frame 3 of the hair has to match frame 3 of the body.
- The layers **play at the same time**, so the hair bounces when the head bobs,
  the weapon swings with the arm, and so on.
- Even if a layer barely moves (like the eyes), it still needs **a full sheet
  with every frame**, positioned to follow the head.
- Blinking is a good thing to put in the eyes' idle animation.

### The shadow

The shadow is the exception. It is **one single image** (not a sheet), placed
under the feet. It does not animate.

---

## 4. Parts the game recolors: draw them in grays

The game recolors hair and skin by **tinting** the image. Tinting works like
laying colored glass over the pixels:

- **White** turns fully into the chosen color.
- **Gray** turns into a darker shade of the chosen color.
- **Black** stays black.
- **Already colored pixels mix badly.** A brown hair drawn in brown and then
  tinted blue will look muddy.

So:

### Hair
- Draw it **only in white and grays**. Use white for the brightest highlight,
  light gray for the main color and darker grays for shading.
- Players can pick **any** hair color, so check that it still reads well when
  it's tinted yellow, black-ish, or bright pink.

### Skin (Body and Head layers)
- Also draw it **in white/light grays** with gray shading.
- Skin comes from a **fixed list of skin tones** (not a free picker). Both the
  body and the head get the same tone, so **shade them the same way** or the
  neck will show a seam.
- The game tints the whole layer. **Don't put anything that must keep its own
  color** (like eyes, lips or tattoos) on the body or head layers. Give those
  their own layer. That is why the eyes are separate.

### Outlines
- Black or very dark outlines stay dark after tinting, so outlines are fine on
  recolored layers.

> Quick test: in your art program, add a "Multiply" color layer over your gray
> hair/skin with a few different colors. That's roughly what the game will do.

---

## 5. Parts the game swaps: armor and weapons

Armor and weapons are **not** recolored. Draw them in **full color**, as they
should look in the game.

The player picks from a list of variants, for example:
- Armor: cloth, leather armor, armor
- Weapon: stick, sword, golden sword

For each variant you make a **full set of sheets**, one per animation (idle and
run). The game swaps the picture but keeps the **same grid**, so every variant
has to:

- Use the **same frame size, frame count and row order** as every other layer.
- Line up with the body in every frame. The sword has to be in the hand in every
  frame of every direction.

### File naming

The game finds the files **by name**. That means naming has to be consistent:
one folder per part, and one file per variant per animation. The tutorial names
them something like:

```
armor/
  cloth_idle.png
  cloth_run.png
  leather_armor_idle.png
  leather_armor_run.png
weapon/
  stick_idle.png
  stick_run.png
  sword_idle.png
  sword_run.png
```

Orea will give you the exact folder and naming rules for this project. Check with
them before exporting a batch, because a single wrong name means that variant won't
load.

---

## 6. Checklist before handing art over

- [ ] Every layer is exported separately, with a transparent background.
- [ ] Every layer uses the same frame size.
- [ ] Row order is Down, Left, Right, Up on every sheet.
- [ ] Each animation has the same frame count across all layers.
- [ ] Stacked in order (Shadow > Body > Armor > Head > Hair > Eyes > Weapon), the
      character lines up in every frame.
- [ ] Hair, body and head are drawn in **white/grays only**.
- [ ] Eyes (and anything else that must keep its color) are on their own layer.
- [ ] Armor and weapons are in full color, with idle and run sheets for each variant.
- [ ] Each variant file name follows the agreed naming.
- [ ] The shadow is one single, static image.
- [ ] Pixel art is exported at 1x (no scaling or smoothing). The game scales it up.

---

## 7. Things still to agree on with Orea

- Frame size
- Which animations exist, and how many frames each one has (the tutorial only has idle + run)
- Whether there are 4 directions, or more (some existing RogueNet characters use
  diagonals)
- Folder and file-name rules
- The list of skin tones
- The color limit per sprite

---

## 8. Videos worth watching

- [Colorize from Grayscale! (Pixel Art Tips)](https://www.youtube.com/watch?v=_b2E2UJR5dE)
  Drawing in grayscale first, then adding color.
- [Infinite Pixel Art Colors with THIS Trick!](https://www.youtube.com/shorts/odvks9jqkKo)
  Recoloring sprites in code so players can customize their character.
- [Moonborn Modular Pixel Art Workflow](https://www.youtube.com/watch?v=P2x7t5OTFgg)
  Building a character out of separate, swappable parts.
- [How to make modular 2d game sprites (live stream)](https://www.youtube.com/watch?v=h_XwcKFC-Qs)
  A longer walkthrough of modular sprites in Krita.
- [Hue Shifting in Pixel Art](https://www.youtube.com/watch?v=PNtMAxYaGyg)
  Why shading often shifts hue, not just brightness. Tinting can't do this,
  which is why recolored parts can look a bit flatter.
