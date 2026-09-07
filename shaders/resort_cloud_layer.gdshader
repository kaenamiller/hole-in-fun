shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform vec3 cloud_tint = vec3(0.98, 0.99, 1.0);
uniform float cloud_strength = 0.55;
uniform float cloud_scale = 0.00016;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * cloud_scale;
	uv += vec2(TIME * 0.0028, TIME * 0.0012);
	float n = noise(uv * 2.8) * 0.62 + noise(uv * 6.5 + 17.0) * 0.38;
	n = smoothstep(0.48, 0.74, n);
	ALBEDO = cloud_tint;
	ALPHA = n * cloud_strength * 0.11;
}
