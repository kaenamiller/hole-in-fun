class_name PlanarReflectionFixture
extends RefCounted

## Isolated planar reflection fixture: flat water plane + asymmetric building.

const AssetFactoryClass = preload("res://scripts/asset_factory.gd")
const ReflectionProbesClass = preload("res://scripts/graphics_reflection_probes.gd")
const SettingsClass = preload("res://scripts/graphics_settings.gd")
const ShadowClass = preload("res://scripts/graphics_shadow.gd")
const PaletteClass = preload("res://scripts/graphics_palette.gd")

const WATER_Y: float = 0.0
const LAKE_HALF: float = 48.0


static func build_root(settings: GraphicsSettings = null) -> Node3D:
	var gfx: GraphicsSettings = settings if settings != null else SettingsClass.for_preset("high")
	var root := Node3D.new()
	root.name = "PlanarReflectionFixture"
	_add_environment(root, gfx)
	_add_ground(root)
	_add_water(root)
	_add_asymmetric_building(root)
	_add_vegetation_marker(root)
	return root


static func water_plane_y() -> float:
	return WATER_Y


static func camera_rig() -> Dictionary:
	return {
		"focus": Vector3(8.0, 0.0, 6.0),
		"yaw": 0.42,
		"size": 42.0,
		"elevation": 0.82,
		"distance": 55.0,
	}


static func _add_environment(parent: Node3D, settings: GraphicsSettings) -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-34, -28, 0)
	ShadowClass.apply_directional_light(light, settings)
	PaletteClass.apply_directional_light(light, 1)
	parent.add_child(light)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	PaletteClass.apply_procedural_sky(sky_material, 1)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	PaletteClass.apply_environment(environment, 1)
	ShadowClass.apply_environment_ssao(environment, settings)
	world_env.environment = environment
	parent.add_child(world_env)


static func _add_ground(parent: Node3D) -> void:
	var shore := MeshInstance3D.new()
	shore.name = "ShorePad"
	var plane := PlaneMesh.new()
	plane.size = Vector2(LAKE_HALF * 2.6, LAKE_HALF * 2.6)
	shore.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7f9a62")
	mat.roughness = 0.92
	shore.material_override = mat
	shore.position = Vector3(0.0, -0.08, 0.0)
	ReflectionProbesClass.tag_dynamic(shore)
	parent.add_child(shore)


static func _add_water(parent: Node3D) -> void:
	var water := MeshInstance3D.new()
	water.name = "LakePlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(LAKE_HALF * 2.0, LAKE_HALF * 2.0)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2f6f78")
	mat.metallic = 0.05
	mat.roughness = 0.22
	water.material_override = mat
	water.position = Vector3(0.0, WATER_Y, 0.0)
	ReflectionProbesClass.tag_water_mesh(water)
	parent.add_child(water)


static func _add_asymmetric_building(parent: Node3D) -> void:
	var clubhouse: Node3D = AssetFactoryClass.build("clubhouse", 0)
	clubhouse.name = "OffsetClubhouse"
	clubhouse.position = Vector3(-22.0, WATER_Y, 14.0)
	clubhouse.rotation_degrees = Vector3(0.0, 38.0, 0.0)
	for child in clubhouse.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = ReflectionProbesClass.LAYER_SCENE
	parent.add_child(clubhouse)

	var kiosk: Node3D = AssetFactoryClass.build("kiosk", 0)
	kiosk.name = "ShoreKiosk"
	kiosk.position = Vector3(18.0, WATER_Y, -10.0)
	kiosk.rotation_degrees = Vector3(0.0, -24.0, 0.0)
	for child in kiosk.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = ReflectionProbesClass.LAYER_SCENE
	parent.add_child(kiosk)


static func _add_vegetation_marker(parent: Node3D) -> void:
	var tree: Node3D = AssetFactoryClass.build("oak_tree", 1)
	tree.name = "LakesideOak"
	tree.position = Vector3(26.0, WATER_Y, 20.0)
	tree.scale = Vector3(1.2, 1.2, 1.2)
	for child in tree.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = ReflectionProbesClass.LAYER_SCENE
	parent.add_child(tree)
