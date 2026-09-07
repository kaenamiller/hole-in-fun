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
@export var msaa_3d: int = 2
@export var reflection_mode: String = "sky"
@export var reflection_resolution: int = 256
@export var weather_particle_cap: int = 600
@export var effect_instance_cap: int = 64
@export var tree_shadow_volumes: bool = true


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
			shadow_distance = 600.0
			shadow_resolution = 2048
			msaa_3d = 0
			reflection_mode = "sky"
			reflection_resolution = 128
			weather_particle_cap = 200
			effect_instance_cap = 24
			tree_shadow_volumes = false
		Preset.HIGH:
			foliage_view_distance = 1100.0
			foliage_density = 1.0
			foliage_lod_bias = 1.6
			shadow_distance = 1400.0
			shadow_resolution = 4096
			msaa_3d = 2
			reflection_mode = "sky"
			reflection_resolution = 512
			weather_particle_cap = 600
			effect_instance_cap = 96
			tree_shadow_volumes = true
		_:
			foliage_view_distance = 900.0
			foliage_density = 1.0
			foliage_lod_bias = 2.0
			shadow_distance = 1100.0
			shadow_resolution = 4096
			msaa_3d = 2
			reflection_mode = "sky"
			reflection_resolution = 256
			weather_particle_cap = 600
			effect_instance_cap = 64
			tree_shadow_volumes = true


func duplicate_settings() -> GraphicsSettings:
	var copy: GraphicsSettings = GraphicsSettings.new()
	copy.preset = preset
	copy.foliage_view_distance = foliage_view_distance
	copy.foliage_density = foliage_density
	copy.foliage_lod_bias = foliage_lod_bias
	copy.shadow_distance = shadow_distance
	copy.shadow_resolution = shadow_resolution
	copy.msaa_3d = msaa_3d
	copy.reflection_mode = reflection_mode
	copy.reflection_resolution = reflection_resolution
	copy.weather_particle_cap = weather_particle_cap
	copy.effect_instance_cap = effect_instance_cap
	copy.tree_shadow_volumes = tree_shadow_volumes
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
		"msaa_3d": msaa_3d,
		"reflection_mode": reflection_mode,
		"reflection_resolution": reflection_resolution,
		"weather_particle_cap": weather_particle_cap,
		"effect_instance_cap": effect_instance_cap,
		"tree_shadow_volumes": tree_shadow_volumes,
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
	sanitize()


func sanitize() -> void:
	foliage_view_distance = clampf(foliage_view_distance, 120.0, 2400.0)
	foliage_density = clampf(foliage_density, 0.2, 1.0)
	foliage_lod_bias = clampf(foliage_lod_bias, 0.5, 8.0)
	shadow_distance = clampf(shadow_distance, 200.0, 2400.0)
	shadow_resolution = _clamp_shadow_resolution(shadow_resolution)
	msaa_3d = clampi(msaa_3d, 0, 3)
	if reflection_mode not in ["sky", "probe", "planar"]:
		reflection_mode = "sky"
	if reflection_mode in ["probe", "planar"]:
		reflection_mode = "sky"
	reflection_resolution = clampi(reflection_resolution, 64, 1024)
	weather_particle_cap = clampi(weather_particle_cap, 0, 1200)
	effect_instance_cap = clampi(effect_instance_cap, 0, 256)


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
