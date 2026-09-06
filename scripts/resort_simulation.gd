class_name ResortSimulation
extends RefCounted

## Data-only resort operations simulation. The scene layer polls these dictionaries.

const OPERATING_MINUTES: float = 600.0
const ENTRANCE: Vector3 = Vector3(64.0, 0.0, 64.0)
const WALK_SPEED: float = 1.8
const CART_SPEED: float = 6.5
const MAX_SUBSTEP: float = 1.0
## Simulated seconds per real second at 1x. Movement speeds and visual
## durations are authored in real-world units and converted with this factor,
## so visible pacing scales directly with the player's speed multiplier.
const SIM_RATE: float = 60.0
## Base visual pace multiplier at 1x. Pure realtime walking is too slow to
## finish rounds within the operating day, so 1x runs ~3x realtime.
const BASE_PACE: float = 3.0
const MAX_STROKES: int = 14
const EVENT_KINDS: Array[String] = [
	"open_day", "charity_scramble", "beginner_clinic", "club_championship",
	"regional_amateur", "invitational"
]
const DEFAULT_ROLES: Dictionary = {
	"groundskeeper": {"name": "Groundskeeper", "wage": 185.0, "grade": 1},
	"service_attendant": {"name": "Service attendant", "wage": 155.0, "grade": 1},
	"cleaner": {"name": "Cleaner", "wage": 145.0, "grade": 1},
}
const DEFAULT_LOANS: Dictionary = {
	"working_capital": {"name": "Working Capital", "principal": 50000.0, "interest": 0.08, "daily_payment": 650.0, "term_days": 90, "grade": 1},
	"equipment_financing": {"name": "Equipment Financing", "principal": 140000.0, "interest": 0.065, "daily_payment": 1250.0, "term_days": 150, "grade": 2},
	"course_expansion": {"name": "Course Expansion", "principal": 400000.0, "interest": 0.055, "daily_payment": 2600.0, "term_days": 240, "grade": 3},
	"recovery": {"name": "Recovery Loan", "principal": 25000.0, "interest": 0.12, "daily_payment": 1650.0, "term_days": 18, "grade": 1},
}
const DEFAULT_EVENTS: Dictionary = {
	"open_day": {"name": "Open Day", "grade": 1, "cost": 900.0, "target": 18, "publicity": 4.0},
	"charity_scramble": {"name": "Charity Scramble", "grade": 1, "cost": 1800.0, "target": 24, "publicity": 7.0},
	"beginner_clinic": {"name": "Beginner Clinic", "grade": 1, "cost": 1200.0, "target": 16, "publicity": 5.0},
	"club_championship": {"name": "Club Championship", "grade": 2, "cost": 4500.0, "target": 32, "publicity": 10.0},
	"regional_amateur": {"name": "Regional Amateur", "grade": 2, "cost": 8500.0, "target": 48, "publicity": 15.0},
	"invitational": {"name": "Invitational", "grade": 3, "cost": 18000.0, "target": 72, "publicity": 24.0},
}

var terrain
var guests: Array[Dictionary] = []
var staff: Array[Dictionary] = []
var groups: Array[Dictionary] = []
var cash: float = 180000.0
var day: int = 1
var minute: float = 0.0
var sandbox: bool = false
var prices: Dictionary = {}
var ledger: Array[Dictionary] = []
var loans: Array[Dictionary] = []
var scheduled_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var grade: int = 1
var publicity: float = 0.0
var open: bool = true
var satisfaction: float = 0.72
var completed_visits: int = 0
var notice: String = ""

var _tick_accumulator: float = 0.0
var _guests_by_group: Dictionary = {}
var _groups_by_id: Dictionary = {}
var _has_departed = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_guest_id: int = 1
var _next_group_id: int = 1
var _next_staff_id: int = 1
var _next_loan_id: int = 1
var _next_event_id: int = 1
var _arrival_target: int = 0
var _arrived_today: int = 0
var _next_arrival_minute: float = 20.0
var _course_holes: Array[Dictionary] = []
var _hole_queues: Dictionary = {}
var _hole_occupancy: Dictionary = {}
var _facility_queues: Dictionary = {}
var _facility_state: Dictionary = {}
var _route_cache: Dictionary = {}
var _route_revision: int = -1
var _today_revenue: float = 0.0
var _today_expense: float = 0.0
var _insolvent_days: int = 0
var _closed_reason: String = ""
var _active_event_id: int = -1
var _catalog_script
var _shot_script


func setup(terrain_ref, sandbox_mode: bool, starter: bool) -> void:
	_guests_by_group.clear()
	_groups_by_id.clear()
	_has_departed=false
	_tick_accumulator=0
	terrain = terrain_ref
	sandbox = sandbox_mode
	cash = 180000.0 if starter else 350000.0
	day = 1
	minute = 0.0
	open = true
	grade = 1
	publicity = 2.0 if starter else 0.0
	satisfaction = 0.72
	completed_visits = 0
	notice = "Resort open"
	prices = {"green_fee": 48.0, "cart": 22.0, "range": 12.0, "snack": 9.0, "event": 18.0}
	guests.clear()
	staff.clear()
	groups.clear()
	ledger.clear()
	loans.clear()
	scheduled_events.clear()
	event_history.clear()
	_hole_queues.clear()
	_hole_occupancy.clear()
	_facility_queues.clear()
	_facility_state.clear()
	_route_cache.clear()
	_next_guest_id = 1
	_next_group_id = 1
	_next_staff_id = 1
	_next_loan_id = 1
	_next_event_id = 1
	_rng.seed = 730241
	_catalog_script = load("res://scripts/catalog.gd") if ResourceLoader.exists("res://scripts/catalog.gd") else null
	_shot_script = load("res://scripts/shot_engine.gd") if ResourceLoader.exists("res://scripts/shot_engine.gd") else null
	_refresh_course()
	_refresh_facilities()
	_reset_arrivals()
	# A starter resort can serve guests immediately; individual hires remain optional.
	if starter:
		_add_staff("service_attendant", false)
		_add_staff("groundskeeper", false)
		_add_staff("cleaner", false)
	_record(0.0, "capital", "Opening balance")


func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	_tick_accumulator += dt
	while _tick_accumulator + 0.0000001 >= MAX_SUBSTEP:
		_tick_step(MAX_SUBSTEP)
		_tick_accumulator = maxf(0.0,_tick_accumulator-MAX_SUBSTEP)


func _tick_step(dt: float) -> void:
	_check_terrain_revision()
	_tick_staff(dt)
	if open:
		_spawn_due_arrivals()
	_tick_groups(dt)
	if _has_departed:
		_cleanup_departed()
		_has_departed=false
	_sync_cart_positions()
	_tick_facility_decay(dt)
	minute += dt / 60.0
	if minute + 0.000001 >= OPERATING_MINUTES:
		_end_day()


func charge(amount: float, category: String, description: String) -> bool:
	amount = maxf(amount, 0.0)
	if sandbox:
		_record(-amount, category, description + " (sandbox)")
		return true
	if cash + 0.001 < amount:
		notice = "Insufficient funds for %s" % description
		return false
	if _is_discretionary_charge(category) and (_insolvent_days > 0 or _has_unpaid_bills()) and cash - amount < _recovery_reserve():
		notice = "Cash is reserved for payroll and overdue bills"
		return false
	cash -= amount
	_today_expense += amount
	_record(-amount, category, description)
	return true


func credit(amount: float, category: String, description: String) -> void:
	amount = maxf(amount, 0.0)
	if not sandbox:
		cash += amount
	_today_revenue += amount
	_record(amount, category, description)


func hire(role: String) -> bool:
	var definition: Dictionary = _role_definition(role)
	if definition.is_empty():
		notice = "Unknown staff role: %s" % role
		return false
	var required_grade: int = int(definition.get("grade", definition.get("min_grade", 1)))
	if not sandbox and grade < required_grade:
		notice = "%s unlocks at grade %d" % [str(definition.get("name", role)), required_grade]
		return false
	var hiring_cost: float = float(definition.get("hiring_cost", definition.get("hire_cost", 250.0)))
	if not charge(hiring_cost, "staff", "Hire %s" % str(definition.get("name", role))):
		return false
	_add_staff(role, true)
	notice = "%s hired" % str(definition.get("name", role))
	return true


func fire(id: int) -> void:
	for index in range(staff.size()):
		if int(staff[index].get("id", -1)) == id:
			var worker: Dictionary = staff[index]
			staff.remove_at(index)
			notice = "%s left the resort" % str(worker.get("name", "Worker"))
			return


func assign_staff(id: int, object_id: int) -> void:
	for worker in staff:
		if int(worker.get("id", -1)) == id:
			worker["assignment"] = object_id
			worker["activity"] = "seeking_assignment"
			worker["route"] = PackedVector3Array()
			return


func borrow(product: String) -> String:
	var definition: Dictionary = _loan_definition(product)
	if definition.is_empty():
		return "Unknown loan product"
	var loan_grade: int = int(definition.get("grade", definition.get("min_grade", 1)))
	if not sandbox and grade < loan_grade:
		return "Loan unlocks at grade %d" % loan_grade
	if product == "recovery":
		for previous in loans:
			if str(previous.get("product", "")) == "recovery":
				return "The one-time recovery loan was already used"
		if cash >= 0.0 and open:
			return "Recovery funding is available after insolvency"
	for existing in loans:
		if str(existing.get("product", "")) == product and float(existing.get("balance", 0.0)) > 0.0:
			return "That loan is already active"
	var principal: float = float(definition.get("principal", definition.get("amount", 0.0)))
	var loan: Dictionary = {
		"id": _next_loan_id, "product": product,
		"name": str(definition.get("name", product.capitalize())),
		"principal": principal, "balance": principal,
		"interest": float(definition.get("daily_interest", float(definition.get("interest", 0.0004)) / 365.0)),
		"daily_payment": float(definition.get("daily_payment", definition.get("payment", principal / maxf(float(definition.get("term_days", 120)), 1.0)))),
		"term_days": int(definition.get("term_days", 120)), "days": 0,
	}
	_next_loan_id += 1
	loans.append(loan)
	credit(principal, "loan", "%s proceeds" % str(loan["name"]))
	if product == "recovery" and cash >= 0.0 and not open and not _course_holes.is_empty():
		reopen()
	notice = "%s funded" % str(loan["name"])
	return notice


func repay(loan_id: int, amount: float) -> String:
	if amount <= 0.0:
		return "Repayment must be positive"
	for loan in loans:
		if int(loan.get("id", -1)) == loan_id:
			var paid: float = minf(amount, float(loan.get("balance", 0.0)))
			if not charge(paid, "loan_payment", "Repay %s" % str(loan.get("name", "loan"))):
				return notice
			loan["balance"] = maxf(0.0, float(loan.get("balance", 0.0)) - paid)
			if float(loan["balance"]) <= 0.01:
				notice = "%s repaid" % str(loan.get("name", "Loan"))
			else:
				notice = "$%.0f repaid" % paid
			return notice
	return "Loan not found"


