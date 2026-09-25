class_name Occupancy
extends RefCounted

## Who stands on each tile: the creatures a step can't go onto (GridMover.is_tile_occupied) and
## that keep a door open (DoorManager). Bodies register themselves (GridMover does it for its
## body) and say when they stop being solid (a ghost); this never looks through the creature
## groups or at a body's stats (cells is the foundation layer, see docs/STRUCTURE.md).
##
## The tile -> bodies index is built once per frame and tick, not per question: with hundreds
## of minions asking every frame, rescanning per question was O(n^2) per frame. Assumes every
## body uses the same tile size, true everywhere in this project today.

class Entry:
	var body: Node2D
	## Tiles per side (a 2x2 boss is 2); the body's position is its top-left tile.
	var footprint := 1
	## False for a ghost: it walks through bodies and blocks nothing.
	var solid := true

static var _entries: Array[Entry] = []
static var _frame := -1
static var _tick := -1
static var _index := {}  # Vector2i -> Array[Node2D]

## Destination tiles of steps already in progress (tile -> the body stepping onto it). A body
## only counts as standing on a tile once its position floors into it, which for a multi-frame
## step happens late -- so without this, two creatures could both see the same tile as free and
## both step onto it. Claimed when a step starts, released when it ends; an entry whose body was
## freed mid-step is ignored (is_instance_valid) rather than needing cleanup. Ghosts never
## reserve, same as they never count as occupants.
static var reserved := {}

static func register(entry: Entry) -> void:
	if not _entries.has(entry):
		_entries.append(entry)
	_frame = -1

static func unregister(entry: Entry) -> void:
	_entries.erase(entry)
	_frame = -1

## Every solid body on `tile` this frame.
static func occupants(tile: Vector2i, size_px: int) -> Array:
	# Also rebuilt on a new tick: a frame can run several ticks, and steps end on them.
	var frame := Engine.get_process_frames()
	if frame != _frame or GameTick.tick != _tick:
		_frame = frame
		_tick = GameTick.tick
		_index.clear()
		for entry in _entries:
			if not entry.solid or not is_instance_valid(entry.body):
				continue
			var pos := entry.body.global_position
			var body_tile := Vector2i(floori(pos.x / size_px), floori(pos.y / size_px))
			for y in entry.footprint:
				for x in entry.footprint:
					var covered := body_tile + Vector2i(x, y)
					if not _index.has(covered):
						_index[covered] = []
					_index[covered].append(entry.body)
	return _index.get(tile, [])
