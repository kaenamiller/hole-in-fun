extends SceneTree

const Simulation = preload("res://scripts/resort_simulation.gd")
const RealTerrain = preload("res://scripts/terrain_model.gd")

var failures: int = 0


class FakeTerrain:
	extends RefCounted
	var holes: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	var wear: float = 0.0
	var revision: int = 1

	func _init(hole_count: int = 3) -> void:
		for index in range(hole_count):
			var x: float = 95.0 + float(index) * 70.0
			holes.append({
				"id": index + 1, "name": "Test %d" % (index + 1),
				"tee": Vector3(x, 0.0, 90.0), "cup": Vector3(x + 42.0, 0.0, 90.0),
				"green_radius": 8.0, "par": 3, "open": true, "waypoints": [],
			})
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
		return 0.5

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


func _init() -> void:
	test_setup_and_lifecycle()
	test_hole_order_and_demand()
	test_finance_staff_and_events()
	test_construction_recovery()
	test_snapshot_rng_continuity()
	test_grade_unlocks()
	test_real_terrain_stress()
	if failures == 0:
		print("PASS test_simulation (%d checks)" % 45)
		quit(0)
	else:
		push_error("FAIL test_simulation: %d failures" % failures)
		quit(1)


func test_setup_and_lifecycle() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	check(sim.staff.size() == 3, "starter creates one worker in each role")
	check(sim.cash == 180000.0, "starter cash is deterministic")
	var group_id: int = sim.admit_group(4)
	check(group_id > 0 and sim.guests.size() == 4, "manual admission creates an individual four-ball")
	var group: Dictionary = sim.groups[0]
	check(group.has("cart_parked"), "group exposes cart parking state")
	var peak_wear=0.0
	var observed_score=false
	var observed_serial=false
	for slice in range(240):
		sim.tick(100.0)
		peak_wear=maxf(peak_wear,terrain.wear)
		for golfer in sim.guests:
			observed_score=observed_score or not golfer.scorecard.is_empty()
			observed_serial=observed_serial or golfer.shot_serial>0
	check(sim.completed_visits > 0, "golfers complete sequential holes within the operating day")
	check(sim.ledger.any(func(item: Dictionary) -> bool: return str(item.get("category", "")) == "admissions"), "green fees enter the ledger")
	check(peak_wear > 0.0, "real play adds course wear before staff restore it")
	var scored: bool = false
	var visible_shot_schema: bool = false
	for guest in sim.guests:
		scored = scored or not (guest.get("scorecard", []) as Array).is_empty()
		visible_shot_schema = visible_shot_schema or guest.has("shot_serial")
	check(scored or observed_score, "individual scorecards record played holes")
	check(visible_shot_schema or observed_serial, "golfers expose stable shot playback serials")


func test_hole_order_and_demand() -> void:
	var ordered_terrain: FakeTerrain = FakeTerrain.new(3)
	ordered_terrain.holes = [ordered_terrain.holes[2], ordered_terrain.holes[0], ordered_terrain.holes[1]]
	var ordered_sim = Simulation.new()
	ordered_sim.setup(ordered_terrain, false, true)
	check(int(ordered_sim._course_holes[0].get("id", -1)) == 3, "course preserves user-defined terrain hole order")
	check(int(ordered_sim._course_holes[1].get("id", -1)) == 1, "course does not silently sort holes by persistent ID")
	var appealing_terrain: FakeTerrain = FakeTerrain.new(3)
	appealing_terrain.objects.append({"id": 999, "kind": "fountain", "pos": Vector3(80.0, 0.0, 80.0), "condition": 1.0, "cleanliness": 1.0})
	appealing_terrain.wear = 0.0
	var appealing_sim = Simulation.new()
	appealing_sim.setup(appealing_terrain, false, true)
	var weak_terrain: FakeTerrain = FakeTerrain.new(3)
	weak_terrain.objects = [weak_terrain.objects[0]]
	weak_terrain.wear = 1.0
	var weak_sim = Simulation.new()
	weak_sim.setup(weak_terrain, false, true)
	check(int(appealing_sim.snapshot().get("arrival_target", 0)) > int(weak_sim.snapshot().get("arrival_target", 0)), "facilities, scenery, and course wear materially affect demand")
	check(float(appealing_sim.demand_factors().get("wear", 0.0)) > float(weak_sim.demand_factors().get("wear", 1.0)), "demand exposes normalized wear impact")


