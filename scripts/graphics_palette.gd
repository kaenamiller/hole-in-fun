class_name GraphicsPalette
extends RefCounted

## Central environment and surface palette for resort lighting (package 03).
## World grading and seasonal tints live here. Gameplay/UI accent colors are
## separate under READABILITY and are not passed through world tonemapping.

# --- Legacy pre-package-03 fixture (retained for A/B comparison) ---
const LEGACY := {
	"sun_color": Color("fff0d3"),
	"sun_energy": 1.12,
	"ambient_color": Color("c6d8cf"),
	"ambient_energy": 0.48,
	"clear_color": Color("b8cabe"),
	"sky_top": Color("789fb4"),
	"sky_horizon": Color("dce4cd"),
	"ground_horizon": Color("dce4cd"),
	"ground_bottom": Color("66734a"),
	"tonemap": Environment.TONE_MAPPER_LINEAR,
	"exposure": 1.0,
	"season_ambient": [
		{"bg": Color("b8cabe"), "amb": Color("d6dfca")},
		{"bg": Color("c2d2b2"), "amb": Color("e0e2c4")},
		{"bg": Color("c9bda1"), "amb": Color("ddd2b6")},
		{"bg": Color("c9d3da"), "amb": Color("dfe6ec")},
	],
}

# --- Retained shader art curves (Compatibility; do not remove without capture) ---
const ART_CURVES := {
	"ground": {"gamma": 1.65, "scale": 0.9},
	"foliage": {"gamma": 1.35, "stipple": 0.18, "emission": 0.055},
	"water": {"gamma": 1.5, "glint_exp": 16.0},
	"path": {"gamma": 1.65, "grain_scale": 0.02, "base": 0.84},
	"horizon": {"gamma": 1.65, "scale": 0.9},
}

# Shader uniform keys for terrain surfaces (index matches TerrainModel palette slots).
const SURFACE_KEYS := [
	"rough_color", "fairway_color", "green_color", "tee_color", "sand_color", "soil_color",
]

# Canonical sRGB surface albedos for terrain shaders (slot 5 water uses water_tint).
const SURFACE_COLORS := [
	Color("637f3d"), Color("8cab4e"), Color("adc665"), Color("94b557"),
	Color("dfcb9e"), Color("65aaa8"), Color("b18b60"),
]

const WATER_TINT_DEFAULT := Color("65aaa8")
const HORIZON_LAKE_TINT := Color("8caaa0")

# Distant vista grading (package 14). Playable surfaces use SURFACE_COLORS instead.
const ATMOSPHERE := {
	"hill_cool": Vector3(0.94, 0.97, 1.05),
	"distant_foliage": Vector3(0.20, 0.32, 0.22),
	"distant_foliage_winter": Vector3(0.34, 0.38, 0.42),
}

# Architecture / prop tints sourced once for AssetFactory and MaterialLibrary.
const ARCH_COLORS := {
	"plaster": Color("#e2d3ad"),
	"timber": Color("#8b5a3c"),
	"timber_dark": Color("#4e3326"),
	"roof": Color("#75604a"),
	"roof_dark": Color("#493d32"),
	"bark": Color("#4e3326"),
	"stone": Color("#777b70"),
	"stone_light": Color("#9a9c8a"),
}

# Stable material IDs: { folder, palette source, physical scale, roughness, flags }.
const MATERIAL_FAMILIES := {
	"course.fairway": {
		"folder": "fairway",
		"palette_slot": 1,
		"meters_per_repeat": 2.0,
		"roughness": 0.88,
		"season_tint": true,
		"triplanar": false,
	},
	"course.rough": {
		"folder": "rough",
		"palette_slot": 0,
		"meters_per_repeat": 1.5,
		"roughness": 0.92,
		"season_tint": true,
		"triplanar": false,
	},
	"course.sand": {
		"folder": "sand",
		"palette_slot": 4,
		"meters_per_repeat": 0.8,
		"roughness": 0.94,
		"season_tint": true,
		"triplanar": false,
	},
	"course.gravel": {
		"folder": "gravel",
		"palette_slot": 6,
		"meters_per_repeat": 0.5,
		"roughness": 0.90,
		"season_tint": false,
		"triplanar": true,
	},
	"prop.stone": {
		"folder": "stone",
		"arch_key": "stone",
		"meters_per_repeat": 1.2,
		"roughness": 0.85,
		"season_tint": false,
		"triplanar": true,
	},
	"arch.plaster": {
		"folder": "plaster",
		"arch_key": "plaster",
		"meters_per_repeat": 1.8,
		"roughness": 0.86,
		"season_tint": false,
		"triplanar": true,
	},
	"prop.bark": {
		"folder": "bark",
		"arch_key": "bark",
		"meters_per_repeat": 0.6,
		"roughness": 0.91,
		"season_tint": false,
		"triplanar": true,
	},
	"arch.timber": {
		"folder": "timber",
		"arch_key": "timber",
		"meters_per_repeat": 1.4,
		"roughness": 0.84,
		"season_tint": false,
		"triplanar": true,
	},
	"arch.roof": {
		"folder": "roof",
		"arch_key": "roof",
		"meters_per_repeat": 0.9,
		"roughness": 0.89,
		"season_tint": false,
		"triplanar": true,
	},
}

