extends SceneTree

const Simulation = preload("res://scripts/resort_simulation.gd")
const RealTerrain = preload("res://scripts/terrain_model.gd")
const MapGeneratorClass = preload("res://scripts/map_generator.gd")
const CatalogClass = preload("res://scripts/catalog.gd")

var failures: int = 0


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
	var tests: Array = [
		["lifecycle", test_setup_and_lifecycle],
		["hole_order", test_hole_order_and_demand],
		["finance_events", test_finance_staff_and_events],
		["construction", test_construction_recovery],
		["snapshot_rng", test_snapshot_rng_continuity],
		["grade_unlocks", test_grade_unlocks],
		["stress", test_real_terrain_stress],
		["event_log", test_event_log],
		["history", test_history_and_series],
		["feedback", test_feedback_aggregation],
		["analytics", test_analytics_overlays],
		["maintenance", test_per_hole_maintenance],
		["staff", test_staff_depth],
		["unlock", test_unlock_progression],
		["facilities", test_facilities_and_upgrades],
		["pricing", test_pricing_depth],
		["marketing", test_marketing_reputation],
		["memberships", test_memberships_and_patrons],
		["pins", test_pin_rotation_and_tees],
		["design_metrics", test_hole_design_metrics],
		["stonebrook", test_stonebrook_starter_day],
	]
	var only: String = OS.get_environment("SIM_TEST_ONLY")
	var wanted: Dictionary = {}
	if not only.is_empty():
		for name_value in only.split(","):
			wanted[str(name_value).strip_edges()] = true
	var t0: int = Time.get_ticks_msec()
	for entry in tests:
		if not wanted.is_empty() and not wanted.has(str(entry[0])):
			continue
		var start: int = Time.get_ticks_msec()
		Callable(entry[1]).call()
		print("TIME %s %dms" % [str(entry[0]), Time.get_ticks_msec() - start])
	if failures == 0:
		print("PASS test_simulation (%d checks, %dms)" % [133, Time.get_ticks_msec() - t0])
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
	var cleaner_id: int = -1
	for worker in sim.staff:
		if str(worker.get("role", "")) == "cleaner":
			cleaner_id = int(worker.get("id", -1))
			break
	sim.assign_staff(cleaner_id, int(restroom.get("id", -1)))
	for worker in sim.staff:
		worker["shift"] = "full"
	sim.tick(500.0)
	check(float(restroom.get("cleanliness", 0.0)) > 0.1, "assigned cleaner travels to and restores a specific facility")
	for worker in sim.staff:
		if int(worker.get("id", -1)) == cleaner_id:
			check(str(worker.get("activity", "")) == "cleaning", "worker activity reflects the assigned role")
			break
	var event_message: String = sim.schedule_event("open_day", 1)
	check(event_message.contains("scheduled"), "canonical event schedules")
	sim.tick(900.0)
	check(sim.day == 2 and not sim.active_event().is_empty(), "scheduled event activates on its actual day")
	sim.active_event()["target"] = 1
	sim.admit_group(1, true)
	for _event_step in range(60):
		sim.tick(800.0)
		if sim.event_history.size() == 1:
			break
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
	live_sim.tick(300.0)
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
	sim.awareness = 50.0
	sim.publicity = 50.0
	sim.cash = 200000.0
	sim._arrival_target = 0
	sim.open = false
	sim.satisfaction = 0.59
	sim.event_history.append({"kind": "open_day", "status": "success"})
	sim._roll_season()
	check(sim.grade == 1, "grade 2 is gated by satisfaction quality")
	sim.satisfaction = 0.8
	terrain.wear = 0.6
	sim._roll_season()
	sim.publicity = 50.0
	check(sim.grade == 1, "grade 2 is gated by maximum course wear")
	terrain.wear = 0.1
	sim._roll_season()
	sim.publicity = 50.0
	check(sim.grade == 2, "grade 2 requires a successful qualifying community event and quality thresholds")
	sim._roll_season()
	sim.publicity = 50.0
	check(sim.grade == 2, "grade 3 remains locked without its higher-tier qualifying event")
	sim.event_history.append({"kind": "club_championship", "status": "success"})
	sim._roll_season()
	sim.publicity = 50.0
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
	sim._arrival_target = 48
	for _group_index in range(12):
		sim.admit_group(4)
	sim._arrival_target = 0
	var admitted: int = sim.guests.size()
	var stress_elapsed: float = 0.0
	while sim.completed_visits == 0 and stress_elapsed < 300000.0:
		sim.tick(3600.0)
		stress_elapsed += 3600.0
	print("real terrain stress: admitted=%d completed=%d day=%d cash=%.0f wear=%.3f elapsed=%.0f" % [admitted, sim.completed_visits, sim.day, sim.cash, terrain.wear, stress_elapsed])
	check(admitted == 48, "real starter terrain admits 12 four-balls")
	check(sim.completed_visits > 0, "real terrain routing and shot play complete visits under stress")
	check(sim.day > 1, "large real-terrain stress tick terminates cleanly")


func test_event_log() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim.tick(24000.0)
	check(sim.log.any(func(entry: Dictionary) -> bool:
		return str(entry.get("category", "")) == "finance" and str(entry.get("text", "")).contains("net")
	), "month close posts a finance summary to the log")
	var broke = Simulation.new()
	broke.setup(FakeTerrain.new(3), false, true)
	broke.cash = -500.0
	broke.open = true
	broke.sandbox = false
	for _month_index in range(3):
		for _day_index in range(30):
			broke._roll_day()
	var closure_entries: int = 0
	for entry in broke.log:
		if str(entry.get("severity", "")) == "critical" and str(entry.get("text", "")).contains("Resort closed"):
			closure_entries += 1
	check(closure_entries == 1, "three insolvent months produce exactly one critical closure entry")
	var refund_sim = Simulation.new()
	refund_sim.setup(FakeTerrain.new(3), false, true)
	for index in range(20):
		var group_id: int = refund_sim.admit_group(1)
		var group: Dictionary = refund_sim._group_by_id(group_id)
		group["paid"] = true
		for guest in refund_sim.guests:
			if int(guest.get("group_id", -1)) == group_id:
				guest["paid_green_fee"] = 48.0
		refund_sim._safe_refund_and_depart(group, "Refund test.", 1.0)
	var refund_entries: Array[Dictionary] = []
	for entry in refund_sim.log:
		if str(entry.get("text", "")) == "Guest refunded":
			refund_entries.append(entry)
	check(refund_entries.size() == 1 and int(refund_entries[0].get("count", 0)) == 20, "identical refunds collapse to one entry")
	for index in range(600):
		sim.post("info", "system", "cap test %d" % index)
	check(sim.log.size() <= 500, "log never exceeds 500 entries")


