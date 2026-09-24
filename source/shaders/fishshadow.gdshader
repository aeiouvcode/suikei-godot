shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float taper = mix(1.0, 0.45, clamp(UV.y, 0.0, 1.0));
	float d = length(vec2(p.x / taper, p.y));
	ALBEDO = vec3(0.0, 0.10, 0.10);
	ALPHA = (1.0 - smoothstep(0.2, 1.0, d)) * 0.85;
}
