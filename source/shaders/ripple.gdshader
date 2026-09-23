shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform float age = 0.0;
uniform float life = 1.6;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float k = age / life;
	float ring = exp(-pow((r - k * 0.9) * 14.0, 2.0)) + 0.5 * exp(-pow((r - k * 0.6) * 18.0, 2.0));
	ALBEDO = vec3(0.9, 1.0, 1.0);
	ALPHA = ring * (1.0 - k) * 0.55;
}
