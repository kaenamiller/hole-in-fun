extends SceneTree
var failures: Array[String] = []
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	check(terrain.holes.size()==3,"Lakeside must retain three holes")
	for hole in terrain.holes:
		check(terrain.hole_valid(hole).is_empty(),hole.name+": "+terrain.hole_valid(hole))
		check(not terrain.route(terrain.entrance,hole.tee,true).is_empty(),hole.name+" must connect to cart route")
	var snapshot: Dictionary = terrain.snapshot()
	var restored := TerrainModel.new()
	restored.restore(snapshot)
	check(restored.surfaces==terrain.surfaces,"Lakeside surfaces must survive save restoration")
	check(restored.objects==terrain.objects,"Landscape objects must survive save restoration")
	var view := TerrainView.new()
	root.add_child(view)
	view.setup(terrain)
	var water_pixel: Color = view._detail_texture.get_image().get_pixel(80,82)
	check(water_pixel.g>0.99,"Central lake must be present in the rendering mask")
	var command: Dictionary = terrain.plan_brush("paint",Vector3(62,0,62),8,1,5)
	terrain.apply_brush(command)
	view.rebuild_dirty()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": check(view._detail_texture.get_image().get_pixel(15,15).g>0.99,"Water brush must refresh the rendering mask")
	terrain.apply_brush(command,true)
	view.rebuild_dirty()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": check(view._detail_texture.get_image().get_pixel(15,15).g<0.01,"Undo must restore the rendering mask")
	view.set_grid(true)
	check(view.water_material.get_shader_parameter("show_grid")==true,"Exact grid view must cover water and ground together")
	view.set_overlay("wear")
	check(view.ground_material.get_shader_parameter("analysis")==true,"Surface art must preserve maintenance overlays")
	view.set_overlay("none")
	check(view.ground_material.get_shader_parameter("analysis")==false,"Leaving overlays must restore resort materials")
	var a := AssetFactory.build("oak_tree",2)
	var b := AssetFactory.build("oak_tree",2)
	check(a.get_child(0).mesh==b.get_child(0).mesh,"Trees must reuse baked meshes")
	a.free(); b.free()
	view.queue_free()
	await process_frame
	print("test_lush: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)
