extends SceneTree

# Renders the primary interface at several window sizes for visual review.
# Run without --headless:  Godot --path . --script tests/capture_ui.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	SaveStore.directory = "user://test_saves/capture_ui_%d" % OS.get_process_id()
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.ui.hide_menu()
	game.menu_open = false
	game.set_speed(1)
	for i in range(6):
		game.sim.admit_group(3)
	game.sim.tick(600.0)
	game.set_speed(0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/ui"))
	for size in [Vector2i(1440, 900), Vector2i(1920, 1080), Vector2i(1100, 700)]:
		get_root().size = size
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		var tag: String = "%dx%d" % [size.x, size.y]
		game.clear_selection()
		game.ui.show_tab("Terrain")
		await _shot("%s_terrain" % tag)
		game.ui.show_tab("Holes")
		await _shot("%s_holes" % tag)
		game.select_hole(int(game.terrain.holes[0].get("id", -1)))
		game.analyze_hole()
		await _shot("%s_hole_inspector" % tag)
		game.clear_selection()
		game.ui.show_tab("Money")
		await _shot("%s_money" % tag)
		if size.x == 1440:
			game.ui.show_tab("Guests")
			await _shot("%s_guests" % tag)
			if not game.sim.guests.is_empty():
				game.select_guest(int(game.sim.guests[0].get("id", -1)))
				await _shot("%s_guest_inspector" % tag)
				game.clear_selection()
			game.ui.show_tab("Staff")
			await _shot("%s_staff" % tag)
			if not game.sim.staff.is_empty():
				game.select_staff(int(game.sim.staff[0].get("id", -1)))
				await _shot("%s_staff_inspector" % tag)
				game.clear_selection()
			game.ui.show_tab("Build")
			await _shot("%s_build" % tag)
			game.ui.show_tab("Reputation")
			await _shot("%s_reputation" % tag)
			game.ui.show_tab("Progress")
			await _shot("%s_progress" % tag)
			game.ui.show_log()
			await _shot("%s_log" % tag)
			game.ui.show_system()
			await _shot("%s_system_save" % tag)
			game.ui._system_section = "settings"
			game.ui.show_system()
			await _shot("%s_system_settings" % tag)
			game.ui._close_system()
		game.ui.show_tab("Reports")
		await _shot("%s_reports" % tag)
	print("CAPTURE_UI_DONE")
	quit()

func _shot(name_value: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	image.save_png("res://builds/ui/%s.png" % name_value)
