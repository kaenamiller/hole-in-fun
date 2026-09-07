class_name GraphicsShadow
extends RefCounted

## Directional shadow, canopy proxy and SSAO presets for package 10.
## Revalidate canopy meshes after package 07 tree upgrades.

const RendererComparisonClass = preload("res://scripts/renderer_comparison.gd")

const SPLIT_MODES: Dictionary = {
	2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
}


static func ssao_supported() -> bool:
	var method: String = RendererComparisonClass.runtime_method()
	var features: Dictionary = RendererComparisonClass.capabilities_for(method).get("renderer_features", {})
	return bool(features.get("ssao", false))


static func preset_rows() -> Array[Dictionary]:
	return [
		{
			"tier": "low",
			"shadow_distance": 600.0,
			"shadow_resolution": 2048,
			"shadow_splits": 2,
			"shadow_split_1": 0.18,
			"shadow_split_2": 0.42,
			"shadow_split_3": 0.70,
			"shadow_bias": 0.18,
			"shadow_normal_bias": 1.85,
			"shadow_blur": 1.25,
			"tree_shadow_volumes": false,
			"ssao_enabled": false,
			"terrain_cast_shadows": false,
		},
		{
			"tier": "standard",
			"shadow_distance": 1100.0,
			"shadow_resolution": 4096,
			"shadow_splits": 2,
			"shadow_split_1": 0.14,
			"shadow_split_2": 0.38,
			"shadow_split_3": 0.62,
			"shadow_bias": 0.12,
			"shadow_normal_bias": 1.25,
			"shadow_blur": 1.6,
			"tree_shadow_volumes": true,
			"ssao_enabled": true,
			"terrain_cast_shadows": false,
		},
		{
			"tier": "high",
			"shadow_distance": 1400.0,
			"shadow_resolution": 4096,
			"shadow_splits": 4,
			"shadow_split_1": 0.10,
			"shadow_split_2": 0.24,
			"shadow_split_3": 0.48,
			"shadow_bias": 0.10,
			"shadow_normal_bias": 1.05,
			"shadow_blur": 1.85,
			"tree_shadow_volumes": true,
			"ssao_enabled": true,
			"terrain_cast_shadows": false,
		},
	]


static func apply_preset_fields(settings: GraphicsSettings, tier: String) -> void:
	for row in preset_rows():
		if row.tier == tier:
			_apply_row(settings, row)
			return


static func _apply_row(settings: GraphicsSettings, row: Dictionary) -> void:
	settings.shadow_distance = float(row.shadow_distance)
	settings.shadow_resolution = int(row.shadow_resolution)
	settings.shadow_splits = int(row.shadow_splits)
	settings.shadow_split_1 = float(row.shadow_split_1)
	settings.shadow_split_2 = float(row.shadow_split_2)
	settings.shadow_split_3 = float(row.shadow_split_3)
	settings.shadow_bias = float(row.shadow_bias)
	settings.shadow_normal_bias = float(row.shadow_normal_bias)
	settings.shadow_blur = float(row.shadow_blur)
	settings.tree_shadow_volumes = bool(row.tree_shadow_volumes)
	settings.ssao_enabled = bool(row.ssao_enabled)
	settings.terrain_cast_shadows = bool(row.terrain_cast_shadows)


static func apply_directional_light(light: DirectionalLight3D, settings: GraphicsSettings) -> void:
	if light == null:
		return
	light.shadow_enabled = true
	light.directional_shadow_blend_splits = true
	light.directional_shadow_max_distance = settings.shadow_distance
	light.shadow_bias = settings.shadow_bias
	light.shadow_normal_bias = settings.shadow_normal_bias
	light.shadow_blur = settings.shadow_blur
	var splits: int = clampi(settings.shadow_splits, 2, 4)
	light.directional_shadow_mode = SPLIT_MODES.get(splits, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	light.directional_shadow_split_1 = clampf(settings.shadow_split_1, 0.05, 0.45)
	light.directional_shadow_split_2 = clampf(settings.shadow_split_2, 0.15, 0.75)
	light.directional_shadow_split_3 = clampf(settings.shadow_split_3, 0.35, 0.90)
	RenderingServer.directional_shadow_atlas_set_size(settings.shadow_resolution, true)


static func apply_environment_ssao(environment: Environment, settings: GraphicsSettings) -> void:
	if environment == null:
		return
	var want_ssao: bool = settings.ssao_enabled and ssao_supported()
	environment.ssao_enabled = want_ssao
	if not want_ssao:
		return
	environment.ssao_radius = settings.ssao_radius
	environment.ssao_intensity = settings.ssao_intensity
	environment.ssao_power = settings.ssao_power
	environment.ssao_detail = settings.ssao_detail
	environment.ssao_horizon = settings.ssao_horizon
	environment.ssao_sharpness = settings.ssao_sharpness
	environment.ssao_light_affect = settings.ssao_light_affect
	environment.ssao_ao_channel_affect = settings.ssao_ao_channel_affect


static func terrain_cast_shadow_mode(enabled: bool) -> GeometryInstance3D.ShadowCastingSetting:
	if enabled:
		return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
