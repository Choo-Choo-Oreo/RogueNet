class_name LineOfSight
extends RefCounted

## Grid line-walk between two cells, blocked by walls -- a supercover walk
## (touches every cell the line passes through, including ones it only clips
## the corner of), so a diagonal wall corner blocks the same way LightFlood's
## diagonal flood steps already do. Cost scales with the distance between the
## two cells, not an area, so it's cheap compared to a flood. Cell units are
## whatever the caller uses, same as LightFlood.

## blocked_at's answer when nothing is in the way.
const CLEAR := Vector2i(-2147483648, -2147483648)

static func clear(from: Vector2i, to: Vector2i, is_blocked: Callable) -> bool:
	return blocked_at(from, to, is_blocked) == CLEAR

## The first cell that stops the line from `from` to `to`, or CLEAR (the debug sight line marks it).
static func blocked_at(from: Vector2i, to: Vector2i, is_blocked: Callable) -> Vector2i:
	var cell := from
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var step_x := signi(to.x - from.x)
	var step_y := signi(to.y - from.y)
	var err := dx - dy
	while cell != to:
		var e2 := err * 2
		var move_x := e2 > -dy
		var move_y := e2 < dx
		var next := cell
		if move_x:
			err -= dy
			next.x += step_x
		if move_y:
			err += dx
			next.y += step_y
		if move_x and move_y:
			# Diagonal step -- both orthogonal neighbours must be open too,
			# same corner rule LightFlood's diagonal flood steps use.
			if is_blocked.call(Vector2i(cell.x + step_x, cell.y)):
				return Vector2i(cell.x + step_x, cell.y)
			if is_blocked.call(Vector2i(cell.x, cell.y + step_y)):
				return Vector2i(cell.x, cell.y + step_y)
		if is_blocked.call(next):
			return next
		cell = next
	return CLEAR