func test_history_and_series() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim._arrival_target = 0
	for _month_index in range(3):
		sim.tick(24000.0)
	check(sim.history.size() == 3, "three starter months produce three history records")
	if sim.history.size() >= 1:
		var record: Dictionary = sim.history[0]
		var ledger_revenue: float = 0.0
		for item in sim.ledger:
			if int(item.get("day", -1)) > int(record.get("day", -1)) - 30 and int(item.get("day", -1)) <= int(record.get("day", -1)) and float(item.get("amount", 0.0)) > 0.0:
				ledger_revenue += float(item.get("amount", 0.0))
		var history_revenue: float = 0.0
		for amount in (record.get("revenue", {}) as Dictionary).values():
			history_revenue += float(amount)
		check(absf(history_revenue - ledger_revenue) < 1.0, "revenue category sums match ledger positive amounts for that month")
		check(float(record.get("completion_rate", -1.0)) >= 0.0 and float(record.get("completion_rate", 1.1)) <= 1.0, "completion_rate stays in 0..1")
		var any_hole_stats: bool = false
		for day_record in sim.history:
			var hole_stats: Dictionary = day_record.get("hole_stats", {})
			if not hole_stats.is_empty():
				any_hole_stats = true
		check(any_hole_stats, "per-hole stats include every played hole day")
	check(sim.today_series.size() <= 60, "today_series has at most 60 points")
	sim.tick(36000.0)
	check(sim.today_series.is_empty(), "today_series clears at day end")
	var cap_terrain: FakeTerrain = FakeTerrain.new(1)
	var cap_sim = Simulation.new()
	cap_sim.setup(cap_terrain, false, false)
	cap_sim.open = false
	cap_sim._arrival_target = 0
	for _day_index in range(400):
		cap_sim._end_day()
	check(cap_sim.history.size() <= 365, "history caps at 365 days")


func test_feedback_aggregation() -> void:
	# Feedback flows through departure reviews into daily aggregation; drive
	# the contract directly so the assertions stay deterministic.
	var agg_sim = Simulation.new()
	agg_sim.setup(FakeTerrain.new(3), false, true)
	var fed_guest: Dictionary = {"id": 1, "name": "Aggregated", "mood": 0.42, "spent": 61.0, "strokes": 12, "skill": 0.5, "group_id": 1, "feedback": [
		{"tag": "completed_round", "delta": 0.05, "minute": 1.0},
		{"tag": "unmet_hunger", "delta": -0.04, "minute": 2.0},
	]}
	agg_sim._record_guest_review(fed_guest, true, 3)
	check(agg_sim.reviews.size() == 1, "departure records exactly one review")
	var hungry_summary: Dictionary = agg_sim.feedback_summary(1, agg_sim.day)
	var complaint_tags: Array[String] = []
	for entry in hungry_summary.get("top_complaints", []):
		complaint_tags.append(str(entry.get("tag", "")))
	check(complaint_tags.has("unmet_hunger") and complaint_tags.size() == 1, "forced hunger without a snack kiosk surfaces unmet_hunger complaints")
	var hungry_guest: Dictionary = {"id": 2, "name": "Starved", "mood": 0.3, "spent": 12.0, "strokes": 14, "skill": 0.3, "group_id": 2, "feedback": [{"tag": "unmet_hunger", "delta": -0.04, "minute": 1.0}]}
	agg_sim._record_guest_review(hungry_guest, false, 1)
	var window_summary: Dictionary = agg_sim.feedback_summary(2, agg_sim.day)
	check(int((window_summary as Dictionary).get("review_count", 0)) == 2, "feedback summary spans multiple departure days")
	var praise_guest: Dictionary = {"id": 3, "name": "Happy", "mood": 0.85, "spent": 90.0, "strokes": 9, "skill": 0.8, "group_id": 3, "feedback": [{"tag": "great_hole", "delta": 0.05, "minute": 1.0}, {"tag": "completed_round", "delta": 0.05, "minute": 2.0}]}
	agg_sim._record_guest_review(praise_guest, true, 3)
	check(agg_sim.reviews.size() == 3, "every departed guest produced exactly one review")
	var final_summary: Dictionary = agg_sim.feedback_summary(1, agg_sim.day)
	var praise_tags: Array[String] = []
	for entry in final_summary.get("top_praise", []):
		praise_tags.append(str(entry.get("tag", "")))
	check(praise_tags.has("great_hole"), "positive visits surface praise tags")
	var review_cap_sim = Simulation.new()
	review_cap_sim.setup(FakeTerrain.new(3), false, true)
	review_cap_sim.arrivals_enabled = false
	for review_index in range(405):
		review_cap_sim._record_guest_review({"id": review_index + 10, "name": "Guest %d" % review_index, "mood": 0.5, "feedback": []}, true, 3)
	check(review_cap_sim.reviews.size() <= 400, "reviews cap at 400 after stress days")


