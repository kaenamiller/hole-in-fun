class_name GraphicsAtmosphere
extends RefCounted

## Distance haze, horizon grading and cosmetic cloud presets (package 14).
## Uses Compatibility basic fog; volumetric fog is intentionally out of scope.

const RendererComparisonClass = preload("res://scripts/renderer_comparison.gd")
const PaletteClass = preload("res://scripts/graphics_palette.gd")


static func fog_supported() -> bool:
	var method: String = RendererComparisonClass.runtime_method()
	var features: Dictionary = RendererComparisonClass.capabilities_for(method).get("renderer_features", {})
	return bool(features.get("basic_fog", false))


static func preset_rows() -> Array[Dictionary]:
	return [
		{
			"tier": "low",
			"atmosphere_haze": 0.45,
			"atmosphere_clouds": false,
			"atmosphere_cloud_strength": 0.0,
		},
		{
			"tier": "standard",
			"atmosphere_haze": 1.0,
			"atmosphere_clouds": true,
			"atmosphere_cloud_strength": 0.55,
		},
		{
			"tier": "high",
			"atmosphere_haze": 1.15,
			"atmosphere_clouds": true,
			"atmosphere_cloud_strength": 0.72,
		},
	]


static func apply_preset_fields(settings: GraphicsSettings, tier: String) -> void:
	for row in preset_rows():
		if row.tier == tier:
			settings.atmosphere_haze = float(row.atmosphere_haze)
			settings.atmosphere_clouds = bool(row.atmosphere_clouds)
			settings.atmosphere_cloud_strength = float(row.atmosphere_cloud_strength)
			return


static func fog_parameters(season: int, settings: GraphicsSettings) -> Dictionary:
	var palette: Dictionary = PaletteClass.atmosphere_for_season(season)
	var haze_scale: float = clampf(settings.atmosphere_haze, 0.0, 1.5)
	return {
		"enabled": fog_supported() and haze_scale > 0.01,
		"density": 0.00115 * haze_scale,
		"depth_begin": 820.0,
		"depth_end": 2150.0,
		"height": 6.0,
		"height_density": 0.11 * haze_scale,
		"aerial_perspective": 0.26 * haze_scale,
		"sky_affect": 0.46,
		"light_color": palette.fog_light,
	}


static func apply_environment_atmosphere(
	environment: Environment,
	settings: GraphicsSettings,
	season: int = 1,
) -> void:
	if environment == null:
		return
	var fog: Dictionary = fog_parameters(season, settings)
	if not bool(fog.enabled):
		environment.fog_enabled = false
		return
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = fog.light_color
	environment.fog_density = float(fog.density)
	environment.fog_depth_begin = float(fog.depth_begin)
	environment.fog_depth_end = float(fog.depth_end)
	environment.fog_height = float(fog.height)
	environment.fog_height_density = float(fog.height_density)
	environment.fog_aerial_perspective = float(fog.aerial_perspective)
	environment.fog_sky_affect = float(fog.sky_affect)


static func horizon_shader_params(season: int, settings: GraphicsSettings) -> Dictionary:
	var palette: Dictionary = PaletteClass.atmosphere_for_season(season)
	var haze_scale: float = clampf(settings.atmosphere_haze, 0.0, 1.5)
	return {
		"season_tint": PaletteClass.terrain_season_tint(season),
		"haze_color": palette.haze_tint,
		"haze_strength": 0.58 * haze_scale,
		"sky_blend": 0.52,
		"detail_fade": 0.62,
		"hill_cool": palette.hill_cool,
	}


static func distant_foliage_shader_params(season: int, settings: GraphicsSettings) -> Dictionary:
	var palette: Dictionary = PaletteClass.atmosphere_for_season(season)
	var haze_scale: float = clampf(settings.atmosphere_haze, 0.0, 1.5)
	return {
		"foliage_color": palette.distant_foliage,
		"haze_color": palette.haze_tint,
		"haze_strength": 0.68 * haze_scale,
		"season_color": PaletteClass.foliage_season_target(season),
		"season_mix": PaletteClass.foliage_season_mix(season),
	}


static func cloud_shader_params(season: int, settings: GraphicsSettings) -> Dictionary:
	var palette: Dictionary = PaletteClass.atmosphere_for_season(season)
	var enabled: bool = settings.atmosphere_clouds and settings.atmosphere_cloud_strength > 0.01
	return {
		"enabled": enabled,
		"cloud_tint": palette.cloud_tint,
		"cloud_strength": settings.atmosphere_cloud_strength if enabled else 0.0,
	}


static func apply_shader_material(material: ShaderMaterial, params: Dictionary) -> void:
	if material == null:
		return
	for key in params.keys():
		if key == "enabled":
			continue
		material.set_shader_parameter(key, params[key])


static func invalidate_reflection_captures(root: Node) -> void:
	# Package 12 hook: sky/atmosphere changes must not leave stale probe captures.
	if root == null:
		return
	for node in root.find_children("*", "ReflectionProbe", true, false):
		if node is ReflectionProbe:
			var probe: ReflectionProbe = node
			if probe.update_mode == ReflectionProbe.UPDATE_ALWAYS:
				continue
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
