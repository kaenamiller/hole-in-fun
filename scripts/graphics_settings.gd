class_name GraphicsSettings
extends Resource

## Visual quality knobs. Defaults match the pre-package Compatibility preset.

enum Preset { LOW, STANDARD, HIGH }

const PRESET_NAMES: Array[String] = ["low", "standard", "high"]

@export var preset: int = Preset.STANDARD
@export var foliage_view_distance: float = 900.0
@export var foliage_density: float = 1.0
@export var foliage_lod_bias: float = 2.0
@export var shadow_distance: float = 1100.0
@export var shadow_resolution: int = 4096
@export var shadow_splits: int = 2
@export var shadow_split_1: float = 0.14
@export var shadow_split_2: float = 0.38
@export var shadow_split_3: float = 0.62
@export var shadow_bias: float = 0.12
@export var shadow_normal_bias: float = 1.25
@export var shadow_blur: float = 1.6
@export var ssao_enabled: bool = true
@export var ssao_radius: float = 1.35
@export var ssao_intensity: float = 0.55
@export var ssao_power: float = 1.45
@export var ssao_detail: float = 0.35
@export var ssao_horizon: float = 0.06
@export var ssao_sharpness: float = 0.92
@export var ssao_light_affect: float = 0.35
@export var ssao_ao_channel_affect: float = 0.65
@export var terrain_cast_shadows: bool = false
@export var msaa_3d: int = 2
@export var reflection_mode: String = "sky"
@export var reflection_resolution: int = 256
@export var weather_particle_cap: int = 600
@export var effect_instance_cap: int = 64
@export var tree_shadow_volumes: bool = true
@export var water_wave_detail: float = 1.0
@export var water_ripple_cap: int = 8
@export var water_reflection_strength: float = 0.28
@export var atmosphere_haze: float = 1.0
@export var atmosphere_clouds: bool = true
@export var atmosphere_cloud_strength: float = 0.55
@export var animation_distance_mid: float = 70.0
@export var animation_distance_far: float = 180.0
@export var animation_update_stride: int = 2


static func preset_name(value: int) -> String:
	return PRESET_NAMES[clampi(value, 0, PRESET_NAMES.size() - 1)]


static func preset_from_name(name_value: String) -> int:
	var lowered: String = name_value.strip_edges().to_lower()
	for index in range(PRESET_NAMES.size()):
		if PRESET_NAMES[index] == lowered:
			return index
	return Preset.STANDARD


static func defaults() -> GraphicsSettings:
	return GraphicsSettings.new()


static func for_preset(name_value: String) -> GraphicsSettings:
	var settings: GraphicsSettings = defaults()
	settings.apply_preset(preset_from_name(name_value))
	return settings


func apply_preset(value: int) -> void:
	preset = clampi(value, 0, Preset.HIGH)
	match preset:
		Preset.LOW:
			foliage_view_distance = 450.0
			foliage_density = 0.55
			foliage_lod_bias = 3.5
			msaa_3d = 0
			reflection_mode = "sky"
			reflection_resolution = 128
			weather_particle_cap = 200
			effect_instance_cap = 24
			water_wave_detail = 0.35
			water_ripple_cap = 4
			water_reflection_strength = 0.0
			animation_distance_mid = 50.0
			animation_distance_far = 120.0
			animation_update_stride = 3
			GraphicsShadow.apply_preset_fields(self, "low")
			GraphicsAtmosphere.apply_preset_fields(self, "low")
		Preset.HIGH:
			foliage_view_distance = 1100.0
			foliage_density = 1.0
			foliage_lod_bias = 1.6
			msaa_3d = 2
			reflection_mode = (
				"planar"
				if RendererComparison.planar_reflections_supported()
				else ("probe" if RendererComparison.reflection_probes_supported() else "sky")
			)
			reflection_resolution = 512
			weather_particle_cap = 600
			effect_instance_cap = 96
			water_wave_detail = 1.0
			water_ripple_cap = 16
			water_reflection_strength = 0.34
			animation_distance_mid = 90.0
			animation_distance_far = 240.0
			animation_update_stride = 1
			GraphicsShadow.apply_preset_fields(self, "high")
			GraphicsAtmosphere.apply_preset_fields(self, "high")
		_:
			foliage_view_distance = 900.0
			foliage_density = 1.0
			foliage_lod_bias = 2.0
			msaa_3d = 2
			reflection_mode = "probe" if RendererComparison.reflection_probes_supported() else "sky"
			reflection_resolution = 256
			weather_particle_cap = 600
			effect_instance_cap = 64
			water_wave_detail = 0.72
			water_ripple_cap = 8
			water_reflection_strength = 0.28
			animation_distance_mid = 70.0
			animation_distance_far = 180.0
			animation_update_stride = 2
			GraphicsShadow.apply_preset_fields(self, "standard")
			GraphicsAtmosphere.apply_preset_fields(self, "standard")


