shader_type canvas_item;

// The light map stores, per 8x8 cell, how far light travelled (0 = at the source, 1 = the edge or unreached).
// Blend that distance between cells at game-pixel centres, then snap it to flat brightness steps,
// so the step edges follow the pixel grid but each step stays a solid level.
uniform float cell_size = 8.0;

// Darkness of each step, from nearest to farthest.
uniform float step_1 = 0.5;
uniform float step_2 = 0.75;
uniform float step_3 = 0.9;
uniform float dark_1 = 0.4;
uniform float dark_2 = 0.75;

void fragment() {
	vec2 pixels = vec2(textureSize(TEXTURE, 0)) * cell_size;
	vec2 snapped = (floor(UV * pixels) + 0.5) / pixels;
	float distance_fraction = texture(TEXTURE, snapped).r;
	float darkness = 1.0;
	if (distance_fraction < step_1) {
		darkness = 0.0;
	} else if (distance_fraction < step_2) {
		darkness = dark_1;
	} else if (distance_fraction < step_3) {
		darkness = dark_2;
	}
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