func schedule_event(kind: String, days_ahead: int = 1) -> String:
	var definition: Dictionary = _event_definition(kind)
	if definition.is_empty():
		return "Unknown event"
	var event_grade: int = int(definition.get("grade", definition.get("min_grade", 1)))
	if not sandbox and grade < event_grade:
		return "%s unlocks at grade %d" % [str(definition.get("name", kind)), event_grade]
	var problem: String = event_requirements(kind)
	if not problem.is_empty(): return problem
	var event_day: int = day + maxi(days_ahead, 1)
	for item in scheduled_events:
		if int(item.get("day", -1)) == event_day:
			return "An event is already scheduled that day"
	var cost: float = float(definition.get("cost", definition.get("booking_cost", 0.0)))
	if not charge(cost, "event", "Schedule %s" % str(definition.get("name", kind))):
		return notice
	var event: Dictionary = {
		"id": _next_event_id, "kind": kind, "name": str(definition.get("name", kind.capitalize())),
		"day": event_day, "cost": cost, "target": int(definition.get("target", definition.get("attendance", 20))),
		"attended": 0, "rounds_completed": 0, "revenue": 0.0, "status": "scheduled",
		"publicity": float(definition.get("publicity", definition.get("satisfaction", definition.get("reward", 5.0)))),
		"expected_revenue": float(definition.get("revenue", 0.0)),
	}
	_next_event_id += 1
	scheduled_events.append(event)
	notice = "%s scheduled for day %d" % [str(event["name"]), event_day]
	return notice


func event_requirements(kind: String) -> String:
	var requirements = {
		"open_day": [1,["clubhouse"]],
		"charity_scramble": [3,["clubhouse","restroom"]],
		"beginner_clinic": [1,["clubhouse","driving_range"]],
		"club_championship": [6,["clubhouse","restroom"]],
		"regional_amateur": [9,["clubhouse","restroom","snack_kiosk"]],
		"invitational": [18,["clubhouse","restroom","snack_kiosk","driving_range","cart_barn","maintenance_shed"]]
	}.get(kind,[])
	if requirements.is_empty(): return "Unknown event"
	if _course_holes.size()<int(requirements[0]):return "Requires %d playable holes" % requirements[0]
	for facility in requirements[1]:
		if not _has_facility(facility):return "Requires a functioning " + str(facility).replace("_"," ")
	return ""


func grade_requirements() -> String:
	if grade >= 3:
		return "Grade 3: premier resort"
	var target_grade: int = grade + 1
	var requirements: Dictionary = _grade_definition(target_grade).get("requirements", {})
	var quality_satisfaction: float = 0.60 if target_grade == 2 else 0.70
	var quality_wear: float = 0.50 if target_grade == 2 else 0.35
	var qualifying_events: String = "Open Day, Charity Scramble, or Beginner Clinic" if target_grade == 2 else "Club Championship or Regional Amateur"
	return "Grade %d requires $%.0f cash, %d buildings, %d playable holes, %.0f publicity, %d%% satisfaction, course wear at or below %d%%, and a successful %s. Current: $%.0f, %d buildings, %d holes, %.0f publicity, %d%% satisfaction, %d%% wear, qualifying event %s." % [target_grade, float(requirements.get("cash", 0.0)), int(requirements.get("buildings", 0)), int(requirements.get("holes", 0)), float(requirements.get("publicity", 0.0)), int(quality_satisfaction * 100.0), int(quality_wear * 100.0), qualifying_events, cash, _building_count(), _course_holes.size(), publicity, int(satisfaction * 100.0), int(_terrain_wear() * 100.0), "complete" if _has_qualifying_event(target_grade) else "needed"]


func unlocks() -> Dictionary:
	return {
		"grade": grade,
		"events": EVENT_KINDS.filter(func(kind: String) -> bool: return int(_event_definition(kind).get("grade", _event_definition(kind).get("min_grade", 1))) <= grade),
		"loans": DEFAULT_LOANS.keys().filter(func(kind) -> bool: return int(_loan_definition(str(kind)).get("grade", _loan_definition(str(kind)).get("min_grade", 1))) <= grade),
	}


func can_build(kind: String) -> bool:
	var definition: Dictionary = _catalog_find(kind)
	return not definition.is_empty() and (sandbox or grade >= int(definition.get("grade", 1)))


func facility_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		var copy: Dictionary = state.duplicate(true)
		var facility_id: int = int(state.get("id", -1))
		copy["queue"] = _queue_for_facility(facility_id).size()
		copy["workers"] = _workers_at(facility_id)
		result.append(copy)
	return result


func demand_factors() -> Dictionary:
	var facility_quality: float = 0.5
	if not _facility_state.is_empty():
		var quality_total: float = 0.0
		for state_value in _facility_state.values():
			var state: Dictionary = state_value
			quality_total += minf(clampf(float(state.get("condition", 1.0)), 0.0, 1.0), clampf(float(state.get("cleanliness", 1.0)), 0.0, 1.0))
		facility_quality = quality_total / float(_facility_state.size())
	var scenery_value: float = 0.0
	if terrain != null and "objects" in terrain:
		for object_value in terrain.objects:
			var object: Dictionary = object_value
			var definition: Dictionary = _catalog_find(str(object.get("kind", "")))
			scenery_value += float(definition.get("beauty", 0.0))
	var local_beauty: float = 0.0
	var beauty_samples: int = 0
	if terrain != null and terrain.has_method("beauty_at"):
		local_beauty += clampf(float(terrain.beauty_at(ENTRANCE)), 0.0, 100.0)
		beauty_samples += 1
		for hole in _course_holes:
			local_beauty += clampf(float(terrain.beauty_at(hole.get("tee", ENTRANCE))), 0.0, 100.0)
			beauty_samples += 1
	if beauty_samples > 0:
		local_beauty /= float(beauty_samples)
	return {
		"satisfaction": clampf(0.45 + satisfaction * 0.9, 0.35, 1.35),
		"facilities": clampf(0.65 + float(_building_count()) * 0.07, 0.65, 1.15),
		"facility_quality": 0.55 + facility_quality * 0.45,
		"scenery": clampf(0.82 + scenery_value * 0.012 + local_beauty * 0.002, 0.82, 1.28),
		"wear": clampf(1.0 - _terrain_wear() * 0.5, 0.5, 1.0),
	}


func active_event() -> Dictionary:
	for item in scheduled_events:
		if int(item.get("id", -1)) == _active_event_id:
			return item
	return {}


func admit_group(size: int, event_guest: bool = false) -> int:
	if not open or _course_holes.is_empty() or not _has_facility("clubhouse") or size < 1 or guests.size() >= 100:
		return -1
	var group_id: int = _next_group_id
	_create_group(mini(clampi(size, 1, 4),100-guests.size()), event_guest and _active_event_id >= 0)
	_arrived_today += clampi(size, 1, 4)
	return group_id


func on_construction(center: Vector3, radius: float, removed_hole_id: int = -1) -> void:
	var removed_index: int = -1
	var old_hole_count: int = _course_holes.size()
	for index in range(_course_holes.size()):
		if int(_course_holes[index].get("id", -1)) == removed_hole_id:
			removed_index = index
			break
	_route_cache.clear()
	_refresh_course()
	_refresh_facilities()
	var affected_groups: Dictionary = {}
	var affected_guests: Dictionary = {}
	var hard_stop_groups: Dictionary = {}
	var compensation: Dictionary = {}
	for guest in guests:
		if str(guest.get("activity", "")) == "departed":
			continue
		var pos: Vector3 = guest.get("pos", ENTRANCE)
		var destination: Vector3 = guest.get("destination", pos)
		var route: PackedVector3Array = guest.get("route", PackedVector3Array())
		var live_shot: Dictionary = guest.get("shot", {})
		var affected: bool = _point_in_edit(pos, center, radius) or _point_in_edit(destination, center, radius) or _path_intersects_edit(route, center, radius) or _shot_intersects_edit(live_shot, center, radius)
		var group_id: int = int(guest.get("group_id", -1))
		var group: Dictionary = _group_by_id(group_id)
		var current_hole_id: int = int(group.get("current_hole_id", -1))
		var current_hole_invalid: bool = current_hole_id >= 0 and _hole_by_id(current_hole_id).is_empty()
		if removed_hole_id >= 0 and current_hole_id == removed_hole_id:
			affected = true
			current_hole_invalid = true
		if current_hole_invalid:
			hard_stop_groups[group_id] = true
		if affected:
			affected_groups[group_id] = true
			if not affected_guests.has(group_id):
				affected_guests[group_id] = []
			affected_guests[group_id].append(int(guest.get("id", -1)))
			compensation[group_id] = float(compensation.get(group_id, 0.0)) + 5.0
			guest["pos"] = _construction_safe_position(pos, center, radius)
			guest["route"] = PackedVector3Array()
			guest["route_index"] = 0
			guest["thought"] = "The crew paused safely while the course changed."
			if not live_shot.is_empty():
				var interrupted: Dictionary = live_shot.duplicate(true)
				interrupted["interrupted"] = true
				guest["last_shot"] = interrupted
				guest["shot"] = {}
				guest["shot_elapsed"] = 0.0
				var reset_ball: Vector3 = _construction_safe_position(live_shot.get("start", guest.get("ball_pos", pos)), center, radius)
				guest["ball_pos"] = reset_ball
				guest["pos"] = reset_ball
				guest["destination"] = reset_ball
				compensation[group_id] = float(compensation[group_id]) + minf(8.0, float(prices.get("green_fee", 48.0)) * 0.1)
				if str(group.get("state", "")) == "playing":
					group["play_phase"] = "ready"
					group["turn_pause"] = 1.0 * SIM_RATE
			elif str(group.get("state", "")) == "playing" and str(group.get("play_phase", "")) == "ready":
				var member_ids: Array = group.get("members", [])
				var player_turn: int = int(group.get("player_turn", 0))
				if player_turn >= 0 and player_turn < member_ids.size() and int(member_ids[player_turn]) == int(guest.get("id", -1)):
					guest["ball_pos"] = guest["pos"]
	# Every route is rebuilt because a route can cross edited cells without either endpoint being nearby.
	for group in groups:
		if str(group.get("state", "")) == "departed":
			continue
		var current_hole_id: int = int(group.get("current_hole_id", -1))
		if bool(group.get("cart", false)) and _point_in_edit(group.get("cart_pos", ENTRANCE), center, radius):
			group["cart_initialized"] = false
		if current_hole_id >= 0 and _hole_by_id(current_hole_id).is_empty():
			hard_stop_groups[int(group.get("id", -1))] = true
			continue
		if not _rebuild_group_routes(group):
			hard_stop_groups[int(group.get("id", -1))] = true
	for worker in staff:
		var worker_pos: Vector3 = worker.get("pos", ENTRANCE)
		var worker_destination: Vector3 = worker.get("destination", worker_pos)
		var worker_route: PackedVector3Array = _raw_route(worker_pos, worker_destination, false)
		if not worker_route.is_empty():
			worker["route"] = worker_route
			worker["route_index"] = 1 if worker_route.size() > 1 else 0
	for group_id_value in hard_stop_groups.keys():
		var group: Dictionary = _group_by_id(int(group_id_value))
		if group.is_empty():
			continue
		var remaining_holes: int = maxi(0, old_hole_count - int(group.get("hole_index", 0)))
		var refund_fraction: float = float(remaining_holes) / float(maxi(1, old_hole_count))
		_safe_refund_and_depart(group, "Course work ended this round safely.", refund_fraction)
		if _raw_route(_group_leader_position(group), ENTRANCE, bool(group.get("cart", false))).is_empty():
			_finish_departure(group)
	for group_id_value in compensation.keys():
		var group: Dictionary = _group_by_id(int(group_id_value))
		if group.is_empty():
			continue
		_pay_construction_compensation(group, float(compensation[group_id_value]), affected_guests.get(group_id_value, []))
	if removed_index >= 0:
		for group in groups:
			if not hard_stop_groups.has(int(group.get("id", -1))) and int(group.get("hole_index", 0)) > removed_index:
				group["hole_index"] = maxi(0, int(group.get("hole_index", 0)) - 1)
	for group in groups:
		for index in range(_course_holes.size()):
			if _course_holes[index].id==group.get("current_hole_id",-1):group["hole_index"]=index
	if not affected_groups.is_empty():
		notice = "%d groups safely resumed after construction; %d interrupted rounds ended" % [affected_groups.size(), hard_stop_groups.size()]