# Gameplay readability accents — not world-graded; keep outside environment palette.
const READABILITY := {
	"ball": Color("fffbef"),
	"flag_pole": Color("e2d3ad"),
	"flag_cloth": Color("75604a"),
	"selection_ring": Color("f1c777"),
	"cup_ring": Color("ffffff"),
	"overlay_traffic": [Color(1.0, 0.55, 0.18, 0.0), Color(1.0, 0.45, 0.08, 0.85)],
	"overlay_cart_traffic": [Color(0.35, 0.65, 1.0, 0.0), Color(0.15, 0.45, 0.95, 0.85)],
	"overlay_waiting": [Color(1.0, 0.92, 0.35, 0.0), Color(0.92, 0.18, 0.12, 0.85)],
}

const SEASON_NAMES := ["spring", "summer", "fall", "winter"]

static func clamp_season(index: int) -> int:
	return clampi(index, 0, 3)

static func season_name(index: int) -> String:
	return SEASON_NAMES[clamp_season(index)]

static func atmosphere_for_season(season: int) -> Dictionary:
	var i: int = clamp_season(season)
	var env: Dictionary = environment_for_season(i)
	var sky_h: Color = env.sky_horizon
	var sky_t: Color = env.sky_top
	var haze: Color = sky_h.lerp(sky_t, 0.58)
	var foliage: Vector3 = ATMOSPHERE.distant_foliage
	if i == 3:
		foliage = ATMOSPHERE.distant_foliage_winter
	elif i == 2:
		foliage = Vector3(0.24, 0.28, 0.18)
	return {
		"fog_light": sky_h.lerp(Color.WHITE, 0.38),
		"haze_tint": Vector3(haze.r, haze.g, haze.b),
		"hill_cool": ATMOSPHERE.hill_cool,
		"distant_foliage": foliage,
		"cloud_tint": Vector3(
			sky_h.lerp(Color.WHITE, 0.72).r,
			sky_h.lerp(Color.WHITE, 0.72).g,
			sky_h.lerp(sky_t, 0.35).b,
		),
	}


static func environment_for_season(season: int) -> Dictionary:
	var i: int = clamp_season(season)
	var legacy_row: Dictionary = LEGACY.season_ambient[i]
	return {
		"sun_color": LEGACY.sun_color,
		"sun_energy": LEGACY.sun_energy,
		"ambient_color": legacy_row.amb,
		"ambient_energy": LEGACY.ambient_energy,
		"clear_color": legacy_row.bg,
		"background_color": legacy_row.bg,
		"sky_top": LEGACY.sky_top,
		"sky_horizon": LEGACY.sky_horizon,
		"ground_horizon": LEGACY.ground_horizon,
		"ground_bottom": LEGACY.ground_bottom,
		"tonemap": LEGACY.tonemap,
		"exposure": LEGACY.exposure,
		"bloom_enabled": false,
		"bloom_intensity": 0.0,
	}

static func terrain_season_tint(season: int) -> Vector3:
	var tints: Array[Vector3] = [
		Vector3(1.0, 1.03, 0.97),
		Vector3(1.02, 1.0, 0.9),
		Vector3(1.08, 0.95, 0.78),
		Vector3(1.15, 1.2, 1.3),
	]
	return tints[clamp_season(season)]

static func foliage_season_target(season: int) -> Color:
	var targets: Array[Color] = [
		Color("#5d8a52"), Color("#3f7040"), Color("#8a6a34"), Color("#e8edf2"),
	]
	return targets[clamp_season(season)]

