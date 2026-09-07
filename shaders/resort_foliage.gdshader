shader_type spatial;
render_mode cull_back;
uniform vec3 season_color : source_color = vec3(1.0);
uniform float season_mix = 0.0;
varying float leaf_light;
varying vec3 local_pos;
void vertex() {
 local_pos=VERTEX;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(TIME*0.85+world.x*0.15+world.z*0.12);
 VERTEX.x+=sway*0.055*max(0.0,VERTEX.y-1.5);
 VERTEX.z+=cos(TIME*0.65+world.x*0.11)*0.025*max(0.0,VERTEX.y-1.5);
 leaf_light=COLOR.a;
}
void fragment() {
 vec3 col=mix(COLOR.rgb,season_color,season_mix);
 float stipple=fract(sin(dot(floor(local_pos*19.0),vec3(12.9898,78.233,47.131)))*43758.5453)-0.5;
 ALBEDO=pow(col,vec3(1.35))*(1.0+stipple*0.18);
 ROUGHNESS=0.95;
 // A little diffuse fill keeps the canopy's shaded side soft and readable.
 EMISSION=col*0.055*leaf_light;
}