func snapshot() -> Dictionary:
	return {
		"version": 1, "tick_accumulator": _tick_accumulator, "guests": guests.duplicate(true), "staff": staff.duplicate(true), "groups": groups.duplicate(true),
		"cash": cash, "day": day, "minute": minute, "sandbox": sandbox, "prices": prices.duplicate(true),
		"ledger": ledger.duplicate(true), "loans": loans.duplicate(true), "scheduled_events": scheduled_events.duplicate(true),
		"event_history": event_history.duplicate(true), "grade": grade, "publicity": publicity, "open": open,
		"satisfaction": satisfaction, "completed_visits": completed_visits, "notice": notice,
		"rng_seed": _rng.seed, "rng_state": _rng.state, "next_guest_id": _next_guest_id,
		"next_group_id": _next_group_id, "next_staff_id": _next_staff_id, "next_loan_id": _next_loan_id,
		"next_event_id": _next_event_id, "arrival_target": _arrival_target, "arrived_today": _arrived_today,
		"next_arrival_minute": _next_arrival_minute, "hole_queues": _hole_queues.duplicate(true),
		"hole_occupancy": _hole_occupancy.duplicate(true), "facility_queues": _facility_queues.duplicate(true),
		"facility_state": _facility_state.duplicate(true), "today_revenue": _today_revenue,
		"today_expense": _today_expense, "insolvent_days": _insolvent_days,
		"closed_reason": _closed_reason, "active_event_id": _active_event_id,
	}


func restore(data: Dictionary) -> void:
	_guests_by_group.clear()
	_groups_by_id.clear()
	_has_departed=false
	_tick_accumulator = data.get("tick_accumulator",0.0)
	guests.assign(data.get("guests", []).duplicate(true))
	staff.assign(data.get("staff", []).duplicate(true))
	groups.assign(data.get("groups", []).duplicate(true))
	cash = float(data.get("cash", 180000.0))
	day = int(data.get("day", 1))
	minute = float(data.get("minute", 0.0))
	sandbox = bool(data.get("sandbox", false))
	prices = Dictionary(data.get("prices", {})).duplicate(true)
	ledger.assign(data.get("ledger", []))
	loans.assign(data.get("loans", []))
	scheduled_events.assign(data.get("scheduled_events", []))
	event_history.assign(data.get("event_history", []))
	grade = int(data.get("grade", 1))
	publicity = float(data.get("publicity", 0.0))
	open = bool(data.get("open", true))
	satisfaction = float(data.get("satisfaction", 0.72))
	completed_visits = int(data.get("completed_visits", 0))
	notice = str(data.get("notice", "Restored"))
	_next_guest_id = int(data.get("next_guest_id", 1))
	_next_group_id = int(data.get("next_group_id", 1))
	_next_staff_id = int(data.get("next_staff_id", 1))
	_next_loan_id = int(data.get("next_loan_id", 1))
	_next_event_id = int(data.get("next_event_id", 1))
	_arrival_target = int(data.get("arrival_target", 0))
	_arrived_today = int(data.get("arrived_today", 0))
	_next_arrival_minute = float(data.get("next_arrival_minute", 20.0))
	_hole_queues = Dictionary(data.get("hole_queues", {})).duplicate(true)
	_hole_occupancy = Dictionary(data.get("hole_occupancy", {})).duplicate(true)
	_facility_queues = Dictionary(data.get("facility_queues", {})).duplicate(true)
	_facility_state = Dictionary(data.get("facility_state", {})).duplicate(true)
	_today_revenue = float(data.get("today_revenue", 0.0))
	_today_expense = float(data.get("today_expense", 0.0))
	_insolvent_days = int(data.get("insolvent_days", 0))
	_closed_reason = str(data.get("closed_reason", ""))
	_active_event_id = int(data.get("active_event_id", -1))
	_rng.seed = int(data.get("rng_seed", 730241))
	_rng.state = int(data.get("rng_state", _rng.state))
	_route_cache.clear()
	_refresh_course()
	_refresh_facilities(false)


func _tick_groups(dt: float) -> void:
	for group in groups:
		var blocked = false
		for guest in _group_guests(group):blocked = blocked or guest.get("blocked",false)
		if blocked:
			group["blocked_seconds"] = float(group.get("blocked_seconds",0))+dt
			if group.blocked_seconds>120:
				if group.state!="departing":
					_safe_refund_and_depart(group,"A route was inaccessible; staff arranged a safe departure.",0.5)
				if _raw_route(_group_leader_position(group),ENTRANCE,false).is_empty():_finish_departure(group)
				for guest in _group_guests(group):guest["blocked"]=false
				group["blocked_seconds"]=0.0
		else:group["blocked_seconds"]=0.0
		match str(group.get("state", "")):
			"arriving":
				if _move_group(group, dt):
					_enqueue_checkin(group)
			"checkin_queue":
				_tick_checkin(group, dt)
			"facility_queue":
				_tick_facility_queue(group, dt)
			"facility_use":
				_tick_facility_use(group, dt)
			"to_tee":
				if _move_group(group, dt):
					_enqueue_hole(group)
			"tee_queue":
				_tick_tee_queue(group, dt)
			"playing":
				_tick_play(group, dt)
			"departing":
				if _move_group(group, dt):
					_finish_departure(group)
			"departed":
				pass


func _spawn_due_arrivals() -> void:
	if minute < _next_arrival_minute or _arrived_today >= _arrival_target:
		return
	if _course_holes.is_empty() or not _has_facility("clubhouse") or guests.size() >= 100:
		_next_arrival_minute += 15.0
		return
	var remaining_slots: int = mini(_arrival_target - _arrived_today,100-guests.size())
	var size: int = mini(_rng.randi_range(1, 4), remaining_slots)
	var event: Dictionary = active_event()
	if not event.is_empty() and int(event.get("attended", 0)) < int(event.get("target", 0)):
		size = mini(maxi(size, 2), remaining_slots)
	_create_group(size, not event.is_empty())
	_arrived_today += size
	var demand_spacing: float = maxf(2.4, 7.5 - float(grade) - publicity * 0.025)
	_next_arrival_minute += _rng.randf_range(demand_spacing * 0.65, demand_spacing * 1.35)


func _person_name(id: int) -> String:
	var first=["Alex","Morgan","Jamie","Sam","Taylor","Jordan","Casey","Riley","Avery","Quinn","Cameron","Drew","Emerson","Rowan","Sage","Charlie"]
	var last=["Park","Miller","Chen","Rivera","Patel","Brooks","Reed","Woods","Nguyen","Carter","Kim","Santos","Gray","Bennett","Clarke","Ellis","Hughes","Moss","Singh"]
	return "%s %s"%[first[id%first.size()],last[(id/first.size()+id*7)%last.size()]]


func _create_group(size: int, event_guest: bool) -> void:
	var group_id: int = _next_group_id
	_next_group_id += 1
	var wants_cart: bool = _cart_available() and _rng.randf() < 0.48
	var group: Dictionary = {
		"id": group_id, "members": [], "size": size, "state": "arriving", "hole_index": 0,
		"player_turn": 0, "current_hole_id": -1, "completed_hole_ids":[], "wait_seconds": 0.0, "service_seconds": 0.0,
		"cart": wants_cart, "cart_pos": ENTRANCE, "cart_parked": true, "cart_initialized": false,
		"cart_phase": "parked", "cart_route": PackedVector3Array(), "cart_route_index": 0,
		"final_destination": ENTRANCE, "event": event_guest, "event_id": _active_event_id if event_guest else -1,
		"facility_id": -1, "facility_kind": "", "facilities_visited": [], "paid": false,
	}
	groups.append(group)
	for index in range(size):
		var guest_id: int = _next_guest_id
		_next_guest_id += 1
		var skill: float = clampf(_rng.randfn(0.53, 0.19), 0.06, 0.97)
		var budget: float = _rng.randf_range(90.0, 260.0)
		var guest: Dictionary = {
			"id": guest_id, "name": _person_name(guest_id), "pos": ENTRANCE,
			"destination": ENTRANCE, "activity": "arriving", "skill": skill,
			"mood": clampf(0.66 + _rng.randf_range(-0.1, 0.16), 0.0, 1.0),
			"hunger": _rng.randf_range(0.05, 0.38), "energy": _rng.randf_range(0.72, 1.0),
			"restroom": _rng.randf_range(0.0, 0.28), "budget": budget, "spent": 0.0,
			"group_id": group_id, "hole_index": 0, "strokes": 0, "scorecard": [],
			"thought": "Looking forward to the round.", "cart": wants_cart, "shot": {},
			"shot_elapsed": 0.0, "shot_serial": 0, "last_shot": {}, "route": PackedVector3Array(), "route_index": 0,
			"ball_pos": ENTRANCE, "paid_green_fee": 0.0,
		}
		if wants_cart:
			guest["cart_pos"] = ENTRANCE
		guests.append(guest)
		group["members"].append(guest_id)
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	var destination: Vector3 = clubhouse.get("pos", ENTRANCE)
	_set_group_destination(group, destination, wants_cart)


