# Items

`<slot>/<id>.json`, one folder per equipment slot (`back`, `chest`, `feet`, `gloves`, `head`,
`legs`, `main_hand`, `neck`, `off_hand`, `ring`). A file has a `name`, its `slot`, an optional
`set` and the `art` path of its worn sprite (under `resources/gfx/gear/`, in matching slots). The
slot folders have no README of their own: they all work as described here, and repeating it
<<<<<<< Updated upstream
nine times would only drift. The full format is in the root `README.md` under "Items".
=======
ten times would only drift.

Rings are the exception to "worn sprite": they have no `art` and are never drawn on the body.
A ring fits either of the two ring slots. A ring can carry its own `bonus` block in the set
format (`game/sets/README.md`); the three legendary rings use it for particles only, and the
rest have none. The full format is in the root `README.md` under "Items".

A set's full-set bonus (effects that play while every armour piece of the set is worn) is
not here: it is in `game/sets/<set>.json`.
>>>>>>> Stashed changes
