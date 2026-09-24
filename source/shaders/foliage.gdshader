shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 leaf : source_color = vec3(0.07, 0.13, 0.08);
uniform vec3 bark : source_color = vec3(0.25, 0.17, 0.12);
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (COLOR.g > 0.5) {
		VERTEX.x += sin(TIME * 0.8 + wp.x * 0.3 + wp.z * 0.2) * 0.04 * VERTEX.y * 0.1;
	}
}
void fragment() {
	float n = texture(noise_tex, wp.xz * 0.4 + wp.y * 0.3).r;
	float n2 = texture(noise_tex, vec2(wp.x + wp.z, wp.y) * 2.5).r;
	float stripe = 0.75 + 0.35 * texture(noise_tex, vec2(atan(wp.x, wp.z) * 3.0, wp.y * 0.15)).r;
	vec3 c;
	if (COLOR.g > 0.5) {
		float l1 = texture(noise_tex, wp.xz * 3.1 + wp.y * 2.3).r;
		float l2 = texture(noise_tex, vec2(wp.x - wp.z, wp.y) * 4.3).r;
		float clump = smoothstep(0.3, 0.7, l1 * 0.6 + l2 * 0.6);
		vec3 lt = mix(leaf, leaf * vec3(1.25, 1.2, 0.8), COLOR.r);
		c = lt * (0.5 + 1.0 * n) * mix(0.35, 1.25, clump);
		NORMAL = normalize(NORMAL + (vec3(l1, l2, l1 * l2) - 0.4) * 0.9);
	} else {
		c = bark * stripe * (0.7 + 0.4 * n2);
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
