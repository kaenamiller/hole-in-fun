shader_type spatial;
uniform vec3 season_tint=vec3(1.0);
void fragment(){ALBEDO=pow(COLOR.rgb*season_tint,vec3(1.65))*0.9; ROUGHNESS=0.95;}
