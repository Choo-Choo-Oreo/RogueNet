shader_type canvas_item;

// The brightness steps (step_1..3, dark_1..2, step_darkness) live in a shared include, because
// the halo other players show uses the same ones.
#include "res://resources/shaders/light_steps.gdshaderinc"

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

// The other players' lights (vision is shared): each has its own window of cells (same layout as
// this sprite's texture) and its own world origin. A pixel takes the brightest light that reaches it.
uniform sampler2D other_map_1 : filter_linear;
uniform sampler2D other_map_2 : filter_linear;
uniform sampler2D other_map_3 : filter_linear;
uniform vec2 other_origin_1 = vec2(0.0);
uniform vec2 other_origin_2 = vec2(0.0);
uniform vec2 other_origin_3 = vec2(0.0);
uniform int other_count = 0;

// Distance fraction of another player's light at a world position (1 = outside its window).
float other_fraction(sampler2D map, vec2 origin, vec2 world) {
	vec2 uv = (world - origin) / (vec2(textureSize(map, 0)) * cell_size);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	return texture(map, uv).r;
}

void fragment() {
	vec2 pixels = vec2(textureSize(TEXTURE, 0)) * cell_size;
	vec2 snapped = (floor(UV * pixels) + 0.5) / pixels;
	vec2 world = window_origin + snapped * pixels;
	float darkness = step_darkness(texture(TEXTURE, snapped).r);
	if (other_count > 0) {
		darkness = min(darkness, step_darkness(other_fraction(other_map_1, other_origin_1, world)));
	}
	if (other_count > 1) {
		darkness = min(darkness, step_darkness(other_fraction(other_map_2, other_origin_2, world)));
	}
	if (other_count > 2) {
		darkness = min(darkness, step_darkness(other_fraction(other_map_3, other_origin_3, world)));
	}
	if (darkness < 1.0) {
		vec2 glow_uv = (world - glow_origin) / (glow_size * cell_size);
		if (glow_uv.x >= 0.0 && glow_uv.y >= 0.0 && glow_uv.x <= 1.0 && glow_uv.y <= 1.0) {
			darkness = min(darkness, step_darkness(texture(glow_map, glow_uv).a));
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