func _enqueue_checkin(group: Dictionary) -> void:
	group["state"] = "checkin_queue"
	group["wait_seconds"] = 0.0
	group["service_seconds"] = 0.0
	for guest in _group_guests(group):
		guest["activity"] = "checking_in"
		guest["thought"] = "Waiting to check in."


func _tick_checkin(group: Dictionary, dt: float) -> void:
	var position: int = _state_queue_position("checkin_queue", int(group["id"]))
	if position >= _checkin_capacity():
		group["wait_seconds"] = float(group.get("wait_seconds", 0.0)) + dt
		_apply_wait_mood(group, dt, 280.0)
		return
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	var service_rate: float = 0.65 + float(_service_workers_at(int(clubhouse.get("id", -1)))) * 0.7
	group["service_seconds"] = float(group.get("service_seconds", 0.0)) + dt * service_rate
	if float(group["service_seconds"]) < 35.0 + float(group.get("size", 1)) * 12.0:
		return
	if not _collect_green_fees(group):
		_safe_refund_and_depart(group, "The resort cannot process our booking.", 1.0)
		return
	var next_kind: String = _choose_pre_round_facility(group)
	if next_kind.is_empty():
		_send_to_next_hole(group)
	else:
		_send_to_facility(group, next_kind)


func _collect_green_fees(group: Dictionary) -> bool:
	if bool(group.get("paid", false)):
		return true
	var fee: float = float(prices.get("green_fee", 48.0))
	var cart_fee: float = float(prices.get("cart", 22.0)) if bool(group.get("cart", false)) else 0.0
	for guest in _group_guests(group):
		var due: float = fee + cart_fee
		if float(guest.get("budget", 0.0)) < due:
			group["cart"] = false
			due = fee
		if float(guest.get("budget", 0.0)) < due:
			return false
		guest["budget"] = float(guest["budget"]) - due
		guest["spent"] = float(guest.get("spent", 0.0)) + due
		guest["paid_green_fee"] = fee
		guest["cart"] = bool(group.get("cart", false))
		credit(due, "admissions", "Green fee%s" % (" and cart" if bool(group.get("cart", false)) else ""))
	group["paid"] = true
	return true


func _choose_pre_round_facility(group: Dictionary) -> String:
	if _has_facility("driving_range") and _rng.randf() < 0.30:
		return "driving_range"
	if _has_facility("snack_kiosk") and _group_average(group, "hunger") > 0.24:
		return "snack_kiosk"
	if _has_facility("restroom") and _group_average(group, "restroom") > 0.2:
		return "restroom"
	return ""


func _send_to_facility(group: Dictionary, kind: String) -> void:
	var facility: Dictionary = _best_facility(kind)
	if facility.is_empty():
		_send_to_next_hole(group)
		return
	group["facility_id"] = int(facility.get("id", -1))
	group["facility_kind"] = kind
	group["state"] = "facility_queue"
	group["wait_seconds"] = 0.0
	var queue: Array = _queue_for_facility(int(group["facility_id"]))
	if not queue.has(int(group["id"])):
		queue.append(int(group["id"]))
	_facility_queues[int(group["facility_id"])] = queue
	_set_group_destination(group, facility.get("pos", ENTRANCE), bool(group.get("cart", false)))


func _tick_facility_queue(group: Dictionary, dt: float) -> void:
	if not _move_group(group, dt):
		return
	var facility_id: int = int(group.get("facility_id", -1))
	var state: Dictionary = _facility_state.get(facility_id, {})
	if state.is_empty() or float(state.get("condition", 0.0)) < 0.12:
		_remove_from_facility_queue(group)
		_send_to_next_hole(group)
		return
	var queue: Array = _queue_for_facility(facility_id)
	var queue_index: int = queue.find(int(group["id"]))
	var base_capacity: int = maxi(1, int(state.get("capacity", 4)))
	var quality: float = minf(float(state.get("condition", 1.0)), float(state.get("cleanliness", 1.0)))
	var capacity: int = maxi(1, int(round(float(base_capacity) * clampf(quality, 0.35, 1.0))))
	capacity += _service_workers_at(facility_id) * maxi(1, base_capacity / 3)
	if queue_index < 0 or queue_index >= capacity:
		group["wait_seconds"] = float(group.get("wait_seconds", 0.0)) + dt
		_apply_wait_mood(group, dt, 220.0)
		return
	group["state"] = "facility_use"
	group["service_seconds"] = 0.0
	for guest in _group_guests(group):
		guest["activity"] = str(group.get("facility_kind", "facility"))
		guest["thought"] = "Taking a quick stop before golf."


func _tick_facility_use(group: Dictionary, dt: float) -> void:
	var facility_id: int = int(group.get("facility_id", -1))
	var state: Dictionary = _facility_state.get(facility_id, {})
	var service_multiplier: float = _facility_service_rate(facility_id)
	group["service_seconds"] = float(group.get("service_seconds", 0.0)) + dt * service_multiplier
	if float(group["service_seconds"]) < _facility_duration(str(group.get("facility_kind", ""))):
		return
	var kind: String = str(group.get("facility_kind", ""))
	for guest in _group_guests(group):
		_apply_facility_to_guest(guest, kind)
	if not state.is_empty():
		state["cleanliness"] = maxf(0.0, float(state.get("cleanliness", 1.0)) - 0.007 * float(group.get("size", 1)))
		state["condition"] = maxf(0.0, float(state.get("condition", 1.0)) - 0.0015 * float(group.get("size", 1)))
	_remove_from_facility_queue(group)
	group["facilities_visited"].append(kind)
	_send_to_next_hole(group)


func _apply_facility_to_guest(guest: Dictionary, kind: String) -> void:
	match kind:
		"snack_kiosk":
			_guest_purchase(guest, float(prices.get("snack", 9.0)), "food", "Snack purchase")
			guest["hunger"] = maxf(0.0, float(guest.get("hunger", 0.0)) - 0.65)
			guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.05)
		"driving_range":
			_guest_purchase(guest, float(prices.get("range", 12.0)), "range", "Driving range")
			guest["skill"] = minf(1.0, float(guest.get("skill", 0.5)) + 0.025)
			guest["energy"] = maxf(0.0, float(guest.get("energy", 1.0)) - 0.04)
		"restroom":
			guest["restroom"] = 0.0
	guest["thought"] = "That was a useful stop."


func _send_to_next_hole(group: Dictionary) -> void:
	var completed_ids = group.get("completed_hole_ids",[])
	var next_index = -1
	for index in range(_course_holes.size()):
		if not completed_ids.has(_course_holes[index].id):
			next_index=index
			break
	if next_index < 0:
		group["hole_index"] = _course_holes.size()
		_release_group_resources(group)
		group["state"] = "departing"
		_set_group_destination(group, ENTRANCE, bool(group.get("cart", false)))
		for guest in _group_guests(group):
			guest["activity"] = "departing"
			guest["thought"] = "Heading home after the round."
		return
	group["hole_index"] = next_index
	var hole: Dictionary = _course_holes[next_index]
	group["state"] = "to_tee"
	group["current_hole_id"] = int(hole.get("id", -1))
	_set_group_destination(group, hole.get("tee", ENTRANCE), bool(group.get("cart", false)))
	for guest in _group_guests(group):
		guest["hole_index"] = int(group["hole_index"])
		guest["activity"] = "walking_to_cart" if bool(group.get("cart", false)) else "walking"
		guest["thought"] = "On the way to hole %d." % (int(group["hole_index"]) + 1)


func _enqueue_hole(group: Dictionary) -> void:
	var hole_id: int = int(group.get("current_hole_id", -1))
	var queue: Array = _hole_queues.get(hole_id, [])
	if not queue.has(int(group["id"])):
		queue.append(int(group["id"]))
	_hole_queues[hole_id] = queue
	group["state"] = "tee_queue"
	group["wait_seconds"] = 0.0
	for guest in _group_guests(group):
		guest["activity"] = "waiting_at_tee"
		guest["thought"] = "Waiting for the fairway to clear."


func _tick_tee_queue(group: Dictionary, dt: float) -> void:
	var hole_id: int = int(group.get("current_hole_id", -1))
	var queue: Array = _hole_queues.get(hole_id, [])
	if queue.is_empty() or int(queue[0]) != int(group["id"]) or int(_hole_occupancy.get(hole_id, -1)) >= 0:
		group["wait_seconds"] = float(group.get("wait_seconds", 0.0)) + dt
		_apply_wait_mood(group, dt, 420.0)
		return
	queue.pop_front()
	_hole_queues[hole_id] = queue
	_hole_occupancy[hole_id] = int(group["id"])
	group["state"] = "playing"
	group["cart_parked"] = true
	group["player_turn"] = 0
	group["play_phase"] = "ready"
	group["turn_pause"] = 1.2 * SIM_RATE
	var hole: Dictionary = _hole_by_id(hole_id)
	for guest in _group_guests(group):
		guest["ball_pos"] = hole.get("tee", guest.get("pos", ENTRANCE))
		guest["hole_strokes"] = 0
		guest["hole_done"] = false
		guest["activity"] = "watching"


func _tick_play(group: Dictionary, dt: float) -> void:
	var hole: Dictionary = _hole_by_id(int(group.get("current_hole_id", -1)))
	if hole.is_empty() or not bool(hole.get("open", true)):
		_safe_refund_and_depart(group, "Course work interrupted the round.", 0.5)
		return
	var players: Array[Dictionary] = _group_guests(group)
	var turn: int = int(group.get("player_turn", 0))
	if turn >= players.size():
		_complete_hole(group, hole)
		return
	var golfer: Dictionary = players[turn]
	var phase: String = str(group.get("play_phase", "ready"))
	if phase == "ready":
		var pause: float = float(group.get("turn_pause", 0.0)) - dt
		group["turn_pause"] = pause
		if pause <= 0.0:
			_begin_shot(group, golfer, hole)
		return
	if phase == "shot":
		golfer["shot_elapsed"] = float(golfer.get("shot_elapsed", 0.0)) + dt
		var shot: Dictionary = golfer.get("shot", {})
		if float(golfer["shot_elapsed"]) >= float(shot.get("duration", 1.0)):
			_finish_shot(group, golfer, hole)
		return
	if phase == "walk":
		if _move_guest(golfer, dt, false):
			var last_shot: Dictionary = golfer.get("last_shot", {})
			golfer["ball_pos"] = last_shot.get("end", golfer.get("pos", ENTRANCE))
			if bool(last_shot.get("holed", false)) or int(golfer.get("hole_strokes", 0)) >= MAX_STROKES:
				_finish_player_hole(group, golfer, hole)
			else:
				group["play_phase"] = "ready"
				group["turn_pause"] = 0.8 * SIM_RATE
				golfer["shot_elapsed"] = 0.0
				_next_player_turn(group,players)


