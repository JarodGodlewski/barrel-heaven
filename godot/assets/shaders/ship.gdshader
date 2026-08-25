shader_type spatial;
render_mode cull_back, specular_disabled;

// Barrel Heaven player ship — palette mask via vertex COLOR channels.
// Mesh builder must assign vertex colors: R = engine/emissive zone,
// G = secondary paint, B = trim. Uncolored meshes render as trim.

uniform vec3 u_primary : source_color = vec3(0.91, 0.95, 0.96);
uniform vec3 u_secondary : source_color = vec3(0.16, 0.62, 0.56);
uniform vec3 u_trim : source_color = vec3(0.10, 0.30, 0.28);
uniform vec3 u_emissive : source_color = vec3(0.24, 0.88, 0.76);
uniform float u_engine_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float u_damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float u_rim_strength : hint_range(0.0, 2.0) = 0.7;

varying vec3 v_mask;

void vertex() {
	v_mask = COLOR.rgb;
}

void fragment() {
	vec3 base = mix(u_primary, u_secondary, clamp(v_mask.g * 1.5, 0.0, 1.0));
	base = mix(base, u_trim, clamp(v_mask.b * 1.5, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	vec3 col = base + fres * u_rim_strength * u_emissive;
	col += u_emissive * u_engine_pulse * clamp(v_mask.r, 0.0, 1.0) * 1.6;
	col = mix(col, vec3(1.0, 0.35, 0.25), u_damage_flash * 0.65);
	ALBEDO = col;
	EMISSION = u_emissive * (u_engine_pulse * 0.35) + vec3(1.0, 0.3, 0.2) * (u_damage_flash * 0.4);
	ROUGHNESS = 0.55;
	METALLIC = 0.15;
}
