extends SceneTree
const Simulation = preload("res://scripts/resort_simulation.gd")
func _init() -> void:
	var sim = Simulation.new()
	var terrain = preload("res://scripts/terrain_model.gd").new()
	terrain.starter_resort()
	sim.setup(terrain, false, true)
	print("sched: %s" % sim.schedule_event("open_day", 1))
	for day in range(75):
		sim.tick(800.0)
		if day in [29, 35, 42, 49, 55, 60, 74]:
			var ev: Dictionary = sim.active_event()
			var event_guests: int = 0
			for guest in sim.guests:
				var group: Dictionary = sim._group_by_id(int(guest.get("group_id", -1)))
				if int(group.get("event_id", -1)) >= 0:
					event_guests += 1
			print("day=%d status=%s attended=%s completed=%s history=%d result=%s" % [day, str((sim.scheduled_events[0] as Dictionary).get("status", "?")), str((sim.scheduled_events[0] as Dictionary).get("attended", -1)), (sim.scheduled_events[0] as Dictionary).get("rounds_completed", -1), sim.event_history.size(), str((sim.event_history[0] as Dictionary).get("status", "-")) if not sim.event_history.is_empty() else "-"])
	quit()
