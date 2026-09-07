shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled,unshaded;

uniform vec4 mark_color : source_color = vec4(0.22, 0.30, 0.12, 0.55);
uniform float mark_fade = 1.0;

void fragment() {
	float edge = smoothstep(0.0, 0.45, length(UV - vec2(0.5)));
	ALBEDO = mark_color.rgb;
	ALPHA = mark_color.a * mark_fade * (1.0 - edge);
}