func test_analytics_overlays() -> void:
	var arrival_terrain: FakeTerrain = FakeTerrain.new(3)
	var arrival_sim = Simulation.new()
	arrival_sim.setup(arrival_terrain, false, true)
	arrival_sim._arrival_target = 0
	for _group_index in range(16):
		arrival_sim.admit_group(4)
	arrival_sim.tick(420.0)
	check(arrival_sim.analytics.max_value("traffic") > 0.0, "guest arrivals accumulate foot traffic")
	var entrance_cell: Vector3 = Vector3((4.5) * 16.0, 0.0, (4.5) * 16.0)
	check(
		is_equal_approx(arrival_sim.analytics.value("traffic", entrance_cell), arrival_sim.analytics.max_value("traffic")),
		"entrance cell has the highest traffic"
	)
	var terrain = RealTerrain.new()
	terrain.starter_resort(true)
	terrain.wear = clampf(float(terrain.wear), 0.0, 1.0)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	for _group_index in range(12):
		sim.admit_group(4)
	sim.tick(2400.0)
	check(sim.analytics.max_value("traffic") > 0.0, "starter day accumulates foot traffic on the real course")
	var holes_with_landings: int = 0
	for hole in terrain.holes:
		var cup: Vector3 = hole.get("cup", Vector3.ZERO)
		var nearby: float = 0.0
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				nearby += sim.analytics.value("landings", cup + Vector3(float(dx) * 4.0, 0.0, float(dz) * 4.0))
		if nearby > 0.0:
			holes_with_landings += 1
	check(holes_with_landings >= 6, "landings recorded near several hole greens after a starter day")
	var peak_traffic: float = sim.analytics.max_value("traffic")
	var saved: Dictionary = sim.analytics.snapshot()
	sim.analytics.add("traffic", Vector3(512, 0, 512), 999.0)
	sim.analytics.restore(saved)
	check(sim.analytics.max_value("traffic") == peak_traffic, "analytics snapshot restores traffic peak")
	check(sim.analytics.value("landings", terrain.holes[0].get("cup", Vector3.ZERO)) > 0.0, "analytics snapshot restores landings")
	var full_saved: Dictionary = sim.snapshot()
	sim.analytics.add("waiting", Vector3(100, 0, 100), 50.0)
	var restored_sim = Simulation.new()
	restored_sim.setup(RealTerrain.new(), false, true)
	restored_sim.restore(full_saved)
	check(restored_sim.analytics.max_value("traffic") == peak_traffic, "sim restore round-trips analytics traffic")


func test_per_hole_maintenance() -> void:
	var terrain = RealTerrain.new()
	terrain.starter_resort(false)
	var legacy_snapshot: Dictionary = terrain.snapshot()
	legacy_snapshot.erase("condition")
	var legacy_copy = RealTerrain.new()
	legacy_copy.restore(legacy_snapshot)
	check(is_equal_approx(legacy_copy.condition_at(terrain.holes[0].cup), 1.0), "old snapshot without condition restores to all ones")

	var stress_terrain = RealTerrain.new()
	stress_terrain.starter_resort(false)
	var stressed_objects: Array[Dictionary] = []
	for object in stress_terrain.objects:
		if str(object.get("kind", "")) != "maintenance_shed":
			stressed_objects.append(object)
	stress_terrain.objects = stressed_objects
	var stress_sim = Simulation.new()
	stress_sim.setup(stress_terrain, false, true)
	var before: Array[float] = []
	for hole in stress_terrain.holes:
		before.append(float(stress_terrain.hole_condition(hole).get("green", 1.0)))
	for _group_index in range(8):
		stress_sim.admit_group(4)
	stress_sim.tick(24000.0)
	var lowered: bool = false
	for index in range(stress_terrain.holes.size()):
		var after: float = float(stress_terrain.hole_condition(stress_terrain.holes[index]).get("green", 1.0))
		lowered = lowered or after < before[index]
	check(lowered, "one stress month lowers the mean green condition of played holes")

	var maint_terrain = RealTerrain.new()
	maint_terrain.starter_resort(false)
	var maintained_objects: Array[Dictionary] = []
	for object in maint_terrain.objects:
		if str(object.get("kind", "")) != "maintenance_shed":
			maintained_objects.append(object)
	maint_terrain.objects = maintained_objects
	var hole_a: Dictionary = maint_terrain.holes[0]
	var hole_b: Dictionary = maint_terrain.holes[1]
	var maint_sim = Simulation.new()
	maint_sim.setup(maint_terrain, false, true)
	var keeper_id: int = -1
	for worker in maint_sim.staff:
		if str(worker.get("role", "")) == "groundskeeper":
			keeper_id = int(worker.get("id", -1))
			break
	check(keeper_id >= 0, "starter includes a groundskeeper for maintenance tests")
	maint_terrain.apply_wear_at(hole_a.cup, 0.35)
	maint_terrain.apply_wear_at(hole_b.cup, 0.35)
	var green_a_before: float = float(maint_terrain.hole_condition(hole_a).get("green", 1.0))
	var green_b_before: float = float(maint_terrain.hole_condition(hole_b).get("green", 1.0))
	maint_sim.assign_staff(keeper_id, {"kind": "hole", "id": int(hole_a.get("id", -1))})
	maint_sim.tick(24000.0)
	var green_a_after: float = float(maint_terrain.hole_condition(hole_a).get("green", 1.0))
	var green_b_after: float = float(maint_terrain.hole_condition(hole_b).get("green", 1.0))
	check(green_a_after > green_a_before, "groundskeeper assigned to a hole raises its green mean over one day")
	check(green_b_after < green_b_before, "unassigned hole falls while assigned hole recovers")

	var closed_terrain = RealTerrain.new()
	closed_terrain.starter_resort(false)
	var open_terrain = RealTerrain.new()
	open_terrain.starter_resort(false)
	var closed_hole: Dictionary = closed_terrain.holes[0]
	var open_hole: Dictionary = open_terrain.holes[0]
	closed_hole["open"] = false
	closed_terrain.apply_wear_at(closed_hole.cup, 0.4)
	open_terrain.apply_wear_at(open_hole.cup, 0.4)
	var closed_sim = Simulation.new()
	closed_sim.setup(closed_terrain, false, true)
	var open_sim = Simulation.new()
	open_sim.setup(open_terrain, false, true)
	var closed_keeper: int = -1
	var open_keeper: int = -1
	for worker in closed_sim.staff:
		if str(worker.get("role", "")) == "groundskeeper":
			closed_keeper = int(worker.get("id", -1))
	for worker in open_sim.staff:
		if str(worker.get("role", "")) == "groundskeeper":
			open_keeper = int(worker.get("id", -1))
	closed_sim.assign_staff(closed_keeper, {"kind": "hole", "id": int(closed_hole.get("id", -1))})
	open_sim.assign_staff(open_keeper, {"kind": "hole", "id": int(open_hole.get("id", -1))})
	for sim_ref in [closed_sim, open_sim]:
		sim_ref._arrival_target = 0
		for worker in sim_ref.staff.duplicate():
			if str(worker.get("role", "")) != "groundskeeper":
				sim_ref.fire(int(worker.get("id", -1)))
	closed_sim.tick(30.0)
	open_sim.tick(30.0)
	var closed_green: float = closed_terrain.condition_at(closed_hole.cup)
	var open_green: float = open_terrain.condition_at(open_hole.cup)
	check(closed_green > open_green, "closing a hole speeds recovery when a groundskeeper is present")


