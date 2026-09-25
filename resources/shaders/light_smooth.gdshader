shader_type canvas_item;

// The darkness over everything the team can't see (PlayerVision.gd). A pixel is seen when a
// teammate's sight reaches its tile and some light (a torch, a glowing tile) reaches it, drawn
// as bright as the brightest of those lights; or when a teammate touches its tile, drawn dim.
// The brightness steps (step_1..3, dark_1..2, step_darkness) live in a shared include.
#include "res://resources/shaders/light_steps.gdshaderinc"

// This sprite's own texture is blank: it only sets the size of the area drawn, in tiles.
uniform float window_cell = 16.0;
uniform vec2 window_origin = vec2(0.0);  // world pixel of this sprite's top-left corner

// Torch maps (LightMap.gd), one per torch on screen: per 8x8 cell, how far its light travelled
// (0 = at the source, 1 = the edge or unreached). Each has its own window and world origin.
uniform float light_cell = 8.0;
uniform sampler2D light_map_1 : filter_linear;
uniform sampler2D light_map_2 : filter_linear;
uniform sampler2D light_map_3 : filter_linear;
uniform sampler2D light_map_4 : filter_linear;
uniform vec2 light_origin_1 = vec2(0.0);
uniform vec2 light_origin_2 = vec2(0.0);
uniform vec2 light_origin_3 = vec2(0.0);
uniform vec2 light_origin_4 = vec2(0.0);
uniform int light_count = 0;

// Glowing tiles (lava, glowstone), baked once for the whole dungeon: rgb = glow colour,
// alpha = distance fraction like the torch maps.
uniform sampler2D glow_map : filter_linear;
uniform vec2 glow_origin = vec2(0.0);    // world pixel of the glow map's top-left corner
uniform vec2 glow_size = vec2(1.0);      // glow map size in cells

// Sight maps (PlayerVision.gd), one per teammate: per tile, r = in sight (1) or not,
// g = touched (1) or not.
uniform float sight_cell = 16.0;
uniform sampler2D sight_map_1 : filter_nearest;
uniform sampler2D sight_map_2 : filter_nearest;
uniform sampler2D sight_map_3 : filter_nearest;
uniform sampler2D sight_map_4 : filter_nearest;
uniform vec2 sight_origin_1 = vec2(0.0);
uniform vec2 sight_origin_2 = vec2(0.0);
uniform vec2 sight_origin_3 = vec2(0.0);
uniform vec2 sight_origin_4 = vec2(0.0);
uniform int sight_count = 0;
// How far out a touched tile counts as, like a light fraction (0.5-0.75 = the first dim step).
uniform float touch_fraction = 0.6;

// Where a world position falls on a window map (outside 0..1 = past its edge).
vec2 window_uv(vec2 size, vec2 origin, float cell, vec2 world) {
	return (world - origin) / (size * cell);
}

bool in_window(vec2 uv) {
	return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}

// A torch map's fraction at a world position (1 = dark past its edge).
float light_at(sampler2D map, vec2 origin, vec2 world) {
	vec2 uv = window_uv(vec2(textureSize(map, 0)), origin, light_cell, world);
	return in_window(uv) ? texture(map, uv).r : 1.0;
}

// A sight map at a world position: x = in sight, y = touched (0 past its edge).
vec2 sense_at(sampler2D map, vec2 origin, vec2 world) {
	vec2 uv = window_uv(vec2(textureSize(map, 0)), origin, sight_cell, world);
	return in_window(uv) ? texture(map, uv).rg : vec2(0.0);
}

void fragment() {
	vec2 pixels = vec2(textureSize(TEXTURE, 0)) * window_cell;
	vec2 world = window_origin + floor(UV * pixels) + 0.5;
	float light = 1.0;
	if (light_count > 0) { light = min(light, light_at(light_map_1, light_origin_1, world)); }
	if (light_count > 1) { light = min(light, light_at(light_map_2, light_origin_2, world)); }
	if (light_count > 2) { light = min(light, light_at(light_map_3, light_origin_3, world)); }
	if (light_count > 3) { light = min(light, light_at(light_map_4, light_origin_4, world)); }
	vec2 glow_uv = window_uv(glow_size, glow_origin, light_cell, world);
	if (in_window(glow_uv)) {
		light = min(light, texture(glow_map, glow_uv).a);
	}
	vec2 sense = vec2(0.0);
	if (sight_count > 0) { sense = max(sense, sense_at(sight_map_1, sight_origin_1, world)); }
	if (sight_count > 1) { sense = max(sense, sense_at(sight_map_2, sight_origin_2, world)); }
	if (sight_count > 2) { sense = max(sense, sense_at(sight_map_3, sight_origin_3, world)); }
	if (sight_count > 3) { sense = max(sense, sense_at(sight_map_4, sight_origin_4, world)); }
	float darkness = sense.x > 0.5 ? step_darkness(light) : 1.0;
	if (sense.y > 0.5) {
		darkness = min(darkness, step_darkness(touch_fraction));
	}
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
