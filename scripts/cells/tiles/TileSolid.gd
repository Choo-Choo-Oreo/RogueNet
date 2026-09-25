class_name TileSolid
extends RefCounted

## The one rule for "is there ground here", read straight from the dungeon's wall and
## floor layers: a wall tile, a void floor or no floor at all is solid. Used by GridMover
## (movement, and BodySweep's bad-tile check), LightMap (light stops there) and
## MinionSpawning (where a body fits), plus DungeonPainter's spawn check and TileDestruction. Doors are not tiles and are not part of it: each
## caller adds its own door rule. A missing layer counts as open.

static var _void_id := -2  # -2: not looked up yet

## "wall", "void", "no floor", or "" when a body can stand on `tile`.
static func reason(walls: TileMapLayer, floors: TileMapLayer, tile: Vector2i) -> String:
	if walls != null and walls.get_cell_source_id(tile) != -1:
		return "wall"
	if floors == null:
		return ""
	var floor_id := floors.get_cell_source_id(tile)
	if floor_id == -1:
		return "no floor"
	return "void" if floor_id == _void() else ""

static func is_solid(walls: TileMapLayer, floors: TileMapLayer, tile: Vector2i) -> bool:
	return reason(walls, floors, tile) != ""

## Whether `tile` has a floor a body could stand on, ignoring any wall over it.
static func has_floor(floors: TileMapLayer, tile: Vector2i) -> bool:
	return reason(null, floors, tile) == ""

## Tile ids are fixed in the registry file, so the void floor's is looked up once.
static func _void() -> int:
	if _void_id == -2:
		_void_id = TileTypeRegistry.new().get_id("floor_void")
	return _void_id
