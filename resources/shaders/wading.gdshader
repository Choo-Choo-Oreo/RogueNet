shader_type canvas_item;

// A creature standing in water (Wading.gd): drawn a little lower, and everything below the
// water's surface is tinted and see-through, with a pale rim where the surface meets the
// body. The surface wobbles a pixel up and down along its length. Gear layers use their
// body's material (use_parent_material), so they sink with it. amount = 0 is dry ground.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Local y of the feet: half the frame's height (the sprite is centred).
uniform float feet_y = 8.0;
// How far the body sinks, and how high the water comes above the ground, at amount 1 (pixels).
uniform float sink = 1.0;
uniform float depth = 4.0;
uniform vec4 water : source_color = vec4(0.22, 0.42, 0.72, 1.0);
uniform vec4 foam : source_color = vec4(0.82, 0.92, 1.0, 1.0);
// How much of the water's colour the underwater part takes, and how much of it still shows.
uniform float tint = 0.6;
uniform float underwater_alpha = 0.45;
// Differs per creature so two people wading side by side don't wobble in step.
uniform float phase = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
	VERTEX.y += round(sink * amount);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (amount > 0.0 && c.a > 0.0) {
		// whole pixels only, so the surface stays on the art's grid
		float row = floor(local_pos.y);
		float col = floor(local_pos.x);
		float wobble = round(sin(TIME * 2.6 + col * 0.9 + phase) * 0.6);
		float surface = feet_y - round((depth + sink) * amount) + wobble;
		if (row > surface) {
			c.rgb = mix(c.rgb, water.rgb, tint);
			c.a *= underwater_alpha;
		} else if (row == surface) {
			c.rgb = mix(c.rgb, foam.rgb, 0.65);
		}
	}
	COLOR = c;
}
