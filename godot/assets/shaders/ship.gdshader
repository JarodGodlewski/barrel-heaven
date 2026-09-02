shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_toon;

uniform vec3 u_primary : source_color = vec3(0.82, 0.72, 0.52);
uniform vec3 u_secondary : source_color = vec3(0.32, 0.22, 0.12);
uniform vec3 u_trim : source_color = vec3(0.55, 0.28, 0.08);
uniform vec3 u_emissive : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 u_mask = vec3(1.0, 0.0, 0.0);
uniform float u_engine_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float u_damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float u_rim_strength : hint_range(0.0, 2.0) = 1.15;

void fragment() {
	vec3 base = mix(u_primary, u_secondary, clamp(u_mask.g * 1.5, 0.0, 1.0));
	base = mix(base, u_trim, clamp(u_mask.b * 1.5, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	vec3 col = base;
	col += fres * u_rim_strength * vec3(1.0, 0.72, 0.28) * 0.55;
	col += u_emissive * u_engine_pulse * clamp(u_mask.r, 0.0, 1.0) * 1.6;
	col = mix(col, vec3(1.0, 0.45, 0.18), u_damage_flash * 0.65);
	ALBEDO = col;
	EMISSION = u_emissive * (u_engine_pulse * 0.35) + vec3(1.0, 0.35, 0.12) * (u_damage_flash * 0.4);
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
