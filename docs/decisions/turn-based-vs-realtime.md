# Turn-Based vs. Real-Time Combat — Design Decision

**Status:** Recommendation drafted, awaiting Orea's decision
**Participants:** Agent for Team-Turn base RogueNet (turn-based case) and Agent for Real-Time RogueNet (real-time case), debating on Orea's request
**Context:** This is the turn/real-time tension noted in `CLAUDE.md` ("turn/action-based dungeon runs") and flagged in project memory as a prior stalemate the team routed around by working on the town/dungeon scaffold instead. This doc is an attempt to actually resolve it.

**Scope note:** Once debated, both sides agreed traversal (walking the dungeon floor, the town hub menu, non-combat interaction) is not contested — the existing real-time movement, animation, and position-relay code already does this and nobody argued to change it. The live disagreement is narrowly about **combat/action resolution**: does a fight resolve on a turn queue or continuously?

---

## Case for pure turn-based (all interaction, including movement)

**Upsides**
- Smallest possible netcode surface: discrete, validated action messages on a locked cadence, not continuous authoritative-enough state. Fits an unsettled, non-strictly-authoritative "local-or-server" networking model well.
- Best fit for a mostly-new-to-programming team — sequential action resolution is far more learnable and debuggable than frame-independent, lag-tolerant continuous state.
- Plays to the roguelite's stated strengths (loot rarity, skill trees) by giving room to evaluate build synergies each action, rather than pressuring twitch execution.
- Genre precedent for the stated structure (party dives from a hub into a procedural run, returns, spends loot/skill progression) exists in Darkest Dungeon — though notably DD is single-player, never pressure-tested against networked co-op.

**Downsides**
- Discards a genre-feel the team's own movement/animation work already leans toward — extending real-time code is a gentler ramp than replacing its foundational assumptions.
- Turn-blocking: party pacing stalls on the slowest decider, a known pain point (mitigated by turn timers, but a real UX cost that real-time party co-op never has to solve).
- No proven networked-co-op precedent as strong as real-time's (Deep Rock Galactic) for the specific "party dives into procedural run together" structure.

---

## Case for pure real-time (all interaction, including combat)

**Upsides**
- Builds directly on validated, already-shipped work: Steam ID sync, peer disconnect handling, position relay, idle animation — no mode-switch, no second interaction paradigm to design and teach.
- Strong genre precedent for the exact structure RogueNet describes: Deep Rock Galactic does hub → party dive → procedural run → return, in real-time, with real networked co-op. (Risk of Rain 2 is real-time networked co-op too, but is a continuous run/loop rather than a hub-return cycle, so it supports "real-time co-op works" generally without supporting the hub-return structural claim specifically.)
- For co-op PvE (not competitive), real-time doesn't require frame-perfect rollback netcode — host-authoritative hit validation with client-side telegraphing (tolerant of some lag) is the standard, well-documented pattern for this genre.
- Loot/skill depth isn't paradigm-locked — ARPGs (Diablo, Path of Exile) pair build depth with real-time execution routinely; real-time adds a second skill axis (positioning/timing) rather than replacing build strategy.
- Never blocks party pacing on the slowest player — everyone acts independently and continuously.

**Downsides**
- The hardest, genuinely unbuilt problem — live combat hit/damage/ability-timing sync across peers on a non-dedicated, not-strictly-authoritative host — hasn't been proven yet by any existing commit. The "we already have real-time sync" argument overstates what's shipped (that's avatar-position plumbing, not combat resolution).
- Steepest ramp for a mostly-new-programming team: state interpolation, frame-independent timing, and lag-tolerant combat resolution are hard even for experienced devs.
- Fights the grain of the "turn/action-based" framing already written into the project's own `CLAUDE.md`.

---

## Debate notes: where the two sides actually converged

Both sides independently proposed the same synthesis once the disagreement was isolated to combat resolution specifically:

- Neither side has proven real-time *combat* netcode works yet — the shipped multiplayer code is traversal/avatar sync, needed identically under either paradigm.
- Turn-based's case is strongest exactly where the risk is highest (combat netcode, team skill ceiling) and weakest exactly where it's already been conceded (traversal feel, sunk movement code).
- Real-time's case is strongest exactly where turn-based is weakest (proven co-op structural precedent via DRG, no turn-blocking) and weakest exactly where the highest risk lives (unbuilt combat sync, steepest learning curve).
- The "mid-turn concurrency" objection to turn-based (a target dying from one party member's action before another's resolves) is real but is a smaller-scale version of the same problem real-time has continuously — not a categorically different one — and is handled once, at resolution time, by simultaneous batch collection + deterministic resolution order.

---

## Joint recommendation: hybrid — real-time traversal, turn-based combat

**Real-time exploration and town hub; combat locks into a team-turn structure when an encounter starts.** Precedent: Divinity: Original Sin, Baldur's Gate 3, Wildermyth — real-time movement, turn-based combat triggered on hostile engagement.

**How it addresses both sides' strongest points:**
- Nothing shipped gets thrown away — movement, animation, position relay, disconnect handling all keep working exactly as built, for everything outside combat.
- Combat — the one genuinely unbuilt, highest-risk piece under either paradigm — gets the smaller, more learnable, more netcode-tolerant treatment: party submits actions during a planning window, actions resolve in one deterministic batch (fixed initiative or simultaneous-resolution-with-tie-break), rather than continuous live state.
- Turn-blocking is mitigated with a soft timer on the planning window (act, or auto-pass/repeat-last-action on timeout) — the same "ready check" pattern real-time co-op games already use for lobby-style waits.
- Loot/skill build depth gets full room to matter in combat (the paradigm best suited to it), while movement keeps whatever real-time feel the team has already built and values.

**Honest tradeoff — not a free lunch:** this does mean a genuine mode-switch at combat start, which breaks the "never interrupts moment-to-moment control" feel of DRG/Risk of Rain 2-style continuous co-op. That's a real genre-feel cost, being stated plainly rather than glossed over. If that continuous-flow feel is a hard requirement, this hybrid is not the answer — full real-time would be, accepting the combat-netcode risk that goes with it.

**Open sub-question, not resolved here:** whether encounters are trigger-zone/scripted (enemy visible in the room, combat starts on contact) or aggro-based (world "locks" into turn mode when hostility triggers). Both are viable; picking one is an implementation decision for whenever combat design starts, not part of this paradigm debate.

**Recommendation:** adopt the hybrid — real-time traversal and town hub, turn-based combat — as it lets the team keep validated real-time work, concentrates the harder learning curve and netcode risk into the one system (combat) where turn-based's advantages are strongest, and has solid genre precedent (DOS/BG3/Wildermyth) for exactly this split. Final call is Orea's.