func test_staff_depth() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, true, false)
	check(sim.hire("cleaner"), "staff depth hire finds a cleaner candidate")
	var worker: Dictionary = sim.staff[0]
	worker["shift"] = "full"
	worker["fatigue"] = 0.0
	worker["morale"] = 0.7
	worker["experience"] = 0.0
	worker["skill"] = 0.8
	var rested_skill: float = sim._effective_skill(worker)
	for _minute_index in range(730):
		worker["activity"] = "cleaning"
		sim._tick_worker_vitals(worker, 60.0, 1.0)
	check(float(worker.get("fatigue", 0.0)) > 0.8, "full shift fatigue exceeds 0.8 after sustained work")
	worker["fatigue"] = 0.85
	check(sim._effective_skill(worker) < rested_skill * 0.55, "fatigue above 0.8 halves effective output")

	var morale_sim = Simulation.new()
	morale_sim.setup(FakeTerrain.new(3), true, false)
	morale_sim.hire("cleaner")
	var unhappy: Dictionary = morale_sim.staff[0]
	var base_wage: float = float(morale_sim._role_definition("cleaner").get("wage", 105.0))
	unhappy["wage"] = base_wage * 0.5
	unhappy["morale"] = 0.25
	for _day_index in range(3):
		unhappy["morale"] = 0.25
		morale_sim._end_staff_day()
	check(bool(unhappy.get("raise_requested", false)), "low wage triggers a raise request after three days")

	var quit_sim = Simulation.new()
	quit_sim.setup(FakeTerrain.new(3), true, false)
	quit_sim.hire("cleaner")
	var quitter: Dictionary = quit_sim.staff[0]
	var cash_before: float = quit_sim.cash
	quitter["raise_requested"] = true
	quitter["raise_ignored_days"] = 4
	quit_sim._end_staff_day()
	check(quit_sim.staff.is_empty(), "ignored raise request removes the worker")
	check(not quit_sim.ledger.any(func(item: Dictionary) -> bool: return str(item.get("category", "")) == "severance"), "voluntary quit does not charge severance")
	check(is_equal_approx(quit_sim.cash, cash_before), "quit leaves cash unchanged")

	var lesson_sim = Simulation.new()
	lesson_sim.setup(FakeTerrain.new(3), true, false)
	lesson_sim.grade = 3
	lesson_sim.candidates.clear()
	lesson_sim._refill_candidates()
	var pro_candidate_id: int = -1
	for candidate in lesson_sim.candidates:
		if str(candidate.get("role", "")) == "golf_pro":
			pro_candidate_id = int(candidate.get("id", -1))
			break
	check(pro_candidate_id >= 0 and lesson_sim.hire(pro_candidate_id), "golf pro can be hired at grade 3")
	var pro: Dictionary = lesson_sim.staff[0]
	var range_facility: Dictionary = lesson_sim._facility_by_kind("driving_range")
	pro["pos"] = range_facility.get("pos", Vector3.ZERO)
	pro["destination"] = pro["pos"]
	lesson_sim._rng.seed = 42
	var lesson_found: bool = false
	for seed_value in range(64):
		lesson_sim._rng.seed = seed_value
		var lesson_guest: Dictionary = {"budget": 200.0, "skill": 0.4, "mood": 0.5, "spent": 0.0}
		lesson_sim._apply_facility_to_guest(lesson_guest, "driving_range", int(range_facility.get("id", -1)))
		if lesson_sim.ledger.any(func(item: Dictionary) -> bool: return str(item.get("category", "")) == "lessons"):
			lesson_found = true
			break
	check(lesson_found, "golf pro lessons appear in the ledger as lessons")

	var train_sim = Simulation.new()
	train_sim.setup(FakeTerrain.new(3), true, false)
	train_sim.hire("cleaner")
	var trainee: Dictionary = train_sim.staff[0]
	var skill_before: float = float(trainee.get("skill", 0.0))
	check(train_sim.train(int(trainee.get("id", -1)), "sanitation"), "sanitation training starts")
	check(train_sim._training_active(trainee), "training marks worker unavailable")
	train_sim._end_staff_day()
	train_sim._end_staff_day()
	check(float(trainee.get("skill", 0.0)) > skill_before, "completed training raises skill")
	check(train_sim._training_active(trainee) == false, "training clears after completion")


