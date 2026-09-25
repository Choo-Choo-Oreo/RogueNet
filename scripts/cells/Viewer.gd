class_name Viewer
extends RefCounted

## What the map needs to know about one body that sees, and maybe carries a light: where it
## is, what its senses reach and what its hands give off. The body owns one, registers it and
## keeps it current; LightMap and PlayerVision read Viewer.all and never look at bodies
## (cells is the foundation layer, see docs/STRUCTURE.md). Any team's body can have one; today
## only adventurers do (PlayerController).

static var all: Array[Viewer] = []

## World pixel of the top-left of the body's tile (its global_position).
var position := Vector2.ZERO
## The held light's data (ItemDatabase.light_of: glow_radius, bright_fraction, glow_color), {} with none.
var light := {}
## Sense ranges in tiles, 0 for a sense it doesn't have.
var sight := 0.0
var touch := 0.0
## The quietest sound it hears in dB (SenseHearing.threshold_db); INF when it is deaf.
var hearing := INF
var ghost := false
## This machine's own player.
var is_local := false

static func register(viewer: Viewer) -> void:
	if not all.has(viewer):
		all.append(viewer)

static func unregister(viewer: Viewer) -> void:
	all.erase(viewer)

## True once this machine's own viewer is a ghost: ghosts see other ghosts' light and vision.
static func local_is_ghost() -> bool:
	return all.any(func(v: Viewer) -> bool: return v.is_local and v.ghost)

## Vision is shared with the team, so every teammate's light and view is drawn for the local
## player too, however far away (a ranger can see through a frontliner's eyes). A dead
## teammate's is only shown to other ghosts.
static func shown_to_local(viewer: Viewer) -> bool:
	return viewer.is_local or not viewer.ghost or local_is_ghost()

## Every viewer, this machine's own first (the order both drawn lists use).
static func local_first() -> Array[Viewer]:
	var ordered: Array[Viewer] = []
	for mine in [true, false]:
		for viewer in all:
			if viewer.is_local == mine:
				ordered.append(viewer)
	return ordered

static func local() -> Viewer:
	for viewer in all:
		if viewer.is_local:
			return viewer
	return null
