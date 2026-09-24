shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://shaders/underwater.gdshaderinc"
uniform vec3 back_color : source_color = vec3(0.25, 0.28, 0.22);
uniform vec3 side_color : source_color = vec3(0.62, 0.62, 0.55);
uniform vec3 belly_color : source_color = vec3(0.92, 0.92, 0.88);
uniform vec3 spot_color : source_color = vec3(0.08, 0.08, 0.07);
uniform vec3 accent_color : source_color = vec3(0.8, 0.25, 0.15);
uniform float parr = 0.0;
uniform float spots = 0.0;
uniform float red_spots = 0.0;
uniform float accent_band = 0.0;
uniform float yellow_patch = 0.0;
uniform float swim_phase = 0.0;
uniform float swim_freq = 6.0;
uniform float swim_amp = 0.06;
uniform float thrash = 0.0;
uniform float out_of_water = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
varying vec3 lp;
void vertex() {
	float t = UV.x; // 0 head -> 1 tail
	float w = pow(clamp(t, 0.0, 1.2), 1.6);
	float a = swim_amp * (1.0 + thrash * 2.5);
	float f = swim_freq * (1.0 + thrash * 1.5);
	VERTEX.x += sin(TIME * f + swim_phase - t * 5.5) * a * w;
	VERTEX.x += sin(TIME * f * 0.5 + swim_phase) * a * 0.15 * (1.0 - t);
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float spotfield(vec2 p, float scale, float r) {
	vec2 g = floor(p * scale); vec2 f = fract(p * scale);
	float m = 9.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 c = o + vec2(hash(g + o), hash(g + o + 17.0)) - f;
		m = min(m, length(c));
	}
	return 1.0 - smoothstep(r * 0.7, r, m);
}
void fragment() {
	float t = UV.x;
	float around = UV.y; // 0 = top (dorsal), 0.5 = belly
	float fin = COLOR.r; // 1 on fins
	float up = cos(around * 6.2831853);
	vec3 col = mix(belly_color, side_color, smoothstep(-0.7, 0.1, up));
	// seen from the bank the dorsal view dominates: a dark olive back with a thin silver flank edge
	col = mix(col, back_color, smoothstep(-0.1, 0.6, up));
	vec2 sp = vec2(t * 7.0, around * 5.0);
	// parr marks: vertical ovals along lateral line
	float pm = smoothstep(0.35, 0.1, abs(fract(t * 9.0 + 0.2) - 0.5)) * smoothstep(0.75, 0.2, abs(up)) * smoothstep(0.12, 0.25, t) * smoothstep(0.85, 0.7, t);
	col = mix(col, back_color * 0.65, pm * parr * 0.8);
	float s = spotfield(vec2(t * 3.0, around * 2.0), 6.0, 0.22) * smoothstep(-0.1, 0.5, up);
	col = mix(col, spot_color, s * spots);
	float rs = spotfield(vec2(t * 3.0 + 0.5, around * 2.0 + 0.3), 5.0, 0.16) * smoothstep(0.7, 0.0, abs(up)) * smoothstep(0.1, 0.3, t);
	col = mix(col, accent_color, rs * red_spots);
	float band = smoothstep(0.45, 0.0, abs(up + 0.05)) * smoothstep(0.1, 0.25, t) * smoothstep(0.95, 0.7, t);
	col = mix(col, accent_color, band * accent_band * 0.75);
	float yp = (1.0 - smoothstep(0.0, 0.06, length(vec2(t - 0.3, (abs(up) - 0.15) * 0.5)))) ;
	col = mix(col, vec3(0.95, 0.8, 0.2), yp * yellow_patch);
	// eye
	float eye = 1.0 - smoothstep(0.012, 0.02, length(vec2((t - 0.07) * 1.0, abs(up) - 0.0) * vec2(1.0, 0.08)));
	col = mix(col, vec3(0.02), eye * step(abs(up), 0.4) * (1.0 - fin));
	col = mix(col, back_color * 0.8 + 0.08, fin * 0.8);
	col *= 0.9 + 0.2 * texture(noise_tex, vec2(t, around) * 3.0).r;
	float depth = g_water_y - wp.y;
	if (depth > 0.0 && out_of_water < 0.5) {
		vec3 insc;
		vec3 T = view_transmit(wp, CAMERA_POSITION_WORLD, insc);
		vec3 c = caustics_rgb(wp.xz, depth, TIME) * smoothstep(0.0, 0.8, up);
		ALBEDO = col * pow(T, vec3(0.75)) * (0.8 + c * 0.7);
		insc *= 0.8;
		EMISSION = insc * 0.55;
		ROUGHNESS = 0.45;
	} else {
		ALBEDO = col;
		ROUGHNESS = 0.3;
	}
	SPECULAR = 0.6;
}
