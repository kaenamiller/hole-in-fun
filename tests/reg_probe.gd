extends SceneTree
const Simulation = preload("res://scripts/resort_simulation.gd")
func _init() -> void:
	var terrain = preload("res://scripts/terrain_model.gd").new()
	terrain.starter_resort()
	terrain.objects.append({"id": 880, "kind": "lodge", "pos": Vector3(220.0, 0.0, 180.0), "rotation": 0.0, "condition": 1.0, "cleanliness": 1.0, "level": 1})
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim.unlocked.append("lodge")
	sim._arrival_target = 48
	for i in range(12):
		sim.admit_group(4)
	var states := {}
	var last_day: int = 0
	for day in range(120):
		last_day = day
		sim._arrival_target = 0
		sim.tick(800.0)
		states.clear()
		for group in sim.groups:
			var st: String = str(group.get("state", ""))
			states[st] = int(states.get(st, 0)) + 1
		if day == 119 or (day > 20 and int(states.get("departed", 0)) + int(states.get("lodged", 0)) >= 12):
			print("L day=%d states=%s completed=%d guests=%d" % [last_day, str(states), sim.completed_visits, sim.guests.size()])
			break
	var pub_sim = Simulation.new()
	var pub_terrain = preload("res://scripts/terrain_model.gd").new()
	pub_terrain.starter_resort()
	pub_sim.setup(pub_terrain, false, true)
	print("pub0=%.1f aware=%.1f" % [pub_sim.publicity, pub_sim.awareness])
	pub_sim.schedule_event("open_day", 1)
	var pub_day: int = 0
	for day2 in range(120):
		pub_day = day2
		pub_sim.tick(800.0)
		if not pub_sim.event_history.is_empty():
			break
	print("pub_event=%.1f aware=%.1f day=%d status=%s" % [pub_sim.publicity, pub_sim.awareness, pub_day, str((pub_sim.event_history[0] as Dictionary).get("status", "-")) if not pub_sim.event_history.is_empty() else "-"])
	quit()
