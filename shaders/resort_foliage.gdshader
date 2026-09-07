shader_type spatial;
render_mode cull_back;
uniform vec3 season_color : source_color = vec3(1.0);
uniform float season_mix = 0.0;
varying float leaf_light;
varying vec3 local_pos;
void vertex() {
 local_pos=VERTEX;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 // UV.x = per-cluster phase, UV.y = branch/leaf wind weight (package 07).
 float phase=UV.x*6.2831853;
 float weight=clamp(UV.y,0.0,1.0);
 if(weight<0.001){
  weight=clamp((VERTEX.y-1.2)*0.35,0.0,1.0);
 }
 float sway=sin(TIME*0.85+world.x*0.15+world.z*0.12+phase);
 float lift=sin(TIME*0.55+world.z*0.09+phase*0.5);
 VERTEX.x+=sway*0.055*weight*max(0.0,VERTEX.y-1.2);
 VERTEX.z+=lift*0.028*weight*max(0.0,VERTEX.y-1.2);
 VERTEX.y+=abs(sway)*0.012*weight;
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
