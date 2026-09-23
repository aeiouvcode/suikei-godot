shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/underwater.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;
uniform float tile = 0.36;
uniform vec3 moss_color : source_color = vec3(0.12, 0.17, 0.07);
uniform vec3 earth_color : source_color = vec3(0.16, 0.13, 0.10);
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = TIME;
	float depth = g_water_y - wp.y;
	vec2 uv = wp.xz * tile;
	if (depth > 0.0) {
		uv += water_slope(wp.xz, t) * 0.035 * clamp(depth, 0.0, 2.0);
	}
	vec3 alb = texture(albedo_tex, uv).rgb;
	vec3 alb2 = texture(albedo_tex, uv * 0.37 + vec2(0.3, 0.7)).rgb;
	float big = texture(detail_noise, wp.xz * 0.05).r;
	alb = mix(alb, alb2, smoothstep(0.45, 0.65, big) * 0.5);
	alb *= 0.85 + 0.3 * texture(detail_noise, wp.xz * 0.21).r;
	vec3 n = texture(normal_tex, uv).xyz;
	float rough = 0.85;
	if (depth <= 0.0) {
		float h = -depth;
		float wet = 1.0 - smoothstep(0.0, 0.12, h);
		alb = mix(alb * vec3(0.92, 0.9, 0.86), alb * 0.55, wet);
		rough = mix(0.9, 0.35, wet);
		float mossy = smoothstep(0.35, 0.9, h + (texture(detail_noise, wp.xz * 0.3).r - 0.5) * 0.8);
		float patchy = texture(detail_noise, wp.xz * 0.9).r;
		vec3 floor_c = mix(earth_color, moss_color, smoothstep(0.35, 0.65, patchy));
		floor_c = mix(floor_c, vec3(0.2, 0.16, 0.1) * 0.8, smoothstep(0.6, 0.8, texture(detail_noise, wp.xz * 2.7).r) * 0.5);
		floor_c *= 0.8 + 0.4 * texture(albedo_tex, wp.xz * 1.3).r;
		alb = mix(alb, floor_c, mossy);
		ALBEDO = alb;
	} else {
		// underwater: soft algae film + optics
		alb = mix(alb, alb * vec3(0.8, 0.9, 0.62), 0.25 * smoothstep(0.3, 0.7, texture(detail_noise, wp.xz * 0.13).r));
		alb = mix(alb, vec3(0.5, 0.49, 0.45), clamp(depth * 0.3, 0.0, 0.45));
		vec3 insc;
		vec3 T = view_transmit(wp, CAMERA_POSITION_WORLD, insc);
		vec3 c = caustics_rgb(wp.xz, depth, t);
		ALBEDO = alb * T * (0.72 + c);
		EMISSION = insc * 0.55;
		rough = 0.7;
	}
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
