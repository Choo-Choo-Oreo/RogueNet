# Entities

One JSON per creature, the same format for both teams: stats, size, speed, senses, the
`actions` it can use (ids from [`../actions/`](../actions/README.md), with per-creature
overrides). A minion or boss also carries its sprite frames; the player's look is chosen at runtime. A creature is a body plus a driver (AI or a player); the
JSON describes the body, so a boss and a player-driven antagonist would use the same file.

| Folder | Holds |
|---|---|
| `entities.protagonist/` | The player body (`player.json`). |
| `entities.antagonist/` | Bosses (`bosses/`) and minions (`minions/`); see its README for the list and the id rules. |

The field-by-field format is in the root `README.md` under "Minions". Sprite PNGs and their
animation JSON live under `resources/gfx/entities/`, in the same folders as here, never in
this folder. Projectile art is in `resources/gfx/entities/entities.projectiles/`; there is
no projectile data yet.
