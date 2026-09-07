shader_type spatial;
render_mode cull_disabled;
uniform vec3 foliage_color = vec3(0.22, 0.34, 0.24);
uniform vec3 haze_color = vec3(0.86, 0.90, 0.94);
uniform float haze_strength = 0.68;
uniform vec3 season_color = vec3(0.35, 0.55, 0.32);
uniform float season_mix = 0.0;

void fragment() {
	vec3 col = mix(foliage_color, season_color, season_mix * 0.55);
	col = mix(col, haze_color, clamp(haze_strength, 0.0, 1.0) * 0.78);
	ALBEDO = pow(col, vec3(1.28)) * 0.86;
	ROUGHNESS = 0.98;
}