func duplicate_settings() -> GraphicsSettings:
	var copy: GraphicsSettings = GraphicsSettings.new()
	copy.preset = preset
	copy.foliage_view_distance = foliage_view_distance
	copy.foliage_density = foliage_density
	copy.foliage_lod_bias = foliage_lod_bias
	copy.shadow_distance = shadow_distance
	copy.shadow_resolution = shadow_resolution
	copy.shadow_splits = shadow_splits
	copy.shadow_split_1 = shadow_split_1
	copy.shadow_split_2 = shadow_split_2
	copy.shadow_split_3 = shadow_split_3
	copy.shadow_bias = shadow_bias
	copy.shadow_normal_bias = shadow_normal_bias
	copy.shadow_blur = shadow_blur
	copy.ssao_enabled = ssao_enabled
	copy.ssao_radius = ssao_radius
	copy.ssao_intensity = ssao_intensity
	copy.ssao_power = ssao_power
	copy.ssao_detail = ssao_detail
	copy.ssao_horizon = ssao_horizon
	copy.ssao_sharpness = ssao_sharpness
	copy.ssao_light_affect = ssao_light_affect
	copy.ssao_ao_channel_affect = ssao_ao_channel_affect
	copy.terrain_cast_shadows = terrain_cast_shadows
	copy.msaa_3d = msaa_3d
	copy.reflection_mode = reflection_mode
	copy.reflection_resolution = reflection_resolution
	copy.weather_particle_cap = weather_particle_cap
	copy.effect_instance_cap = effect_instance_cap
	copy.tree_shadow_volumes = tree_shadow_volumes
	copy.water_wave_detail = water_wave_detail
	copy.water_ripple_cap = water_ripple_cap
	copy.water_reflection_strength = water_reflection_strength
	copy.atmosphere_haze = atmosphere_haze
	copy.atmosphere_clouds = atmosphere_clouds
	copy.atmosphere_cloud_strength = atmosphere_cloud_strength
	copy.animation_distance_mid = animation_distance_mid
	copy.animation_distance_far = animation_distance_far
	copy.animation_update_stride = animation_update_stride
	return copy


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"preset": preset_name(preset),
		"foliage_view_distance": foliage_view_distance,
		"foliage_density": foliage_density,
		"foliage_lod_bias": foliage_lod_bias,
		"shadow_distance": shadow_distance,
		"shadow_resolution": shadow_resolution,
		"shadow_splits": shadow_splits,
		"shadow_split_1": shadow_split_1,
		"shadow_split_2": shadow_split_2,
		"shadow_split_3": shadow_split_3,
		"shadow_bias": shadow_bias,
		"shadow_normal_bias": shadow_normal_bias,
		"shadow_blur": shadow_blur,
		"ssao_enabled": ssao_enabled,
		"ssao_radius": ssao_radius,
		"ssao_intensity": ssao_intensity,
		"ssao_power": ssao_power,
		"ssao_detail": ssao_detail,
		"ssao_horizon": ssao_horizon,
		"ssao_sharpness": ssao_sharpness,
		"ssao_light_affect": ssao_light_affect,
		"ssao_ao_channel_affect": ssao_ao_channel_affect,
		"terrain_cast_shadows": terrain_cast_shadows,
		"msaa_3d": msaa_3d,
		"reflection_mode": reflection_mode,
		"reflection_resolution": reflection_resolution,
		"weather_particle_cap": weather_particle_cap,
		"effect_instance_cap": effect_instance_cap,
		"tree_shadow_volumes": tree_shadow_volumes,
		"water_wave_detail": water_wave_detail,
		"water_ripple_cap": water_ripple_cap,
		"water_reflection_strength": water_reflection_strength,
		"atmosphere_haze": atmosphere_haze,
		"atmosphere_clouds": atmosphere_clouds,
		"atmosphere_cloud_strength": atmosphere_cloud_strength,
		"animation_distance_mid": animation_distance_mid,
		"animation_distance_far": animation_distance_far,
		"animation_update_stride": animation_update_stride,
	}


