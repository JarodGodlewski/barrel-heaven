shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

// Barrel Heaven arena floor — procedural grid, replaces Three.js GridHelper.

uniform vec3 u_line_major : source_color = vec3(0.22, 0.16, 0.06);
uniform vec3 u_line_minor : source_color = vec3(0.10, 0.08, 0.04);
uniform float u_cell = 120.0;
uniform float u_alpha : hint_range(0.0, 1.0) = 0.16;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz / u_cell;
	vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	float minor = 1.0 - min(min(g.x, g.y), 1.0);
	ALBEDO = mix(u_line_minor, u_line_major, minor);
	ALPHA = u_alpha * max(minor, 0.25);
}