static func foliage_season_mix_raw(season: int) -> float:
	var mixes: Array[float] = [0.55, 0.0, 0.75, 0.85]
	return mixes[clamp_season(season)]

static func foliage_season_mix(season: int) -> float:
	return foliage_season_mix_raw(season) * 0.75

static func surface_vector(slot: int) -> Vector3:
	var color: Color = SURFACE_COLORS[clampi(slot, 0, SURFACE_COLORS.size() - 1)]
	return Vector3(color.r, color.g, color.b)

static func surface_colors_for_terrain(model: TerrainModel = null) -> Dictionary:
	var out: Dictionary = {}
	var palette: PackedColorArray = model.palette if model != null else SURFACE_COLORS
	for i in range(SURFACE_KEYS.size()):
		var slot: int = [0, 1, 2, 3, 4, 6][i]
		var color: Color = palette[clampi(slot, 0, palette.size() - 1)]
		out[SURFACE_KEYS[i]] = Vector3(color.r, color.g, color.b)
	return out

static func water_tint(model: TerrainModel = null) -> Vector3:
	var color: Color = model.water_color if model != null else WATER_TINT_DEFAULT
	return Vector3(color.r, color.g, color.b)

static func apply_directional_light(light: DirectionalLight3D, season: int = 1) -> void:
	if light == null:
		return
	var env: Dictionary = environment_for_season(season)
	light.light_color = env.sun_color
	light.light_energy = env.sun_energy

static func apply_procedural_sky(sky_material: ProceduralSkyMaterial, season: int = 1) -> void:
	if sky_material == null:
		return
	var env: Dictionary = environment_for_season(season)
	sky_material.sky_top_color = env.sky_top
	sky_material.sky_horizon_color = env.sky_horizon
	sky_material.ground_horizon_color = env.ground_horizon
	sky_material.ground_bottom_color = env.ground_bottom
	sky_material.sun_angle_max = 8.0

static func apply_environment(environment: Environment, season: int = 1) -> void:
	if environment == null:
		return
	var env: Dictionary = environment_for_season(season)
	environment.background_color = env.background_color
	environment.ambient_light_color = env.ambient_color
	environment.ambient_light_energy = env.ambient_energy
	environment.tonemap_mode = env.tonemap
	environment.tonemap_exposure = env.exposure
	environment.glow_enabled = env.bloom_enabled
	environment.glow_intensity = env.bloom_intensity
	RenderingServer.set_default_clear_color(env.clear_color)

static func apply_terrain_materials(
	ground_material: ShaderMaterial,
	water_material: ShaderMaterial,
	horizon_material: ShaderMaterial,
	model: TerrainModel,
	season: int,
) -> void:
	if ground_material != null:
		for key in surface_colors_for_terrain(model):
			ground_material.set_shader_parameter(key, surface_colors_for_terrain(model)[key])
		ground_material.set_shader_parameter("season_tint", terrain_season_tint(season))
	if water_material != null:
		water_material.set_shader_parameter("water_tint", water_tint(model))
	if horizon_material != null:
		horizon_material.set_shader_parameter("season_tint", terrain_season_tint(season))

static func legacy_comparison_dict() -> Dictionary:
	return LEGACY.duplicate(true)

static func material_family(family_id: String) -> Dictionary:
	if not MATERIAL_FAMILIES.has(family_id):
		push_error("Unknown material family: " + family_id)
		return {}
	return MATERIAL_FAMILIES[family_id]

static func material_tint_color(family_id: String, model: TerrainModel = null) -> Color:
	var def: Dictionary = material_family(family_id)
	if def.is_empty():
		return Color.WHITE
	if def.has("palette_slot"):
		var palette: PackedColorArray = model.palette if model != null else SURFACE_COLORS
		var slot: int = int(def.palette_slot)
		return palette[clampi(slot, 0, palette.size() - 1)]
	var arch_key: String = str(def.get("arch_key", ""))
	if ARCH_COLORS.has(arch_key):
		return ARCH_COLORS[arch_key]
	return Color.WHITE

static func season_tinted_material_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for family_id in MATERIAL_FAMILIES.keys():
		if bool(MATERIAL_FAMILIES[family_id].get("season_tint", false)):
			ids.append(family_id)
	return ids

static func material_season_mix(family_id: String, season: int) -> float:
	if not bool(material_family(family_id).get("season_tint", false)):
		return 0.0
	return foliage_season_mix_raw(season) * 0.55