func _begin_shot(group: Dictionary, golfer: Dictionary, hole: Dictionary) -> void:
	var start: Vector3 = golfer.get("ball_pos", hole.get("tee", ENTRANCE))
	var shot: Dictionary
	if _shot_script != null and _shot_script.has_method("shot"):
		shot = _shot_script.shot(terrain, start, hole, float(golfer.get("skill", 0.5)), _rng)
	else:
		shot = _fallback_shot(start, hole, float(golfer.get("skill", 0.5)))
	# The persistent serial/last_shot pair lets the view animate independently
	# even when a 60-second root tick advances past this physical flight.
	shot["physics_duration"] = maxf(0.4,float(shot.get("duration", 1.0)))
	shot["duration"] = shot["physics_duration"] * SIM_RATE
	golfer["shot"] = shot
	golfer["last_shot"] = shot.duplicate(true)
	golfer["shot_serial"] = int(golfer.get("shot_serial", 0)) + 1
	golfer["shot_elapsed"] = 0.0
	golfer["activity"] = "swinging"
	golfer["thought"] = _shot_thought(shot)
	group["play_phase"] = "shot"
	if terrain != null and "wear" in terrain:
		terrain.wear = minf(1.0, float(terrain.wear) + 0.000015)


func _finish_shot(group: Dictionary, golfer: Dictionary, hole: Dictionary) -> void:
	var shot: Dictionary = golfer.get("shot", {})
	var added: int = 1 + int(shot.get("penalty", 0))
	golfer["hole_strokes"] = int(golfer.get("hole_strokes", 0)) + added
	golfer["strokes"] = int(golfer.get("strokes", 0)) + added
	var landing: Vector3 = shot.get("end", golfer.get("pos", ENTRANCE))
	golfer["destination"] = landing
	# Carts remain parked on the cart network during hole play.
	golfer["route"] = _route(golfer.get("pos", start_position(hole)), landing, false)
	golfer["route_index"] = 1 if (golfer["route"] as PackedVector3Array).size() > 1 else 0
	golfer["activity"] = "walking_to_ball"
	golfer["last_shot"] = shot.duplicate(true)
	golfer["shot"] = {}
	group["play_phase"] = "walk"


func _finish_player_hole(group: Dictionary, golfer: Dictionary, hole: Dictionary) -> void:
	var strokes: int = int(golfer.get("hole_strokes", MAX_STROKES))
	golfer["scorecard"].append(strokes)
	golfer["shot"] = {}
	golfer["shot_elapsed"] = 0.0
	golfer["activity"] = "watching"
	golfer["mood"] = clampf(float(golfer.get("mood", 0.5)) + (float(int(hole.get("par", 4)) - strokes) * 0.018), 0.0, 1.0)
	golfer["hole_done"] = true
	_next_player_turn(group,_group_guests(group))
	group["play_phase"] = "ready"
	group["turn_pause"] = 0.7 * SIM_RATE


func _next_player_turn(group: Dictionary, players: Array[Dictionary]) -> void:
	var current = int(group.get("player_turn",0))
	for offset in range(1,players.size()+1):
		var next = (current+offset)%players.size()
		if not players[next].get("hole_done",false):
			group["player_turn"] = next
			return
	group["player_turn"] = players.size()


func _complete_hole(group: Dictionary, hole: Dictionary) -> void:
	var hole_id: int = int(hole.get("id", -1))
	if not group.has("completed_hole_ids"):group["completed_hole_ids"]=[]
	if not group.completed_hole_ids.has(hole_id):group.completed_hole_ids.append(hole_id)
	if int(_hole_occupancy.get(hole_id, -1)) == int(group["id"]):
		_hole_occupancy[hole_id] = -1
	group["hole_index"] = int(group.get("hole_index", 0)) + 1
	group["current_hole_id"] = -1
	for guest in _group_guests(group):
		guest["energy"] = maxf(0.0, float(guest.get("energy", 1.0)) - 0.055)
		guest["hunger"] = minf(1.0, float(guest.get("hunger", 0.0)) + 0.07)
		guest["restroom"] = minf(1.0, float(guest.get("restroom", 0.0)) + 0.045)
		guest["hole_index"] = int(group["hole_index"])
	if bool(group.get("event", false)):
		_add_event_hole(group)
	# One real mid-round stop makes demand and service staffing matter.
	if int(group["hole_index"]) < _course_holes.size() and not group["facilities_visited"].has("snack_kiosk") and _group_average(group, "hunger") > 0.62 and _has_facility("snack_kiosk"):
		_send_to_facility(group, "snack_kiosk")
	else:
		_send_to_next_hole(group)


func _finish_departure(group: Dictionary) -> void:
	_has_departed=true
	group["state"] = "departed"
	group["departed_day"] = day
	group["departed_minute"] = minute
	var completed: bool = not _course_holes.is_empty()
	for hole in _course_holes:
		if not group.get("completed_hole_ids",[]).has(hole.id):completed=false
	for guest in _group_guests(group):
		guest["activity"] = "departed"
		guest["pos"] = ENTRANCE
		guest["destination"] = ENTRANCE
		guest["route"] = PackedVector3Array()
		if completed:
			completed_visits += 1
			guest["thought"] = "A complete round—I’ll remember this place."
		else:
			guest["thought"] = "Time to head home."
		satisfaction = lerpf(satisfaction, _group_average(group, "mood"), 0.018 * float(group.get("size", 1)))
	if completed and bool(group.get("event", false)):
		var event: Dictionary = _event_by_id(int(group.get("event_id", -1)))
		if not event.is_empty():
			event["rounds_completed"] = int(event.get("rounds_completed", 0)) + int(group.get("size", 1))


func _safe_refund_and_depart(group: Dictionary, thought: String, fraction: float) -> void:
	_release_group_resources(group)
	var refund: float = 0.0
	for guest in _group_guests(group):
		var amount: float = float(guest.get("paid_green_fee", 0.0)) * clampf(fraction, 0.0, 1.0)
		refund += amount
		guest["budget"] = float(guest.get("budget", 0.0)) + amount
		guest["paid_green_fee"] = maxf(0,float(guest.get("paid_green_fee",0))-amount)
		guest["spent"] = maxf(0,float(guest.get("spent",0))-amount)
		guest["thought"] = thought
		guest["shot"] = {}
		guest["shot_elapsed"] = 0.0
	if refund > 0.0:
		_force_expense(refund, "refund", "Guest recovery refund")
	group["state"] = "departing"
	_set_group_destination(group, ENTRANCE, bool(group.get("cart", false)))


func _release_group_resources(group: Dictionary) -> void:
	var group_id: int = int(group.get("id", -1))
	var hole_id: int = int(group.get("current_hole_id", -1))
	if int(_hole_occupancy.get(hole_id, -2)) == group_id:
		_hole_occupancy[hole_id] = -1
	for key in _hole_queues.keys():
		var queue: Array = _hole_queues[key]
		queue.erase(group_id)
		_hole_queues[key] = queue
	_remove_from_facility_queue(group)


func _tick_staff(dt: float) -> void:
	for worker in staff:
		var target: Dictionary = _staff_target(worker)
		if target.is_empty():
			worker["activity"] = "available"
			continue
		var target_pos: Vector3 = target.get("pos", ENTRANCE)
		if worker.get("destination", ENTRANCE) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
			worker["destination"] = target_pos
			worker["route"] = _route(worker.get("pos", ENTRANCE), target_pos, false)
			worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
		if not _move_person(worker, dt, WALK_SPEED):
			worker["activity"] = "walking"
			continue
		var role: String = str(worker.get("role", ""))
		var worker_skill: float = clampf(float(worker.get("skill", 0.7)), 0.25, 1.5)
		var object_id: int = int(target.get("id", -1))
		var state: Dictionary = _facility_state.get(object_id, {})
		if role == "groundskeeper":
			worker["activity"] = "maintaining"
			if not state.is_empty():
				state["condition"] = minf(1.0, float(state.get("condition", 1.0)) + dt * 0.00022 * worker_skill)
			if terrain != null and "wear" in terrain:
				terrain.wear = maxf(0.0, float(terrain.wear) - dt * 0.0000008 * worker_skill)
		elif role == "cleaner":
			worker["activity"] = "cleaning"
			if not state.is_empty():
				state["cleanliness"] = minf(1.0, float(state.get("cleanliness", 1.0)) + dt * 0.0005 * worker_skill)
		else:
			worker["activity"] = "serving"


func _staff_target(worker: Dictionary) -> Dictionary:
	var assignment: int = int(worker.get("assignment", -1))
	if assignment >= 0:
		return _facility_state.get(assignment, {})
	var role: String = str(worker.get("role", ""))
	if role == "service_attendant":
		var clubhouse: Dictionary = _facility_by_kind("clubhouse")
		if not clubhouse.is_empty():
			return clubhouse
	var best: Dictionary = {}
	var lowest: float = 2.0
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		var value: float = float(state.get("cleanliness", 1.0)) if role == "cleaner" else float(state.get("condition", 1.0))
		if value < lowest:
			lowest = value
			best = state
	return best


func _tick_facility_decay(dt: float) -> void:
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		var use: float = float(_queue_for_facility(int(state.get("id", -1))).size())
		state["cleanliness"] = maxf(0.0, float(state.get("cleanliness", 1.0)) - dt * (0.000002 + use * 0.000001))
		state["condition"] = maxf(0.0, float(state.get("condition", 1.0)) - dt * 0.0000008)
		_sync_facility_object(state)


func _end_day() -> void:
	# Any group still present leaves safely; closed gates never strand a visitor.
	for group in groups:
		if str(group.get("state", "")) != "departed":
			_safe_refund_and_depart(group, "The course is closing; staff guided us out.", 0.35)
			_finish_departure(group)
	_settle_events()
	_settle_wages_and_upkeep()
	_settle_loans()
	_update_grade()
	var net: float = _today_revenue - _today_expense
	_record(0.0, "daily_summary", "Day %d net $%.0f" % [day, net])
	if cash < 0.0:
		_insolvent_days += 1
	else:
		_insolvent_days = 0
	if _insolvent_days >= 3 and not sandbox:
		open = false
		_closed_reason = "Insolvent for three consecutive days"
		notice = "Resort closed: %s. Repay debt or add funds, then call reopen()." % _closed_reason
	day += 1
	minute = 0.0
	_today_revenue = 0.0
	_today_expense = 0.0
	_cleanup_departed()
	_refresh_course()
	_refresh_facilities(false)
	_reset_arrivals()


