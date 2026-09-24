// Shared underwater optics: absorption along the refracted view path,
// in-scatter, sun attenuation with depth and animated chromatic caustics.
global uniform float g_water_y;
global uniform vec3 g_sun_dir;
global uniform vec3 g_absorb;
global uniform vec3 g_scatter;
global uniform float g_caustic_power;
global uniform float g_flow_speed;
global uniform sampler2D g_caustics : filter_linear_mipmap, repeat_enable;
global uniform sampler2D g_water_n : filter_linear_mipmap, repeat_enable;

vec2 water_slope(vec2 xz, float t) {
	vec2 flow = vec2(0.0, g_flow_speed);
	vec3 a = texture(g_water_n, xz * 0.11 + flow * t * 0.11).xyz * 2.0 - 1.0;
	vec3 b = texture(g_water_n, xz * 0.23 + vec2(0.37, 0.61) + flow * t * 0.19 + vec2(t * 0.013, 0.0)).xyz * 2.0 - 1.0;
	return (a.xy * 0.6 + b.xy * 0.4);
}

float caustic_at(vec2 p, float t) {
	float c1 = texture(g_caustics, p * 0.42 + vec2(t * 0.021, t * 0.047 * g_flow_speed + t * 0.01)).r;
	float c2 = texture(g_caustics, p * 0.57 + vec2(-t * 0.018, t * 0.033 + 0.5)).r;
	return min(c1, c2);
}

vec3 caustics_rgb(vec2 xz, float depth, float t) {
	vec2 s = water_slope(xz, t) * 0.18 * clamp(depth, 0.0, 2.5);
	vec2 p = xz + s;
	float spread = 0.010 + depth * 0.012;
	vec3 c = vec3(caustic_at(p + vec2(spread, 0.0), t), caustic_at(p, t), caustic_at(p - vec2(spread, 0.0), t));
	float fade = smoothstep(0.0, 0.12, depth) * exp(-depth * 0.35);
	return pow(c, vec3(1.6)) * 3.0 * g_caustic_power * fade;
}

// returns transmittance along refracted view path and sets scatter weight
vec3 view_transmit(vec3 wp, vec3 cam, out vec3 inscatter) {
	float d = max(g_water_y - wp.y, 0.0);
	vec3 v = normalize(wp - cam);
	float sin_i = sqrt(max(0.0, 1.0 - v.y * v.y));
	float sin_t = sin_i / 1.333;
	float cos_t = sqrt(max(0.05, 1.0 - sin_t * sin_t));
	float L = d / cos_t + d; // view path + sun path down
	vec3 T = exp(-g_absorb * L);
	// single scattering with a forward-peaked Henyey-Greenstein phase (after Clearwater, MIT):
	// looking down-sun the water column glows a little brighter than looking into shadow
	vec3 sun_t = refract(-g_sun_dir, vec3(0.0, 1.0, 0.0), 1.0 / 1.3335);
	vec3 tr = refract(v, vec3(0.0, 1.0, 0.0), 1.0 / 1.3335);
	float cs = dot(sun_t, -tr);
	float g = 0.75;
	float ph = (1.0 - g * g) / (12.566 * pow(1.0 + g * g - 2.0 * g * cs, 1.5));
	inscatter = g_scatter * (1.0 - exp(-g_absorb * (d / cos_t) * 0.9)) * (0.8 + 2.2 * ph);
	return T;
}
