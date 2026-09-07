extends SceneTree

const Simulation = preload("res://scripts/resort_simulation.gd")


class FakeTerrain:
	extends RefCounted
	var holes: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	var wear: float = 0.0
	var revision: int = 1
	var _green_condition: Dictionary = {}

	func _init(hole_count: int = 3) -> void:
		for index in range(hole_count):
			var x: float = 95.0 + float(index) * 70.0
			var hole_id: int = index + 1
			holes.append({
				"id": hole_id, "name": "Test %d" % hole_id,
				"tee": Vector3(x, 0.0, 90.0), "cup": Vector3(x + 42.0, 0.0, 90.0),
				"green_radius": 8.0, "par": 3, "open": true, "waypoints": [],
			})
			_green_condition[hole_id] = 1.0
		var kinds: Array[String] = ["clubhouse", "driving_range", "restroom", "snack_kiosk", "cart_barn", "maintenance_shed"]
		for index in range(kinds.size()):
			objects.append({
				"id": 100 + index, "kind": kinds[index],
				"pos": Vector3(72.0 + float(index) * 8.0, 0.0, 70.0),
				"rotation": 0.0, "condition": 1.0, "cleanliness": 1.0,
			})

	func height_at(_pos: Vector3) -> float:
		return 0.0

	func surface_at(pos: Vector3) -> int:
		for hole in holes:
			if pos.distance_to(hole.get("cup", Vector3.ZERO)) <= float(hole.get("green_radius", 8.0)):
				return 2
		return 1

	func slope_at(_pos: Vector3) -> Vector2:
		return Vector2.ZERO

	func playable(_pos: Vector3) -> bool:
		return true

	func segment_blocked(_a: Vector3, _b: Vector3) -> bool:
		return false

	func beauty_at(_pos: Vector3) -> float:
		return 50.0

	func route(start: Vector3, finish: Vector3, _cart: bool = false) -> PackedVector3Array:
		return PackedVector3Array([start, finish])

	func nearest_safe(pos: Vector3) -> Vector3:
		return Vector3(clampf(pos.x, 0.0, 1024.0), 0.0, clampf(pos.z, 0.0, 1024.0))

	func ready_holes() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for hole in holes:
			if bool(hole.get("open", true)):
				result.append(hole)
		return result

	func course_wear() -> float:
		return wear

	func condition_at(pos: Vector3) -> float:
		for hole in holes:
			if pos.distance_to(hole.get("cup", Vector3.ZERO)) <= float(hole.get("green_radius", 8.0)):
				return float(_green_condition.get(int(hole.get("id", -1)), 1.0))
		return clampf(1.0 - wear, 0.0, 1.0)

	func apply_wear_at(pos: Vector3, amount: float) -> void:
		wear = clampf(wear + amount * 0.02, 0.0, 1.0)
		for hole in holes:
			if pos.distance_to(hole.get("cup", Vector3.ZERO)) <= float(hole.get("green_radius", 8.0)):
				var hole_id: int = int(hole.get("id", -1))
				_green_condition[hole_id] = clampf(float(_green_condition.get(hole_id, 1.0)) - amount, 0.0, 1.0)

	func restore_condition_at(pos: Vector3, amount: float, neighborhood: int = 0) -> void:
		for hole in holes:
			if pos.distance_to(hole.get("cup", Vector3.ZERO)) <= float(hole.get("green_radius", 8.0)) + float(neighborhood) * 4.0:
				var hole_id: int = int(hole.get("id", -1))
				_green_condition[hole_id] = clampf(float(_green_condition.get(hole_id, 1.0)) + amount, 0.0, 1.0)
		wear = maxf(0.0, wear - amount * 0.01)

	func hole_condition(hole: Dictionary) -> Dictionary:
		var green: float = float(_green_condition.get(int(hole.get("id", -1)), 1.0))
		return {"green": green, "fairway": green, "tee": green, "bunkers": green}

	func refresh_hole_condition_cache(_sim_minute: float) -> void:
		pass

	func worst_cell_for_hole(hole: Dictionary) -> Vector3:
		return Vector3(hole.get("cup", Vector3.ZERO))

	func worst_cell_near(origin: Vector3, _radius: float) -> Vector3:
		return origin

	func overnight_decay(_has_maintenance_shed: bool) -> void:
		wear = clampf(wear + 0.01, 0.0, 1.0)



func _init() -> void:
	var terrain := FakeTerrain.new(3)
	var kept: Array[Dictionary] = []
	for object in FakeTerrain.new(3).objects:
		if str(object.get("kind", "")) != "clubhouse":
			kept.append(object)
	terrain.objects = kept
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim.arrivals_enabled = false
	sim.admit_group(2)
	for day in range(15):
		sim.tick(800.0)
		var st: String = str((sim.groups[0] as Dictionary).get("state", "?"))
		print("N day=%d state=%s completed=%d guests=%d activity=%s" % [day, st, sim.completed_visits, sim.guests.size(), str(sim.guests[0].get("activity", "?")) if not sim.guests.is_empty() else "-"])
		if sim.completed_visits >= 2:
			break
	quit()
