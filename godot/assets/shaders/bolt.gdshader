shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// Barrel Heaven projectile bolt — soft additive glow, fresnel edge falloff.

uniform vec4 u_core : source_color = vec4(1.0, 0.72, 0.18, 1.0);
uniform float u_fade : hint_range(0.0, 1.0) = 1.0;
uniform float u_intensity = 1.8;

void fragment() {
	float fr = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float a = clamp(1.0 - fr * 0.8, 0.15, 1.0) * u_fade;
	ALBEDO = u_core.rgb * u_intensity;
	ALPHA = a * u_core.a;
}