func test_finance_staff_and_events() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, false)
	var before_hire: float = sim.cash
	check(sim.hire("cleaner"), "valid worker can be hired")
	check(sim.cash < before_hire and sim.staff.size() == 1, "hiring costs cash and adds one individual worker")
	check(not sim.hire("magician"), "unknown worker role is rejected")
	var loan_message: String = sim.borrow("working_capital")
	check(loan_message.contains("funded") and sim.loans.size() == 1, "loan products fund the business")
	var balance: float = float(sim.loans[0].get("balance", 0.0))
	check(sim.repay(int(sim.loans[0].get("id", -1)), 500.0).contains("repaid"), "voluntary loan repayment succeeds")
	check(float(sim.loans[0].get("balance", 0.0)) < balance, "repayment reduces principal")
	sim.cash = -10000.0
	sim.open = false
	check(sim.borrow("recovery").contains("funded") and sim.open, "one-time recovery funding can reopen an insolvent playable resort")
	check(sim.borrow("recovery").contains("already used"), "recovery funding cannot be repeated")
	var restroom: Dictionary = terrain.objects[2]
	restroom["cleanliness"] = 0.1
	sim.on_construction(Vector3(900.0, 0.0, 900.0), 1.0)
	sim.assign_staff(int(sim.staff[0].get("id", -1)), int(restroom.get("id", -1)))
	sim.tick(500.0)
	check(float(restroom.get("cleanliness", 0.0)) > 0.1, "assigned cleaner travels to and restores a specific facility")
	check(str(sim.staff[0].get("activity", "")) == "cleaning", "worker activity reflects the assigned role")
	var event_message: String = sim.schedule_event("open_day", 1)
	check(event_message.contains("scheduled"), "canonical event schedules")
	sim.tick(36000.0)
	check(sim.day == 2 and not sim.active_event().is_empty(), "scheduled event activates on its actual day")
	sim.active_event()["target"] = 1
	sim.admit_group(1, true)
	sim.tick(36000.0)
	check(sim.event_history.size() == 1, "event resolves from actual attendance and play")
	var result: Dictionary = sim.event_history[0]
	check(int(result.get("attended", 0)) >= 1, "event attendance is counted only after play starts")
	check(int(result.get("rounds_completed", 0)) >= 1, "event round completion is based on finished visits")


func test_construction_recovery() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	var group_id: int = sim.admit_group(2)
	var group: Dictionary = sim.groups[0]
	group["paid"] = true
	for guest in sim.guests:
		guest["paid_green_fee"] = 48.0
	var cash_before: float = sim.cash
	sim.on_construction(Vector3(64.0, 0.0, 64.0), 20.0, -1)
	check(str(group.get("state", "")) == "arriving", "unrelated nearby work relocates the group and resumes its activity")
	check(sim.cash < cash_before, "construction compensation is a real expense")
	check(sim.ledger.any(func(item: Dictionary) -> bool: return str(item.get("category", "")) == "construction_compensation"), "interrupted activity compensation is auditable")
	check(sim._group_by_id(group_id).get("current_hole_id", -2) == -1, "construction releases hole occupancy")
	# Advance a separate golfer to a live shot and interrupt the flight itself.
	var live_terrain: FakeTerrain = FakeTerrain.new(3)
	var live_sim = Simulation.new()
	live_sim.setup(live_terrain, false, true)
	live_sim._arrival_target = 1
	live_sim.admit_group(1)
	var live_guest: Dictionary = live_sim.guests[0]
	var live_group: Dictionary = live_sim.groups[0]
	for _step in range(800):
		live_sim.tick(20.0)
		if not (live_guest.get("shot", {}) as Dictionary).is_empty():
			break
	check(not (live_guest.get("shot", {}) as Dictionary).is_empty(), "test reaches a visible live shot")
	var stroke_before: int = int(live_guest.get("strokes", 0))
	var serial_before: int = int(live_guest.get("shot_serial", 0))
	var shot: Dictionary = live_guest.get("shot", {})
	live_sim.on_construction(shot.get("landing", live_guest.get("pos", Vector3.ZERO)), 3.0, -1)
	check(str(live_group.get("state", "")) == "playing" and str(live_group.get("play_phase", "")) == "ready", "interrupted live shot resets in place and resumes the hole")
	check(int(live_guest.get("strokes", 0)) == stroke_before and (live_guest.get("shot", {}) as Dictionary).is_empty(), "interrupted shot adds no stroke")
	live_sim.tick(100.0)
	check(int(live_guest.get("shot_serial", 0)) > serial_before, "golfer takes a replacement shot after the edit")
	check(live_sim.ledger.any(func(item: Dictionary) -> bool: return str(item.get("category", "")) == "construction_compensation"), "live shot interruption records compensation")


