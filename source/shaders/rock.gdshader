shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/underwater.gdshaderinc"
uniform sampler2D rock_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 granite : source_color = vec3(0.52, 0.52, 0.50);
uniform vec3 moss : source_color = vec3(0.13, 0.18, 0.07);
uniform float moss_amount = 0.6;
uniform float seed = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec3 tri(vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z);
	return texture(rock_noise, p.yz * s).rgb * w.x + texture(rock_noise, p.xz * s).rgb * w.y + texture(rock_noise, p.xy * s).rgb * w.z;
}
void fragment() {
	float t = TIME;
	vec3 p = wp + vec3(seed * 13.1, 0.0, seed * 7.3);
	float big = tri(p, wn, 0.18).r;
	float fine = tri(p, wn, 1.6).r;
	float speck = tri(p, wn, 5.0).r;
	vec3 col = granite * (0.7 + 0.5 * big) * (0.85 + 0.3 * fine);
	col = mix(col, vec3(0.12), smoothstep(0.62, 0.7, speck) * 0.6);
	col = mix(col, vec3(0.85, 0.84, 0.8), smoothstep(0.66, 0.72, fine) * 0.25);
	float depth = g_water_y - wp.y;
	float rough = 0.8;
	if (depth <= 0.0) {
		float h = -depth;
		float up = smoothstep(0.35, 0.85, wn.y);
		float m = up * smoothstep(0.08, 0.3, h) * smoothstep(0.35, 0.6, big + fine * 0.4) * moss_amount * 1.6;
		vec3 mc = moss * (0.7 + 0.6 * fine);
		col = mix(col, mc, clamp(m, 0.0, 1.0));
		float wet = 1.0 - smoothstep(0.0, 0.15, h);
		col = mix(col, col * 0.5, wet);
		rough = mix(0.85, 0.3, wet);
		ALBEDO = col;
	} else {
		col = mix(col, col * vec3(0.55, 0.75, 0.45), 0.5 * smoothstep(0.4, 0.8, wn.y));
		vec3 insc;
		vec3 T = view_transmit(wp, CAMERA_POSITION_WORLD, insc);
		vec3 c = caustics_rgb(wp.xz + wp.y * 0.3, depth, t) * smoothstep(-0.2, 0.6, wn.y);
		ALBEDO = col * T * (0.72 + c);
		EMISSION = insc * 0.55;
		rough = 0.6;
	}
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
