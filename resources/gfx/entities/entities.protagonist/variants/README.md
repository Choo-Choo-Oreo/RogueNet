# Character skins

More looks to pick in town (Choose Character), on top of the Human (Default Man) in
`../human/`. Test variants, made 2026-09-25: human (female), elf, dwarf and kemono, each male
and female.

- One folder per skin, named by its id (`<race>_<male|female>`), holding `<id>.json` and its
  sheets `<Race><Sex>-Down/DownRight/Right/UpRight/Up.png` plus `-Blink.png`.
- `<id>.json` is only `{"like": "human", "art": "<sheets' path minus -<Direction>.png>"}`:
  everything else (animations, speed, idle blink) comes from the Human
  (`PlayerController.character_data`). A new folder with a json shows up in the picker by itself.
- **Elf, dwarf and kemono have their own bodies** (dwarf short and broad, elf tall and slim,
  kemono a fox with ears and tail; the elf woman wears a gown, the dwarf woman a skirt).
  **Gear is drawn for the Human's body and does not fit them**: each race needs its own gear art.
  Until it has some, their json says `"fits_gear": false` and no gear is drawn on them (the
  items are still worn and still count).
- `human_female` is the Human's pixels plus long hair, so all gear fits her.
- All are made by `.claude/tools/character_skins.py`. The drawn races' standing poses are
  hand-drawn grids in it; their walk frames are made from those the way the Human walks (frames
  1 and 3 dip 1px with one foot lifted, the side view strides). Run it again after editing a grid,
  and when the Human's sheets change (for `human_female`).
- No `.aseprite` files yet: the PNGs are the source until someone hand-edits one.
