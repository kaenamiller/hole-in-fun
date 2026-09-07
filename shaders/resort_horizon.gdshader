shader_type spatial;
uniform vec3 season_tint = vec3(1.0);
uniform vec3 haze_color = vec3(0.86, 0.90, 0.94);
uniform float haze_strength = 0.58;
uniform float sky_blend = 0.52;
uniform float detail_fade = 0.62;
uniform vec3 hill_cool = vec3(0.94, 0.97, 1.06);

void fragment() {
	float dist = clamp(COLOR.a, 0.0, 1.0);
	vec3 base_col = COLOR.rgb * season_tint * mix(vec3(1.0), hill_cool, dist * detail_fade);
	base_col = mix(base_col, haze_color, dist * haze_strength * 0.82);
	float gamma = mix(1.65, 1.22, dist * detail_fade);
	vec3 albedo = pow(base_col, vec3(gamma)) * mix(0.9, 0.97, dist);
	albedo = mix(albedo, haze_color, dist * sky_blend * 0.38);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.95, 0.99, dist);
}
