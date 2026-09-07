shader_type spatial;
render_mode cull_back;
uniform sampler2D detail_map : filter_linear, repeat_disable;
uniform sampler2D water_field : filter_linear, repeat_disable;
uniform vec3 water_tint : source_color = vec3(0.32,0.60,0.64);
uniform float depth_tint_strength = 0.42;
uniform float shallow_depth_m = 0.35;
uniform float deep_depth_m = 4.5;
uniform float wave_detail = 1.0;
uniform int ripple_count = 0;
uniform vec4 ripple_positions[16];
uniform vec4 ripple_meta[16];
uniform sampler2D reflection_map : filter_linear, repeat_disable;
uniform bool use_reflection = false;
uniform bool planar_reflection = false;
uniform float reflection_plane_y = 0.0;
uniform mat4 reflection_view_projection;
uniform float reflection_strength = 0.28;
uniform float reflection_fresnel = 2.4;
uniform bool show_grid = false;
varying vec3 world_pos;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
            mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 wave_normal(vec2 p, float detail) {
 float t = TIME;
 vec2 q = p * 0.11 + vec2(noise2(p * 0.03) * 2.4, noise2(p * 0.027 + 17.0) * 2.1);
 float a = sin(q.x * 1.0 + q.y * 0.62 + t * 0.62);
 float b = sin(q.x * 1.47 - q.y * 0.91 - t * 0.48 + 1.7);
 float c = sin((q.x * 2.35 + q.y * 1.18) * 0.55 + t * 0.83 + noise2(q * 0.19) * 1.6);
 float d = sin((q.x * 0.71 - q.y * 1.63) * 1.15 - t * 0.36 + noise2(q * 0.08 + 4.0) * 2.0);
 float wave = a * 0.42 + b * 0.28 + c * 0.18 * detail + d * 0.12 * detail;
 float dx = cos(q.x * 1.0 + q.y * 0.62 + t * 0.62) * 0.42
          + cos(q.x * 1.47 - q.y * 0.91 - t * 0.48 + 1.7) * 0.28 * 1.47
          + cos((q.x * 2.35 + q.y * 1.18) * 0.55 + t * 0.83 + noise2(q * 0.19) * 1.6) * 0.18 * detail * 1.29
          + cos((q.x * 0.71 - q.y * 1.63) * 1.15 - t * 0.36 + noise2(q * 0.08 + 4.0) * 2.0) * 0.12 * detail * 0.82;
 float dy = cos(q.x * 1.0 + q.y * 0.62 + t * 0.62) * 0.42 * 0.62
          - sin(q.x * 1.47 - q.y * 0.91 - t * 0.48 + 1.7) * 0.28 * 0.91
          + cos((q.x * 2.35 + q.y * 1.18) * 0.55 + t * 0.83 + noise2(q * 0.19) * 1.6) * 0.18 * detail * 0.65
          - sin((q.x * 0.71 - q.y * 1.63) * 1.15 - t * 0.36 + noise2(q * 0.08 + 4.0) * 2.0) * 0.12 * detail * 1.87;
 return normalize(vec3(-dx * 0.0045, 1.0, -dy * 0.0045));
}

float ripple_sum(vec2 p, float body_id_norm) {
 float sum = 0.0;
 for (int i = 0; i < 16; i++) {
  if (i >= ripple_count) { break; }
  vec4 slot = ripple_positions[i];
  vec4 meta = ripple_meta[i];
  if (abs(meta.y - body_id_norm) > 0.004) { continue; }
  float age = TIME - slot.z;
  if (age < 0.0) { continue; }
  float radius = max(meta.x, 0.5);
  float dist = length(p - slot.xy);
  float ring = 1.0 - smoothstep(radius * 0.15, radius, dist);
  float wave = sin((dist - age * 4.8) * 2.6 / max(radius * 0.22, 0.2)) * ring;
  sum += wave * slot.w * exp(-age * 0.85);
 }
 return sum;
}

void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
 vec2 uv = world_pos.xz / 1024.0;
 if (show_grid) { uv = (floor(world_pos.xz / 4.0) + 0.5) / 256.0; }
 vec4 field = texture(water_field, uv);
 float lake = field.a;
 if (!show_grid) {
  vec2 step_uv = vec2(0.7 / 256.0);
  lake = lake * 0.5 + (
   texture(water_field, uv + vec2(step_uv.x, 0.0)).a +
   texture(water_field, uv - vec2(step_uv.x, 0.0)).a +
   texture(water_field, uv + vec2(0.0, step_uv.y)).a +
   texture(water_field, uv - vec2(0.0, step_uv.y)).a
  ) * 0.125;
 }
 if (lake <= 0.5) { discard; }

 vec2 p = world_pos.xz;
 float depth_m = field.r * 12.0;
 float shore_m = field.g * 16.0;
 float body_id_norm = field.b;
 float depth_t = smoothstep(shallow_depth_m, deep_depth_m, depth_m);
 vec3 shallow = water_tint * vec3(1.08, 1.04, 0.98);
 vec3 deep = water_tint * vec3(0.52, 0.73, 0.77);
 vec3 col = mix(shallow, deep, depth_t * depth_tint_strength + 0.18);
 float bank_influence = (1.0 - smoothstep(0.0, 2.2, shore_m)) * 0.22;
 col = mix(col, water_tint * vec3(0.86, 0.78, 0.66), bank_influence);

 float detail = clamp(wave_detail, 0.0, 1.0);
 vec3 wn = wave_normal(p, detail);
 float ripple = ripple_sum(p, body_id_norm);
 wn = normalize(wn + vec3(ripple * 0.18, 0.0, ripple * 0.18));
 float glint = pow(max(0.0, dot(normalize(vec3(0.35, 1.0, 0.2)), wn)), 16.0) * 0.035 * (0.65 + detail * 0.35);
 col += vec3(0.74, 0.87, 0.84) * glint;
 float foam = (1.0 - smoothstep(0.0, 1.1, shore_m)) * 0.08;
 col = mix(col, vec3(0.52, 0.63, 0.49), foam);

 if (use_reflection) {
  vec2 ref_uv;
  if (planar_reflection) {
   vec4 clip = reflection_view_projection * vec4(world_pos.x, reflection_plane_y, world_pos.z, 1.0);
   ref_uv = clip.xy * 0.5 + 0.5;
   ref_uv.y = 1.0 - ref_uv.y;
  } else {
   ref_uv = world_pos.xz / 1024.0;
  }
  float edge = smoothstep(0.0, 0.03, ref_uv.x) * smoothstep(1.0, 0.97, ref_uv.x)
             * smoothstep(0.0, 0.03, ref_uv.y) * smoothstep(1.0, 0.97, ref_uv.y);
  vec3 reflection = texture(reflection_map, ref_uv).rgb;
  float fresnel = pow(1.0 - max(dot(normalize(NORMAL), wn), 0.0), reflection_fresnel);
  col = mix(col, reflection, reflection_strength * fresnel * edge);
 }

 ALBEDO = pow(max(col, vec3(0.0)), vec3(1.5));
 NORMAL = wn;
 ROUGHNESS = mix(0.38, 0.28, detail);
 METALLIC = 0.02;
 SPECULAR = mix(0.18, 0.28, detail);
}