func load_dict(data: Dictionary) -> void:
	if data.has("preset"):
		apply_preset(preset_from_name(str(data.get("preset", "standard"))))
	if data.has("foliage_view_distance"):
		foliage_view_distance = maxf(120.0, float(data.foliage_view_distance))
	if data.has("foliage_density"):
		foliage_density = clampf(float(data.foliage_density), 0.2, 1.0)
	if data.has("foliage_lod_bias"):
		foliage_lod_bias = clampf(float(data.foliage_lod_bias), 0.5, 8.0)
	if data.has("shadow_distance"):
		shadow_distance = clampf(float(data.shadow_distance), 200.0, 2400.0)
	if data.has("shadow_resolution"):
		shadow_resolution = _clamp_shadow_resolution(int(data.shadow_resolution))
	if data.has("shadow_splits"):
		shadow_splits = clampi(int(data.shadow_splits), 2, 4)
	if data.has("shadow_split_1"):
		shadow_split_1 = clampf(float(data.shadow_split_1), 0.05, 0.45)
	if data.has("shadow_split_2"):
		shadow_split_2 = clampf(float(data.shadow_split_2), 0.15, 0.75)
	if data.has("shadow_split_3"):
		shadow_split_3 = clampf(float(data.shadow_split_3), 0.35, 0.90)
	if data.has("shadow_bias"):
		shadow_bias = clampf(float(data.shadow_bias), 0.02, 0.35)
	if data.has("shadow_normal_bias"):
		shadow_normal_bias = clampf(float(data.shadow_normal_bias), 0.5, 3.0)
	if data.has("shadow_blur"):
		shadow_blur = clampf(float(data.shadow_blur), 0.5, 3.0)
	if data.has("ssao_enabled"):
		ssao_enabled = bool(data.ssao_enabled)
	if data.has("ssao_radius"):
		ssao_radius = clampf(float(data.ssao_radius), 0.2, 4.0)
	if data.has("ssao_intensity"):
		ssao_intensity = clampf(float(data.ssao_intensity), 0.0, 2.0)
	if data.has("ssao_power"):
		ssao_power = clampf(float(data.ssao_power), 0.5, 4.0)
	if data.has("ssao_detail"):
		ssao_detail = clampf(float(data.ssao_detail), 0.0, 1.0)
	if data.has("ssao_horizon"):
		ssao_horizon = clampf(float(data.ssao_horizon), 0.0, 1.0)
	if data.has("ssao_sharpness"):
		ssao_sharpness = clampf(float(data.ssao_sharpness), 0.0, 1.0)
	if data.has("ssao_light_affect"):
		ssao_light_affect = clampf(float(data.ssao_light_affect), 0.0, 1.0)
	if data.has("ssao_ao_channel_affect"):
		ssao_ao_channel_affect = clampf(float(data.ssao_ao_channel_affect), 0.0, 1.0)
	if data.has("terrain_cast_shadows"):
		terrain_cast_shadows = bool(data.terrain_cast_shadows)
	if data.has("msaa_3d"):
		msaa_3d = clampi(int(data.msaa_3d), 0, 3)
	if data.has("reflection_mode"):
		var mode: String = str(data.reflection_mode).to_lower()
		reflection_mode = mode if mode in ["sky", "probe", "planar"] else "sky"
	if data.has("reflection_resolution"):
		reflection_resolution = clampi(int(data.reflection_resolution), 64, 1024)
	if data.has("weather_particle_cap"):
		weather_particle_cap = clampi(int(data.weather_particle_cap), 0, 1200)
	if data.has("effect_instance_cap"):
		effect_instance_cap = clampi(int(data.effect_instance_cap), 0, 256)
	if data.has("tree_shadow_volumes"):
		tree_shadow_volumes = bool(data.tree_shadow_volumes)
	if data.has("water_wave_detail"):
		water_wave_detail = clampf(float(data.water_wave_detail), 0.0, 1.0)
	if data.has("water_ripple_cap"):
		water_ripple_cap = clampi(int(data.water_ripple_cap), 0, WaterRipplePool.MAX_SLOTS)
	if data.has("water_reflection_strength"):
		water_reflection_strength = clampf(float(data.water_reflection_strength), 0.0, 1.0)
	if data.has("atmosphere_haze"):
		atmosphere_haze = clampf(float(data.atmosphere_haze), 0.0, 1.5)
	if data.has("atmosphere_clouds"):
		atmosphere_clouds = bool(data.atmosphere_clouds)
	if data.has("atmosphere_cloud_strength"):
		atmosphere_cloud_strength = clampf(float(data.atmosphere_cloud_strength), 0.0, 1.0)
	if data.has("animation_distance_mid"):
		animation_distance_mid = clampf(float(data.animation_distance_mid), 20.0, 200.0)
	if data.has("animation_distance_far"):
		animation_distance_far = clampf(float(data.animation_distance_far), 40.0, 400.0)
	if data.has("animation_update_stride"):
		animation_update_stride = clampi(int(data.animation_update_stride), 1, 4)
	sanitize()