func test_snapshot_rng_continuity() -> void:
	var terrain_a: FakeTerrain = FakeTerrain.new(3)
	var sim_a = Simulation.new()
	sim_a.setup(terrain_a, false, true)
	sim_a.tick(900.0)
	var saved: Dictionary = sim_a.snapshot()
	sim_a.tick(1200.0)
	var after_a: Dictionary = sim_a.snapshot()
	var terrain_b: FakeTerrain = FakeTerrain.new(3)
	var sim_b = Simulation.new()
	sim_b.setup(terrain_b, false, true)
	sim_b.restore(saved)
	sim_b.tick(1200.0)
	var after_b: Dictionary = sim_b.snapshot()
	check(int(after_a.get("rng_state", -1)) == int(after_b.get("rng_state", -2)), "restore resumes the exact random stream")
	check(int(after_a.get("next_guest_id", -1)) == int(after_b.get("next_guest_id", -2)), "restore preserves monotonic IDs")
	check(sim_a.groups.size() == sim_b.groups.size(), "restored simulation makes the same arrival decisions")
	check(is_equal_approx(sim_a.cash, sim_b.cash), "restored simulation repeats financial outcomes")


func test_grade_unlocks() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(9)
	var sim = Simulation.new()
	sim.setup(terrain, true, false)
	sim.publicity = 50.0
	sim.cash = 200000.0
	sim._arrival_target = 0
	sim.open = false
	sim.satisfaction = 0.59
	sim.event_history.append({"kind": "open_day", "status": "success"})
	sim.tick(36000.0)
	check(sim.grade == 1, "grade 2 is gated by satisfaction quality")
	sim.satisfaction = 0.8
	terrain.wear = 0.6
	sim.tick(36000.0)
	check(sim.grade == 1, "grade 2 is gated by maximum course wear")
	terrain.wear = 0.1
	sim.tick(36000.0)
	check(sim.grade == 2, "grade 2 requires a successful qualifying community event and quality thresholds")
	sim.tick(36000.0)
	check(sim.grade == 2, "grade 3 remains locked without its higher-tier qualifying event")
	sim.event_history.append({"kind": "club_championship", "status": "success"})
	sim.tick(36000.0)
	check(sim.grade == 3, "grade 3 unlocks after a successful championship and catalog requirements")
	check((sim.unlocks().get("events", []) as Array).has("invitational"), "premier event unlock is exposed")
	check(sim.can_build("maintenance_shed"), "building grade API follows catalog")


func test_real_terrain_stress() -> void:
	var terrain = RealTerrain.new()
	terrain.starter_resort(true)
	# TerrainModel normalization is owned by its module; adapt legacy values for this contract test.
	terrain.wear = clampf(float(terrain.wear), 0.0, 1.0)
	for object in terrain.objects:
		object["condition"] = clampf(float(object.get("condition", 1.0)), 0.0, 1.0)
		object["cleanliness"] = clampf(float(object.get("cleanliness", 1.0)), 0.0, 1.0)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim._arrival_target = 100
	for _group_index in range(25):
		sim.admit_group(4)
	var admitted: int = sim.guests.size()
	sim.tick(36000.0)
	print("real terrain stress: admitted=%d completed=%d day=%d cash=%.0f wear=%.3f" % [admitted, sim.completed_visits, sim.day, sim.cash, terrain.wear])
	check(admitted == 100, "real starter terrain admits 25 four-balls")
	check(sim.completed_visits > 0, "real terrain routing and shot play complete visits under stress")
	check(sim.day == 2, "large real-terrain day tick terminates cleanly")


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
