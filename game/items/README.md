# Items

`<slot>/<id>.json`, one folder per equipment slot (`back`, `chest`, `feet`, `gloves`, `head`,
`legs`, `main_hand`, `neck`, `off_hand`). A file has a `name`, its `slot`, an optional `set`
and the `art` path of its worn sprite (under `resources/gfx/gear/`, in matching slots; the plain
`fallback_sword`, `fallback_bow`, `fallback_wand` and `fallback_torch` keep theirs in `resources/gfx/fallbacks/`). The
slot folders have no README of their own: they all work as described here, and repeating it
nine times would only drift. The full format is in the root `README.md` under "Items".
