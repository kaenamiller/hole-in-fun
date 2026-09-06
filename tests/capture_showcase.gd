extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.hide_menu()
	game.speed=0
	game.set_tool("inspect")
	game.sim.tick(3000)
	game.camera.reset_view()
	game.ui.show_tab("Holes")
	game.ui.refresh()
	await capture("showcase_course.png")
	game.camera.focus=Vector3(133,0,123)
	game.camera.size=110
	game.ui.show_tab("Build")
	game.ui.refresh()
	await capture("showcase_clubhouse.png")
	game.select_hole(game.terrain.holes[0].id)
	game.analyze_hole()
	game.ui.refresh()
	await capture("showcase_shots.png")
	game.clear_analysis()
	if not game.sim.guests.is_empty():
		game.select_guest(game.sim.guests[0].id)
		game.ui.refresh()
		await capture("showcase_golfer.png")
	game.queue_free()
	await process_frame
	quit()

func capture(filename: String) -> void:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+filename)
