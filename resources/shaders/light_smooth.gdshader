shader_type canvas_item;

// The light map stores, per 8x8 cell, how far light travelled (0 = at the source, 1 = the edge or unreached).
// Blend that distance between cells at game-pixel centres, then snap it to flat brightness steps,
// so the step edges follow the pixel grid but each step stays a solid level.
uniform float cell_size = 8.0;

// Second map for glowing tiles (lava, glowstone): rgb = glow colour, alpha = distance fraction
// (0 = at the source, 1 = no glow). It only softens darkness where the player's light already
// reaches, so a glow never reveals ground the player can't see.
// The glow map covers the whole dungeon and is baked once; the player's light map is a window
// that moves, so its pixels are converted to world position to find the matching glow pixel.
uniform sampler2D glow_map : filter_linear;
uniform vec2 window_origin = vec2(0.0);  // world pixel of this sprite's top-left corner
uniform vec2 glow_origin = vec2(0.0);    // world pixel of the glow map's top-left corner
uniform vec2 glow_size = vec2(1.0);      // glow map size in cells

// Darkness of each step, from nearest to farthest.
uniform float step_1 = 0.5;
uniform float step_2 = 0.75;
uniform float step_3 = 0.9;
uniform float dark_1 = 0.4;
uniform float dark_2 = 0.75;

float step_darkness(float distance_fraction) {
	if (distance_fraction < step_1) {
		return 0.0;
	} else if (distance_fraction < step_2) {
		return dark_1;
	} else if (distance_fraction < step_3) {
		return dark_2;
	}
	return 1.0;
}

void fragment() {
	vec2 pixels = vec2(textureSize(TEXTURE, 0)) * cell_size;
	vec2 snapped = (floor(UV * pixels) + 0.5) / pixels;
	float darkness = step_darkness(texture(TEXTURE, snapped).r);
	if (darkness < 1.0) {
		vec2 world = window_origin + snapped * pixels;
		vec2 glow_uv = (world - glow_origin) / (glow_size * cell_size);
		if (glow_uv.x >= 0.0 && glow_uv.y >= 0.0 && glow_uv.x <= 1.0 && glow_uv.y <= 1.0) {
			darkness = min(darkness, step_darkness(texture(glow_map, glow_uv).a));
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
