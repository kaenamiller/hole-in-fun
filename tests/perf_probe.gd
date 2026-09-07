extends SceneTree
const Simulation = preload("res://scripts/resort_simulation.gd")
class FakeTerrain:
	extends RefCounted
	var holes: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	var wear: float = 0.0
	var revision: int = 1
	func _init(hole_count: int = 3) -> void:
		for index in range(hole_count):
			holes.append({"id": index + 1, "name": "T%d" % index, "tee": Vector3(95.0 + index * 70.0, 0.0, 90.0), "cup": Vector3(137.0 + index * 70.0, 0.0, 90.0), "green_radius": 8.0, "par": 3, "open": true})
		var kinds: Array[String] = ["clubhouse", "driving_range", "restroom", "snack_kiosk", "cart_barn", "maintenance_shed"]
		for index in range(kinds.size()):
			objects.append({"id": 100 + index, "kind": kinds[index], "pos": Vector3(72.0 + index * 8.0, 0.0, 70.0), "rotation": 0.0, "condition": 1.0, "cleanliness": 1.0})
func _init() -> void:
	var sim = Simulation.new()
	sim.setup(FakeTerrain.new(3), false, true)
	sim._arrival_target = 0
	var t0: int = Time.get_ticks_msec()
	sim.tick(1000.0)
	var with_staff: int = Time.get_ticks_msec() - t0
	sim.staff.clear()
	t0 = Time.get_ticks_msec()
	sim.tick(1000.0)
	var no_staff: int = Time.get_ticks_msec() - t0
	print("with_staff=%dms no_staff=%dms staff_delta=%dms" % [with_staff, no_staff, with_staff - no_staff])
	quit()
