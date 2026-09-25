# Items

`<slot>/<id>.json`, one folder per equipment slot (`back`, `chest`, `feet`, `gloves`, `head`,
`legs`, `main_hand`, `neck`, `off_hand`). A file has a `name`, its `slot`, an optional `set`
and the `art` path of its worn sprite (under `resources/gfx/gear/`, in matching slots). The
slot folders have no README of their own: they all work as described here, and repeating it
nine times would only drift. The full format is in the root `README.md` under "Items".

A set's full-set bonus (effects that play while every armour piece of the set is worn) is
not here: it is in `game/sets/<set>.json`.
