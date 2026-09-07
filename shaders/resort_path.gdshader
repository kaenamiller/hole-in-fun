shader_type spatial;
render_mode cull_back;
uniform vec3 path_color : source_color = vec3(0.7,0.62,0.44);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=fract(sin(dot(floor(world_pos.xz*8.0),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO=pow(path_color,vec3(1.65))*(0.84+grain*0.02);
 ROUGHNESS=0.96;
}
