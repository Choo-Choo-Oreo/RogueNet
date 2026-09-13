extends Node2D

const NEIGHBOR_BITMASK_TO_ATLAS_COORD := {
	0b1111: Vector2i(2, 1), # All corners
	0b0001: Vector2i(1, 3), # Outer bottom-right corner
	0b0010: Vector2i(0, 0), # Outer bottom-left corner
	0b0100: Vector2i(0, 2), # Outer top-right corner
	0b1000: Vector2i(3, 3), # Outer top-left corner
	0b0101: Vector2i(1, 0), # Right edge
	0b1010: Vector2i(3, 2), # Left edge
	0b0011: Vector2i(3, 0), # Bottom edge
	0b1100: Vector2i(1, 2), # Top edge
	0b0111: Vector2i(1, 1), # Inner bottom-right corner
	0b1011: Vector2i(2, 0), # Inner bottom-left corner
	0b1101: Vector2i(2, 2), # Inner top-right corner
	0b1110: Vector2i(3, 1), # Inner top-left corner
	0b0110: Vector2i(2, 3), # Bottom-left top-right corners
	0b1001: Vector2i(0, 1), # Top-left bottom-right corners
	0b0000: Vector2i(-1, -1), # No corners, treated as empty tile
}
