shader_type canvas_item;

// Normal-map shading driven by code instead of a Godot light.
// A flat surface is left exactly as drawn. Surfaces tilted toward the light get brighter,
// tilted away get darker, in flat steps, fading out with distance from the light.
uniform vec2 light_pos = vec2(0.0);      // world position of the light (set by LightMap.gd)
uniform float light_height = 24.0;       // lower = stronger, sharper highlights
uniform float strength = 0.8;            // overall amount of shading
uniform float reach = 96.0;              // pixels from the light where shading fades to nothing
uniform float steps = 4.0;               // brightness levels of the shading (higher = smoother)

// The other players' lights (set by LightMap.gd).
uniform vec2 other_lights[3];
uniform int other_light_count = 0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// How much one light brightens or darkens a pixel.
float light_shade(vec3 normal, vec2 light) {
	vec2 to_light = light - world_pos;
	// The normal maps are green-up, screen y is down, so flip y for the light direction.
	vec3 light_dir = normalize(vec3(to_light.x, -to_light.y, light_height));
	float tilt = max(dot(normal, light_dir), 0.0) - light_dir.z;
	float falloff = 1.0 - clamp(length(to_light) / reach, 0.0, 1.0);
	float shade = floor(tilt * strength * steps + 0.5) / steps;
	return shade * falloff;
}

void fragment() {
	vec3 normal = normalize(texture(NORMAL_TEXTURE, UV).xyz * 2.0 - 1.0);
	// Use whichever light affects this pixel the most. Picking the nearest light made a hard seam
	// halfway between two players, and adding the lights doubled the effect where they overlap.
	// Each light fades out smoothly and the strongest of them is smooth too, without the doubling.
	float total = light_shade(normal, light_pos);
	for (int i = 0; i < 3; i++) {
		if (i < other_light_count) {
			float other = light_shade(normal, other_lights[i]);
			if (abs(other) > abs(total)) {
				total = other;
			}
		}
	}
	COLOR.rgb *= 1.0 + total;
}
