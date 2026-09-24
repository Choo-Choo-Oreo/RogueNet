class_name AbilityShapes
extends RefCounted

## Which tiles an ability covers. Abilities describe their reach in JSON ("shape":
## {"type": "circle", "radius": 2}) and this turns that into world tiles, so a new
## ability (or a new enemy using an old one) never needs shape code of its own.
##
##   circle  "radius" (tiles, may be fractional): every tile within that distance of
##           the body's edge, all the way around it. 1 = the four sides, 1.5 = the
##           corners too.
##   line    "length" and "width" (tiles): a strip starting at the body's edge and
##           running toward the target along whichever axis it is mostly on, centred
##           on the body.
##
## The body is `body_size` tiles square with its top-left tile at `body_tile` (see
## GridMover.footprint). The body's own tiles are never part of the result.

static func cells(shape: Dictionary, body_tile: Vector2i, body_size: int, target_tile: Vector2i) -> Array[Vector2i]:
	match str(shape.get("type", "")):
		"circle":
			return _circle(float(shape.get("radius", 1)), body_tile, body_size)
		"line":
			return _line(maxi(1, int(shape.get("length", 3))), maxi(1, int(shape.get("width", 1))), body_tile, body_size, target_tile)
	push_warning("Ability shape '%s' is not known (circle, line)" % str(shape.get("type", "")))
	return []

static func _circle(radius: float, body_tile: Vector2i, body_size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var last := body_size - 1
	var reach := ceili(radius)
	for dy in range(-reach, body_size + reach):
		for dx in range(-reach, body_size + reach):
			if dx >= 0 and dx <= last and dy >= 0 and dy <= last:
				continue
			# Whole tiles between this tile and the body's edge (0 beside it, 1 next out...).
			var gap_x := -dx if dx < 0 else maxi(dx - last, 0)
			var gap_y := -dy if dy < 0 else maxi(dy - last, 0)
			if gap_x * gap_x + gap_y * gap_y <= radius * radius:
				result.append(body_tile + Vector2i(dx, dy))
	return result

static func _line(length: int, width: int, body_tile: Vector2i, body_size: int, target_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var body_centre := Vector2(body_tile) + Vector2(body_size, body_size) / 2.0
	var to_target := Vector2(target_tile) + Vector2(0.5, 0.5) - body_centre
	var horizontal := absf(to_target.x) >= absf(to_target.y)
	var way := 1 if (to_target.x if horizontal else to_target.y) >= 0.0 else -1
	# Offset of the strip's first lane from the body's first lane, so it stays centred.
	var lateral := floori((body_size - width) / 2.0)
	for step in length:
		var along := body_size + step if way > 0 else -1 - step
		for lane in width:
			var across := lateral + lane
			result.append(body_tile + (Vector2i(along, across) if horizontal else Vector2i(across, along)))
	return result
