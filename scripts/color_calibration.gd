class_name ColorCalibration
extends RefCounted

## Deterministic lighting swatch scene for package 03 calibration.

const PaletteClass = preload("res://scripts/graphics_palette.gd")
const AssetFactoryClass = preload("res://scripts/asset_factory.gd")

static func build_root(season: int = 1) -> Node3D:
	var root := Node3D.new()
	root.name = "ColorCalibration"
	_add_lighting(root, season)
	_add_neutral_swatches(root)
	_add_material_samples(root)
	_add_game_assets(root)
	return root

static func _add_lighting(parent: Node3D, season: int) -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-38, -38, 0)
	var settings: GraphicsSettings = GraphicsSettings.defaults()
	GraphicsShadow.apply_directional_light(light, settings)
	PaletteClass.apply_directional_light(light, season)
	parent.add_child(light)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	PaletteClass.apply_procedural_sky(sky_material, season)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	PaletteClass.apply_environment(environment, season)
	GraphicsShadow.apply_environment_ssao(environment, settings)
	GraphicsAtmosphere.apply_environment_atmosphere(environment, settings, season)
	world_env.environment = environment
	parent.add_child(world_env)

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(48, 48)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("8a8a8a")
	floor_mat.roughness = 0.92
	floor.material_override = floor_mat
	floor.position = Vector3(0, -0.01, 0)
	parent.add_child(floor)

static func _add_neutral_swatches(parent: Node3D) -> void:
	var row := Node3D.new()
	row.name = "NeutralSwatches"
	parent.add_child(row)
	var grays: Array = [
		{"label": "gray18", "color": Color("2e2e2e")},
		{"label": "gray50", "color": Color("808080")},
		{"label": "gray90", "color": Color("e6e6e6")},
		{"label": "white", "color": Color.WHITE},
	]
	for i in grays.size():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = grays[i].color
		mat.roughness = 0.85
		_add_box(row, Vector3(1.4, 0.12, 1.4), mat, Vector3(-9 + i * 2.2, 0.06, -6))
	var rough := StandardMaterial3D.new()
	rough.albedo_color = Color("c8c8c8")
	rough.roughness = 0.95
	_add_sphere(row, 0.55, rough, Vector3(-2, 0.55, -6))
	var glossy := StandardMaterial3D.new()
	glossy.albedo_color = Color("d0d0d0")
	glossy.roughness = 0.12
	glossy.metallic = 0.05
	_add_sphere(row, 0.55, glossy, Vector3(0.5, 0.55, -6))

static func _add_material_samples(parent: Node3D) -> void:
	var row := Node3D.new()
	row.name = "SurfaceSamples"
	parent.add_child(row)
	var ground_shader: Shader = load("res://shaders/resort_ground.gdshader")
	var water_shader: Shader = load("res://shaders/resort_water.gdshader")
	var path_shader: Shader = load("res://shaders/resort_path.gdshader")

	var ground := ShaderMaterial.new()
	ground.shader = ground_shader
	for key in PaletteClass.surface_colors_for_terrain():
		ground.set_shader_parameter(key, PaletteClass.surface_colors_for_terrain()[key])
	ground.set_shader_parameter("season_tint", PaletteClass.terrain_season_tint(1))
	var dry_field := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dry_field.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.0))
	ground.set_shader_parameter("water_field", ImageTexture.create_from_image(dry_field))
	_add_quad(row, ground, Vector3(-8, 0.02, 0), Vector3(3.5, 0, 2.5), "turf")

	var water := ShaderMaterial.new()
	water.shader = water_shader
	water.set_shader_parameter("water_tint", PaletteClass.water_tint())
	var water_mask := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	water_mask.set_pixel(0, 0, Color(0.2, 0.5, 0.0, 1.0))
	water.set_shader_parameter("water_field", ImageTexture.create_from_image(water_mask))
	_add_quad(row, water, Vector3(-3.5, 0.04, 0), Vector3(2.5, 0, 2.5), "water")

	var path := ShaderMaterial.new()
	path.shader = path_shader
	path.set_shader_parameter("path_color", Vector3(0.7, 0.62, 0.44))
	_add_quad(row, path, Vector3(0.5, 0.02, 0), Vector3(2.5, 0, 2.5), "path")

	var shrub: Node3D = AssetFactoryClass.build("desert_shrub", 0)
	shrub.position = Vector3(4.5, 0, 0)
	shrub.scale = Vector3.ONE * 1.1
	row.add_child(shrub)

	var stone := MaterialLibrary.material("prop.stone")
	_add_sphere(row, 0.65, stone, Vector3(7.0, 0.65, -0.5))
	var plaster := MaterialLibrary.material("arch.plaster")
	_add_box(row, Vector3(1.2, 1.0, 0.4), plaster, Vector3(7.0, 0.5, 1.2))
	var timber := MaterialLibrary.material("arch.timber")
	_add_box(row, Vector3(1.4, 0.35, 0.35), timber, Vector3(9.0, 0.18, 1.2))

static func _add_game_assets(parent: Node3D) -> void:
	var row := Node3D.new()
	row.name = "GameAssets"
	parent.add_child(row)
	var flag: Node3D = AssetFactoryClass.build("flag", 0)
	flag.position = Vector3(-6, 0, 4)
	flag.scale = Vector3.ONE * 1.2
	row.add_child(flag)
	var tree: Node3D = AssetFactoryClass.build("oak_tree", 0)
	tree.position = Vector3(-2, 0, 4.5)
	tree.scale = Vector3.ONE * 0.55
	row.add_child(tree)
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = PaletteClass.READABILITY.ball
	_add_sphere(row, 0.28, ball_mat, Vector3(2, 0.28, 4.2))
	var stake: Node3D = AssetFactoryClass.build("stake", 1)
	stake.position = Vector3(3.5, 0, 4.2)
	row.add_child(stake)

static func _add_box(parent: Node3D, size: Vector3, material: Material, position: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = material
	mesh_inst.position = position
	parent.add_child(mesh_inst)

static func _add_sphere(parent: Node3D, radius: float, material: Material, position: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_inst.mesh = sphere
	mesh_inst.material_override = material
	mesh_inst.position = position
	parent.add_child(mesh_inst)

static func _add_quad(
	parent: Node3D,
	material: Material,
	center: Vector3,
	size: Vector3,
	_name: String,
) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = _name
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	mesh_inst.mesh = plane
	mesh_inst.material_override = material
	mesh_inst.position = center
	parent.add_child(mesh_inst)