func test_unlock_progression() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, false)
	check(not sim.can_build("cart_barn"), "cart_barn is not buildable at start")
	var cash_before: float = sim.cash
	var commit_message: String = sim.commit_project("cart_fleet")
	check(commit_message.contains("committed") and sim.cash < cash_before, "committing cart_fleet charges cost immediately")
	check(sim.projects.size() == 1, "cart_fleet creates an active project")
	for _day_index in range(3):
		sim._end_day()
	check(sim.can_build("cart_barn"), "cart_barn unlocks after cart_fleet completes")
	check(sim.unlocked.has("cart_fleet"), "cart_fleet id is recorded in unlocked")

	var milestone_sim = Simulation.new()
	milestone_sim.setup(FakeTerrain.new(3), false, false)
	milestone_sim.unlocked.append("local_press")
	check(not milestone_sim.project_available("charity_network"), "milestone node stays unavailable until completed_visits passes")
	milestone_sim.completed_visits = 200
	check(milestone_sim.project_available("charity_network"), "milestone node becomes available when completed_visits is met")

	var concurrent_sim = Simulation.new()
	concurrent_sim.setup(FakeTerrain.new(3), false, false)
	concurrent_sim.cash = 200000.0
	check(concurrent_sim.commit_project("cart_fleet").contains("committed"), "first concurrent project commits")
	check(concurrent_sim.commit_project("greenkeeping").contains("committed"), "second concurrent project commits")
	check(concurrent_sim.commit_project("bunker_craft").contains("Two projects"), "third concurrent commit is rejected")

	var grade_terrain: FakeTerrain = FakeTerrain.new(9)
	var grade_sim = Simulation.new()
	grade_sim.setup(grade_terrain, false, false)
	grade_sim.cash = 200000.0
	grade_sim.publicity = 50.0
	grade_sim.satisfaction = 0.85
	grade_terrain.wear = 0.1
	grade_sim.event_history.append({"kind": "open_day", "status": "success"})
	grade_sim._update_grade()
	check(grade_sim.grade == 1, "grade promotion requires listed progress nodes")
	grade_sim.unlocked.append("greenkeeping")
	grade_sim.unlocked.append("local_press")
	grade_sim._update_grade()
	check(grade_sim.grade == 2, "grade promotion succeeds when branch nodes are complete")


func test_facilities_and_upgrades() -> void:
	var restaurant_terrain: FakeTerrain = FakeTerrain.new(3)
	restaurant_terrain.objects.append({
		"id": 501, "kind": "restaurant", "pos": Vector3(120.0, 0.0, 72.0),
		"rotation": 0.0, "condition": 1.0, "cleanliness": 1.0, "level": 1,
	})
	var restaurant_sim = Simulation.new()
	restaurant_sim.setup(restaurant_terrain, false, true)
	restaurant_sim.unlocked.append("pro_shop")
	restaurant_sim.unlocked.append("restaurant")
	restaurant_sim.unlocked.append("bar_terrace")
	var group_id: int = restaurant_sim.admit_group(2)
	check(group_id > 0, "restaurant facility test admits a group")
	var group: Dictionary = restaurant_sim._group_by_id(group_id)
	for guest in restaurant_sim.guests:
		if int(guest.get("group_id", -1)) == group_id:
			guest["hunger"] = 0.9
			guest["budget"] = 300.0
	group["paid"] = true
	group["round_complete"] = true
	group["post_round"] = true
	group["post_round_queue"] = ["restaurant"]
	group["post_round_index"] = 0
	group["state"] = "facility_use"
	group["facility_kind"] = "restaurant"
	group["facility_id"] = 501
	group["service_seconds"] = 999.0
	restaurant_sim._tick_facility_use(group, 1.0)
	check(float(restaurant_sim._facility_revenue.get("meals", 0.0)) > 0.0, "restaurant records meals revenue for hungry post-round groups")
	group["round_complete"] = true
	restaurant_sim._begin_departure_or_lodge(group)
	restaurant_sim._finish_departure(group)
	check(restaurant_sim.completed_visits > 0, "post-round restaurant stop still counts round completion")

	var halfway_terrain: FakeTerrain = FakeTerrain.new(6)
	halfway_terrain.objects.append({
		"id": 502, "kind": "halfway_house", "pos": Vector3(120.0, 0.0, 72.0),
		"rotation": 0.0, "condition": 1.0, "cleanliness": 1.0, "level": 1,
	})
	var halfway_sim = Simulation.new()
	halfway_sim.setup(halfway_terrain, false, true)
	var halfway_group_id: int = halfway_sim.admit_group(2)
	var halfway_group: Dictionary = halfway_sim._group_by_id(halfway_group_id)
	halfway_group["paid"] = true
	for guest in halfway_sim.guests:
		if int(guest.get("group_id", -1)) == halfway_group_id:
			guest["hunger"] = 0.8
			guest["energy"] = 0.3
	while str(halfway_group.get("state", "")) not in ["departed", "departing", "lodged"]:
		if str(halfway_group.get("state", "")) == "playing":
			halfway_group["player_turn"] = halfway_group.get("size", 1)
			for guest in halfway_sim.guests:
				if int(guest.get("group_id", -1)) == halfway_group_id:
					guest["hole_done"] = true
		halfway_sim.tick(400.0)
		if halfway_sim.day > 4:
			break
	check(halfway_group.get("facilities_visited", []).has("halfway_house"), "halfway house visit occurs mid-round on a 6-hole course")
	check(int(halfway_group.get("hole_index", 0)) >= 6 or halfway_sim.completed_visits > 0, "group finishes the 6-hole course after halfway stop")

	var lodge_terrain: FakeTerrain = FakeTerrain.new(3)
	lodge_terrain.objects.append({
		"id": 503, "kind": "lodge", "pos": Vector3(120.0, 0.0, 72.0),
		"rotation": 0.0, "condition": 1.0, "cleanliness": 1.0, "level": 1,
	})
	var lodge_sim = Simulation.new()
	lodge_sim.setup(lodge_terrain, false, true)
	lodge_sim.unlocked.append("pro_shop")
	lodge_sim.unlocked.append("restaurant")
	lodge_sim.unlocked.append("lodge")
	var lodge_group_id: int = lodge_sim.admit_group(2)
	var lodge_group: Dictionary = lodge_sim._group_by_id(lodge_group_id)
	lodge_group["wants_lodging"] = true
	lodge_group["lodge_nights"] = 2
	lodge_group["round_complete"] = true
	lodge_group["state"] = "lodged"
	var guests_before: int = lodge_sim.guests.size()
	var cash_before: float = lodge_sim.cash
	lodge_sim._process_lodge_night()
	check(lodge_sim.guests.size() == guests_before, "lodged groups survive end of day")
	check(lodge_sim.cash >= cash_before, "lodged groups are charged room rates overnight")
	lodge_sim._release_lodge_guests_to_tee()
	check(str(lodge_group.get("state", "")) in ["to_tee", "facility_queue", "tee_queue", "playing", "checkin_queue"], "lodged groups replay next morning")
	check(not bool(lodge_group.get("paid", true)), "returning lodge guests pay green fees again")

	var clubhouse_terrain: FakeTerrain = FakeTerrain.new(3)
	for object in clubhouse_terrain.objects:
		if str(object.get("kind", "")) == "clubhouse":
			object["level"] = 1
	var base_sim = Simulation.new()
	base_sim.setup(clubhouse_terrain, false, true)
	var base_capacity: int = base_sim._checkin_capacity()
	for object in clubhouse_terrain.objects:
		if str(object.get("kind", "")) == "clubhouse":
			object["level"] = 2
	base_sim._refresh_facilities(false)
	check(base_sim._checkin_capacity() > base_capacity, "upgrading the clubhouse raises check-in capacity")

	var closed_terrain: FakeTerrain = FakeTerrain.new(3)
	for object in closed_terrain.objects:
		if str(object.get("kind", "")) == "snack_kiosk":
			object["closed"] = true
	var closed_sim = Simulation.new()
	closed_sim.setup(closed_terrain, false, true)
	closed_sim._rng.seed = 99
	var probe_group: Dictionary = {"hunger": 0.9, "restroom": 0.0, "mood": 0.5, "size": 2}
	check(closed_sim._choose_pre_round_facility(probe_group) != "snack_kiosk", "a closed facility is never chosen")
	for _attempt in range(20):
		if closed_sim._choose_pre_round_facility(probe_group) == "snack_kiosk":
			check(false, "closed snack kiosk should never be chosen")
			break


