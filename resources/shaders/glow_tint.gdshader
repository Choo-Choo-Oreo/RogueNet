shader_type canvas_item;

// Tints and brightens what is already on screen near a glowing tile (lava, glowstone).
// Coloured light works by multiplying: grey stone under orange light keeps its red and loses
// green and blue. Pixels the player can't see are already black, so multiplying leaves them
// black and the glow never reveals anything.
//
// The sprite's texture is the glow map from LightMap.gd: rgb = glow colour, alpha = distance
// fraction (0 = at the source, 1 = no glow). Steps match light_smooth.gdshader.
uniform float cell_size = 8.0;
uniform float tint_strength = 0.6;   // how far pixels shift toward the glow colour at full level
uniform float boost = 0.35;          // extra brightness at full level, so the source reads as glowing
uniform float step_1 = 0.5;
uniform float step_2 = 0.75;
uniform float step_3 = 0.9;
uniform float level_1 = 0.6;
uniform float level_2 = 0.25;
uniform sampler2D screen : hint_screen_texture, filter_nearest;

float glow_level(float distance_fraction) {
	if (distance_fraction < step_1) {
		return 1.0;
	} else if (distance_fraction < step_2) {
		return level_1;
	} else if (distance_fraction < step_3) {
		return level_2;
	}
	return 0.0;
}

void fragment() {
	vec2 pixels = vec2(textureSize(TEXTURE, 0)) * cell_size;
	vec2 snapped = (floor(UV * pixels) + 0.5) / pixels;
	vec4 glow = texture(TEXTURE, snapped);
	float level = glow_level(glow.a);
	vec3 scene = texture(screen, SCREEN_UV).rgb;
	vec3 tint = glow.rgb / max(max(glow.r, glow.g), max(glow.b, 0.001));
	vec3 lit = scene * mix(vec3(1.0), tint, level * tint_strength) * (1.0 + boost * level);
	COLOR = vec4(lit, 1.0);
}
