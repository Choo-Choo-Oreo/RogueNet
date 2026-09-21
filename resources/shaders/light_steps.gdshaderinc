// The brightness steps of a player's light, shared by the darkness shader and the halo other
// players show, so both keep the same look and radius.
// Distance fractions run from 0 (at the light) to 1 (at light_radius).
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