func sanitize() -> void:
	foliage_view_distance = clampf(foliage_view_distance, 120.0, 2400.0)
	foliage_density = clampf(foliage_density, 0.2, 1.0)
	foliage_lod_bias = clampf(foliage_lod_bias, 0.5, 8.0)
	shadow_distance = clampf(shadow_distance, 200.0, 2400.0)
	shadow_resolution = _clamp_shadow_resolution(shadow_resolution)
	shadow_splits = clampi(shadow_splits, 2, 4)
	shadow_split_1 = clampf(shadow_split_1, 0.05, 0.45)
	shadow_split_2 = clampf(shadow_split_2, 0.15, 0.75)
	shadow_split_3 = clampf(shadow_split_3, 0.35, 0.90)
	shadow_bias = clampf(shadow_bias, 0.02, 0.35)
	shadow_normal_bias = clampf(shadow_normal_bias, 0.5, 3.0)
	shadow_blur = clampf(shadow_blur, 0.5, 3.0)
	ssao_radius = clampf(ssao_radius, 0.2, 4.0)
	ssao_intensity = clampf(ssao_intensity, 0.0, 2.0)
	ssao_power = clampf(ssao_power, 0.5, 4.0)
	ssao_detail = clampf(ssao_detail, 0.0, 1.0)
	ssao_horizon = clampf(ssao_horizon, 0.0, 1.0)
	ssao_sharpness = clampf(ssao_sharpness, 0.0, 1.0)
	ssao_light_affect = clampf(ssao_light_affect, 0.0, 1.0)
	ssao_ao_channel_affect = clampf(ssao_ao_channel_affect, 0.0, 1.0)
	msaa_3d = clampi(msaa_3d, 0, 3)
	if reflection_mode not in ["sky", "probe", "planar"]:
		reflection_mode = "sky"
	if reflection_mode == "planar" and not RendererComparison.planar_reflections_supported():
		reflection_mode = "probe" if RendererComparison.reflection_probes_supported() else "sky"
	if reflection_mode == "probe" and not RendererComparison.reflection_probes_supported():
		reflection_mode = "sky"
	reflection_resolution = clampi(reflection_resolution, 64, 1024)
	weather_particle_cap = clampi(weather_particle_cap, 0, 1200)
	effect_instance_cap = clampi(effect_instance_cap, 0, 256)
	water_wave_detail = clampf(water_wave_detail, 0.0, 1.0)
	water_ripple_cap = clampi(water_ripple_cap, 0, WaterRipplePool.MAX_SLOTS)
	water_reflection_strength = clampf(water_reflection_strength, 0.0, 1.0)
	atmosphere_haze = clampf(atmosphere_haze, 0.0, 1.5)
	atmosphere_cloud_strength = clampf(atmosphere_cloud_strength, 0.0, 1.0)
	animation_distance_mid = clampf(animation_distance_mid, 20.0, 200.0)
	animation_distance_far = clampf(animation_distance_far, maxf(animation_distance_mid + 10.0, 40.0), 400.0)
	animation_update_stride = clampi(animation_update_stride, 1, 4)


static func _clamp_shadow_resolution(value: int) -> int:
	var allowed: Array[int] = [512, 1024, 2048, 4096, 8192]
	var best: int = 4096
	var best_delta: int = 999999
	for candidate in allowed:
		var delta: int = absi(candidate - value)
		if delta < best_delta:
			best_delta = delta
			best = candidate
	return best
