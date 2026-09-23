shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
#include "res://shaders/underwater.gdshaderinc"
uniform vec3 sky_reflect : source_color = vec3(0.78, 0.86, 0.88);
uniform vec3 bank_reflect : source_color = vec3(0.06, 0.10, 0.07);
uniform float channel_half = 5.0;
uniform float rapid_z = -15.0;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec4 ripples[8];
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = TIME;
	vec2 s = water_slope(wp.xz, t);
	float rapid = smoothstep(rapid_z + 5.0, rapid_z, wp.z);
	s *= 1.0 + rapid * 2.5;
	// tap / cast ripples: xy=pos, z=start time, w=strength
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		float age = t - r.z;
		if (age > 0.0 && age < 3.0 && r.w > 0.0) {
			vec2 d = wp.xz - r.xy;
			float dist = length(d);
			float radius = age * 0.9;
			float ring = sin((dist - radius) * 26.0) * exp(-pow((dist - radius) * 6.0, 2.0));
			float amp = r.w * (1.0 - age / 3.0) * 0.8 / (1.0 + dist * 2.0);
			s += normalize(d + 1e-4) * ring * amp;
		}
	}
	vec3 n = normalize(vec3(-s.x * 0.35, 1.0, -s.y * 0.35));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float cosv = clamp(dot(n, v), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - cosv, 5.0);
	// reflected direction: near banks the reflection is dark forest
	vec3 rd = reflect(-v, n);
	float bankness = smoothstep(channel_half * 0.35, channel_half * 1.1, abs(wp.x)) + smoothstep(0.35, 0.05, rd.y);
	vec3 refl = mix(sky_reflect, bank_reflect, clamp(bankness, 0.0, 1.0) * 0.85);
	float foam = 0.0;
	if (rapid > 0.001) {
		float f1 = texture(foam_noise, wp.xz * vec2(0.6, 0.25) + vec2(0.0, t * 0.35)).r;
		float f2 = texture(foam_noise, wp.xz * vec2(1.3, 0.5) + vec2(0.2, t * 0.6)).r;
		foam = smoothstep(0.55, 0.8, f1 * 0.6 + f2 * 0.5) * rapid;
	}
	ALBEDO = mix(refl, vec3(0.95), foam);
	ALPHA = clamp(fres * 0.9 + 0.05 + foam * 0.8, 0.0, 1.0);
	ROUGHNESS = mix(0.04, 0.5, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
