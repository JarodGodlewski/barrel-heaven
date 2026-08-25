shader_type sky;

// Barrel Heaven sky — The Well. Deep space gradient + procedural twinkling stars.
// Replaces the Three.js FogExp2 + 900-point starfield.

uniform vec3 u_top : source_color = vec3(0.02, 0.04, 0.08);
uniform vec3 u_bottom : source_color = vec3(0.01, 0.02, 0.05);
uniform float u_star_density : hint_range(0.8, 1.0) = 0.985;
uniform float u_star_scale = 220.0;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	float h = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(u_bottom, u_top, h);
	vec3 cell = floor(EYEDIR * u_star_scale);
	float star = step(u_star_density, hash(cell));
	float tw = 0.6 + 0.4 * sin(TIME * 2.0 + hash(cell + vec3(1.0)) * 40.0);
	col += vec3(0.73, 0.83, 1.0) * star * tw * 0.85;
	COLOR = col;
}
