shader_type spatial;
render_mode cull_back;

// Barrel Heaven enemy — emissive pulse scales as hull drops, dissolve on death.
// u_death_t: 0 = alive, 1 = fully dissolved.

uniform vec3 u_body : source_color = vec3(0.55, 0.18, 0.18);
uniform vec3 u_accent : source_color = vec3(0.90, 0.25, 0.20);
uniform float u_pulse_speed : hint_range(0.0, 10.0) = 2.4;
uniform float u_hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float u_death_t : hint_range(0.0, 1.0) = 0.0;
uniform float u_flash : hint_range(0.0, 1.0) = 0.0;
uniform float u_dissolve_scale = 220.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * u_pulse_speed);
	vec3 col = mix(u_body, u_accent, pulse * 0.35);
	col = mix(col, vec3(1.0), u_flash * 0.85);
	ALBEDO = col;
	EMISSION = u_accent * pulse * (1.0 - u_hp_ratio) * 0.8 + vec3(u_flash) * 0.6;
	ROUGHNESS = 0.7;
	if (u_death_t > 0.001) {
		float n = hash(floor(UV * u_dissolve_scale));
		if (n > 1.0 - u_death_t) {
			discard;
		}
	}
}