func reopen() -> bool:
	if cash < 0.0 and not sandbox:
		notice = "Positive cash is required to reopen"
		return false
	if _course_holes.is_empty():
		notice = "At least one playable hole is required to reopen"
		return false
	open = true
	_insolvent_days = 0
	_closed_reason = ""
	notice = "Resort reopened"
	return true


func _settle_wages_and_upkeep() -> void:
	var wages: float = 0.0
	for worker in staff:
		wages += float(worker.get("wage", 0.0))
	if wages > 0.0:
		_force_expense(wages, "wages", "Daily payroll")
	var upkeep: float = 0.0
	if terrain != null and "objects" in terrain:
		for object_value in terrain.objects:
			var object: Dictionary = object_value
			var definition: Dictionary = _catalog_find(str(object.get("kind", "")))
			upkeep += float(definition.get("upkeep", 0.0))
	if upkeep > 0.0:
		_force_expense(upkeep, "upkeep", "Facility and scenery upkeep")


func _settle_loans() -> void:
	for loan in loans:
		var balance: float = float(loan.get("balance", 0.0))
		if balance <= 0.0:
			continue
		var interest: float = balance * float(loan.get("interest", 0.0))
		loan["days"] = int(loan.get("days", 0)) + 1
		_force_expense(interest, "interest", "%s interest" % str(loan.get("name", "Loan")))
		var payment: float = minf(float(loan.get("daily_payment", 0.0)), balance)
		if sandbox or cash >= payment:
			charge(payment, "loan_payment", "%s scheduled payment" % str(loan.get("name", "Loan")))
			loan["balance"] = maxf(0.0, balance - payment)
			loan["missed_payments"] = maxi(0, int(loan.get("missed_payments", 0)) - 1)
		else:
			loan["missed_payments"] = int(loan.get("missed_payments", 0)) + 1
			loan["balance"] = balance + 45.0
			_force_expense(45.0, "loan_fee", "%s missed payment fee" % str(loan.get("name", "Loan")))


func _settle_events() -> void:
	for event in scheduled_events:
		if int(event.get("day", -1)) != day or str(event.get("status", "")) != "active":
			continue
		var attendance: int = int(event.get("attended", 0))
		var completed: int = int(event.get("rounds_completed", 0))
		var target: int = maxi(1, int(event.get("target", 1)))
		var completion_ratio: float = float(completed) / float(target)
		var attendance_ratio: float = float(attendance) / float(target)
		var success: bool = attendance_ratio >= 0.65 and completion_ratio >= 0.45
		event["status"] = "success" if success else "underperformed"
		event["result"] = "%s · %d attended · %d completed rounds" % ["Success" if success else "Underperformed", attendance, completed]
		event["attendance_ratio"] = attendance_ratio
		event["completion_ratio"] = completion_ratio
		if success:
			var earned: float = float(event.get("expected_revenue", 0.0)) * minf(1.25, attendance_ratio) * minf(1.0, completion_ratio / 0.7)
			if earned > 0.0:
				credit(earned, "event_revenue", "%s result" % str(event.get("name", "Event")))
				event["revenue"] = float(event.get("revenue", 0.0)) + earned
			publicity += float(event.get("publicity", 5.0)) * minf(1.25, attendance_ratio)
			satisfaction = minf(1.0, satisfaction + 0.025)
		else:
			publicity = maxf(0.0, publicity - 2.0)
			satisfaction = maxf(0.0, satisfaction - 0.018)
		event_history.append(event.duplicate(true))
	_active_event_id = -1


func _reset_arrivals() -> void:
	var base: float = 54.0 + float(grade) * 11.0 + publicity * 0.7
	var factors: Dictionary = demand_factors()
	base *= float(factors.get("satisfaction", 1.0))
	base *= float(factors.get("facilities", 1.0))
	base *= float(factors.get("facility_quality", 1.0))
	base *= float(factors.get("scenery", 1.0))
	base *= float(factors.get("wear", 1.0))
	base *= clampf(1.12 - (float(prices.get("green_fee", 48.0)) - 48.0) / 130.0, 0.35, 1.35)
	base *= clampf(float(_course_holes.size()) / 3.0, 0.25, 1.5)
	_arrival_target = clampi(int(round(base)), 8, 112)
	_arrived_today = 0
	_next_arrival_minute = _rng.randf_range(12.0, 24.0)
	_active_event_id = -1
	for event in scheduled_events:
		if int(event.get("day", -1)) == day and str(event.get("status", "scheduled")) == "scheduled":
			event["status"] = "active"
			_active_event_id = int(event.get("id", -1))
			_arrival_target = mini(120, _arrival_target + int(event.get("target", 0)))
			notice = "%s is underway" % str(event.get("name", "Event"))
			break


func _add_event_hole(group: Dictionary) -> void:
	var event: Dictionary = _event_by_id(int(group.get("event_id", -1)))
	if event.is_empty():
		return
	if not bool(group.get("event_counted", false)):
		event["attended"] = int(event.get("attended", 0)) + int(group.get("size", 1))
		group["event_counted"] = true
		var revenue: float = float(prices.get("event", 18.0)) * float(group.get("size", 1))
		event["revenue"] = float(event.get("revenue", 0.0)) + revenue
		credit(revenue, "event_revenue", "%s attendance" % str(event.get("name", "Event")))


func _update_grade() -> void:
	while grade < 3:
		var target_grade: int = grade + 1
		var definition: Dictionary = _grade_definition(target_grade)
		var requirements: Dictionary = definition.get("requirements", {})
		var required_satisfaction: float = 0.60 if target_grade == 2 else 0.70
		var maximum_wear: float = 0.50 if target_grade == 2 else 0.35
		if cash < float(requirements.get("cash", 0.0)) or _building_count() < int(requirements.get("buildings", 0)) or _course_holes.size() < int(requirements.get("holes", 0)) or publicity < float(requirements.get("publicity", 0.0)) or satisfaction < required_satisfaction or _terrain_wear() > maximum_wear or not _has_qualifying_event(target_grade):
			break
		grade = target_grade
		notice = "Resort upgraded to grade %d: %s" % [grade, str(definition.get("name", "new grade"))]


func _refresh_course() -> void:
	_course_holes.clear()
	if terrain == null:
		return
	if terrain.has_method("ready_holes"):
		var values = terrain.ready_holes()
		for value in values:
			_course_holes.append(value)
	elif "holes" in terrain:
		for value in terrain.holes:
			var hole: Dictionary = value
			if bool(hole.get("open", true)):
				_course_holes.append(hole)
	for hole in _course_holes:
		var hole_id: int = int(hole.get("id", -1))
		if not _hole_queues.has(hole_id):
			_hole_queues[hole_id] = []
		if not _hole_occupancy.has(hole_id):
			_hole_occupancy[hole_id] = -1


func _refresh_facilities(reset_values: bool = true) -> void:
	var seen: Dictionary = {}
	if terrain != null and "objects" in terrain:
		for value in terrain.objects:
			var object: Dictionary = value
			var kind: String = str(object.get("kind", ""))
			var definition: Dictionary = _catalog_find(kind)
			if definition.is_empty() or not definition.has("capacity"):
				continue
			var object_id: int = int(object.get("id", -1))
			seen[object_id] = true
			var state: Dictionary = _facility_state.get(object_id, {})
			if state.is_empty():
				state = {"id": object_id, "kind": kind}
			state["pos"] = object.get("pos", ENTRANCE)
			state["capacity"] = int(definition.get("capacity", 4))
			state["condition"] = float(object.get("condition", 1.0)) if reset_values else float(state.get("condition", object.get("condition", 1.0)))
			state["cleanliness"] = float(object.get("cleanliness", 1.0)) if reset_values else float(state.get("cleanliness", object.get("cleanliness", 1.0)))
			_facility_state[object_id] = state
	for key in _facility_state.keys():
		if not seen.has(key):
			_facility_state.erase(key)
			_facility_queues.erase(key)


func _check_terrain_revision() -> void:
	var revision: int = 0
	if terrain != null and "revision" in terrain:
		revision = int(terrain.revision)
	if revision != _route_revision:
		_route_revision = revision
		_route_cache.clear()


func _set_group_destination(group: Dictionary, destination: Vector3, use_cart: bool) -> void:
	var members: Array[Dictionary] = _group_guests(group)
	if members.is_empty():
		return
	var leader: Dictionary = members[0]
	if use_cart:
		var cart_start: Vector3 = group.get("cart_pos", leader.get("pos", ENTRANCE))
		var cart_path: PackedVector3Array = _raw_route(cart_start, destination, true)
		if not cart_path.is_empty():
			if not bool(group.get("cart_initialized", false)):
				group["cart_pos"] = cart_path[0]
				group["cart_initialized"] = true
			cart_start = group.get("cart_pos", cart_path[0])
			group["cart_route"] = cart_path
			group["cart_route_index"] = 1 if cart_path.size() > 1 else 0
			group["cart_phase"] = "walk_to_cart"
			group["cart_parked"] = true
			group["final_destination"] = destination
			for guest in members:
				guest["destination"] = cart_start
				guest["route"] = _route(guest.get("pos", ENTRANCE), cart_start, false)
				guest["route_index"] = 1 if (guest["route"] as PackedVector3Array).size() > 1 else 0
				guest["activity"] = "walking_to_cart"
				guest["cart_pos"] = group["cart_pos"]
			return
		group["cart"] = false
		group["cart_parked"] = true
		for guest in members:
			guest["cart"] = false
	var path: PackedVector3Array = _route(leader.get("pos", ENTRANCE), destination, false)
	group["final_destination"] = destination
	for guest in members:
		guest["destination"] = destination
		guest["route"] = path.duplicate()
		guest["route_index"] = 1 if path.size() > 1 else 0


func _move_group(group: Dictionary, dt: float) -> bool:
	var use_cart: bool = bool(group.get("cart", false))
	if use_cart:
		return _move_cart_group(group, dt)
	var arrived: bool = true
	for guest in _group_guests(group):
		if not _move_guest(guest, dt, false):
			arrived = false
	return arrived


