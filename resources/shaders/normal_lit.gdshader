shader_type canvas_item;

// Normal-map shading driven by code instead of a Godot light.
// A flat surface is left exactly as drawn. Surfaces tilted toward the light get brighter,
// tilted away get darker, in flat steps, fading out with distance from the light.
uniform float light_height = 24.0;       // lower = stronger, sharper highlights
uniform float strength = 0.8;            // overall amount of shading
uniform float reach = 96.0;              // pixels from the light where shading fades to nothing
uniform float steps = 4.0;               // brightness levels of the shading (higher = smoother)

// World positions of the torches on screen (set by LightMap.gd); none when nobody holds one.
uniform vec2 lights[4];
uniform int light_count = 0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// What one light does to a pixel: x = how much it brightens or darkens (already faded with
// distance), y = how strongly the light reaches this pixel (1 at the light, 0 at `reach`).
vec2 light_shade(vec3 normal, vec2 light) {
	vec2 to_light = light - world_pos;
	// The normal maps are green-up, screen y is down, so flip y for the light direction.
	vec3 light_dir = normalize(vec3(to_light.x, -to_light.y, light_height));
	float tilt = max(dot(normal, light_dir), 0.0) - light_dir.z;
	float falloff = 1.0 - clamp(length(to_light) / reach, 0.0, 1.0);
	float shade = floor(tilt * strength * steps + 0.5) / steps;
	return vec2(shade * falloff, falloff);
}

void fragment() {
	vec3 normal = normalize(texture(NORMAL_TEXTURE, UV).xyz * 2.0 - 1.0);
	// Blend the lights instead of choosing one. Choosing (nearest, or strongest) switches at a line
	// between two players and leaves a hard seam. Adding the lights is smooth everywhere, and dividing
	// by the total reach (never less than 1) stops the effect doubling where they overlap. With one
	// light the total reach is at most 1, so it is that light's shading alone.
	vec2 sum = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		if (i < light_count) {
			sum += light_shade(normal, lights[i]);
		}
	}
	COLOR.rgb *= 1.0 + sum.x / max(sum.y, 1.0);
}
