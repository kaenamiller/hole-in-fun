shader_type spatial;
render_mode cull_back;
uniform sampler2D detail_map : filter_linear, repeat_disable;
uniform vec3 water_tint : source_color = vec3(0.32,0.60,0.64);
uniform bool show_grid = false;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 uv=world_pos.xz/1024.0;
 if(show_grid) { uv=(floor(world_pos.xz/4.0)+0.5)/256.0; }
 float lake=texture(detail_map,uv).g;
 if(!show_grid) {
  vec2 step_uv=vec2(0.7/256.0);
  lake=lake*0.5+(texture(detail_map,uv+vec2(step_uv.x,0)).g+texture(detail_map,uv-vec2(step_uv.x,0)).g+texture(detail_map,uv+vec2(0,step_uv.y)).g+texture(detail_map,uv-vec2(0,step_uv.y)).g)*0.125;
 }
 if(lake<=0.5) { discard; }
 vec2 p=world_pos.xz;
 float a=sin(p.x*0.18+p.y*0.11+TIME*0.7);
 float b=sin(p.x*0.28-p.y*0.17-TIME*0.54);
 float c=sin(p.x*0.9+p.y*0.12+TIME*0.9);
 float wave=a*0.48+b*0.32+c*0.2;
 float shore=1.0-smoothstep(0.51,0.93,lake);
 vec3 deep=water_tint*vec3(0.52,0.73,0.77);
 vec3 col=mix(deep,water_tint*1.13,shore*0.35+wave*0.025+0.15);
 float glint=pow(max(0.0,a*0.5+b*0.3+c*0.2),16.0)*0.035;
 col+=vec3(0.74,0.87,0.84)*glint;
 float foam=(1.0-smoothstep(0.50,0.56,lake))*0.08;
 ALBEDO=pow(mix(col,vec3(0.52,0.63,0.49),foam),vec3(1.5));
 NORMAL=normalize(NORMAL+vec3(a*0.003,c*0.002,b*0.003));
 ROUGHNESS=0.32;
 METALLIC=0.02;
 SPECULAR=0.25;
}