func _move_cart_group(group: Dictionary, dt: float) -> bool:
	var members: Array[Dictionary] = _group_guests(group)
	if members.is_empty():
		return true
	var phase: String = str(group.get("cart_phase", "walk_to_cart"))
	if phase == "parked":
		return true
	if phase == "walk_to_cart":
		var gathered: bool = true
		for guest in members:
			guest["activity"] = "walking_to_cart"
			if not _move_person(guest, dt, WALK_SPEED):
				gathered = false
		if not gathered:
			return false
		var cart_path: PackedVector3Array = group.get("cart_route", PackedVector3Array())
		if cart_path.is_empty():
			group["cart"] = false
			_set_group_destination(group,group.get("final_destination",ENTRANCE),false)
			return false
		group["cart_phase"] = "riding"
		group["cart_parked"] = false
		for guest in members:
			guest["destination"] = cart_path[cart_path.size() - 1]
			guest["route"] = cart_path.duplicate()
			guest["route_index"] = 1 if cart_path.size() > 1 else 0
			guest["activity"] = "riding"
		phase = "riding"
	if phase == "riding":
		var parked: bool = true
		for guest in members:
			guest["activity"] = "riding"
			if not _move_person(guest, dt, CART_SPEED):
				parked = false
		group["cart_pos"] = members[0].get("pos", group.get("cart_pos", ENTRANCE))
		if not parked:
			return false
		group["cart_parked"] = true
		group["cart_phase"] = "walk_from_cart"
		var destination: Vector3 = group.get("final_destination", group["cart_pos"])
		for guest in members:
			guest["destination"] = destination
			guest["route"] = _route(guest.get("pos", group["cart_pos"]), destination, false)
			guest["route_index"] = 1 if (guest["route"] as PackedVector3Array).size() > 1 else 0
			guest["activity"] = "walking_from_cart"
		phase = "walk_from_cart"
	if phase == "walk_from_cart":
		var arrived: bool = true
		for guest in members:
			guest["activity"] = "walking_from_cart"
			if not _move_person(guest, dt, WALK_SPEED):
				arrived = false
		if arrived:
			group["cart_phase"] = "parked"
		return arrived
	return false


func _sync_cart_positions() -> void:
	for group in groups:
		if not bool(group.get("cart", false)):
			continue
		var cart_pos: Vector3 = group.get("cart_pos", ENTRANCE)
		for guest in _group_guests(group):
			guest["cart_pos"] = cart_pos


func _move_guest(guest: Dictionary, dt: float, use_cart: bool) -> bool:
	return _move_person(guest, dt, CART_SPEED if use_cart else WALK_SPEED)


func _move_person(person: Dictionary, dt: float, speed: float) -> bool:
	var destination: Vector3 = person.get("destination", person.get("pos", ENTRANCE))
	var pos: Vector3 = person.get("pos", ENTRANCE)
	var route: PackedVector3Array = person.get("route", PackedVector3Array())
	if route.is_empty():
		if pos.distance_to(destination) <= 0.15:
			person["pos"] = destination
			return true
		route = _route(pos, destination, speed > WALK_SPEED + 0.1)
		person["route"] = route
		person["route_index"] = 1 if route.size() > 1 else 0
	if route.is_empty():
		person["blocked"] = true
		return false
	person["blocked"] = false
	var distance_left: float = speed * dt * SIM_RATE * BASE_PACE
	var index: int = int(person.get("route_index", 0))
	while distance_left > 0.0 and index < route.size():
		var target: Vector3 = route[index]
		var segment: float = pos.distance_to(target)
		if segment <= distance_left + 0.001:
			pos = target
			distance_left -= segment
			index += 1
		else:
			pos = pos.move_toward(target, distance_left)
			distance_left = 0.0
	person["pos"] = pos
	person["route_index"] = index
	if index >= route.size() or pos.distance_to(destination) <= 0.15:
		person["pos"] = destination
		person["route"] = PackedVector3Array()
		person["route_index"] = 0
		return true
	return false


func _route(start: Vector3, destination: Vector3, cart: bool) -> PackedVector3Array:
	if start.distance_to(destination) <= 0.1:
		return PackedVector3Array([destination])
	var key: String = "%d:%d:%d:%d:%d" % [int(start.x / 4.0), int(start.z / 4.0), int(destination.x / 4.0), int(destination.z / 4.0), 1 if cart else 0]
	if _route_cache.has(key):
		return (_route_cache[key] as PackedVector3Array).duplicate()
	var result: PackedVector3Array = PackedVector3Array()
	if terrain != null and terrain.has_method("route"):
		result = terrain.route(start, destination, cart)
	if result.is_empty():
		return result
	_route_cache[key] = result.duplicate()
	return result


func _raw_route(start: Vector3, destination: Vector3, cart: bool) -> PackedVector3Array:
	if start.distance_to(destination) <= 0.15:
		return PackedVector3Array([destination])
	if terrain != null and terrain.has_method("route"):
		return terrain.route(start, destination, cart)
	return PackedVector3Array([start, destination])


func _rebuild_group_routes(group: Dictionary) -> bool:
	var members: Array[Dictionary] = _group_guests(group)
	var group_uses_cart: bool = bool(group.get("cart", false))
	for _pass_index in range(2):
		var all_valid: bool = true
		for guest in members:
			if not _guest_needs_route(group, guest):
				continue
			var start: Vector3 = guest.get("pos", ENTRANCE)
			var destination: Vector3 = guest.get("destination", start)
			var use_cart: bool = group_uses_cart and _guest_route_uses_cart(group, guest)
			var rebuilt: PackedVector3Array = _raw_route(start, destination, use_cart)
			if rebuilt.is_empty():
				all_valid = false
				break
			guest["route"] = rebuilt
			guest["route_index"] = 1 if rebuilt.size() > 1 else 0
		if all_valid:
			return true
		if not group_uses_cart:
			return false
		# A severed cart route can still become a safe walking round.
		group_uses_cart = false
		group["cart"] = false
		group["cart_parked"] = true
		for guest in members:
			guest["cart"] = false
	return false


func _guest_needs_route(group: Dictionary, guest: Dictionary) -> bool:
	var state: String = str(group.get("state", ""))
	if state in ["arriving", "to_tee", "departing", "facility_queue"]:
		return guest.get("pos", ENTRANCE).distance_to(guest.get("destination", ENTRANCE)) > 0.15
	if state == "playing" and str(group.get("play_phase", "")) == "walk":
		var members: Array = group.get("members", [])
		var turn: int = int(group.get("player_turn", 0))
		return turn >= 0 and turn < members.size() and int(members[turn]) == int(guest.get("id", -1))
	return false


func _guest_route_uses_cart(group: Dictionary, guest: Dictionary) -> bool:
	var activity: String = str(guest.get("activity", ""))
	if activity in ["walking", "walking_to_ball"]:
		return false
	if activity in ["riding", "riding_to_ball"]:
		return true
	return bool(group.get("cart", false)) and str(group.get("cart_phase","")) == "riding"