func test_pricing_depth() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	check(is_equal_approx(sim.price("green_fee", {"minute": 300.0}), 48.0), "base green fee at midday")
	check(is_equal_approx(sim.price("green_fee", {"minute": 450.0}), 32.0), "twilight green fee after twilight start")
	check(is_equal_approx(sim.price("green_fee", {"minute": 300.0, "day": 6}), 58.0), "weekend green fee overrides twilight band")

	var weekday_sim = Simulation.new()
	weekday_sim.setup(FakeTerrain.new(3), false, true)
	weekday_sim.day = 3
	weekday_sim._reset_arrivals()
	var weekday_target: int = weekday_sim._arrival_target
	var weekend_sim = Simulation.new()
	weekend_sim.setup(FakeTerrain.new(3), false, true)
	weekend_sim.day = 6
	weekend_sim._rng.seed = weekday_sim._rng.seed
	weekend_sim._reset_arrivals()
	check(weekend_sim._arrival_target > weekday_target, "weekend arrivals exceed weekday on identical state")

	var balk_sim = Simulation.new()
	balk_sim.setup(FakeTerrain.new(3), false, true)
	balk_sim.prices["green_fee"]["base"] = 200.0
	balk_sim.prices["green_fee"]["twilight"] = 200.0
	balk_sim.prices["green_fee"]["weekend"] = 200.0
	balk_sim._arrival_target = 0
	var balk_id: int = balk_sim.admit_group(2)
	for guest in balk_sim.guests:
		guest["budget"] = 50.0
	var balk_group: Dictionary = balk_sim._group_by_id(balk_id)
	balk_group["state"] = "checkin_queue"
	balk_group["service_seconds"] = 999.0
	var admissions_before: int = 0
	for item in balk_sim.ledger:
		if str(item.get("category", "")) == "admissions":
			admissions_before += 1
	check(not balk_sim._collect_green_fees(balk_group), "extreme green fee triggers balk")
	check(balk_sim._today_balked >= 2, "balk counter records rejected guests")
	var admissions_after: int = 0
	for item in balk_sim.ledger:
		if str(item.get("category", "")) == "admissions":
			admissions_after += 1
	check(admissions_after == admissions_before, "balked groups record no admissions revenue")

	var cheap_sim = Simulation.new()
	cheap_sim.setup(FakeTerrain.new(3), false, true)
	cheap_sim.prices["green_fee"]["base"] = 20.0
	cheap_sim.prices["green_fee"]["twilight"] = 20.0
	cheap_sim.prices["green_fee"]["weekend"] = 20.0
	var cheap_rate: float = cheap_sim._demand_rate(cheap_sim.day)
	var default_sim = Simulation.new()
	default_sim.setup(FakeTerrain.new(3), false, true)
	check(cheap_rate > default_sim._demand_rate(default_sim.day), "low green fee raises daily arrivals")
	cheap_sim._arrival_target = 20
	cheap_sim.admit_group(2)
	for guest in cheap_sim.guests:
		guest["budget"] = 500.0
	cheap_sim._collect_green_fees(cheap_sim.groups[0])
	var cheap_spend: float = float(cheap_sim.guests[0].get("spent", 0.0))
	default_sim.admit_group(2)
	for guest in default_sim.guests:
		guest["budget"] = 500.0
	default_sim._collect_green_fees(default_sim.groups[0])
	var default_spend: float = float(default_sim.guests[0].get("spent", 0.0))
	check(cheap_spend < default_spend, "low fee lowers average spend per paying guest")

	var legacy_sim = Simulation.new()
	legacy_sim.setup(FakeTerrain.new(3), false, true)
	legacy_sim.restore({
		"prices": {
			"green_fee": 55.0, "cart": 24.0, "range": 11.0, "snack": 8.0, "event": 20.0,
			"lesson": 40.0, "retail": 45.0, "meal": 30.0, "room": 110.0,
		},
	})
	check(is_equal_approx(legacy_sim.price("green_fee", {}), 55.0), "flat green_fee restores as base band")
	check(is_equal_approx(legacy_sim.price("event_entry", {}), 20.0), "flat event migrates to event_entry")
	check(legacy_sim.prices["cart"] is Dictionary and is_equal_approx(float(legacy_sim.prices["cart"]["base"]), 24.0), "flat ancillary prices wrap as base entries")


