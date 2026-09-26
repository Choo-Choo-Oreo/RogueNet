// GameView's smooth camera: shifts the finished world picture by the camera's leftover fraction
// of an art pixel (set by GameView each frame). Only moves it; every pixel stays a hard block.
// Technique from apples/godot-smooth-pixel-subviewport-container (its anti-aliasing part is left
// out: it blends colours across pixel edges).
shader_type canvas_item;

uniform vec2 vertex_offset;

void vertex() {
	VERTEX += vertex_offset;
}
