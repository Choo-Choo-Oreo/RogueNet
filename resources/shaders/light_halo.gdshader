shader_type canvas_item;
render_mode blend_add;

// The glow other players show: a disc the size of a player's light, in the same brightness steps,
// added on top of the darkness. It shows where they are without lighting the ground around them.
#include "res://resources/shaders/light_steps.gdshaderinc"

uniform vec4 halo_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float strength = 0.35;

void fragment() {
	float fraction = length(UV - vec2(0.5)) * 2.0;
	float lit = 1.0 - step_darkness(fraction);
	COLOR = vec4(halo_color.rgb, lit * strength);
}