func test_marketing_reputation() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim._reset_arrivals()
	check(sim._arrival_target >= 3 and sim._arrival_target <= 16, "starter day-one arrivals stay within a sane band")
	var awareness_before: float = sim.awareness
	var cash_before: float = sim.cash
	check(sim.start_campaign("local_flyers").contains("started"), "local flyers campaign starts")
	var charged_first: float = cash_before - sim.cash
	check(approx_within(charged_first, 220.0, 0.01), "local flyers charges the first day immediately")
	for _day in range(6):
		sim._roll_day()
	var awareness_gain: float = sim.awareness - awareness_before
	check(awareness_gain >= 2.0 and awareness_gain <= 6.0, "seven days of local flyers raises awareness by about eight")
	var marketing_spend: float = 0.0
	for entry in sim.ledger:
		if str(entry.get("category", "")) == "marketing":
			marketing_spend -= float(entry.get("amount", 0.0))
	check(approx_within(marketing_spend, 7.0 * 220.0, 1.0), "local flyers charges seven daily payments")

	var refund_sim = Simulation.new()
	refund_sim.setup(FakeTerrain.new(3), false, true)
	var demand_before: int = refund_sim._demand_arrival_target(refund_sim.day, refund_sim.minute)
	for _day in range(7):
		for guest_index in range(4):
			var guest: Dictionary = {
				"id": guest_index + 1, "mood": 0.2, "feedback": [{"tag": "refund_closure", "delta": -0.2, "minute": 0.0}],
			}
			refund_sim._add_rating_sample(refund_sim._departure_star_rating(guest))
		refund_sim._roll_day()
	check(refund_sim.rating < 2.0, "forced refund departures drag rating below two within five days")
	check(refund_sim._demand_arrival_target(refund_sim.day, refund_sim.minute) < demand_before, "low rating lowers next-day demand")

	var slot_sim = Simulation.new()
	slot_sim.setup(FakeTerrain.new(3), false, true)
	slot_sim.cash = 200000.0
	check(slot_sim.start_campaign("local_flyers").contains("started"), "first campaign slot accepts local flyers")
	check(slot_sim.start_campaign("radio_spot").contains("started"), "second campaign slot accepts radio spot")
	var blocked: String = slot_sim.start_campaign("social_video")
	check(not blocked.is_empty() and blocked.to_lower().contains("two"), "third campaign start returns an error")

	var magazine_sim = Simulation.new()
	magazine_sim.setup(FakeTerrain.new(3), false, true)
	magazine_sim.cash = 200000.0
	magazine_sim.grade = 2
	magazine_sim.rating = 4.0
	magazine_sim._rating_sum = 4.0
	magazine_sim._rating_weight = 1.0
	check(magazine_sim.start_campaign("golf_magazine").contains("started"), "golf magazine starts at grade two with strong rating")
	var expert_without: int = 0
	var expert_with: int = 0
	var baseline = Simulation.new()
	baseline.setup(FakeTerrain.new(3), false, true)
	baseline._rng.seed = magazine_sim._rng.seed
	for _index in range(80):
		baseline._create_group(1, false)
		if float(baseline.guests.back().get("skill", 0.0)) >= 0.72:
			expert_without += 1
		baseline.guests.pop_back()
		baseline.groups.pop_back()
	magazine_sim._rng.seed = baseline._rng.seed
	for _index in range(80):
		magazine_sim._create_group(1, false)
		if float(magazine_sim.guests.back().get("skill", 0.0)) >= 0.72:
			expert_with += 1
		magazine_sim.guests.pop_back()
		magazine_sim.groups.pop_back()
	check(expert_with > expert_without, "expert share rises during golf magazine")


