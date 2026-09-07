extends SceneTree

const FixtureClass = preload("res://scripts/planar_reflection_fixture.gd")
const PlanarClass = preload("res://scripts/graphics_planar_reflections.gd")
const SettingsClass = preload("res://scripts/graphics_settings.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/planar_reflections")
	var settings: GraphicsSettings = SettingsClass.for_preset("high")
	settings.reflection_mode = "planar"
	var scene: Node3D = FixtureClass.build_root(settings)
	root.add_child(scene)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	root.add_child(camera)

	var rig: Dictionary = FixtureClass.camera_rig()
	_apply_rig(camera, rig)

	for view_name in ["overview", "zoom", "tilt"]:
		await _capture(scene, camera, settings, view_name)
		if view_name == "overview":
			camera.size = 28.0
			_apply_rig(camera, rig)
		elif view_name == "zoom":
			rig["elevation"] = 1.15
			rig["yaw"] = 0.72
			_apply_rig(camera, rig)

	scene.queue_free()
	await process_frame
	print(
		"Planar reflection captures complete. Draw calls: %d; primitives: %d"
		% [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		]
	)
	quit()

func _apply_rig(camera: Camera3D, rig: Dictionary) -> void:
	var focus: Vector3 = rig.get("focus", Vector3.ZERO)
	var yaw: float = float(rig.get("yaw", 0.0))
	var distance: float = float(rig.get("distance", 50.0))
	var elevation: float = float(rig.get("elevation", 0.8))
	camera.size = float(rig.get("size", 40.0))
	var framed_focus: Vector3 = focus + Vector3(cos(yaw), 0.0, -sin(yaw)) * camera.size * 0.14
	camera.position = framed_focus + Vector3(sin(yaw) * distance, distance * elevation, cos(yaw) * distance)
	camera.look_at(framed_focus, Vector3.UP)

func _capture(_scene: Node3D, camera: Camera3D, settings: GraphicsSettings, view: String) -> void:
	for i in range(10):
		await process_frame
	var reflected: Transform3D = PlanarClass.reflect_transform_across_plane(
		camera.global_transform,
		Plane(Vector3.UP, -FixtureClass.water_plane_y()),
	)
	var path: String = "res://builds/planar_reflections/%s-%s.png" % [settings.reflection_mode, view]
	var tex: Texture2D = root.get_texture()
	if tex == null:
		print("Skipped %s (headless dummy framebuffer); reflected origin y=%.2f" % [path, reflected.origin.y])
		return
	var image: Image = tex.get_image()
	if image != null and not image.is_empty():
		image.save_png(path)
		print("Captured %s" % path)
	else:
		print("Skipped %s (empty framebuffer)" % path)