func _point_in_edit(point: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius + 4.0


func _path_intersects_edit(path: PackedVector3Array, center: Vector3, radius: float) -> bool:
	if path.is_empty():
		return false
	if _point_in_edit(path[0], center, radius):
		return true
	for index in range(1, path.size()):
		if _segment_distance_2d(center, path[index - 1], path[index]) <= radius + 4.0:
			return true
	return false


func _shot_intersects_edit(shot: Dictionary, center: Vector3, radius: float) -> bool:
	if shot.is_empty():
		return false
	var start: Vector3 = shot.get("start", center)
	var landing: Vector3 = shot.get("landing", start)
	var finish: Vector3 = shot.get("end", landing)
	return _segment_distance_2d(center, start, landing) <= radius + 4.0 or _segment_distance_2d(center, landing, finish) <= radius + 4.0


func _segment_distance_2d(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var point_2d: Vector2 = Vector2(point.x, point.z)
	var start_2d: Vector2 = Vector2(start.x, start.z)
	var delta: Vector2 = Vector2(finish.x, finish.z) - start_2d
	if delta.length_squared() <= 0.0001:
		return point_2d.distance_to(start_2d)
	var along: float = clampf((point_2d - start_2d).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point_2d.distance_to(start_2d + delta * along)


func _construction_safe_position(pos: Vector3, center: Vector3, radius: float) -> Vector3:
	var safe: Vector3 = _safe_position(pos)
	if not _point_in_edit(safe, center, radius):
		return safe
	var outward: Vector3 = Vector3(pos.x - center.x, 0.0, pos.z - center.z)
	if outward.length_squared() < 0.001:
		outward = Vector3(1.0, 0.0, 0.0)
	outward = outward.normalized()
	for index in range(12):
		var angle: float = float(index) * TAU / 12.0
		var direction: Vector3 = outward.rotated(Vector3.UP, angle)
		var candidate: Vector3 = center + direction * (radius + 8.0)
		candidate = _safe_position(candidate)
		if not _point_in_edit(candidate, center, radius):
			return candidate
	return ENTRANCE


func _group_leader_position(group: Dictionary) -> Vector3:
	var members: Array[Dictionary] = _group_guests(group)
	return members[0].get("pos", ENTRANCE) if not members.is_empty() else ENTRANCE


func _pay_construction_compensation(group: Dictionary, amount: float, guest_ids: Array) -> void:
	if amount <= 0.0:
		return
	var recipients: Array[Dictionary] = []
	for guest in _group_guests(group):
		if guest_ids.is_empty() or guest_ids.has(int(guest.get("id", -1))):
			recipients.append(guest)
	if recipients.is_empty():
		return
	var per_guest: float = amount / float(recipients.size())
	for guest in recipients:
		guest["budget"] = float(guest.get("budget", 0.0)) + per_guest
	_force_expense(amount, "construction_compensation", "Interrupted activity compensation for group %d" % int(group.get("id", -1)))


func _fallback_shot(start: Vector3, hole: Dictionary, skill: float) -> Dictionary:
	var cup: Vector3 = hole.get("cup", start)
	var distance: float = start.distance_to(cup)
	var reach: float = minf(distance, lerpf(70.0, 205.0, skill) * _rng.randf_range(0.82, 1.05))
	var direction: Vector3 = start.direction_to(cup)
	var sideways: Vector3 = Vector3(-direction.z, 0.0, direction.x) * _rng.randfn(0.0, (1.0 - skill) * reach * 0.09)
	var end: Vector3 = start + direction * reach + sideways
	if terrain != null and terrain.has_method("nearest_safe"):
		end = terrain.nearest_safe(end)
	var holed: bool = distance <= 3.0 or end.distance_to(cup) <= 1.2
	if holed:
		end = cup
	return {"start": start, "landing": end, "end": end, "target": cup, "arc": 0.3, "duration": clampf(distance / 60.0, 0.7, 3.4), "club": "Putter" if distance < 18.0 else "Iron", "penalty": 0, "holed": holed, "hazard": false, "reason": ""}


func _shot_thought(shot: Dictionary) -> String:
	if bool(shot.get("holed", false)):
		return "It’s in!"
	if bool(shot.get("hazard", false)):
		return "That found trouble. I can recover."
	var club: String = str(shot.get("club", "club"))
	return "A %s should set up the next shot." % club.to_lower()


func _group_guests(group: Dictionary) -> Array[Dictionary]:
	var id=int(group.get("id",-1))
	if _guests_by_group.has(id):return _guests_by_group[id]
	var result: Array[Dictionary] = []
	var member_ids: Array = group.get("members", [])
	for guest in guests:
		if member_ids.has(int(guest.get("id", -1))):
			result.append(guest)
	_guests_by_group[id]=result
	return result


func _group_by_id(id: int) -> Dictionary:
	if _groups_by_id.has(id):return _groups_by_id[id]
	for group in groups:
		if int(group.get("id", -1)) == id:
			_groups_by_id[id]=group
			return group
	return {}


func _hole_by_id(id: int) -> Dictionary:
	for hole in _course_holes:
		if int(hole.get("id", -1)) == id:
			return hole
	return {}


func start_position(hole: Dictionary) -> Vector3:
	return hole.get("tee", ENTRANCE)


func _facility_by_kind(kind: String) -> Dictionary:
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		if str(state.get("kind", "")) == kind:
			return state
	return {}


func _best_facility(kind: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -1000.0
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		if str(state.get("kind", "")) != kind:
			continue
		var score: float = float(state.get("condition", 0.0)) + float(state.get("cleanliness", 0.0)) - float(_queue_for_facility(int(state.get("id", -1))).size()) * 0.1
		if score > best_score:
			best_score = score
			best = state
	return best


func _has_facility(kind: String) -> bool:
	return not _facility_by_kind(kind).is_empty()


func _cart_available() -> bool:
	var barn: Dictionary = _facility_by_kind("cart_barn")
	if barn.is_empty():
		return false
	var carts_in_use: int = 0
	for group in groups:
		if bool(group.get("cart", false)) and str(group.get("state", "")) != "departed":
			carts_in_use += 1
	return carts_in_use < int(barn.get("capacity", 0))


func _queue_for_facility(id: int) -> Array:
	return _facility_queues.get(id, [])


func _remove_from_facility_queue(group: Dictionary) -> void:
	var facility_id: int = int(group.get("facility_id", -1))
	if _facility_queues.has(facility_id):
		var queue: Array = _facility_queues[facility_id]
		queue.erase(int(group.get("id", -1)))
		_facility_queues[facility_id] = queue
	group["facility_id"] = -1


func _facility_service_rate(facility_id: int) -> float:
	var workers: int = _service_workers_at(facility_id)
	var state: Dictionary = _facility_state.get(facility_id, {})
	var quality: float = minf(float(state.get("condition", 1.0)), float(state.get("cleanliness", 1.0)))
	return maxf(0.4, quality) * (1.0 + float(workers) * 0.65)


func _workers_at(facility_id: int) -> int:
	var count: int = 0
	for worker in staff:
		if int(worker.get("assignment", -1)) == facility_id or worker.get("pos", ENTRANCE).distance_to(_facility_state.get(facility_id, {}).get("pos", ENTRANCE)) < 12.0:
			count += 1
	return count


func _service_workers_at(facility_id: int) -> int:
	var count: int = 0
	var target_pos: Vector3 = _facility_state.get(facility_id, {}).get("pos", ENTRANCE)
	for worker in staff:
		if str(worker.get("role", "")) != "service_attendant":
			continue
		if int(worker.get("assignment", -1)) == facility_id or (int(worker.get("assignment", -1)) < 0 and worker.get("pos", ENTRANCE).distance_to(target_pos) < 12.0):
			count += 1
	return count


func _facility_duration(kind: String) -> float:
	match kind:
		"driving_range": return 150.0
		"snack_kiosk": return 55.0
		"restroom": return 38.0
		_: return 60.0


func _group_average(group: Dictionary, field: String) -> float:
	var members: Array[Dictionary] = _group_guests(group)
	if members.is_empty():
		return 0.0
	var total: float = 0.0
	for guest in members:
		total += float(guest.get(field, 0.0))
	return total / float(members.size())


func _apply_wait_mood(group: Dictionary, dt: float, grace_seconds: float) -> void:
	if float(group.get("wait_seconds", 0.0)) <= grace_seconds:
		return
	for guest in _group_guests(group):
		guest["mood"] = maxf(0.0, float(guest.get("mood", 0.5)) - dt * 0.00008)
		guest["thought"] = "This queue is taking too long."


func _guest_purchase(guest: Dictionary, amount: float, category: String, description: String) -> bool:
	if float(guest.get("budget", 0.0)) + 0.001 < amount:
		guest["thought"] = "I’ll save my remaining cash."
		return false
	guest["budget"] = float(guest.get("budget", 0.0)) - amount
	guest["spent"] = float(guest.get("spent", 0.0)) + amount
	credit(amount, category, description)
	return true


func _checkin_capacity() -> int:
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	var quality: float = minf(float(clubhouse.get("condition", 1.0)), float(clubhouse.get("cleanliness", 1.0)))
	var base: int = maxi(1, int(round(float(int(clubhouse.get("capacity", 4)) / 4) * clampf(quality, 0.35, 1.0))))
	return base + _service_workers_at(int(clubhouse.get("id", -1)))


func _state_queue_position(state: String, group_id: int) -> int:
	var ids: Array[int] = []
	for group in groups:
		if str(group.get("state", "")) == state:
			ids.append(int(group.get("id", -1)))
	ids.sort()
	return ids.find(group_id)


func _role_count(role: String) -> int:
	var count: int = 0
	for worker in staff:
		if str(worker.get("role", "")) == role:
			count += 1
	return count


func _add_staff(role: String, stagger: bool) -> void:
	var definition: Dictionary = _role_definition(role)
	var id: int = _next_staff_id
	_next_staff_id += 1
	staff.append({
		"id": id, "name": "%s %02d" % [str(definition.get("name", role.capitalize())), id],
		"role": role, "pos": ENTRANCE + Vector3(float(id % 3) * 1.3, 0.0, float(id % 2) * 1.1),
		"destination": ENTRANCE, "activity": "starting" if stagger else "available", "assignment": -1,
		"wage": float(definition.get("wage", definition.get("daily_wage", 150.0))),
		"skill": float(definition.get("skill", 0.7)),
		"route": PackedVector3Array(), "route_index": 0,
	})


func _role_definition(role: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("staff_roles"):
		for value in _catalog_script.staff_roles():
			var item: Dictionary = value
			if str(item.get("id", "")) == role:
				return item
	return DEFAULT_ROLES.get(role, {})


func _loan_definition(product: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("loans"):
		for value in _catalog_script.loans():
			var item: Dictionary = value
			if str(item.get("id", "")) == product:
				return item
	return DEFAULT_LOANS.get(product, {})


func _event_definition(kind: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("events"):
		for value in _catalog_script.events():
			var item: Dictionary = value
			if str(item.get("id", "")) == kind:
				return item
	return DEFAULT_EVENTS.get(kind, {})


func _catalog_find(kind: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("find"):
		var found = _catalog_script.find(kind)
		if found is Dictionary:
			return found
	return {}


func _event_by_id(id: int) -> Dictionary:
	for event in scheduled_events:
		if int(event.get("id", -1)) == id:
			return event
	return {}


func _has_qualifying_event(target_grade: int) -> bool:
	var accepted: Array = ["open_day", "charity_scramble", "beginner_clinic"] if target_grade == 2 else ["club_championship", "regional_amateur"]
	for event in event_history:
		if str(event.get("status", "")) == "success" and accepted.has(str(event.get("kind", ""))):
			return true
	return false


func _terrain_wear() -> float:
	if terrain != null and "wear" in terrain:
		return clampf(float(terrain.wear), 0.0, 1.0)
	return 0.0


func _grade_definition(target_grade: int) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("grades"):
		for value in _catalog_script.grades():
			var item: Dictionary = value
			if int(item.get("grade", -1)) == target_grade:
				return item
	if target_grade == 2:
		return {"grade": 2, "name": "Club", "requirements": {"cash": 45000.0, "buildings": 3, "holes": 6, "publicity": 18.0}}
	return {"grade": 3, "name": "Resort", "requirements": {"cash": 120000.0, "buildings": 6, "holes": 9, "publicity": 42.0}}


func _usable_facility_count() -> int:
	var count: int = 0
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		if float(state.get("condition", 0.0)) >= 0.3 and float(state.get("cleanliness", 0.0)) >= 0.2:
			count += 1
	return count


func _building_count() -> int:
	return _facility_state.size()


func _safe_position(pos: Vector3) -> Vector3:
	if terrain != null and terrain.has_method("nearest_safe"):
		return terrain.nearest_safe(pos)
	return ENTRANCE


func _sync_facility_object(state: Dictionary) -> void:
	if terrain == null or not ("objects" in terrain):
		return
	var state_id: int = int(state.get("id", -1))
	for object_value in terrain.objects:
		var object: Dictionary = object_value
		if int(object.get("id", -2)) == state_id:
			object["condition"] = float(state.get("condition", 1.0))
			object["cleanliness"] = float(state.get("cleanliness", 1.0))
			return


func _force_expense(amount: float, category: String, description: String) -> void:
	amount = maxf(0.0, amount)
	if not sandbox:
		cash -= amount
	_today_expense += amount
	_record(-amount, category, description)


func _is_discretionary_charge(category: String) -> bool:
	return not category in ["loan_payment", "refund", "guest_recovery", "construction_compensation", "wages", "upkeep", "interest", "loan_fee"]


func _has_unpaid_bills() -> bool:
	for loan in loans:
		if int(loan.get("missed_payments", 0)) > 0:
			return true
	return false


func _recovery_reserve() -> float:
	var reserve: float = 0.0
	for worker in staff:
		reserve += float(worker.get("wage", 0.0))
	for loan in loans:
		if float(loan.get("balance", 0.0)) > 0.0:
			reserve += float(loan.get("daily_payment", 0.0))
	return maxf(500.0, reserve)


func _record(amount: float, category: String, description: String) -> void:
	ledger.append({"day": day, "minute": minute, "amount": amount, "category": category, "description": description, "balance": cash})


func _cleanup_departed() -> void:
	_guests_by_group.clear()
	_groups_by_id.clear()
	var retained_guests: Array[Dictionary] = []
	for guest in guests:
		if str(guest.get("activity", "")) != "departed":
			retained_guests.append(guest)
	guests = retained_guests
	var retained_groups: Array[Dictionary] = []
	for group in groups:
		if str(group.get("state", "")) != "departed":
			retained_groups.append(group)
	groups = retained_groups
