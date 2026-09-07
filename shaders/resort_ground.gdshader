shader_type spatial;
render_mode cull_back;
uniform sampler2D turf_map : filter_linear, repeat_disable;
uniform sampler2D detail_map : filter_linear, repeat_disable;
uniform vec3 rough_color : source_color = vec3(0.35,0.46,0.20);
uniform vec3 fairway_color : source_color = vec3(0.48,0.64,0.25);
uniform vec3 green_color : source_color = vec3(0.63,0.75,0.32);
uniform vec3 tee_color : source_color = vec3(0.52,0.66,0.29);
uniform vec3 sand_color : source_color = vec3(0.86,0.76,0.53);
uniform vec3 soil_color : source_color = vec3(0.42,0.30,0.18);
uniform vec3 season_tint = vec3(1.0);
uniform bool show_grid = false;
uniform bool analysis = false;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 uv=world_pos.xz/1024.0;
 if(show_grid) { uv=(floor(world_pos.xz/4.0)+0.5)/256.0; }
 vec4 t=texture(turf_map,uv);
 vec4 d=texture(detail_map,uv);
 if(!show_grid) {
  vec2 step_uv=vec2(0.7/256.0);
  t=t*0.5+(texture(turf_map,uv+vec2(step_uv.x,0))+texture(turf_map,uv-vec2(step_uv.x,0))+texture(turf_map,uv+vec2(0,step_uv.y))+texture(turf_map,uv-vec2(0,step_uv.y)))*0.125;
  // Water uses the shared exact mask; soften only turf and sand contours.

  d=d*0.5+(texture(detail_map,uv+vec2(step_uv.x,0))+texture(detail_map,uv-vec2(step_uv.x,0))+texture(detail_map,uv+vec2(0,step_uv.y))+texture(detail_map,uv-vec2(0,step_uv.y)))*0.125;

 }
 if(d.g>0.5) { discard; }
 vec4 weights=smoothstep(vec4(0.27),vec4(0.73),t);
 vec3 col=rough_color;
 col=mix(col,fairway_color,weights.g);
 col=mix(col,green_color,weights.b);
 col=mix(col,tee_color,weights.a);
 // A slightly darker collar gives greens a deliberate, manicured edge.
 float collar=smoothstep(0.05,0.22,t.b)*(1.0-smoothstep(0.28,0.5,t.b));
 col=mix(col,rough_color*0.88,collar*0.48);
 float stripe=smoothstep(-0.13,0.13,sin((world_pos.x*0.78+world_pos.z*0.63)*0.56));
 col*=1.0+(stripe-0.5)*(weights.g*0.065+weights.b*0.07+weights.a*0.09);
 float grain=noise(world_pos.xz*3.8)-0.5;
 float broad=noise(world_pos.xz*0.038)-0.5;
 col*=1.0+broad*0.12+grain*0.025;
 float sand=smoothstep(0.28,0.7,d.r);
 col=mix(col,sand_color*(0.94+noise(world_pos.xz*4.0)*0.09),sand);
 float lip=smoothstep(0.07,0.26,d.r)*(1.0-smoothstep(0.26,0.52,d.r));
 col*=1.0-lip*0.23;
 col=mix(col,soil_color,smoothstep(0.3,0.7,d.b));
 float bank=smoothstep(0.03,0.48,d.g);
 col=mix(col,sand_color*0.68,bank*0.7);
 col*=season_tint;
 if(analysis) { col=COLOR.rgb; }
 if(show_grid) {
  vec2 coord=world_pos.xz/4.0;
  vec2 grid=abs(fract(coord-0.5)-0.5)/max(fwidth(coord),vec2(0.015));
  float line=1.0-min(min(grid.x,grid.y),1.0);
  col=mix(col,vec3(0.12,0.22,0.14),line*0.38);
 }
 ALBEDO=pow(max(col,vec3(0.0)),vec3(1.65))*0.9;
 ROUGHNESS=mix(0.94,0.83,sand);
}
