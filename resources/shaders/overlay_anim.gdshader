shader_type canvas_item;

// Animated overlay for a tile type (lava embers, acid bubbles), drawn per 8x8 quad.
// The sheet is 8 rows x 8 frames of 8x8: every row is one animation, played left to right.
// Each quad plays one row, then on the next cycle picks another row (or nothing), so the
// pattern never repeats in lockstep. The row is picked from the quad's world position and the
// cycle number, so the same quad always gets the same sequence.
uniform sampler2D overlay_tex : filter_nearest;
uniform float frame_time = 0.1;   // seconds per frame
uniform float density = 0.2;      // chance that a quad plays an animation in a given cycle
uniform float cell_size = 8.0;

varying vec2 world_pos;

float rand2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cell = floor(world_pos / cell_size);
	float t = TIME / (8.0 * frame_time) + rand2(cell);
	float cycle = floor(t);
	float frame = floor(fract(t) * 8.0);
	if (rand2(cell + vec2(cycle * 3.7, 41.0)) > density) {
		discard;
	}
	float row = floor(rand2(cell + vec2(cycle * 1.9, 7.0)) * 8.0);
	float previous = floor(rand2(cell + vec2((cycle - 1.0) * 1.9, 7.0)) * 8.0);
	if (row == previous) {
		row = mod(row + 1.0, 8.0);
	}
	vec2 pixel = floor(fract(world_pos / cell_size) * 8.0);
	COLOR = texture(overlay_tex, (vec2(frame, row) * 8.0 + pixel + 0.5) / 64.0);
}
