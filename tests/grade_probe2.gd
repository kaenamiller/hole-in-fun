extends SceneTree

const Simulation = preload("res://scripts/resort_simulation.gd")

class FakeTerrain:
	extends RefCounted
	var holes: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	var wear: float = 0.0
	func _init(hole_count: int = 9) -> void:
		for index in range(hole_count):
			holes.append({"id": index + 1, "name": "T%d" % index, "tee": Vector3(95.0 + index * 70.0, 0.0, 90.0), "cup": Vector3(137.0 + index * 70.0, 0.0, 90.0), "green_radius": 8.0, "par": 3, "open": true})
		var kinds: Array[String] = ["clubhouse", "driving_range", "restroom", "snack_kiosk", "cart_barn", "maintenance_shed"]
		for index in range(kinds.size()):
			objects.append({"id": 100 + index, "kind": kinds[index], "pos": Vector3(72.0 + index * 8.0, 0.0, 70.0), "rotation": 0.0, "condition": 1.0, "cleanliness": 1.0})
	func course_wear() -> float:
		return wear

func _init() -> void:
	var sim = Simulation.new()
	sim.setup(FakeTerrain.new(9), true, false)
	sim.awareness = 50.0
	sim.publicity = 50.0
	sim.cash = 200000.0
	sim._arrival_target = 0
	sim.open = false
	sim.satisfaction = 0.59
	sim.event_history.append({"kind": "open_day", "status": "success"})
	sim._roll_season()
	print("g1=%d pub=%.1f aware=%.1f" % [sim.grade, sim.publicity, sim.awareness])
	sim.satisfaction = 0.8
	sim.awareness = 50.0
	sim.publicity = 50.0
	sim._roll_season()
	print("g2a=%d" % sim.grade)
	sim.awareness = 50.0
	sim.publicity = 50.0
	sim._roll_season()
	print("g2b=%d pub=%.1f" % [sim.grade, sim.publicity])
	sim._roll_season()
	sim.event_history.append({"kind": "club_championship", "status": "success"})
	sim.awareness = 50.0
	sim.publicity = 50.0
	sim._roll_season()
	print("g3=%d unlocked=%s" % [sim.grade, str(sim.unlocks().get("events", []))])
	quit()