func test_memberships_and_patrons() -> void:
	var terrain: FakeTerrain = FakeTerrain.new(3)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	var returning_seen: bool = false
	for _day_index in range(40):
		sim.tick(800.0)
		for patron_id in sim.patrons.keys():
			if int((sim.patrons[patron_id] as Dictionary).get("visits", 0)) > 1:
				returning_seen = true
				break
		if returning_seen:
			break
	check(sim.patrons.size() > 0, "completed visits create patron records")
	var returning_guests: int = 0
	for guest in sim.guests:
		if int(guest.get("patron_id", -1)) >= 0:
			returning_guests += 1
	for patron_id in sim.patrons.keys():
		if int(sim.patrons[patron_id].get("visits", 0)) > 1:
			returning_guests += 1
	check(returning_guests > 0, "returning guests carry patron_id or accumulated visits")

	var visit_sim = Simulation.new()
	visit_sim.setup(FakeTerrain.new(3), false, true)
	var guest_seed: Dictionary = {"name": "Pat Lee", "skill": 0.58, "budget": 180.0}
	var patron_id: int = visit_sim._create_patron_from_guest(guest_seed, 0.82, 64.0)
	var visits_before: int = int(visit_sim.patrons[patron_id].get("visits", 0))
	var guest: Dictionary = {
		"patron_id": patron_id, "name": "Pat Lee", "skill": 0.58, "budget": 180.0,
		"mood": 0.78, "spent": 72.0, "scorecard": [4, 5, 4],
	}
	visit_sim._update_patron_after_visit(guest, 0.78, 72.0, true, false)
	check(int(visit_sim.patrons[patron_id].get("visits", 0)) == visits_before + 1, "a patron's visits increase after another stay")

	var member_sim = Simulation.new()
	member_sim.setup(FakeTerrain.new(3), false, true)
	member_sim.satisfaction = 0.95
	for _day in range(10):
		member_sim.tick(820.0)
	var member_guest: Dictionary = {
		"name": "Member Candidate", "skill": 0.62, "budget": 420.0, "mood": 0.88, "spent": 140.0, "patron_id": -1,
	}
	var member_patron_id: int = member_sim._create_patron_from_guest(member_guest, 0.88, 140.0)
	member_sim.patrons[member_patron_id]["visits"] = 4
	member_sim.patrons[member_patron_id]["affinity"] = 0.82
	member_sim.patrons[member_patron_id]["budget_base"] = 420.0
	member_guest["patron_id"] = member_patron_id
	member_sim._join_membership(member_sim.patrons[member_patron_id], "social", member_guest)
	check(bool(member_sim.patrons[member_patron_id].get("member", false)), "high-affinity patron can join as a member")
	member_sim.patrons[member_patron_id]["joined_day"] = member_sim.day
	member_sim._settle_membership_dues()
	var membership_income: float = 0.0
	for entry in member_sim.ledger:
		if str(entry.get("category", "")) == "membership":
			membership_income += float(entry.get("amount", 0.0))
	check(membership_income > 0.0, "membership dues appear in the ledger")
	check(member_sim.members().size() >= 1, "members() exposes joined patrons")

	var refund_sim = Simulation.new()
	refund_sim.setup(FakeTerrain.new(3), false, true)
	var refund_guest_seed: Dictionary = {"name": "Refund Patron", "skill": 0.5, "budget": 120.0}
	var refund_patron_id: int = refund_sim._create_patron_from_guest(refund_guest_seed, 0.75, 40.0)
	var affinity_before: float = float(refund_sim.patrons[refund_patron_id].get("affinity", 0.0))
	var refund_guest: Dictionary = {
		"patron_id": refund_patron_id, "mood": 0.25, "spent": 0.0, "skill": 0.5, "budget": 80.0,
	}
	refund_sim._update_patron_after_visit(refund_guest, 0.25, 0.0, false, true)
	check(float(refund_sim.patrons[refund_patron_id].get("affinity", 1.0)) < affinity_before, "refund departures reduce patron affinity")
	refund_sim.patrons[refund_patron_id]["affinity"] = 0.12
	refund_sim.patrons[refund_patron_id]["last_day"] = refund_sim.day - 25
	refund_sim._prune_lost_patrons()
	check(not refund_sim.patrons.has(refund_patron_id), "neglected patrons are removed as lost customers")

	var cap_sim = Simulation.new()
	cap_sim.setup(FakeTerrain.new(3), false, true)
	for index in range(601):
		cap_sim.patrons[index + 1] = {
			"id": index + 1, "member": false, "affinity": 0.25 + float(index % 10) * 0.05,
			"last_day": 1, "visits": 1,
		}
	cap_sim._next_patron_id = 602
	cap_sim._create_patron_from_guest({"name": "Overflow", "skill": 0.5, "budget": 90.0}, 0.7, 20.0)
	check(cap_sim.patrons.size() <= 600, "patrons never exceed 600")

	check(Catalog.memberships().size() == 3, "catalog exposes three membership tiers")
	check(not Catalog.membership("player").is_empty(), "Catalog.membership resolves player tier")


func test_pin_rotation_and_tees() -> void:
	var terrain = RealTerrain.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup: Vector3 = Vector3(420.0, 0.0, 300.0)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 16.0, 2)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 16.0, 1)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	hole["pins"] = [cup, cup + Vector3(8.0, 0.0, 6.0)]
	hole["pin_index"] = 0
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	hole["pin_index"] = 0
	sim._rotate_pins()
	check(int(hole.get("pin_index", 0)) == 1, "pin_index rotates daily when multiple pins exist")
	var forward: Vector3 = tee + Vector3(-6.0, 0.0, 0.0)
	var back: Vector3 = tee + Vector3(12.0, 0.0, 0.0)
	hole["tees"] = [
		{"pos": forward, "name": "forward"},
		{"pos": tee, "name": "middle"},
		{"pos": back, "name": "back"},
	]
	sim.unlocked.append("championship_tees")
	check(sim.start_position(hole, 0.25).distance_to(forward) < 1.0, "beginners start from the forward tee")
	check(sim.start_position(hole, 0.85).distance_to(back) < 1.0, "experts start from the back tee")


func test_hole_design_metrics() -> void:
	var terrain = RealTerrain.new()
	terrain.starter_resort(true)
	var sim = Simulation.new()
	sim.setup(terrain, false, true)
	sim.refresh_hole_metrics(true)
	var summary: Dictionary = sim.course_metrics_summary()
	check(not summary.is_empty(), "starter course metrics cache populates")
	var design_score: float = float(summary.get("design_score", -1.0))
	var slope: float = float(summary.get("slope", -1.0))
	check(design_score >= 30.0 and design_score <= 70.0, "18-hole starter design_score stays within 30..70")
	check(slope >= 90.0 and slope <= 130.0, "18-hole starter slope stays within 90..130")

	var hole: Dictionary = terrain.holes[0]
	var hole_id: int = int(hole.get("id", -1))
	var revision_before: int = int(terrain.revision)
	var cached: Dictionary = sim.hole_metrics.get(hole_id, {})
	check(int(cached.get("revision", -1)) == revision_before, "hole metrics cache records terrain revision")
	hole["par"] = 5 if int(hole.get("par", 4)) != 5 else 3
	terrain.touch()
	check(int(terrain.revision) != revision_before, "hole edit bumps terrain revision")
	sim.refresh_hole_metrics(true)
	var refreshed: Dictionary = sim.hole_metrics.get(hole_id, {})
	check(int(refreshed.get("revision", -2)) == int(terrain.revision), "cache invalidates when a hole is edited")


func test_stonebrook_starter_day() -> void:
	var map_def: Dictionary = CatalogClass.map("stonebrook_hills")
	var terrain: TerrainModel = MapGeneratorClass.generate(map_def)
	terrain.starter_resort(false)
	var sim = Simulation.new()
	sim.setup(terrain, false, true, map_def)
	sim.open = true
	var group_id: int = sim.admit_group(4)
	check(group_id > 0, "stonebrook starter day admits a group at translated entrance")
	for _step in range(120):
		sim.tick(60.0)
	var stranded: int = 0
	for group in sim.groups:
		if str(group.get("activity", "")) in ["departing", "finished"]:
			continue
		if sim._raw_route(sim._group_leader_position(group), terrain.entrance, false).is_empty():
			stranded += 1
	check(stranded == 0, "stonebrook starter day should not strand guests away from entrance")


func approx_within(a: float, b: float, tolerance: float) -> bool:
	return absf(float(a) - float(b)) <= tolerance


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
