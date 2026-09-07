class_name ShadowDiagnostics
extends RefCounted

## Deterministic shadow/contact diagnostic fixture for package 10.
## Tree + building contact, bridge, slope, cart and foundation close-up.

const PaletteClass = preload("res://scripts/graphics_palette.gd")
const ShadowClass = preload("res://scripts/graphics_shadow.gd")
const AssetFactoryClass = preload("res://scripts/asset_factory.gd")
const SettingsClass = preload("res://scripts/graphics_settings.gd")


static func build_root(settings: GraphicsSettings = null) -> Node3D:
	var gfx: GraphicsSettings = settings if settings != null else SettingsClass.defaults()
	var root := Node3D.new()
	root.name = "ShadowDiagnostics"
	_add_lighting(root, gfx)
	_add_ground(root)
	_add_contact_set(root)
	return root


static func _add_lighting(parent: Node3D, settings: GraphicsSettings) -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-38, -38, 0)
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
	var floor := MeshInstance3D.new()
	floor.name = "FairwayPad"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("74a35b")
	floor_mat.roughness = 0.9
	floor.material_override = floor_mat
	floor.position = Vector3(0, -0.01, 0)
	parent.add_child(floor)

	var slope := MeshInstance3D.new()
	slope.name = "SteepBank"
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array([
		Vector3(-8, 0, 10), Vector3(8, 0, 10), Vector3(8, 0, 18),
		Vector3(-8, 0, 10), Vector3(8, 0, 18), Vector3(-8, 3.6, 18),
	])
	var normals := PackedVector3Array()
	for i in range(verts.size()):
		normals.append(Vector3.UP)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	slope.mesh = mesh
	var slope_mat := StandardMaterial3D.new()
	slope_mat.albedo_color = Color("69883d")
	slope_mat.roughness = 0.88
	slope.material_override = slope_mat
	slope.cast_shadow = ShadowClass.terrain_cast_shadow_mode(false)
	parent.add_child(slope)


static func _add_contact_set(parent: Node3D) -> void:
	var set := Node3D.new()
	set.name = "ContactSet"
	parent.add_child(set)

	var clubhouse: Node3D = AssetFactoryClass.build("clubhouse", 0)
	clubhouse.position = Vector3(-6, 0, 2)
	clubhouse.rotation.y = 0.35
	set.add_child(clubhouse)

	var tree: Node3D = AssetFactoryClass.build("oak_tree", 1)
	tree.position = Vector3(-1.5, 0, 4.5)
	tree.scale = Vector3.ONE * 0.62
	set.add_child(tree)

	var pine: Node3D = AssetFactoryClass.build("pine_tree", 2)
	pine.position = Vector3(2.5, 0, 5.5)
	pine.scale = Vector3.ONE * 0.58
	set.add_child(pine)

	var cart: Node3D = AssetFactoryClass.cart()
	cart.position = Vector3(5.5, 0, 1.5)
	cart.rotation.y = -0.8
	set.add_child(cart)

	var bridge: Node3D = AssetFactoryClass.build("bridge_cart", 0)
	bridge.position = Vector3(10, 0, 12)
	bridge.rotation.y = PI * 0.5
	bridge.scale = Vector3(0.55, 0.55, 0.55)
	set.add_child(bridge)

	var foundation := MeshInstance3D.new()
	foundation.name = "FoundationStep"
	var step := BoxMesh.new()
	step.size = Vector3(3.2, 0.42, 2.4)
	foundation.mesh = step
	foundation.material_override = AssetFactoryClass._material(AssetFactoryClass.TERRACOTTA_DARK)
	foundation.position = Vector3(-6.2, 0.21, -1.2)
	set.add_child(foundation)
