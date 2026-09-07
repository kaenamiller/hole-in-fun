shader_type spatial;
render_mode cull_back;
uniform sampler2D turf_map : filter_linear, repeat_disable;
uniform sampler2D detail_map : filter_linear, repeat_disable;
uniform sampler2D pattern_map : filter_linear, repeat_disable;
uniform vec3 rough_color : source_color = vec3(0.35,0.46,0.20);
uniform vec3 fairway_color : source_color = vec3(0.48,0.64,0.25);
uniform vec3 green_color : source_color = vec3(0.63,0.75,0.32);
uniform vec3 tee_color : source_color = vec3(0.52,0.66,0.29);
uniform vec3 sand_color : source_color = vec3(0.86,0.76,0.53);
uniform vec3 soil_color : source_color = vec3(0.42,0.30,0.18);
uniform vec3 season_tint = vec3(1.0);
uniform sampler2D fairway_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_detail : filter_linear_mipmap, repeat_enable;
uniform float fairway_repeat = 2.0;
uniform float rough_repeat = 1.5;
uniform float sand_repeat = 0.8;
uniform bool use_material_details = false;
uniform vec2 default_stripe_dir = vec2(0.78,0.63);
uniform float stripe_overview_fade = 1.0;
uniform sampler2D contour_map : filter_linear, repeat_disable;
uniform sampler2D water_field : filter_linear, repeat_disable;
uniform bool use_contour_map = false;
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
 vec4 pat=texture(pattern_map,uv);
 vec4 contour=texture(contour_map,uv);
 vec4 water=texture(water_field,uv);
 if(!show_grid) {
  vec2 step_uv=vec2(0.7/256.0);
  t=t*0.5+(texture(turf_map,uv+vec2(step_uv.x,0))+texture(turf_map,uv-vec2(step_uv.x,0))+texture(turf_map,uv+vec2(0,step_uv.y))+texture(turf_map,uv-vec2(0,step_uv.y)))*0.125;
  // Water uses the shared exact mask; soften only turf and sand contours.

  d=d*0.5+(texture(detail_map,uv+vec2(step_uv.x,0))+texture(detail_map,uv-vec2(step_uv.x,0))+texture(detail_map,uv+vec2(0,step_uv.y))+texture(detail_map,uv-vec2(0,step_uv.y)))*0.125;

  pat=pat*0.5+(texture(pattern_map,uv+vec2(step_uv.x,0))+texture(pattern_map,uv-vec2(step_uv.x,0))+texture(pattern_map,uv+vec2(0,step_uv.y))+texture(pattern_map,uv-vec2(0,step_uv.y)))*0.125;
  contour=contour*0.5+(texture(contour_map,uv+vec2(step_uv.x,0))+texture(contour_map,uv-vec2(step_uv.x,0))+texture(contour_map,uv+vec2(0,step_uv.y))+texture(contour_map,uv-vec2(0,step_uv.y)))*0.125;
  water=water*0.5+(texture(water_field,uv+vec2(step_uv.x,0))+texture(water_field,uv-vec2(step_uv.x,0))+texture(water_field,uv+vec2(0,step_uv.y))+texture(water_field,uv-vec2(0,step_uv.y)))*0.125;

 }
 if(d.g>0.5) { discard; }
 vec4 weights=smoothstep(vec4(0.27),vec4(0.73),t);
 if(use_contour_map) {
  weights.g=max(weights.g,contour.r);
  weights.b=max(weights.b,contour.r);
  weights=clamp(weights,vec4(0.0),vec4(1.0));
 }
 vec3 col=rough_color;
 col=mix(col,fairway_color,weights.g);
 col=mix(col,green_color,weights.b);
 col=mix(col,tee_color,weights.a);
 // A slightly darker collar gives greens a deliberate, manicured edge.
 float collar=smoothstep(0.05,0.22,t.b)*(1.0-smoothstep(0.28,0.5,t.b));
 if(use_contour_map) { collar=max(collar,contour.b*0.85); }
 col=mix(col,rough_color*0.88,collar*0.48);
 vec2 stripe_dir=pat.rg*2.0-1.0;
 if(length(stripe_dir)<0.02) { stripe_dir=normalize(default_stripe_dir); }
 else { stripe_dir=normalize(stripe_dir); }
 float stripe_freq=mix(0.56,pat.b*1.5,step(0.001,pat.b));
 float stripe_coord=dot(world_pos.xz,stripe_dir)*stripe_freq;
 float stripe_aa=max(fwidth(stripe_coord),0.001);
 float stripe=smoothstep(-0.13-stripe_aa,0.13+stripe_aa,sin(stripe_coord));
 float stripe_mix=pat.a*stripe_overview_fade*(weights.g*0.065+weights.b*0.07+weights.a*0.09);
 col*=1.0+(stripe-0.5)*stripe_mix;
 float sand=smoothstep(0.28,0.7,d.r);
 if(use_contour_map) { sand=max(sand,contour.g); }
 float grain=noise(world_pos.xz*3.8)-0.5;
 float broad=noise(world_pos.xz*0.038)-0.5;
 float detail_fade=smoothstep(420.0,140.0,length(world_pos.xz-vec2(512.0)));
 if(use_material_details) {
  vec2 f_uv=world_pos.xz/max(fairway_repeat,0.05);
  vec2 r_uv=world_pos.xz/max(rough_repeat,0.05);
  vec2 s_uv=world_pos.xz/max(sand_repeat,0.05);
  vec3 f_tex=texture(fairway_detail,f_uv).rgb;
  vec3 r_tex=texture(rough_detail,r_uv).rgb;
  vec3 s_tex=texture(sand_detail,s_uv).rgb;
  col=mix(col,col*f_tex,weights.g*detail_fade*0.42);
  col=mix(col,col*r_tex,(1.0-weights.g-weights.b-weights.a)*detail_fade*0.36);
  col=mix(col,col*s_tex,sand*detail_fade*0.48);
  grain*=1.0-detail_fade*0.65;
  broad*=1.0-detail_fade*0.55;
 }
 col*=1.0+broad*0.12+grain*0.025;
 col=mix(col,sand_color*(0.94+noise(world_pos.xz*4.0)*0.09),sand);
 float lip=smoothstep(0.07,0.26,d.r)*(1.0-smoothstep(0.26,0.52,d.r));
 if(use_contour_map) { lip=max(lip,contour.a*0.9); }
 col*=1.0-lip*0.23;
 col=mix(col,soil_color,smoothstep(0.3,0.7,d.b));
 float dry_shore=water.g*(1.0-water.a);
 float slope=1.0-clamp(NORMAL.y,0.0,1.0);
 float bank=max(smoothstep(0.03,0.48,d.g), (1.0-smoothstep(0.0,0.75,dry_shore))*(1.0-slope*0.72));
 col=mix(col,sand_color*0.68,bank*0.58);
 col=mix(col,soil_color*0.92,bank*0.18*(1.0-slope));
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
