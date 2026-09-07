class_name ResortSimulation
extends RefCounted

## Data-only resort operations simulation. The scene layer polls these dictionaries.

const OPERATING_MINUTES: float = 600.0
## Calendar and actors deliberately use different time scales. The caller
## advances this clock in calendar seconds; physical systems consume
## dt / SIM_RATE actor-seconds. Speed controls affect both at the caller.
const DAY_SIM_SECONDS: float = 800.0
const DAYS_PER_MONTH: int = 30
const MONTH_ABBREVIATIONS: Array[String] = [
	"Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb"
]
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Fall", "Winter"]
## Per-season demand multipliers, indexed like SEASON_NAMES.
const SEASON_DEMAND: Array[float] = [1.05, 1.2, 0.95, 0.7]
const MAX_GUESTS: int = 200
const PATRONS_CAP: int = 600
const PATRON_HISTORY_CAP: int = 10
const PATRON_SCORECARDS_CAP: int = 5
const ENTRANCE: Vector3 = Vector3(64.0, 0.0, 64.0)
const WALK_SPEED: float = 1.8
const CART_SPEED: float = 6.5
const MAX_SUBSTEP: float = 6.0 # 0.1 actor-second at 1x
## Calendar seconds per actor-second at 1x.
const SIM_RATE: float = 60.0
## Base visual pace multiplier at 1x. Chosen so an 18-hole round takes the
## majority of a 20-minute season while walking still looks brisk (~1.6x realtime).
const BASE_PACE: float = 1.6
## Flight-time stretch for shots; the visible ball hangs this much longer.
const SHOT_PACE: float = 1.5
const MAX_STROKES: int = 14
const EVENT_KINDS: Array[String] = [
	"open_day", "charity_scramble", "beginner_clinic", "club_championship",
	"regional_amateur", "invitational"
]
const DEFAULT_ROLES: Dictionary = {
	"groundskeeper": {"name": "Groundskeeper", "wage": 185.0, "grade": 1},
	"service_attendant": {"name": "Service attendant", "wage": 155.0, "grade": 1},
	"cleaner": {"name": "Cleaner", "wage": 145.0, "grade": 1},
	"golf_pro": {"name": "Golf pro", "wage": 240.0, "grade": 2},
	"shop_clerk": {"name": "Shop clerk", "wage": 130.0, "grade": 2},
	"marshal": {"name": "Marshal", "wage": 150.0, "grade": 2},
	"head_greenkeeper": {"name": "Head greenkeeper", "wage": 300.0, "grade": 3},
}
const STAFF_TRAIT_IDS: Array[String] = ["quick_learner", "mentor", "night_owl", "grumpy", "careful"]
const FATIGUE_RATE: float = 0.0011
const FATIGUE_WARN_THRESHOLD: float = 0.8
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
var candidates: Array[Dictionary] = []
var groups: Array[Dictionary] = []
var cash: float = 180000.0
var day: int = 1
var calendar_second: float = 0.0
var minute: float = 0.0 # Deprecated compatibility alias for calendar_second.
## Time within the current calendar day (0..DAY_SIM_SECONDS) and monotonic
## actor-seconds since the resort opened, for physical durations spanning days.
var _day_seconds: float = 0.0
var _actor_elapsed_seconds: float = 0.0
## Monthly settlement counter; the view autosaves whenever it changes.
var settlements: int = 0
## Master switch for walk-in demand; suspended arrivals still let active
## golfers finish their rounds.
var arrivals_enabled: bool = true
var _period_arrivals: int = 0
var sandbox: bool = false
var prices: Dictionary = {}
## Public course rating (1..5 stars) from guest reviews; negative until seeded.
var rating: float = -1.0
var awareness: float = 0.0
var buzz: float = 0.0
var campaigns: Array[Dictionary] = []
var press_headlines: Array[String] = []
var ledger: Array[Dictionary] = []
var loans: Array[Dictionary] = []
var scheduled_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var grade: int = 1
var publicity: float = 0.0
var open: bool = true
var game_over: bool = false
var game_over_reason: String = ""
var satisfaction: float = 0.72
var completed_visits: int = 0
var unlocked: Array[String] = []
var projects: Array[Dictionary] = []
var notice: String = ""
var log: Array[Dictionary] = []
var last_seen_log_id: int = 0
var history: Array[Dictionary] = []
var today_series: Array[Dictionary] = []
var records: Dictionary = {}
var reviews: Array[Dictionary] = []
var daily_feedback: Dictionary = {}
var patrons: Dictionary = {}
var membership_dues: Dictionary = {"social": 180.0, "player": 520.0, "founder": 1400.0}
var membership_open: Dictionary = {"social": true, "player": true, "founder": true}
var analytics: AnalyticsGrid = AnalyticsGrid.new()
var hole_metrics: Dictionary = {}

const LOG_CAP: int = 500
const SEVERITY_ORDER: Dictionary = {"info": 0, "success": 1, "warning": 2, "critical": 3}
const TAB_IDS: Dictionary = {"Terrain": 0, "Holes": 1, "Build": 2, "Guests": 3, "Staff": 4, "Money": 5, "Events": 6, "Marketing": 7, "Progress": 8, "Statistics": 9, "Saves": 10}
const MAX_CONCURRENT_PROJECTS: int = 2
const MAX_CONCURRENT_CAMPAIGNS: int = 2
const STARTER_AWARENESS: float = 48.0
const RATING_HALF_LIFE_DAYS: float = 14.0
const BUZZ_DAILY_DECAY: float = 0.6
const AWARENESS_DAILY_DECAY: float = 0.015
const RATING_TAG_FAMILIES: Dictionary = {
	"course": ["poor_greens", "hazard", "great_hole"],
	"facilities": ["dirty_facility", "broken_facility", "served_snack", "served_range", "served_restroom"],
	"service": ["wait_tee", "wait_checkin", "wait_facility"],
	"value": ["too_expensive"],
	"scenery": ["bland_scenery", "lovely_scenery"],
}
const HISTORY_CAP: int = 365
## Demand was authored against the 36,000-second operating day; this converts
## the marketing demand model to the 800-second calendar day with headroom so
## relative demand differences stay visible in whole-guest targets.
const TARGET_ROUND_ACTOR_SECONDS: float = 900.0
const AVERAGE_GROUP_SIZE: float = 2.5
const TARGET_COURSE_UTILIZATION: float = 0.78
const TODAY_SERIES_INTERVAL: float = DAY_SIM_SECONDS / 30.0
const TODAY_SERIES_MAX: int = 60
const FEEDBACK_CAP: int = 12
const REVIEWS_CAP: int = 400
const FEEDBACK_TEXT: Dictionary = {
	"wait_tee": "Long waits at the tee",
	"wait_checkin": "Slow check-in at the clubhouse",
	"wait_facility": "Long waits at resort facilities",
	"served_snack": "Enjoyed a snack stop",
	"served_range": "Helpful warm-up at the range",
	"served_restroom": "Appreciated a clean restroom stop",
	"unmet_hunger": "Could not find food when hungry",
	"unmet_restroom": "Restroom needs went unmet",
	"hazard": "Trouble on the course",
	"great_hole": "A memorable hole",
	"refund_closure": "Refund after an unexpected closure",
	"refund_construction": "Refund after construction interrupted play",
	"refund_closing_time": "Refund when the course closed for the day",
	"dirty_facility": "Facilities felt unclean",
	"broken_facility": "Facilities felt broken or unusable",
	"too_expensive": "Green fees felt too high",
	"bland_scenery": "Scenery felt plain",
	"lovely_scenery": "Beautiful scenery on the course",
	"completed_round": "Finished a full round",
	"poor_greens": "Greens were bumpy and slow",
	"member_join": "Joined as a member",
	"member_cancel": "Cancelled membership",
}
const FEEDBACK_NEGATIVE_TAGS: Array[String] = [
	"wait_tee", "wait_checkin", "wait_facility", "unmet_hunger", "unmet_restroom", "hazard",
	"refund_closure", "refund_construction", "refund_closing_time", "dirty_facility",
	"broken_facility", "too_expensive", "bland_scenery", "poor_greens",
]
const FEEDBACK_POSITIVE_TAGS: Array[String] = [
	"served_snack", "served_range", "served_restroom", "great_hole", "lovely_scenery", "completed_round",
]
const WEEKDAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const PRICE_BOOK_KEYS: Array[String] = [
	"green_fee", "cart", "range", "snack", "lesson", "event_entry", "retail", "meal", "room",
]
const DEFAULT_PRICES: Dictionary = {
	"green_fee": {"base": 48.0, "twilight": 32.0, "weekend": 58.0, "twilight_start_minute": 420.0},
	"cart": {"base": 22.0}, "range": {"base": 12.0}, "snack": {"base": 9.0}, "lesson": {"base": 35.0},
	"event_entry": {"base": 18.0}, "retail": {"base": 42.0}, "meal": {"base": 28.0}, "room": {"base": 120.0},
	"group_discount": 0.10, "member_discount": 0.15, "replay_fee": 24.0, "bundle_weekend_cart": false,
}
const FEEDBACK_REFUND_TAGS: Array[String] = [
	"refund_closure", "refund_construction", "refund_closing_time",
]

var _tick_accumulator: float = 0.0
var _next_log_id: int = 1
var _facility_warn_day: Dictionary = {}
var _cart_cap_since: float = -1.0
var _tee_queue_since: Dictionary = {}
var _hole_open_state: Dictionary = {}
var _guests_by_group: Dictionary = {}
var _groups_by_id: Dictionary = {}
var _has_departed = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_guest_id: int = 1
var _next_group_id: int = 1
var _next_staff_id: int = 1
var _next_candidate_id: int = 1
var _next_loan_id: int = 1
var _next_event_id: int = 1
var _arrival_target: int = 0
var _demand_carry: float = 0.0
var _arrived_today: int = 0
## Countdown in sim seconds until the next group may arrive.
var _next_arrival_in: float = 20.0
var _course_holes: Array[Dictionary] = []
var _hole_queues: Dictionary = {}
var _hole_occupancy: Dictionary = {}
var _facility_queues: Dictionary = {}
var _facility_state: Dictionary = {}
var _route_cache: Dictionary = {}
var _route_revision: int = -1
var _course_metrics_cache: Dictionary = {}
var _course_metrics_revision: int = -1
var _today_revenue: float = 0.0
var _today_expense: float = 0.0
var _today_by_category: Dictionary = {"revenue": {}, "expenses": {}}
var _today_cash_open: float = 0.0
var _today_groups: int = 0
var _today_completed_rounds: int = 0
var _today_refunds: float = 0.0
var _today_spend_total: float = 0.0
var _today_spend_guests: int = 0
var _today_mood_sum: float = 0.0
var _today_mood_count: int = 0
var _wait_tee_seconds: float = 0.0
var _wait_checkin_seconds: float = 0.0
var _max_tee_queue: int = 0
var _facility_visits: Dictionary = {}
var _facility_revenue: Dictionary = {}
var _hole_stats_today: Dictionary = {}
var _last_series_sample_minute: float = -TODAY_SERIES_INTERVAL
var _today_peak_guests: int = 0
var _today_peak_queue: int = 0
var _today_peak_queue_minute: float = 0.0
var _today_balked: int = 0
var _rating_sum: float = 3.0
var _rating_weight: float = 1.0
var _loyalty_mailer_days: int = 0
var _next_patron_id: int = 1
var _member_arrival_queue: Array[int] = []
var _member_arrival_index: int = 0
var _membership_churn_log: Array[Dictionary] = []
var _course_record_press_day: int = -1
var _facility_unusable_day: bool = false
var _positive_streak: int = 0
var _insolvent_days: int = 0
var _closed_reason: String = ""
var _active_event_id: int = -1
var _catalog_script
var _shot_script


func _entrance() -> Vector3:
	if terrain != null and terrain is TerrainModel:
		return terrain.entrance
	return ENTRANCE


func setup(terrain_ref, sandbox_mode: bool, starter: bool, map_def: Dictionary = {}) -> void:
	_guests_by_group.clear()
	_groups_by_id.clear()
	_has_departed=false
	_tick_accumulator=0
	terrain = terrain_ref
	sandbox = sandbox_mode
	cash = float(map_def.get("starting_cash", 180000.0 if starter else 350000.0))
	day = 1
	minute = 0.0
	calendar_second = 0.0
	_day_seconds = 0.0
	_actor_elapsed_seconds = 0.0
	settlements = 0
	_period_arrivals = 0
	_demand_carry = 0.0
	arrivals_enabled = true
	open = true
	game_over = false
	game_over_reason = ""
	grade = 1
	awareness = STARTER_AWARENESS if starter else 0.0
	buzz = 0.0
	campaigns.clear()
	press_headlines.clear()
	satisfaction = 0.72
	_rating_sum = 3.0
	_rating_weight = 1.0
	rating = 3.0
	_loyalty_mailer_days = 0
	_course_record_press_day = -1
	_facility_unusable_day = false
	_update_derived_publicity()
	completed_visits = 0
	unlocked.clear()
	projects.clear()
	notice = ""
	log.clear()
	last_seen_log_id = 0
	history.clear()
	today_series.clear()
	records = {}
	reviews.clear()
	daily_feedback.clear()
	patrons.clear()
	membership_dues = {"social": 180.0, "player": 520.0, "founder": 1400.0}
	membership_open = {"social": true, "player": true, "founder": true}
	_next_patron_id = 1
	_member_arrival_queue.clear()
	_member_arrival_index = 0
	_membership_churn_log.clear()
	analytics = AnalyticsGrid.new()
	hole_metrics.clear()
	_course_metrics_cache.clear()
	_course_metrics_revision = -1
	_reset_daily_accumulators()
	_today_cash_open = cash
	_next_log_id = 1
	_facility_warn_day.clear()
	_cart_cap_since = -1.0
	_tee_queue_since.clear()
	_hole_open_state.clear()
	prices = _default_prices()
	guests.clear()
	staff.clear()
	candidates.clear()
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
	_next_candidate_id = 1
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
	_bootstrap_unlocks(starter)
	_refill_candidates()
	_record(0.0, "capital", "Opening balance")
	post("info", "system", "Resort open")


func post(severity: String, category: String, text: String, pos: Vector3 = Vector3.INF, target: Dictionary = {}) -> void:
	if not log.is_empty():
		var last: Dictionary = log.back()
		if int(last.get("day", -1)) == day and str(last.get("category", "")) == category and str(last.get("text", "")) == text:
			last["count"] = int(last.get("count", 1)) + 1
			if SEVERITY_ORDER.get(severity, 0) >= SEVERITY_ORDER.get("warning", 2):
				notice = text
			return
	var entry: Dictionary = {
		"id": _next_log_id, "day": day, "minute": minute, "severity": severity, "category": category,
		"text": text, "count": 1,
	}
	if pos.is_finite():
		entry["pos"] = pos
	if not target.is_empty():
		entry["target"] = target.duplicate(true)
	_next_log_id += 1
	log.append(entry)
	while log.size() > LOG_CAP:
		log.pop_front()
	if SEVERITY_ORDER.get(severity, 0) >= SEVERITY_ORDER.get("warning", 2):
		notice = text


func unread_count(severity_at_least: String = "warning") -> int:
	var threshold: int = int(SEVERITY_ORDER.get(severity_at_least, 2))
	var count: int = 0
	for entry in log:
		if int(entry.get("id", 0)) <= last_seen_log_id:
			continue
		if int(SEVERITY_ORDER.get(str(entry.get("severity", "info")), 0)) >= threshold:
			count += 1
	return count


func _tab_target(tab_name: String) -> Dictionary:
	return {"kind": "tab", "id": int(TAB_IDS.get(tab_name, 10))}


func tick(dt: float) -> void:
	if dt <= 0.0 or game_over:
		return
	_tick_accumulator += dt
	while _tick_accumulator + 0.0000001 >= MAX_SUBSTEP:
		_tick_step(MAX_SUBSTEP)
		_tick_accumulator = maxf(0.0,_tick_accumulator-MAX_SUBSTEP)


func _tick_step(dt: float) -> void:
	var actor_dt: float = dt / SIM_RATE
	_check_terrain_revision()
	_tick_staff(actor_dt)
	_tick_groups(actor_dt)
	if _has_departed:
		_cleanup_departed()
		_has_departed=false
	_sync_cart_positions()
	_tick_facility_decay(actor_dt)
	_tick_watchdogs(actor_dt)
	_maybe_sample_today_series()
	_day_seconds += dt
	_actor_elapsed_seconds += actor_dt
	calendar_second = _day_seconds
	minute = calendar_second
	_spawn_due_arrivals(dt)
	while _day_seconds + 0.000001 >= DAY_SIM_SECONDS:
		_day_seconds -= DAY_SIM_SECONDS
		_roll_day()


## Calendar helpers. Day 1 is March 1 of Year 1; every month has 30 days so a
## quarter is exactly 90 days.


func month_index_for(calendar_day: int) -> int:
	return int((calendar_day - 1) % 360) / DAYS_PER_MONTH


func month_index() -> int:
	return month_index_for(day)


func year_number() -> int:
	return 1 + int((day - 1) / 360)


func day_of_month() -> int:
	return int((day - 1) % DAYS_PER_MONTH) + 1


func season_index_for(calendar_day: int) -> int:
	return month_index_for(calendar_day) / 3


func season_index() -> int:
	return season_index_for(day)


func season_name() -> String:
	return SEASON_NAMES[season_index()]


func date_string() -> String:
	return date_string_for(day)


func date_string_for(calendar_day: int) -> String:
	return "%s %d, Year %d" % [MONTH_ABBREVIATIONS[month_index_for(calendar_day)], int((calendar_day - 1) % DAYS_PER_MONTH) + 1, year_number_for(calendar_day)]


func year_number_for(calendar_day: int) -> int:
	return 1 + int((calendar_day - 1) / 360)


func season_name_for(calendar_day: int) -> String:
	return SEASON_NAMES[season_index_for(calendar_day)]


func weather() -> String:
	return ["rain", "clear", "leaves", "snow"][season_index()]


func clock_string() -> String:
	var hours: float = fmod(_day_seconds / DAY_SIM_SECONDS * 24.0 + 6.0, 24.0)
	return "%s %02d:%02d" % [WEEKDAY_NAMES[weekday(day)], int(hours), int(fmod(hours, 1.0) * 60.0)]


func weekday(calendar_day: int) -> int:
	return (calendar_day - 1) % 7


func is_weekend(calendar_day: int) -> bool:
	return weekday(calendar_day) >= 5


func rating_or_satisfaction() -> float:
	if rating >= 0.0:
		return rating
	return satisfaction


func _effective_rating() -> float:
	if _rating_weight > 0.001:
		return clampf(_rating_sum / _rating_weight, 1.0, 5.0)
	return 3.0


func _update_derived_publicity() -> void:
	rating = _effective_rating()
	publicity = clampf(awareness * (0.4 + 0.15 * rating) + buzz, 0.0, 100.0)


func _campaign_definition(campaign_id: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("campaign"):
		return _catalog_script.campaign(campaign_id)
	return {}


func can_campaign(campaign_id: String) -> bool:
	var definition: Dictionary = _campaign_definition(campaign_id)
	if definition.is_empty():
		return false
	if sandbox:
		return true
	if grade < int(definition.get("min_grade", 1)):
		return false
	if definition.has("min_rating") and _effective_rating() < float(definition.get("min_rating", 0.0)):
		return false
	var grant_key: String = str(definition.get("grant", ""))
	if not grant_key.is_empty() and not _grant_from_completed(grant_key):
		return false
	return true


func start_campaign(campaign_id: String) -> String:
	var definition: Dictionary = _campaign_definition(campaign_id)
	if definition.is_empty():
		return "Unknown campaign"
	if campaigns.size() >= MAX_CONCURRENT_CAMPAIGNS:
		return "Only two campaigns can run at once"
	for active in campaigns:
		if str(active.get("id", "")) == campaign_id:
			return "%s is already running" % str(definition.get("name", campaign_id))
	if not can_campaign(campaign_id):
		return "%s is not available yet" % str(definition.get("name", campaign_id))
	var cost: float = float(definition.get("cost", 0.0))
	if not charge(cost, "marketing", "%s · day 1" % str(definition.get("name", campaign_id))):
		return notice if not notice.is_empty() else "Insufficient funds"
	var entry: Dictionary = {
		"id": campaign_id,
		"days_left": maxi(1, int(definition.get("days", 1))),
		"started_day": day,
	}
	campaigns.append(entry)
	if definition.has("buzz_once"):
		buzz = clampf(buzz + float(definition.get("buzz_once", 0.0)), -20.0, 20.0)
	if bool(definition.get("expert_group", false)):
		_spawn_pro_visit_group()
	if int(definition.get("loyalty_days", 0)) > 0:
		_loyalty_mailer_days = maxi(_loyalty_mailer_days, int(definition.get("loyalty_days", 0)))
	_update_derived_publicity()
	post("info", "event", "Started %s" % str(definition.get("name", campaign_id)), Vector3.INF, _tab_target("Marketing"))
	return "%s started · $%s charged" % [str(definition.get("name", campaign_id)), _money_text(cost)]


func stop_campaign(campaign_id: String) -> String:
	for index in range(campaigns.size()):
		if str(campaigns[index].get("id", "")) != campaign_id:
			continue
		var definition: Dictionary = _campaign_definition(campaign_id)
		campaigns.remove_at(index)
		post("info", "event", "Stopped %s" % str(definition.get("name", campaign_id)), Vector3.INF, _tab_target("Marketing"))
		return "Stopped %s" % str(definition.get("name", campaign_id))
	return "Campaign not running"


func forecast_arrivals() -> Dictionary:
	var target: int = _demand_arrival_target(day, minute)
	var margin: float = maxf(1.0, float(target) * 0.12)
	return {
		"expected": target,
		"low": maxi(1, int(round(float(target) - margin))),
		"high": int(round(float(target) + margin)),
	}


func rating_breakdown() -> Dictionary:
	var summary: Dictionary = feedback_summary(30, day)
	var tag_totals: Dictionary = summary.get("tag_totals", {})
	var total_tags: int = 0
	for count in tag_totals.values():
		total_tags += int(count)
	total_tags = maxi(1, total_tags)
	var sub_scores: Dictionary = {}
	for family in RATING_TAG_FAMILIES.keys():
		var penalty_share: float = 0.0
		for tag in RATING_TAG_FAMILIES[family]:
			penalty_share += float(tag_totals.get(tag, 0)) / float(total_tags)
		if family == "value":
			var avg_spend: float = float(summary.get("average_spend", 0.0))
			var spend_penalty: float = clampf((avg_spend - 95.0) / 180.0, 0.0, 1.0) * 0.35
			penalty_share = clampf(penalty_share + spend_penalty, 0.0, 1.0)
		sub_scores[family] = clampf(5.0 - penalty_share * 4.0, 1.0, 5.0)
	var course_score: float = float(sub_scores.get("course", 3.0))
	var course_summary: Dictionary = course_metrics_summary()
	if not course_summary.is_empty():
		var design_score: float = float(course_summary.get("design_score", -1.0))
		if design_score >= 0.0:
			var design_stars: float = 1.0 + clampf(design_score / 100.0, 0.0, 1.0) * 4.0
			course_score = clampf(course_score * 0.7 + design_stars * 0.3, 1.0, 5.0)
	return {
		"stars": _effective_rating(),
		"course": course_score,
		"facilities": float(sub_scores.get("facilities", 3.0)),
		"service": float(sub_scores.get("service", 3.0)),
		"value": float(sub_scores.get("value", 3.0)),
		"scenery": float(sub_scores.get("scenery", 3.0)),
		"design_score": float(course_summary.get("design_score", -1.0)),
	}


func _demand_rate(calendar_day: int) -> float:
	var demand: Dictionary = demand_factors()
	var effective_rating: float = _effective_rating()
	# A hole is one pipeline slot. Capacity is expressed as golfers per
	# calendar day at the target actor-time round length.
	var actor_seconds_per_day: float = DAY_SIM_SECONDS / SIM_RATE
	var base: float = float(_course_holes.size()) * AVERAGE_GROUP_SIZE * actor_seconds_per_day / TARGET_ROUND_ACTOR_SECONDS
	base *= TARGET_COURSE_UTILIZATION
	base *= clampf(0.45 + awareness / 100.0, 0.45, 1.45)
	base *= clampf(0.55 + effective_rating * 0.12, 0.67, 1.15)
	base *= SEASON_DEMAND[season_index_for(calendar_day)]
	base *= float(demand.get("facilities", 1.0))
	base *= float(demand.get("facility_quality", 1.0))
	base *= float(demand.get("scenery", 1.0))
	base *= float(demand.get("wear", 1.0))
	var reference_fee: float = 40.0 + 12.0 * float(grade) + 4.0 * effective_rating
	var avg_fee: float = _expected_average_green_fee()
	var elasticity: float = clampf(1.25 - 0.55 * (avg_fee / maxf(1.0, reference_fee) - 1.0), 0.3, 1.4)
	base *= elasticity
	base *= 1.35 if is_weekend(calendar_day) else 0.9
	return base


func _demand_arrival_target(calendar_day: int, minute_value: float) -> int:
	return clampi(roundi(_demand_rate(calendar_day)), 0, 60)


func _skill_bias() -> float:
	var bias: float = 0.0
	for active in campaigns:
		var definition: Dictionary = _campaign_definition(str(active.get("id", "")))
		bias += float(definition.get("skill_bias", 0.0))
	return bias


func _expert_arrival_boost() -> float:
	var boost: float = 0.0
	for active in campaigns:
		var definition: Dictionary = _campaign_definition(str(active.get("id", "")))
		boost += float(definition.get("expert_boost", 0.0))
	return boost


func _add_rating_sample(stars: float) -> void:
	_rating_sum += clampf(stars, 1.0, 5.0)
	_rating_weight += 1.0
	_update_derived_publicity()


func _departure_star_rating(guest: Dictionary) -> float:
	for refund_tag in FEEDBACK_REFUND_TAGS:
		for entry in guest.get("feedback", []):
			if str(entry.get("tag", "")) == refund_tag:
				return 1.0
	return clampf(1.0 + float(guest.get("mood", 0.5)) * 4.0, 1.0, 5.0)


func _decay_reputation() -> void:
	var signature: Dictionary = course_metrics_summary().get("signature_hole", {})
	if not signature.is_empty():
		if float(signature.get("fun", 0.0)) > 0.75 and float(signature.get("scenery", 0.0)) > 50.0:
			awareness = clampf(awareness + 3.0, 0.0, 100.0)
	awareness = maxf(0.0, awareness * (1.0 - AWARENESS_DAILY_DECAY))
	buzz *= BUZZ_DAILY_DECAY
	var decay: float = pow(0.5, 1.0 / RATING_HALF_LIFE_DAYS)
	_rating_sum *= decay
	_rating_weight *= decay
	var summary: Dictionary = feedback_summary(3, day)
	var praise_share: float = 0.0
	var complaint_share: float = 0.0
	for entry in summary.get("top_praise", []):
		praise_share += float(entry.get("share", 0.0))
	for entry in summary.get("top_complaints", []):
		complaint_share += float(entry.get("share", 0.0))
	buzz = clampf(buzz + (praise_share - complaint_share) * 40.0, -20.0, 20.0)
	_update_derived_publicity()


func _apply_campaign_daily(definition: Dictionary, first_day: bool = false) -> void:
	if definition.is_empty():
		return
	if definition.has("awareness_daily"):
		awareness = clampf(awareness + float(definition.get("awareness_daily", 0.0)), 0.0, 100.0)


func _tick_campaigns() -> void:
	var retiring: Array[String] = []
	for active in campaigns:
		var campaign_id: String = str(active.get("id", ""))
		var definition: Dictionary = _campaign_definition(campaign_id)
		_apply_campaign_daily(definition)
		active["days_left"] = int(active.get("days_left", 1)) - 1
		if int(active.get("days_left", 0)) <= 0:
			retiring.append(campaign_id)
			post("info", "event", "%s campaign finished" % str(definition.get("name", campaign_id)), Vector3.INF, _tab_target("Marketing"))
			continue
		var cost: float = float(definition.get("cost", 0.0))
		if cost > 0.0:
			charge(cost, "marketing", "%s · day %d" % [str(definition.get("name", campaign_id)), int(definition.get("days", 1)) - int(active.get("days_left", 0)) + 1])
	for campaign_id in retiring:
		for index in range(campaigns.size()):
			if str(campaigns[index].get("id", "")) == campaign_id:
				campaigns.remove_at(index)
				break
	if _loyalty_mailer_days > 0:
		_loyalty_mailer_days -= 1
	_update_derived_publicity()


func _spawn_pro_visit_group() -> void:
	if not open or _course_holes.is_empty() or guests.size() >= MAX_GUESTS - 4:
		return
	_create_group(4, false)
	var group: Dictionary = groups.back()
	for guest in _group_guests(group):
		guest["skill"] = 0.97
	_add_press_headline("Touring pro visits Cedar House — cameras follow every shot.")


func _add_press_headline(text: String) -> void:
	if text.is_empty():
		return
	press_headlines.append(text)
	while press_headlines.size() > 8:
		press_headlines.pop_front()
	post("info", "event", text, Vector3.INF, _tab_target("Marketing"))


func _settle_press_moments() -> void:
	var arrivals: int = _period_arrivals
	var completion_rate: float = float(_today_completed_rounds) / maxf(1.0, float(maxi(1, _today_groups)))
	if arrivals > 20 and completion_rate < 0.4:
		buzz = clampf(buzz - 6.0, -20.0, 20.0)
		_add_press_headline("Local paper runs a congestion story after long waits.")
	if _facility_unusable_day:
		buzz = clampf(buzz - 4.0, -20.0, 20.0)
		_add_press_headline("Guests complain after facilities were unusable all day.")
	_facility_unusable_day = false
	_update_derived_publicity()


func _course_par_total() -> int:
	var total: int = 0
	for hole in _course_holes:
		total += int(hole.get("par", 4))
	return total


func course_metrics_summary() -> Dictionary:
	# UI reads must never launch hundreds of shot simulations synchronously.
	# Metrics are refreshed explicitly (analysis/day rollover) and may be stale
	# for the brief period after construction.
	return _course_metrics_cache.duplicate(true)


func refresh_hole_metrics(force: bool = false) -> void:
	_refresh_hole_metrics_cache(force)


func _refresh_hole_metrics_cache(force: bool = false) -> void:
	if terrain == null or _shot_script == null or not _shot_script.has_method("metrics"):
		return
	var revision: int = int(terrain.revision) if "revision" in terrain else 0
	var holes: Array = []
	if not _course_holes.is_empty():
		for hole in _course_holes:
			holes.append(hole)
	elif "holes" in terrain:
		for hole_value in terrain.holes:
			var hole: Dictionary = hole_value
			if bool(hole.get("open", true)):
				holes.append(hole)
	var metrics_by_id: Dictionary = {}
	for hole in holes:
		var hole_id: int = int(hole.get("id", -1))
		if hole_id < 0:
			continue
		var cached: Dictionary = hole_metrics.get(hole_id, {})
		if not force and int(cached.get("revision", -1)) == revision and cached.has("metrics"):
			metrics_by_id[hole_id] = cached.metrics
			continue
		var computed: Dictionary = _shot_script.metrics(terrain, hole)
		metrics_by_id[hole_id] = computed
		hole_metrics[hole_id] = {
			"revision": revision,
			"metrics": computed,
		}
	if holes.is_empty():
		_course_metrics_cache.clear()
		_course_metrics_revision = revision
		return
	if force or _course_metrics_revision != revision or _course_metrics_cache.is_empty():
		if _shot_script.has_method("course_metrics"):
			_course_metrics_cache = _shot_script.course_metrics(terrain, holes, 30, 42, metrics_by_id)
		_course_metrics_revision = revision


func _design_score_requirement_met(target_grade: int) -> bool:
	if sandbox:
		return true
	var summary: Dictionary = course_metrics_summary()
	if summary.is_empty():
		return true
	var score: float = float(summary.get("design_score", -1.0))
	if score < 0.0:
		return true
	var threshold: float = 45.0 if target_grade == 2 else 65.0
	return score >= threshold


func _tee_queue_grace_seconds(hole_id: int) -> float:
	var cached: Dictionary = hole_metrics.get(hole_id, {})
	var metrics: Dictionary = cached.get("metrics", {})
	if metrics.is_empty():
		return 420.0
	var pace_minutes: float = float(metrics.get("pace_minutes", {}).get("value", 7.0))
	return clampf(pace_minutes * 60.0, 120.0, 1200.0)


func _default_prices() -> Dictionary:
	return DEFAULT_PRICES.duplicate(true)


func _migrate_prices(raw: Dictionary) -> Dictionary:
	var migrated: Dictionary = raw.duplicate(true)
	if migrated.has("event") and not migrated.has("event_entry"):
		var event_value: Variant = migrated["event"]
		if event_value is float or event_value is int:
			migrated["event_entry"] = {"base": float(event_value)}
		migrated.erase("event")
	for key in PRICE_BOOK_KEYS:
		if not migrated.has(key):
			continue
		var value: Variant = migrated[key]
		if value is float or value is int:
			migrated[key] = {"base": float(value)}
	for key in PRICE_BOOK_KEYS:
		if not migrated.has(key):
			migrated[key] = DEFAULT_PRICES[key].duplicate(true) if DEFAULT_PRICES[key] is Dictionary else DEFAULT_PRICES[key]
	if migrated.get("green_fee") is Dictionary:
		var green: Dictionary = migrated["green_fee"]
		if not green.has("twilight"):
			green["twilight"] = float(DEFAULT_PRICES["green_fee"]["twilight"])
		if not green.has("weekend"):
			green["weekend"] = float(DEFAULT_PRICES["green_fee"]["weekend"])
		if not green.has("twilight_start_minute"):
			green["twilight_start_minute"] = float(DEFAULT_PRICES["green_fee"]["twilight_start_minute"])
	for scalar_key in ["group_discount", "member_discount", "replay_fee", "bundle_weekend_cart"]:
		if not migrated.has(scalar_key):
			migrated[scalar_key] = DEFAULT_PRICES[scalar_key]
	return migrated


func _price_book_entry(key: String) -> Dictionary:
	var value: Variant = prices.get(key, DEFAULT_PRICES.get(key, {"base": 0.0}))
	if value is float or value is int:
		return {"base": float(value)}
	if value is Dictionary:
		return value
	return {"base": 0.0}


func _price_book_scalar(key: String) -> float:
	var value: Variant = prices.get(key, DEFAULT_PRICES.get(key, 0.0))
	if value is bool:
		return 1.0 if value else 0.0
	return float(value)


func price(key: String, context: Dictionary = {}) -> float:
	if key in ["group_discount", "member_discount", "replay_fee"]:
		return _price_book_scalar(key)
	if key == "bundle_weekend_cart":
		return 1.0 if bool(prices.get("bundle_weekend_cart", false)) else 0.0
	var ctx_minute: float = float(context.get("minute", _day_seconds))
	var ctx_day: int = int(context.get("day", day))
	var group_size: int = int(context.get("group_size", 1))
	var membership: String = str(context.get("membership_tier", ""))
	var book: Dictionary = _price_book_entry(key)
	var amount: float = float(book.get("base", 0.0))
	if key == "green_fee":
		if is_weekend(ctx_day):
			amount = float(book.get("weekend", amount))
		elif ctx_minute >= float(book.get("twilight_start_minute", 420.0)):
			amount = float(book.get("twilight", amount))
		if bool(prices.get("bundle_weekend_cart", false)) and is_weekend(ctx_day):
			amount += float(_price_book_entry("cart").get("base", 22.0))
	elif key == "cart" and bool(prices.get("bundle_weekend_cart", false)) and is_weekend(ctx_day):
		amount = 0.0
	if key == "green_fee" and group_size >= 4:
		amount *= 1.0 - _price_book_scalar("group_discount")
	if membership == "social" and key == "snack":
		amount *= 1.0 - _price_book_scalar("member_discount")
	elif membership == "player" and key == "green_fee":
		amount = 0.0
	elif membership == "founder" and key in ["green_fee", "cart", "range"]:
		amount = 0.0
	return maxf(0.0, amount)


func set_price_field(key: String, field: String, value: float) -> void:
	if key in ["group_discount", "member_discount", "replay_fee"]:
		prices[key] = value
		return
	if not prices.has(key) or not prices[key] is Dictionary:
		prices[key] = _price_book_entry(key).duplicate(true)
	prices[key][field] = value


func suggested_price(key: String) -> float:
	var reference_fee: float = 40.0 + 12.0 * float(grade) + 4.0 * rating_or_satisfaction()
	match key:
		"green_fee":
			return round(reference_fee * 0.88)
		"cart":
			return round(reference_fee * 0.42)
		"range":
			return round(reference_fee * 0.22)
		"snack":
			return round(reference_fee * 0.16)
		"lesson":
			return round(reference_fee * 0.62)
		"retail":
			return round(reference_fee * 0.75)
		"meal":
			return round(reference_fee * 0.50)
		"room":
			return round(reference_fee * 2.10)
		"event_entry":
			return round(reference_fee * 0.32)
	return round(reference_fee * 0.50)


func _expected_average_green_fee() -> float:
	var book: Dictionary = _price_book_entry("green_fee")
	var base: float = float(book.get("base", 48.0))
	var twilight: float = float(book.get("twilight", base))
	var weekend: float = float(book.get("weekend", base))
	var twilight_share: float = 0.30
	var weekend_share: float = 2.0 / 7.0
	var weekday_share: float = 1.0 - weekend_share
	var weekday_avg: float = base * (1.0 - twilight_share) + twilight * twilight_share
	return weekday_avg * weekday_share + weekend * weekend_share


func _beauty_factor() -> float:
	var local_beauty: float = 0.0
	var samples: int = 0
	if terrain != null and terrain.has_method("beauty_at"):
		local_beauty += clampf(float(terrain.beauty_at(_entrance())), 0.0, 100.0)
		samples += 1
		for hole in _course_holes:
			local_beauty += clampf(float(terrain.beauty_at(hole.get("tee", _entrance()))), 0.0, 100.0)
			samples += 1
	if samples > 0:
		return clampf(local_beauty / float(samples) / 100.0, 0.0, 1.0)
	return 0.5


func _guest_perceived_value() -> float:
	return rating_or_satisfaction() * 0.6 + _beauty_factor() * 0.2 + float(_course_holes.size()) / 18.0 * 0.2


func _guest_price_tolerance(skill: float, budget: float) -> float:
	return clampf(0.78 + skill * 0.22 + (budget - 90.0) / 340.0 * 0.28, 0.72, 1.5)


func _price_willing(guest: Dictionary, amount: float, bundle_active: bool = false) -> bool:
	var perceived: float = amount
	if bundle_active:
		perceived *= 0.92
	var tolerance: float = float(guest.get("price_tolerance", 1.0))
	var ceiling: float = tolerance * (35.0 + 90.0 * _guest_perceived_value())
	return perceived <= ceiling


func pricing_summary() -> Dictionary:
	var rows: Array[Dictionary] = []
	for key in PRICE_BOOK_KEYS:
		var book: Dictionary = _price_book_entry(key)
		var row: Dictionary = {
			"key": key,
			"label": key.replace("_", " ").capitalize(),
			"base": float(book.get("base", 0.0)),
			"suggested": suggested_price(key),
		}
		if key == "green_fee":
			row["twilight"] = float(book.get("twilight", row["base"]))
			row["weekend"] = float(book.get("weekend", row["base"]))
			row["twilight_start_minute"] = float(book.get("twilight_start_minute", 420.0))
		rows.append(row)
	var revenue_per_visitor: float = _today_revenue / maxf(1.0, float(maxi(1, _arrived_today)))
	return {
		"balked_today": _today_balked,
		"revenue_per_visitor": revenue_per_visitor,
		"group_discount": _price_book_scalar("group_discount"),
		"member_discount": _price_book_scalar("member_discount"),
		"bundle_weekend_cart": bool(prices.get("bundle_weekend_cart", false)),
		"rows": rows,
	}


func _roll_day() -> void:
	_settle_membership_dues()
	_prune_lost_patrons()
	_settle_press_moments()
	_decay_reputation()
	_tick_campaigns()
	_end_staff_day()
	_settle_events()
	day += 1
	analytics.decay("traffic", 0.985)
	analytics.decay("cart_traffic", 0.985)
	analytics.decay("waiting", 0.98)
	analytics.decay("landings", 0.995)
	analytics.decay("hazard_landings", 0.995)
	if terrain != null and terrain.has_method("overnight_decay"):
		terrain.overnight_decay(_has_facility("maintenance_shed"))
	_facility_warn_day.clear()
	_cart_cap_since = -1.0
	_tee_queue_since.clear()
	today_series.clear()
	_last_series_sample_minute = -TODAY_SERIES_INTERVAL
	_refresh_course()
	_refresh_facilities(false)
	# Course analysis is explicitly requested by the shot lab. Running it here
	# would block the day transition for seconds on a developed course.
	if month_index_for(day) != month_index_for(day - 1):
		_roll_month()
	if season_index_for(day) != season_index_for(day - 1):
		_roll_season()
	_tick_projects()
	_reset_arrivals()


func _end_day() -> void:
	_roll_day()


func _roll_month() -> void:
	var settled_day: int = day - 1
	var next_day: int = day
	# Settlement is dated to the settled month so ledger, history, and UI stay
	# on the same books.
	day = settled_day
	_settle_wages_and_upkeep()
	_settle_loans()
	_review_staff_month()
	var net: float = _today_revenue - _today_expense
	_record(0.0, "monthly_summary", "%s net $%.0f" % [date_string_for(settled_day), net])
	_append_monthly_history(net, settled_day)
	post("info", "finance", "%s closed · net $%.0f" % [date_string_for(settled_day), net], Vector3.INF, _tab_target("Money"))
	day = next_day
	if cash < 0.0:
		_insolvent_days += 1
		post("warning", "finance", "Insolvent month %d: cash below zero" % _insolvent_days, Vector3.INF, _tab_target("Money"))
	else:
		_insolvent_days = 0
	if _insolvent_days >= 3 and not sandbox:
		open = false
		_closed_reason = "Insolvent for three consecutive months"
		game_over = true
		game_over_reason = _closed_reason
		post("critical", "finance", "Game over: %s." % _closed_reason, Vector3.INF, _tab_target("Money"))
	_today_revenue = 0.0
	_today_expense = 0.0
	_period_arrivals = 0
	_reset_daily_accumulators()
	_today_cash_open = cash
	settlements += 1
	_cleanup_departed()


func _roll_season() -> void:
	_update_grade()
	post("info", "system", "%s begins · seasonal assessment complete" % season_name(), Vector3.INF, _tab_target("Events"))


func charge(amount: float, category: String, description: String) -> bool:
	amount = maxf(amount, 0.0)
	if sandbox:
		_record(-amount, category, description + " (sandbox)")
		return true
	if cash + 0.001 < amount:
		post("warning", "finance", "Insufficient funds for %s" % description, Vector3.INF, _tab_target("Money"))
		return false
	if _is_discretionary_charge(category) and (_insolvent_days > 0 or _has_unpaid_bills()) and cash - amount < _recovery_reserve():
		post("warning", "finance", "Cash is reserved for payroll and overdue bills", Vector3.INF, _tab_target("Money"))
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


func hire(role_or_candidate: Variant) -> bool:
	if role_or_candidate is int:
		return _hire_candidate(int(role_or_candidate))
	var role: String = str(role_or_candidate)
	for candidate in candidates:
		if str(candidate.get("role", "")) == role:
			return _hire_candidate(int(candidate.get("id", -1)))
	if candidates.is_empty():
		_refill_candidates()
	for candidate in candidates:
		if str(candidate.get("role", "")) == role:
			return _hire_candidate(int(candidate.get("id", -1)))
	post("warning", "staff", "No applicants for %s" % role, Vector3.INF, _tab_target("Staff"))
	return false


func _hire_candidate(candidate_id: int) -> bool:
	var candidate: Dictionary = _candidate_by_id(candidate_id)
	if candidate.is_empty():
		post("warning", "staff", "Applicant is no longer available", Vector3.INF, _tab_target("Staff"))
		return false
	var role: String = str(candidate.get("role", ""))
	var definition: Dictionary = _role_definition(role)
	if definition.is_empty():
		return false
	if not sandbox and not can_build(role):
		post("warning", "staff", "%s unlocks via the Progress tree" % str(definition.get("name", role)), Vector3.INF, _tab_target("Progress"))
		return false
	var signing_cost: float = float(candidate.get("wage", definition.get("wage", 150.0))) * 2.0
	if not charge(signing_cost, "staff", "Signing bonus for %s" % str(candidate.get("name", role))):
		return false
	_add_staff_from_candidate(candidate)
	candidates.erase(candidate)
	var worker_id: int = int(staff.back().get("id", -1))
	post("info", "staff", "%s hired" % str(staff.back().get("name", role)), staff.back().get("pos", _entrance()), {"kind": "staff", "id": worker_id})
	return true


func fire(id: int) -> void:
	for index in range(staff.size()):
		if int(staff[index].get("id", -1)) != id:
			continue
		var worker: Dictionary = staff[index]
		var severance: float = float(worker.get("wage", 0.0)) * 3.0
		if severance > 0.0:
			_force_expense(severance, "severance", "Severance for %s" % str(worker.get("name", "Worker")))
		staff.remove_at(index)
		for other in staff:
			other["morale"] = maxf(0.0, float(other.get("morale", 0.7)) - 0.05)
		post("info", "staff", "%s left the resort" % str(worker.get("name", "Worker")), worker.get("pos", _entrance()), {"kind": "staff", "id": id})
		return


func train(worker_id: int, course_id: String) -> bool:
	var course: Dictionary = _training_definition(course_id)
	if course.is_empty():
		post("warning", "staff", "Unknown training course: %s" % course_id, Vector3.INF, _tab_target("Staff"))
		return false
	var worker: Dictionary = _worker_by_id(worker_id)
	if worker.is_empty():
		return false
	if str(worker.get("role", "")) != str(course.get("role", "")):
		post("warning", "staff", "That course is not for this role", Vector3.INF, _tab_target("Staff"))
		return false
	if _training_active(worker):
		post("warning", "staff", "%s is already in training" % str(worker.get("name", "Worker")), Vector3.INF, _tab_target("Staff"))
		return false
	var cost: float = float(course.get("cost", 0.0))
	if not charge(cost, "training", "%s for %s" % [str(course.get("name", course_id)), str(worker.get("name", "Worker"))]):
		return false
	worker["training"] = {"course": course_id, "days_left": int(course.get("days", 1))}
	worker["activity"] = "training"
	post("info", "staff", "%s started %s" % [str(worker.get("name", "Worker")), str(course.get("name", course_id))], worker.get("pos", _entrance()), {"kind": "staff", "id": worker_id})
	return true


func set_shift(worker_id: int, shift: String) -> void:
	var worker: Dictionary = _worker_by_id(worker_id)
	if worker.is_empty():
		return
	if shift not in ["early", "late", "full"]:
		return
	worker["shift"] = shift
	worker["activity"] = "seeking_assignment"


func grant_raise(worker_id: int) -> bool:
	var worker: Dictionary = _worker_by_id(worker_id)
	if worker.is_empty() or not bool(worker.get("raise_requested", false)):
		return false
	worker["wage"] = float(worker.get("wage", 0.0)) * 1.12
	worker["raise_requested"] = false
	worker["raise_ignored_days"] = 0
	worker["low_morale_days"] = 0
	worker["morale"] = minf(1.0, float(worker.get("morale", 0.7)) + 0.12)
	post("success", "staff", "Raise accepted for %s" % str(worker.get("name", "Worker")), worker.get("pos", _entrance()), {"kind": "staff", "id": worker_id})
	return true


func assign_staff(id: int, target) -> void:
	for worker in staff:
		if int(worker.get("id", -1)) == id:
			if target is int:
				var object_id: int = int(target)
				worker["assignment"] = {"kind": "object", "id": object_id} if object_id >= 0 else -1
			elif target is Dictionary:
				worker["assignment"] = (target as Dictionary).duplicate(true)
			else:
				worker["assignment"] = -1
			worker.erase("maint_target")
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
	return "%s funded" % str(loan["name"])


func repay(loan_id: int, amount: float) -> String:
	if amount <= 0.0:
		return "Repayment must be positive"
	for loan in loans:
		if int(loan.get("id", -1)) == loan_id:
			var paid: float = minf(amount, float(loan.get("balance", 0.0)))
			if not charge(paid, "loan_payment", "Repay %s" % str(loan.get("name", "loan"))):
				return notice if not notice.is_empty() else "Insufficient funds"
			loan["balance"] = maxf(0.0, float(loan.get("balance", 0.0)) - paid)
			if float(loan["balance"]) <= 0.01:
				return "%s repaid" % str(loan.get("name", "Loan"))
			return "$%.0f repaid" % paid
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
	return "%s scheduled for day %d" % [str(event["name"]), event_day]


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
	if not hole_metrics.is_empty():
		if kind == "club_championship":
			var slope: float = float(course_metrics_summary().get("slope", 0.0))
			if slope > 0.0 and slope < 105.0:
				return "Course slope %.0f is below 105 for a championship" % slope
		if kind == "beginner_clinic":
			var beginner_friendly: bool = false
			for cached_value in hole_metrics.values():
				var cached: Dictionary = cached_value
				var metrics: Dictionary = cached.get("metrics", {})
				if float(metrics.get("difficulty", {}).get("value", 99.0)) <= 0.0:
					beginner_friendly = true
					break
			if not beginner_friendly:
				return "Need at least one hole with difficulty at or below par for beginners"
	return ""


func grade_requirements() -> String:
	if grade >= 3:
		return "Grade 3: premier resort"
	var target_grade: int = grade + 1
	var requirements: Dictionary = _grade_definition(target_grade).get("requirements", {})
	var quality_satisfaction: float = 0.60 if target_grade == 2 else 0.70
	var quality_wear: float = 0.50 if target_grade == 2 else 0.35
	var qualifying_events: String = "Open Day, Charity Scramble, or Beginner Clinic" if target_grade == 2 else "Club Championship or Regional Amateur"
	var grade_node: Dictionary = _grade_unlock_node(target_grade)
	var branch_text: String = ""
	if not grade_node.is_empty():
		var names: Array[String] = []
		for node_id in grade_node.get("nodes", []):
			var branch_node: Dictionary = _unlock_node(str(node_id))
			if not branch_node.is_empty():
				names.append(str(branch_node.get("name", node_id)))
		if not names.is_empty():
			branch_text = " Progress tree: %s (see THE PLAN tab)." % ", ".join(names)
	return "Grade %d requires $%.0f cash, %d buildings, %d playable holes, %.0f publicity, %d%% satisfaction, course wear at or below %d%%, a successful %s, and listed progress nodes OR the quality thresholds.%s Current: $%.0f, %d buildings, %d holes, %.0f publicity, %d%% satisfaction, %d%% wear, qualifying event %s." % [target_grade, float(requirements.get("cash", 0.0)), int(requirements.get("buildings", 0)), int(requirements.get("holes", 0)), float(requirements.get("publicity", 0.0)), int(quality_satisfaction * 100.0), int(quality_wear * 100.0), qualifying_events, branch_text, cash, _building_count(), _course_holes.size(), publicity, int(satisfaction * 100.0), int(_terrain_wear() * 100.0), "complete" if _has_qualifying_event(target_grade) else "needed"]


func unlocks() -> Dictionary:
	return {
		"grade": grade,
		"completed": unlocked.duplicate(),
		"projects": projects.duplicate(true),
		"events": EVENT_KINDS.filter(func(kind: String) -> bool: return int(_event_definition(kind).get("grade", _event_definition(kind).get("min_grade", 1))) <= grade),
		"loans": DEFAULT_LOANS.keys().filter(func(kind) -> bool: return int(_loan_definition(str(kind)).get("grade", _loan_definition(str(kind)).get("min_grade", 1))) <= grade),
	}


func can_build(kind: String) -> bool:
	if sandbox:
		return not _catalog_find(kind).is_empty()
	if _catalog_script != null and _catalog_script.has_method("unlock_for"):
		var gate: Dictionary = _catalog_script.unlock_for(kind)
		if gate.is_empty():
			return not _catalog_find(kind).is_empty()
		return _has_grant(kind)
	return not _catalog_find(kind).is_empty() and grade >= int(_catalog_find(kind).get("grade", 1))


func project_available(node_id: String) -> bool:
	var node: Dictionary = _unlock_node(node_id)
	if node.is_empty() or str(node.get("kind", "")) == "grade":
		return false
	if unlocked.has(node_id) or not _project_for(node_id).is_empty():
		return false
	if grade < int(node.get("grade", 1)):
		return false
	for required_id in node.get("requires", []):
		if not unlocked.has(str(required_id)):
			return false
	var milestone: Dictionary = node.get("milestone", {})
	if not milestone.is_empty():
		var progress: Dictionary = milestone_progress(node_id)
		if float(progress.get("current", 0.0)) < float(progress.get("target", 0.0)):
			return false
	return true


func commit_project(node_id: String) -> String:
	var node: Dictionary = _unlock_node(node_id)
	if node.is_empty() or str(node.get("kind", "")) == "grade":
		return "Unknown project"
	if unlocked.has(node_id):
		return "%s is already complete" % str(node.get("name", node_id))
	if not _project_for(node_id).is_empty():
		return "%s is already in progress" % str(node.get("name", node_id))
	if not project_available(node_id):
		return "%s is not available yet" % str(node.get("name", node_id))
	if projects.size() >= MAX_CONCURRENT_PROJECTS:
		return "Only two projects can run at once"
	var cost: float = float(node.get("cost", 0.0))
	if not charge(cost, "project", "Committed %s" % str(node.get("name", node_id))):
		return "Insufficient funds for %s" % str(node.get("name", node_id))
	var days: int = maxi(1, int(node.get("days", 1)))
	projects.append({"id": node_id, "days_left": days, "started_day": day})
	post("info", "construction", "Started %s · %d day(s)" % [str(node.get("name", node_id)), days], Vector3.INF, _tab_target("Progress"))
	return "%s committed · $%s · completes in %d day(s)" % [str(node.get("name", node_id)), _money_text(cost), days]


func cancel_project(node_id: String) -> String:
	var project: Dictionary = _project_for(node_id)
	if project.is_empty():
		return "No such project in progress"
	if int(project.get("started_day", -1)) != day:
		return "Projects can only be cancelled on the day they were committed"
	var node: Dictionary = _unlock_node(node_id)
	var refund: float = float(node.get("cost", 0.0)) * 0.8
	projects.erase(project)
	credit(refund, "project_refund", "Cancelled %s" % str(node.get("name", node_id)))
	post("info", "construction", "Cancelled %s · refunded 80%%" % str(node.get("name", node_id)), Vector3.INF, _tab_target("Progress"))
	return "Cancelled %s · refunded $%s" % [str(node.get("name", node_id)), _money_text(refund)]


func milestone_progress(node_id: String) -> Dictionary:
	var node: Dictionary = _unlock_node(node_id)
	var milestone: Dictionary = node.get("milestone", {})
	if milestone.is_empty():
		return {"kind": "", "current": 0.0, "target": 0.0, "label": ""}
	var kind: String = str(milestone.get("kind", ""))
	var target: float = float(milestone.get("value", 0.0))
	var current: float = 0.0
	match kind:
		"completed_visits":
			current = float(completed_visits)
		"rating":
			current = rating_or_satisfaction() * 100.0
		"holes":
			current = float(_course_holes.size())
		"events_won":
			for event in event_history:
				if str(event.get("status", "")) == "success":
					current += 1.0
		"members":
			current = 0.0
		"beauty_peak":
			current = 0.0
	var label: String = "%s / %s" % [str(int(current)), str(int(target))]
	match kind:
		"completed_visits":
			label = "%d / %d completed visits" % [int(current), int(target)]
		"rating":
			label = "%.0f / %.0f guest rating" % [current, target]
		"holes":
			label = "%d / %d playable holes" % [int(current), int(target)]
		"events_won":
			label = "%d / %d successful events" % [int(current), int(target)]
	return {"kind": kind, "current": current, "target": target, "label": label}


func facility_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		var copy: Dictionary = state.duplicate(true)
		var facility_id: int = int(state.get("id", -1))
		copy["queue"] = _queue_for_facility(facility_id).size()
		copy["workers"] = _workers_at(facility_id)
		copy["staffed"] = _facility_staffed(state)
		copy["level"] = int(state.get("level", 1))
		copy["revenue_today"] = float(state.get("revenue_today", 0.0))
		copy["visits_today"] = int(state.get("visits_today", 0))
		copy["closed"] = bool(state.get("closed", false))
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
		local_beauty += clampf(float(terrain.beauty_at(_entrance())), 0.0, 100.0)
		beauty_samples += 1
		for hole in _course_holes:
			local_beauty += clampf(float(terrain.beauty_at(hole.get("tee", _entrance()))), 0.0, 100.0)
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
	if not open or _course_holes.is_empty() or not _has_facility("clubhouse") or size < 1 or guests.size() >= MAX_GUESTS:
		return -1
	var group_id: int = _next_group_id
	_create_group(mini(clampi(size, 1, 4),MAX_GUESTS-guests.size()), event_guest and _active_event_id >= 0)
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
		var pos: Vector3 = guest.get("pos", _entrance())
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
				compensation[group_id] = float(compensation[group_id]) + minf(8.0, price("green_fee", {}) * 0.1)
				if str(group.get("state", "")) == "playing":
					group["play_phase"] = "ready"
					group["turn_pause"] = 2.0
			elif str(group.get("state", "")) == "playing" and str(group.get("play_phase", "")) == "ready":
				var member_ids: Array = group.get("members", [])
				var player_turn: int = int(group.get("player_turn", 0))
				if player_turn >= 0 and player_turn < member_ids.size() and int(member_ids[player_turn]) == int(guest.get("id", -1)):
					guest["ball_pos"] = guest["pos"]
	# Only routes touching the edited area need rebuilding. Other current paths
	# remain valid and avoid an A* query storm during brush interaction.
	for group in groups:
		if str(group.get("state", "")) == "departed":
			continue
		var current_hole_id: int = int(group.get("current_hole_id", -1))
		if bool(group.get("cart", false)) and _point_in_edit(group.get("cart_pos", _entrance()), center, radius):
			group["cart_initialized"] = false
		if current_hole_id >= 0 and _hole_by_id(current_hole_id).is_empty():
			hard_stop_groups[int(group.get("id", -1))] = true
			continue
		if not affected_groups.has(int(group.get("id", -1))):
			continue
		if not _rebuild_group_routes(group):
			hard_stop_groups[int(group.get("id", -1))] = true
	for worker in staff:
		var worker_pos: Vector3 = worker.get("pos", _entrance())
		var worker_destination: Vector3 = worker.get("destination", worker_pos)
		var current_route: PackedVector3Array = worker.get("route", PackedVector3Array())
		if not _point_in_edit(worker_pos, center, radius) and not _point_in_edit(worker_destination, center, radius) and not _path_intersects_edit(current_route, center, radius):
			continue
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
		_safe_refund_and_depart(group, "Course work ended this round safely.", refund_fraction, "refund_construction")
		if _raw_route(_group_leader_position(group), _entrance(), bool(group.get("cart", false))).is_empty():
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
		post("info", "construction", "%d groups safely resumed after construction; %d interrupted rounds ended" % [affected_groups.size(), hard_stop_groups.size()])


func snapshot() -> Dictionary:
	return {
		"version": 2, "tick_accumulator": _tick_accumulator, "guests": guests.duplicate(true), "staff": staff.duplicate(true), "candidates": candidates.duplicate(true), "groups": groups.duplicate(true),
		"cash": cash, "day": day, "minute": minute, "sandbox": sandbox, "prices": prices.duplicate(true),
		"rating": rating,
		"awareness": awareness,
		"buzz": buzz,
		"campaigns": campaigns.duplicate(true),
		"press_headlines": press_headlines.duplicate(),
		"rating_sum": _rating_sum,
		"rating_weight": _rating_weight,
		"loyalty_mailer_days": _loyalty_mailer_days,
		"day_seconds": _day_seconds, "actor_elapsed_seconds": _actor_elapsed_seconds, "settlements": settlements,
		"game_over": game_over, "game_over_reason": game_over_reason,
		"period_arrivals": _period_arrivals, "demand_carry": _demand_carry, "arrivals_enabled": arrivals_enabled,
		"ledger": ledger.duplicate(true), "loans": loans.duplicate(true), "scheduled_events": scheduled_events.duplicate(true),
		"event_history": event_history.duplicate(true), "grade": grade, "publicity": publicity, "open": open,
		"satisfaction": satisfaction, "completed_visits": completed_visits, "notice": notice,
		"log": log.duplicate(true), "next_log_id": _next_log_id, "last_seen_log_id": last_seen_log_id,
		"rng_seed": _rng.seed, "rng_state": _rng.state, "next_guest_id": _next_guest_id,
		"next_group_id": _next_group_id, "next_staff_id": _next_staff_id, "next_candidate_id": _next_candidate_id, "next_loan_id": _next_loan_id,
		"next_event_id": _next_event_id, "arrival_target": _arrival_target, "arrived_today": _arrived_today,
		"next_arrival_in": _next_arrival_in, "hole_queues": _hole_queues.duplicate(true),
		"hole_occupancy": _hole_occupancy.duplicate(true), "facility_queues": _facility_queues.duplicate(true),
		"facility_state": _facility_state.duplicate(true), "today_revenue": _today_revenue,
		"today_expense": _today_expense, "insolvent_days": _insolvent_days,
		"closed_reason": _closed_reason, "active_event_id": _active_event_id,
		"history": history.duplicate(true), "today_series": today_series.duplicate(true),
		"records": records.duplicate(true), "today_by_category": _today_by_category.duplicate(true),
		"today_cash_open": _today_cash_open, "today_groups": _today_groups,
		"today_completed_rounds": _today_completed_rounds, "today_refunds": _today_refunds,
		"today_spend_total": _today_spend_total, "today_spend_guests": _today_spend_guests,
		"today_mood_sum": _today_mood_sum, "today_mood_count": _today_mood_count,
		"wait_tee_seconds": _wait_tee_seconds, "wait_checkin_seconds": _wait_checkin_seconds,
		"max_tee_queue": _max_tee_queue, "facility_visits": _facility_visits.duplicate(true),
		"facility_revenue": _facility_revenue.duplicate(true), "hole_stats_today": _hole_stats_today.duplicate(true),
		"last_series_sample_minute": _last_series_sample_minute, "today_peak_guests": _today_peak_guests,
		"today_peak_queue": _today_peak_queue, "today_peak_queue_minute": _today_peak_queue_minute,
		"today_balked": _today_balked,
		"positive_streak": _positive_streak,
		"reviews": reviews.duplicate(true),
		"daily_feedback": daily_feedback.duplicate(true),
		"analytics": analytics.snapshot(),
		"unlocked": unlocked.duplicate(),
		"projects": projects.duplicate(true),
		"patrons": patrons.duplicate(true),
		"next_patron_id": _next_patron_id,
		"membership_dues": membership_dues.duplicate(true),
		"membership_open": membership_open.duplicate(true),
		"membership_churn_log": _membership_churn_log.duplicate(true),
		"member_arrival_queue": _member_arrival_queue.duplicate(),
		"member_arrival_index": _member_arrival_index,
		"hole_metrics": hole_metrics.duplicate(true),
		"course_metrics_cache": _course_metrics_cache.duplicate(true),
		"course_metrics_revision": _course_metrics_revision,
	}


func restore(data: Dictionary) -> void:
	_guests_by_group.clear()
	_groups_by_id.clear()
	_has_departed=false
	_tick_accumulator = data.get("tick_accumulator",0.0)
	guests.assign(data.get("guests", []).duplicate(true))
	staff.assign(data.get("staff", []).duplicate(true))
	for worker in staff:
		_normalize_worker(worker)
	candidates.assign(data.get("candidates", []).duplicate(true))
	groups.assign(data.get("groups", []).duplicate(true))
	for group in groups:
		if str(group.get("state", "")) == "lodged":
			group["state"] = "departing"
			group["wants_lodging"] = false
			group["lodge_nights"] = 0
			group["destination"] = _entrance()
			group["route"] = PackedVector3Array()
			group["route_index"] = 0
	cash = float(data.get("cash", 180000.0))
	day = int(data.get("day", 1))
	calendar_second = float(data.get("calendar_second", data.get("minute", _day_seconds)))
	minute = calendar_second
	_day_seconds = float(data.get("day_seconds", minute * 60.0))
	var elapsed_fallback: float = (float(day - 1) * DAY_SIM_SECONDS + _day_seconds) / SIM_RATE
	_actor_elapsed_seconds = float(data.get("actor_elapsed_seconds", elapsed_fallback))
	if not data.has("actor_elapsed_seconds") and data.has("sim_elapsed"):
		_actor_elapsed_seconds = float(data.get("sim_elapsed", 0.0)) / SIM_RATE
	game_over = bool(data.get("game_over", false))
	game_over_reason = str(data.get("game_over_reason", ""))
	settlements = int(data.get("settlements", maxi(0, month_index_for(day))))
	_period_arrivals = int(data.get("period_arrivals", 0))
	_demand_carry = float(data.get("demand_carry", 0.0))
	arrivals_enabled = bool(data.get("arrivals_enabled", true))
	sandbox = bool(data.get("sandbox", false))
	prices = _migrate_prices(Dictionary(data.get("prices", {})))
	rating = float(data.get("rating", -1.0))
	awareness = float(data.get("awareness", data.get("publicity", 0.0)))
	buzz = float(data.get("buzz", 0.0))
	campaigns.assign(data.get("campaigns", []))
	press_headlines.assign(data.get("press_headlines", []))
	_rating_sum = float(data.get("rating_sum", 3.0))
	_rating_weight = float(data.get("rating_weight", 1.0))
	_loyalty_mailer_days = int(data.get("loyalty_mailer_days", 0))
	if not data.has("rating_sum"):
		if rating < 0.0:
			rating = 3.0
		_rating_sum = rating
		_rating_weight = 1.0
	if not data.has("awareness"):
		awareness = float(data.get("publicity", 0.0))
	_update_derived_publicity()
	for guest in guests:
		if not guest.has("price_tolerance"):
			guest["price_tolerance"] = _guest_price_tolerance(float(guest.get("skill", 0.5)), float(guest.get("budget", 120.0)))
		if not guest.has("patron_id"):
			guest["patron_id"] = -1
	ledger.assign(data.get("ledger", []))
	loans.assign(data.get("loans", []))
	scheduled_events.assign(data.get("scheduled_events", []))
	event_history.assign(data.get("event_history", []))
	grade = int(data.get("grade", 1))
	open = bool(data.get("open", true))
	satisfaction = float(data.get("satisfaction", 0.72))
	completed_visits = int(data.get("completed_visits", 0))
	notice = str(data.get("notice", "Restored"))
	log.assign(data.get("log", []))
	_next_log_id = int(data.get("next_log_id", 1))
	last_seen_log_id = int(data.get("last_seen_log_id", 0))
	_facility_warn_day.clear()
	_cart_cap_since = -1.0
	_tee_queue_since.clear()
	_hole_open_state.clear()
	_next_guest_id = int(data.get("next_guest_id", 1))
	_next_group_id = int(data.get("next_group_id", 1))
	_next_staff_id = int(data.get("next_staff_id", 1))
	_next_candidate_id = int(data.get("next_candidate_id", 1))
	_next_loan_id = int(data.get("next_loan_id", 1))
	_next_event_id = int(data.get("next_event_id", 1))
	_arrival_target = int(data.get("arrival_target", 0))
	_arrived_today = int(data.get("arrived_today", 0))
	_next_arrival_in = float(data.get("next_arrival_in", 0.0))
	_hole_queues = Dictionary(data.get("hole_queues", {})).duplicate(true)
	_hole_occupancy = Dictionary(data.get("hole_occupancy", {})).duplicate(true)
	_facility_queues = Dictionary(data.get("facility_queues", {})).duplicate(true)
	_facility_state = Dictionary(data.get("facility_state", {})).duplicate(true)
	_today_revenue = float(data.get("today_revenue", 0.0))
	_today_expense = float(data.get("today_expense", 0.0))
	_insolvent_days = int(data.get("insolvent_days", 0))
	_closed_reason = str(data.get("closed_reason", ""))
	_active_event_id = int(data.get("active_event_id", -1))
	history.assign(data.get("history", []))
	today_series.assign(data.get("today_series", []))
	records = Dictionary(data.get("records", {})).duplicate(true)
	_today_by_category = Dictionary(data.get("today_by_category", {"revenue": {}, "expenses": {}})).duplicate(true)
	_today_cash_open = float(data.get("today_cash_open", cash))
	_today_groups = int(data.get("today_groups", 0))
	_today_completed_rounds = int(data.get("today_completed_rounds", 0))
	_today_refunds = float(data.get("today_refunds", 0.0))
	_today_spend_total = float(data.get("today_spend_total", 0.0))
	_today_spend_guests = int(data.get("today_spend_guests", 0))
	_today_mood_sum = float(data.get("today_mood_sum", 0.0))
	_today_mood_count = int(data.get("today_mood_count", 0))
	_wait_tee_seconds = float(data.get("wait_tee_seconds", 0.0))
	_wait_checkin_seconds = float(data.get("wait_checkin_seconds", 0.0))
	_max_tee_queue = int(data.get("max_tee_queue", 0))
	_facility_visits = Dictionary(data.get("facility_visits", {})).duplicate(true)
	_facility_revenue = Dictionary(data.get("facility_revenue", {})).duplicate(true)
	_hole_stats_today = Dictionary(data.get("hole_stats_today", {})).duplicate(true)
	_last_series_sample_minute = float(data.get("last_series_sample_minute", -TODAY_SERIES_INTERVAL))
	_today_peak_guests = int(data.get("today_peak_guests", 0))
	_today_peak_queue = int(data.get("today_peak_queue", 0))
	_today_peak_queue_minute = float(data.get("today_peak_queue_minute", 0.0))
	_today_balked = int(data.get("today_balked", 0))
	_positive_streak = int(data.get("positive_streak", 0))
	reviews.assign(data.get("reviews", []))
	daily_feedback = Dictionary(data.get("daily_feedback", {})).duplicate(true)
	analytics.restore(Dictionary(data.get("analytics", {})))
	hole_metrics = Dictionary(data.get("hole_metrics", {})).duplicate(true)
	_course_metrics_cache = Dictionary(data.get("course_metrics_cache", {})).duplicate(true)
	_course_metrics_revision = int(data.get("course_metrics_revision", -1))
	if data.has("unlocked"):
		unlocked.assign(data.get("unlocked", []))
		projects.assign(data.get("projects", []))
	else:
		_migrate_unlocks_from_grade(grade)
	patrons = Dictionary(data.get("patrons", {})).duplicate(true)
	_next_patron_id = int(data.get("next_patron_id", 1))
	for patron_key in patrons.keys():
		_next_patron_id = maxi(_next_patron_id, int(patron_key) + 1)
	membership_dues = Dictionary(data.get("membership_dues", membership_dues)).duplicate(true)
	membership_open = Dictionary(data.get("membership_open", membership_open)).duplicate(true)
	_membership_churn_log.assign(data.get("membership_churn_log", []))
	_member_arrival_queue.assign(data.get("member_arrival_queue", []))
	_member_arrival_index = int(data.get("member_arrival_index", 0))
	_rng.seed = int(data.get("rng_seed", 730241))
	_rng.state = int(data.get("rng_state", _rng.state))
	_route_cache.clear()
	_refresh_course()
	_refresh_facilities(false)
	if candidates.is_empty():
		_refill_candidates()
	_update_derived_publicity()


func _tick_groups(dt: float) -> void:
	for group in groups:
		var blocked = false
		for guest in _group_guests(group):blocked = blocked or guest.get("blocked",false)
		if blocked:
			group["blocked_seconds"] = float(group.get("blocked_seconds",0))+dt
			if group.blocked_seconds>120:
				if group.state!="departing":
					_safe_refund_and_depart(group,"A route was inaccessible; staff arranged a safe departure.",0.5,"refund_closure")
				if _raw_route(_group_leader_position(group),_entrance(),false).is_empty():_finish_departure(group)
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
			"lodged":
				for guest in _group_guests(group):
					guest["activity"] = "lodged"
					guest["thought"] = "Resting at the lodge."
			"departed":
				pass


func members() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if not bool(patron.get("member", false)):
			continue
		var copy: Dictionary = patron.duplicate(true)
		copy["id"] = int(patron_id)
		copy["handicap"] = _patron_handicap(patron)
		result.append(copy)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return result


func patron_summary() -> Dictionary:
	var counts: Dictionary = {"social": 0, "player": 0, "founder": 0}
	var monthly_dues: float = 0.0
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if not bool(patron.get("member", false)):
			continue
		var tier: String = str(patron.get("tier", ""))
		counts[tier] = int(counts.get(tier, 0)) + 1
		monthly_dues += _membership_dues_for_tier(tier)
	var churn_30: int = 0
	for entry in _membership_churn_log:
		if day - int(entry.get("day", day)) <= 30:
			churn_30 += 1
	var caps: Dictionary = {}
	for tier in _membership_catalog():
		var tier_id: String = str(tier.get("id", ""))
		caps[tier_id] = _membership_cap(tier_id)
	return {
		"total_patrons": patrons.size(),
		"member_counts": counts,
		"members_total": int(counts.get("social", 0)) + int(counts.get("player", 0)) + int(counts.get("founder", 0)),
		"monthly_dues_income": monthly_dues,
		"churn_30": churn_30,
		"dues": membership_dues.duplicate(true),
		"open": membership_open.duplicate(true),
		"caps": caps,
		"tiers": _membership_catalog(),
	}


func _membership_catalog() -> Array:
	if _catalog_script != null and _catalog_script.has_method("memberships"):
		return _catalog_script.memberships()
	return []


func _membership_definition(tier_id: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("membership"):
		return _catalog_script.membership(tier_id)
	return {}


func _membership_dues_for_tier(tier_id: String) -> float:
	if membership_dues.has(tier_id):
		return float(membership_dues[tier_id])
	var definition: Dictionary = _membership_definition(tier_id)
	return float(definition.get("dues", 0.0))


func _membership_tier_unlocked(tier_id: String) -> bool:
	if sandbox:
		return not _membership_definition(tier_id).is_empty()
	match tier_id:
		"social":
			return grade >= int(_membership_definition("social").get("min_grade", 1))
		"player":
			return _grant_from_completed("membership:2")
		"founder":
			return _grant_from_completed("membership:3") and _grant_from_completed("membership:founder")
	return false


func _membership_tier_open(tier_id: String) -> bool:
	return bool(membership_open.get(tier_id, true)) and _membership_tier_unlocked(tier_id)


func _membership_cap(tier_id: String) -> int:
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	var level: int = int(clubhouse.get("level", 1))
	var capacity: int = int(_facility_tier_stats("clubhouse", level).get("capacity", 28))
	match tier_id:
		"social":
			return capacity * 4
		"player":
			return capacity * 2
		"founder":
			return maxi(1, int(round(float(capacity) * 0.5)))
	return 0


func _membership_tier_count(tier_id: String) -> int:
	var count: int = 0
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if bool(patron.get("member", false)) and str(patron.get("tier", "")) == tier_id:
			count += 1
	return count


func _patron_by_id(patron_id: int) -> Dictionary:
	return patrons.get(patron_id, {})


func _patron_on_site(patron_id: int) -> bool:
	for guest in guests:
		if int(guest.get("patron_id", -1)) == patron_id:
			return true
	return false


func _guest_membership_tier(guest: Dictionary) -> String:
	var patron_id: int = int(guest.get("patron_id", -1))
	if patron_id < 0:
		return ""
	var patron: Dictionary = _patron_by_id(patron_id)
	if patron.is_empty() or not bool(patron.get("member", false)):
		return ""
	return str(patron.get("tier", ""))


func _guest_price_context(guest: Dictionary, group: Dictionary = {}) -> Dictionary:
	return {
		"minute": minute,
		"day": day,
		"group_size": int(group.get("size", 1)) if not group.is_empty() else 1,
		"membership_tier": _guest_membership_tier(guest),
	}


func _group_has_priority_member(group: Dictionary) -> bool:
	for guest in _group_guests(group):
		var tier: String = _guest_membership_tier(guest)
		if tier in ["player", "founder"]:
			return true
	return false


func _patron_handicap(patron: Dictionary) -> float:
	var cards: Array = patron.get("scorecards", [])
	if cards.is_empty():
		return 0.0
	var total: float = 0.0
	for card in cards:
		total += float(int(card.get("strokes", 0)) - int(card.get("par", 0)))
	return (total / float(cards.size())) * 1.1


func _patron_mood_average(patron: Dictionary) -> float:
	var history: Array = patron.get("history", [])
	if history.is_empty():
		return 0.66
	var total: float = 0.0
	for entry in history:
		total += float(entry.get("mood", 0.66))
	return total / float(history.size())


func _returning_patron_chance() -> float:
	if patrons.is_empty():
		return 0.0
	var eligible: bool = false
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if _patron_on_site(int(patron_id)):
			continue
		if int(patron.get("last_day", 0)) < day:
			eligible = true
			break
	if not eligible:
		return 0.0
	return clampf(0.15 + 0.5 * satisfaction, 0.2, 0.65)


func _pick_returning_patron_id() -> int:
	var ids: Array[int] = []
	var weights: Array[float] = []
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if _patron_on_site(int(patron_id)):
			continue
		var last_day: int = int(patron.get("last_day", 0))
		if last_day >= day:
			continue
		var days_since: int = maxi(1, day - last_day)
		var weight: float = float(patron.get("affinity", 0.5)) * (1.0 + minf(30.0, float(days_since)) / 30.0)
		if weight <= 0.0:
			continue
		ids.append(int(patron_id))
		weights.append(weight)
	if ids.is_empty():
		return -1
	var total: float = 0.0
	for weight in weights:
		total += weight
	var roll: float = _rng.randf() * total
	var cumulative: float = 0.0
	for index in range(ids.size()):
		cumulative += weights[index]
		if roll <= cumulative:
			return ids[index]
	return ids.back()


func _apply_patron_to_guest(guest: Dictionary, patron: Dictionary) -> void:
	guest["patron_id"] = int(patron.get("id", -1))
	guest["name"] = str(patron.get("name", guest.get("name", "Guest")))
	var visits: int = int(patron.get("visits", 0))
	guest["skill"] = clampf(float(patron.get("skill", 0.5)) + 0.005 * float(visits), 0.06, 0.97)
	var mood_avg: float = _patron_mood_average(patron)
	guest["budget"] = float(patron.get("budget_base", 120.0)) * (0.85 + 0.3 * mood_avg)
	guest["price_tolerance"] = _guest_price_tolerance(float(guest.get("skill", 0.5)), float(guest.get("budget", 120.0)))


func _create_patron_from_guest(guest: Dictionary, mood: float, spent: float) -> int:
	var patron_id: int = _next_patron_id
	_next_patron_id += 1
	var patron: Dictionary = {
		"id": patron_id,
		"name": str(guest.get("name", _person_name(patron_id))),
		"skill": float(guest.get("skill", 0.5)),
		"budget_base": maxf(float(guest.get("budget", 0.0)) + spent, 90.0),
		"visits": 1,
		"last_day": day,
		"affinity": clampf(mood, 0.0, 1.0),
		"member": false,
		"tier": "",
		"joined_day": 0,
		"dues_paid_through": 0,
		"handicap": 0.0,
		"favourite_hole_id": -1,
		"history": [{"day": day, "mood": mood, "spent": spent}],
		"scorecards": [],
		"low_affinity_visits": 0,
	}
	patrons[patron_id] = patron
	_enforce_patron_cap()
	return patron_id


func _enforce_patron_cap() -> void:
	while patrons.size() > PATRONS_CAP:
		var drop_id: int = -1
		var drop_score: Vector2 = Vector2(INF, INF)
		for patron_id in patrons.keys():
			var patron: Dictionary = patrons[patron_id]
			if bool(patron.get("member", false)):
				continue
			var affinity: float = float(patron.get("affinity", 0.0))
			var last_day: int = int(patron.get("last_day", 0))
			var score: Vector2 = Vector2(affinity, float(last_day))
			if score < drop_score:
				drop_score = score
				drop_id = int(patron_id)
		if drop_id < 0:
			break
		patrons.erase(drop_id)


func _update_patron_after_visit(guest: Dictionary, mood: float, spent: float, completed: bool, refunded: bool) -> void:
	var patron_id: int = int(guest.get("patron_id", -1))
	if patron_id < 0:
		if mood >= 0.55:
			patron_id = _create_patron_from_guest(guest, mood, spent)
			guest["patron_id"] = patron_id
		return
	var patron: Dictionary = _patron_by_id(patron_id)
	if patron.is_empty():
		return
	var affinity: float = lerpf(float(patron.get("affinity", 0.5)), mood, 0.4)
	if refunded:
		affinity = maxf(0.0, affinity - 0.15)
	patron["affinity"] = affinity
	patron["visits"] = int(patron.get("visits", 0)) + 1
	patron["last_day"] = day
	patron["skill"] = float(guest.get("skill", patron.get("skill", 0.5)))
	patron["budget_base"] = maxf(float(patron.get("budget_base", 90.0)), float(guest.get("budget", 0.0)) + spent)
	var history: Array = patron.get("history", [])
	history.append({"day": day, "mood": mood, "spent": spent})
	while history.size() > PATRON_HISTORY_CAP:
		history.pop_front()
	patron["history"] = history
	if affinity < 0.35:
		patron["low_affinity_visits"] = int(patron.get("low_affinity_visits", 0)) + 1
	else:
		patron["low_affinity_visits"] = 0
	if completed:
		var strokes: int = int(guest.get("strokes", 0))
		var par_total: int = 0
		for hole in _course_holes:
			par_total += int(hole.get("par", 4))
		var cards: Array = patron.get("scorecards", [])
		cards.append({"strokes": strokes, "par": par_total})
		while cards.size() > PATRON_SCORECARDS_CAP:
			cards.pop_front()
		patron["scorecards"] = cards
		patron["handicap"] = _patron_handicap(patron)
		if not _course_holes.is_empty():
			var favourite: int = int(_course_holes[_rng.randi_range(0, _course_holes.size() - 1)].get("id", -1))
			if int(patron.get("favourite_hole_id", -1)) < 0:
				patron["favourite_hole_id"] = favourite
	if bool(patron.get("member", false)):
		_maybe_cancel_membership(patron, guest)
	else:
		_maybe_offer_membership(patron, guest)


func _best_affordable_membership_tier(patron: Dictionary) -> String:
	var order: Array[String] = ["founder", "player", "social"]
	for tier_id in order:
		if not _membership_tier_open(tier_id):
			continue
		if _membership_tier_count(tier_id) >= _membership_cap(tier_id):
			continue
		var dues: float = _membership_dues_for_tier(tier_id)
		if float(patron.get("budget_base", 0.0)) < dues / 30.0 * 2.0:
			continue
		return tier_id
	return ""


func _maybe_offer_membership(patron: Dictionary, guest: Dictionary) -> void:
	if int(patron.get("visits", 0)) < 3:
		return
	if float(patron.get("affinity", 0.0)) < 0.7:
		return
	var tier_id: String = _best_affordable_membership_tier(patron)
	if tier_id.is_empty():
		return
	var dues: float = _membership_dues_for_tier(tier_id)
	if float(patron.get("budget_base", 0.0)) < dues / 30.0 * 2.0:
		return
	if _rng.randf() >= 0.5 * float(patron.get("affinity", 0.5)):
		return
	_join_membership(patron, tier_id, guest)


func _join_membership(patron: Dictionary, tier_id: String, guest: Dictionary) -> void:
	patron["member"] = true
	patron["tier"] = tier_id
	patron["joined_day"] = day
	patron["dues_paid_through"] = day
	var tier_name: String = str(_membership_definition(tier_id).get("name", tier_id.capitalize()))
	_feedback(guest, "member_join", 0.08, "I joined as a %s member." % tier_name)
	post("success", "guest", "%s joined as a %s member" % [str(patron.get("name", "Guest")), tier_name], Vector3.INF, _tab_target("Money"))


func _maybe_cancel_membership(patron: Dictionary, guest: Dictionary) -> void:
	var tier_id: String = str(patron.get("tier", ""))
	var dues: float = _membership_dues_for_tier(tier_id)
	var monthly_budget: float = float(patron.get("budget_base", 0.0)) * 30.0
	var reason: String = ""
	if int(patron.get("low_affinity_visits", 0)) >= 2:
		reason = "loyalty faded after repeated poor visits"
	elif dues > monthly_budget * 0.45:
		reason = "dues exceed what I can afford"
	if reason.is_empty():
		return
	_cancel_membership(patron, guest, reason)


func _cancel_membership(patron: Dictionary, guest: Dictionary, reason: String) -> void:
	var tier_name: String = str(_membership_definition(str(patron.get("tier", ""))).get("name", patron.get("tier", "Member")))
	patron["member"] = false
	patron["tier"] = ""
	patron["joined_day"] = 0
	patron["dues_paid_through"] = 0
	patron["low_affinity_visits"] = 0
	_membership_churn_log.append({"day": day, "patron_id": int(patron.get("id", -1)), "tier": tier_name})
	_feedback(guest, "member_cancel", -0.06, "I cancelled my %s membership." % tier_name)
	post("info", "guest", "%s cancelled %s membership · %s" % [str(patron.get("name", "Guest")), tier_name, reason], Vector3.INF, _tab_target("Money"))


func _prune_lost_patrons() -> void:
	var removed: Array[String] = []
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if float(patron.get("affinity", 1.0)) >= 0.2:
			continue
		if day - int(patron.get("last_day", day)) < 20:
			continue
		removed.append(str(patron.get("name", "Guest")))
		patrons.erase(patron_id)
	if not removed.is_empty():
		post("info", "guest", "Lost customer", Vector3.INF, _tab_target("Guests"))


func _schedule_member_arrivals() -> void:
	_member_arrival_queue.clear()
	_member_arrival_index = 0
	var booking_boost: float = 1.5 if _loyalty_mailer_days > 0 else 1.0
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if not bool(patron.get("member", false)):
			continue
		var tier_id: String = str(patron.get("tier", ""))
		if not _membership_tier_open(tier_id):
			continue
		if _patron_on_site(int(patron_id)):
			continue
		var chance: float = 0.35 * float(patron.get("affinity", 0.5)) * booking_boost
		if _rng.randf() < chance:
			_member_arrival_queue.append(int(patron_id))
	var event: Dictionary = active_event()
	if not event.is_empty() and str(event.get("kind", "")) == "club_championship":
		for patron_id in patrons.keys():
			var patron: Dictionary = patrons[patron_id]
			if not bool(patron.get("member", false)) or str(patron.get("tier", "")) != "founder":
				continue
			if _member_arrival_queue.has(int(patron_id)):
				continue
			if _patron_on_site(int(patron_id)):
				continue
			_member_arrival_queue.append(int(patron_id))


func _settle_membership_dues() -> void:
	for patron_id in patrons.keys():
		var patron: Dictionary = patrons[patron_id]
		if not bool(patron.get("member", false)):
			continue
		var joined_day: int = int(patron.get("joined_day", day))
		if day % DAYS_PER_MONTH != joined_day % DAYS_PER_MONTH:
			continue
		var tier_id: String = str(patron.get("tier", ""))
		var dues: float = _membership_dues_for_tier(tier_id)
		if dues <= 0.0:
			continue
		var tier_name: String = str(_membership_definition(tier_id).get("name", tier_id.capitalize()))
		credit(dues, "membership", "%s dues · %s" % [tier_name, str(patron.get("name", "Member"))])
		patron["dues_paid_through"] = day


func _try_spawn_member_arrival() -> bool:
	if _member_arrival_index >= _member_arrival_queue.size():
		return false
	if _course_holes.is_empty() or not _has_facility("clubhouse") or guests.size() >= MAX_GUESTS:
		return false
	var patron_id: int = int(_member_arrival_queue[_member_arrival_index])
	_member_arrival_index += 1
	var patron: Dictionary = _patron_by_id(patron_id)
	if patron.is_empty() or _patron_on_site(patron_id):
		return _try_spawn_member_arrival()
	var event: Dictionary = active_event()
	var as_event: bool = not event.is_empty() and str(event.get("kind", "")) == "club_championship" and str(patron.get("tier", "")) == "founder"
	_create_member_group(patron, as_event)
	return true


func _create_member_group(patron: Dictionary, event_guest: bool) -> void:
	var group_id: int = _next_group_id
	_next_group_id += 1
	var group: Dictionary = {
		"id": group_id, "members": [], "size": 1, "state": "arriving", "hole_index": 0,
		"player_turn": 0, "current_hole_id": -1, "completed_hole_ids":[], "wait_seconds": 0.0, "service_seconds": 0.0,
		"cart": false, "cart_pos": _entrance(), "cart_parked": true, "cart_initialized": false,
		"cart_phase": "parked", "cart_route": PackedVector3Array(), "cart_route_index": 0,
		"final_destination": _entrance(), "event": event_guest, "event_id": _active_event_id if event_guest else -1,
		"facility_id": -1, "facility_kind": "", "facilities_visited": [], "paid": false,
		"wants_lodging": false, "lodge_nights": 0,
		"caddie": false, "post_round": false, "post_round_queue": [], "post_round_index": 0,
		"round_complete": false, "member_booking": true,
	}
	groups.append(group)
	_today_groups += 1
	var guest_id: int = _next_guest_id
	_next_guest_id += 1
	var guest: Dictionary = {
		"id": guest_id, "name": str(patron.get("name", _person_name(guest_id))), "pos": _entrance(),
		"destination": _entrance(), "activity": "arriving", "skill": float(patron.get("skill", 0.5)),
		"mood": clampf(float(patron.get("affinity", 0.66)) + _rng.randf_range(-0.05, 0.08), 0.0, 1.0),
		"hunger": _rng.randf_range(0.05, 0.38), "energy": _rng.randf_range(0.72, 1.0),
		"restroom": _rng.randf_range(0.0, 0.28), "budget": float(patron.get("budget_base", 120.0)),
		"spent": 0.0, "price_tolerance": _guest_price_tolerance(float(patron.get("skill", 0.5)), float(patron.get("budget_base", 120.0))),
		"group_id": group_id, "hole_index": 0, "strokes": 0, "scorecard": [],
		"thought": "Looking forward to my member round.", "feedback": [], "cart": false, "shot": {},
		"shot_elapsed": 0.0, "shot_serial": 0, "last_shot": {}, "route": PackedVector3Array(), "route_index": 0,
		"ball_pos": _entrance(), "paid_green_fee": 0.0, "patron_id": int(patron.get("id", -1)),
	}
	if str(patron.get("tier", "")) == "founder" and _cart_available():
		group["cart"] = true
		guest["cart"] = true
		guest["cart_pos"] = _entrance()
	guests.append(guest)
	group["members"].append(guest_id)
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	_set_group_destination(group, clubhouse.get("pos", _entrance()), bool(group.get("cart", false)))


func guest_patron_line(guest: Dictionary) -> String:
	var patron_id: int = int(guest.get("patron_id", -1))
	if patron_id < 0:
		return ""
	var patron: Dictionary = _patron_by_id(patron_id)
	if patron.is_empty():
		return ""
	var parts: Array[String] = []
	var visits: int = int(patron.get("visits", 0))
	if visits > 0:
		parts.append("Visit %d" % visits)
	if bool(patron.get("member", false)):
		var tier_name: String = str(_membership_definition(str(patron.get("tier", ""))).get("name", patron.get("tier", "Member")))
		parts.append("%s member" % tier_name)
	var handicap: float = _patron_handicap(patron)
	if handicap > 0.01:
		parts.append("Handicap %.1f" % handicap)
	return " · ".join(parts)


func _spawn_due_arrivals(dt: float) -> void:
	if not open or not arrivals_enabled:
		return
	_next_arrival_in -= dt
	if _next_arrival_in > 0.0:
		return
	if _try_spawn_member_arrival():
		_next_arrival_in = _rng.randf_range(0.45, 0.95) * DAY_SIM_SECONDS / maxf(1.0, float(maxi(_arrival_target, 1)))
		return
	if _arrived_today >= _arrival_target:
		_next_arrival_in = 60.0
		return
	if _course_holes.is_empty() or not _has_facility("clubhouse") or guests.size() >= MAX_GUESTS:
		_next_arrival_in = 60.0
		return
	var remaining_slots: int = mini(_arrival_target - _arrived_today, MAX_GUESTS - guests.size())
	var size: int = mini(_rng.randi_range(1, 4), remaining_slots)
	var event: Dictionary = active_event()
	if not event.is_empty() and int(event.get("attended", 0)) < int(event.get("target", 0)):
		size = mini(maxi(size, 2), remaining_slots)
	_create_group(size, not event.is_empty())
	_arrived_today += size
	_period_arrivals += size
	var interval: float = _rng.randf_range(0.65, 1.35) * DAY_SIM_SECONDS / maxf(1.0, float(_arrival_target))
	var green_book: Dictionary = _price_book_entry("green_fee")
	var twilight_start: float = float(green_book.get("twilight_start_minute", 420.0))
	if _day_seconds >= twilight_start and not is_weekend(day):
		var base_fee: float = float(green_book.get("base", 48.0))
		var twilight_fee: float = float(green_book.get("twilight", base_fee))
		var twilight_boost: float = clampf(base_fee / maxf(1.0, twilight_fee), 1.0, 1.6)
		interval /= twilight_boost
	_next_arrival_in = interval


func _person_name(id: int) -> String:
	var first=["Alex","Morgan","Jamie","Sam","Taylor","Jordan","Casey","Riley","Avery","Quinn","Cameron","Drew","Emerson","Rowan","Sage","Charlie"]
	var last=["Park","Miller","Chen","Rivera","Patel","Brooks","Reed","Woods","Nguyen","Carter","Kim","Santos","Gray","Bennett","Clarke","Ellis","Hughes","Moss","Singh"]
	return "%s %s"%[first[id%first.size()],last[(id/first.size()+id*7)%last.size()]]


func _create_group(size: int, event_guest: bool) -> void:
	var group_id: int = _next_group_id
	_next_group_id += 1
	var wants_cart: bool = _cart_available() and _rng.randf() < 0.48
	var lodge_prob: float = 0.12 + 0.2 * float(grade - 1)
	var wants_lodging: bool = _lodge_rooms_available() > 0 and _has_facility("lodge") and _rng.randf() < lodge_prob
	var wants_caddie: bool = _has_facility("caddie_house") and _rng.randf() < 0.28
	var group: Dictionary = {
		"id": group_id, "members": [], "size": size, "state": "arriving", "hole_index": 0,
		"player_turn": 0, "current_hole_id": -1, "completed_hole_ids":[], "wait_seconds": 0.0, "service_seconds": 0.0,
		"cart": wants_cart, "cart_pos": _entrance(), "cart_parked": true, "cart_initialized": false,
		"cart_phase": "parked", "cart_route": PackedVector3Array(), "cart_route_index": 0,
		"final_destination": _entrance(), "event": event_guest, "event_id": _active_event_id if event_guest else -1,
		"facility_id": -1, "facility_kind": "", "facilities_visited": [], "paid": false,
		"wants_lodging": wants_lodging, "lodge_nights": _rng.randi_range(1, 3) if wants_lodging else 0,
		"caddie": wants_caddie, "post_round": false, "post_round_queue": [], "post_round_index": 0,
		"round_complete": false,
	}
	groups.append(group)
	_today_groups += 1
	for index in range(size):
		var guest_id: int = _next_guest_id
		_next_guest_id += 1
		var patron_id: int = -1
		if _rng.randf() < _returning_patron_chance():
			patron_id = _pick_returning_patron_id()
		var skill: float = clampf(_rng.randfn(0.53 + _skill_bias(), 0.19), 0.06, 0.97)
		if _expert_arrival_boost() > 0.0 and _rng.randf() < _expert_arrival_boost():
			skill = clampf(maxf(skill, _rng.randfn(0.82, 0.08)), 0.06, 0.97)
		var budget: float = _rng.randf_range(90.0, 260.0)
		var guest: Dictionary = {
			"id": guest_id, "name": _person_name(guest_id), "pos": _entrance(),
			"destination": _entrance(), "activity": "arriving", "skill": skill,
			"mood": clampf(0.66 + _rng.randf_range(-0.1, 0.16), 0.0, 1.0),
			"hunger": _rng.randf_range(0.05, 0.38), "energy": _rng.randf_range(0.72, 1.0),
			"restroom": _rng.randf_range(0.0, 0.28), "budget": budget, "spent": 0.0,
			"price_tolerance": _guest_price_tolerance(skill, budget),
			"group_id": group_id, "hole_index": 0, "strokes": 0, "scorecard": [],
			"thought": "Looking forward to the round.", "feedback": [], "cart": wants_cart, "shot": {},
			"shot_elapsed": 0.0, "shot_serial": 0, "last_shot": {}, "route": PackedVector3Array(), "route_index": 0,
			"ball_pos": _entrance(), "paid_green_fee": 0.0, "patron_id": patron_id,
		}
		if patron_id >= 0:
			var patron: Dictionary = _patron_by_id(patron_id)
			if not patron.is_empty():
				patron["id"] = patron_id
				_apply_patron_to_guest(guest, patron)
			else:
				guest["patron_id"] = -1
		if wants_cart:
			guest["cart_pos"] = _entrance()
		if wants_caddie:
			guest["skill"] = minf(1.0, float(guest.get("skill", 0.5)) + 0.04)
		guests.append(guest)
		group["members"].append(guest_id)
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	var destination: Vector3 = clubhouse.get("pos", _entrance())
	_set_group_destination(group, destination, wants_cart)


func _enqueue_checkin(group: Dictionary) -> void:
	group["state"] = "checkin_queue"
	group["wait_seconds"] = 0.0
	group["service_seconds"] = 0.0
	group["_wait_noted"] = false
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
		if str(group.get("state", "")) != "departing":
			_safe_refund_and_depart(group, "The resort cannot process our booking.", 1.0, "")
		return
	var next_kind: String = _choose_pre_round_facility(group)
	if next_kind.is_empty():
		_send_to_next_hole(group)
	else:
		_send_to_facility(group, next_kind)


func _collect_green_fees(group: Dictionary) -> bool:
	if bool(group.get("paid", false)):
		return true
	for guest in _group_guests(group):
		var price_context: Dictionary = _guest_price_context(guest, group)
		var fee: float = price("green_fee", price_context)
		var cart_fee: float = price("cart", price_context) if bool(group.get("cart", false)) else 0.0
		var entry_fee: float = price("event_entry", price_context) if bool(group.get("event", false)) else 0.0
		var bundle_active: bool = bool(prices.get("bundle_weekend_cart", false)) and is_weekend(day)
		var due: float = fee + cart_fee + entry_fee
		if not _price_willing(guest, due, bundle_active):
			_balk_group(group, "The green fees are more than I wanted to pay.")
			return false
		if float(guest.get("budget", 0.0)) < due:
			group["cart"] = false
			cart_fee = 0.0
			due = fee + entry_fee
		if float(guest.get("budget", 0.0)) < due:
			_feedback(guest, "too_expensive", -0.05, "The green fees are more than I budgeted for.")
			return false
		guest["budget"] = float(guest["budget"]) - due
		guest["spent"] = float(guest.get("spent", 0.0)) + due
		guest["paid_green_fee"] = fee + entry_fee
		guest["cart"] = bool(group.get("cart", false))
		var description: String = "Green fee"
		if entry_fee > 0.0:
			description += " and event entry"
		if bool(group.get("cart", false)) and cart_fee > 0.0:
			description += " and cart"
		elif bool(group.get("cart", false)) and bundle_active:
			description += " with cart bundle"
		if due > 0.0:
			credit(due, "admissions", description)
	group["paid"] = true
	return true


func _balk_group(group: Dictionary, thought: String) -> void:
	for guest in _group_guests(group):
		_feedback(guest, "too_expensive", -0.05, thought)
		_today_balked += 1
	_release_group_resources(group)
	group["state"] = "departing"
	_set_group_destination(group, _entrance(), bool(group.get("cart", false)))


func _choose_pre_round_facility(group: Dictionary) -> String:
	if _has_facility("putting_green") and _rng.randf() < 0.22:
		return "putting_green"
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
	group["_wait_noted"] = false
	var queue: Array = _queue_for_facility(int(group["facility_id"]))
	if not queue.has(int(group["id"])):
		queue.append(int(group["id"]))
	_facility_queues[int(group["facility_id"])] = queue
	_set_group_destination(group, facility.get("pos", _entrance()), bool(group.get("cart", false)))


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
	if str(state.get("kind", "")) == "pro_shop" and not _shop_clerk_present():
		base_capacity = maxi(1, int(round(float(base_capacity) * 0.6)))
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
	var revenue_total: float = 0.0
	for guest in _group_guests(group):
		revenue_total += _apply_facility_to_guest(guest, kind, facility_id)
	if not kind.is_empty():
		_facility_visits[kind] = int(_facility_visits.get(kind, 0)) + 1
	if not state.is_empty():
		state["visits_today"] = int(state.get("visits_today", 0)) + 1
		state["revenue_today"] = float(state.get("revenue_today", 0.0)) + revenue_total
	if not state.is_empty():
		var decay_mult: float = float(_facility_tier_stats(str(state.get("kind", "")), int(state.get("level", 1))).get("decay_mult", 1.0))
		state["cleanliness"] = maxf(0.0, float(state.get("cleanliness", 1.0)) - 0.007 * float(group.get("size", 1)) * decay_mult)
		state["condition"] = maxf(0.0, float(state.get("condition", 1.0)) - 0.0015 * float(group.get("size", 1)))
	_remove_from_facility_queue(group)
	if not group.has("facilities_visited"):
		group["facilities_visited"] = []
	if not group["facilities_visited"].has(kind):
		group["facilities_visited"].append(kind)
	if bool(group.get("post_round", false)):
		var queue: Array = group.get("post_round_queue", [])
		var next_index: int = int(group.get("post_round_index", 0)) + 1
		group["post_round_index"] = next_index
		if next_index < queue.size():
			group["facility_kind"] = str(queue[next_index])
			group["state"] = "facility_queue"
			group["service_seconds"] = 0.0
			group["wait_seconds"] = 0.0
			_send_to_facility(group, str(queue[next_index]))
			return
		group["post_round"] = false
		_begin_departure_or_lodge(group)
		return
	_send_to_next_hole(group)


func _apply_facility_to_guest(guest: Dictionary, kind: String, facility_id: int = -1) -> float:
	var state: Dictionary = _facility_state.get(facility_id, {})
	var condition: float = float(state.get("condition", 1.0))
	var cleanliness: float = float(state.get("cleanliness", 1.0))
	var revenue: float = 0.0
	var group: Dictionary = _group_by_id(int(guest.get("group_id", -1)))
	var price_context: Dictionary = _guest_price_context(guest, group)
	if condition < 0.12:
		_feedback(guest, "broken_facility", -0.04, "This facility really needs repair.")
	elif cleanliness < 0.3:
		_feedback(guest, "dirty_facility", -0.025, "Could use a good clean.")
	match kind:
		"snack_kiosk", "halfway_house":
			var snack_price: float = price("snack", price_context)
			if kind == "halfway_house" or _guest_purchase(guest, snack_price, "food", "Snack purchase"):
				if kind != "halfway_house":
					revenue += snack_price
					_facility_revenue[kind] = float(_facility_revenue.get(kind, 0.0)) + snack_price
			guest["hunger"] = maxf(0.0, float(guest.get("hunger", 0.0)) - (0.5 if kind == "halfway_house" else 0.65))
			if kind == "halfway_house":
				guest["energy"] = minf(1.0, float(guest.get("energy", 0.0)) + 0.15)
			_feedback(guest, "served_snack", 0.05 if kind == "snack_kiosk" else 0.04, "That was a useful stop.")
		"putting_green":
			guest["skill"] = minf(1.0, float(guest.get("skill", 0.5)) + 0.015)
			guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.03)
			guest["thought"] = "Nice rolls on the practice green."
		"driving_range":
			var lesson_given: bool = false
			var range_level: int = int(state.get("level", 1))
			var lesson_bonus: float = float(_facility_tier_stats("driving_range", range_level).get("lesson_bonus", 0.0))
			if _golf_pro_available() and _rng.randf() < 0.5 + lesson_bonus:
				var lesson_price: float = price("lesson", {"minute": _day_seconds, "day": day})
				if _guest_purchase(guest, lesson_price, "lessons", "Golf lesson"):
					revenue += lesson_price
					_facility_revenue["lessons"] = float(_facility_revenue.get("lessons", 0.0)) + lesson_price
					guest["skill"] = minf(1.0, float(guest.get("skill", 0.5)) + 0.06)
					guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.08)
					_feedback(guest, "served_range", 0.06, "A helpful lesson before the round.")
					lesson_given = true
			if not lesson_given:
				var range_price: float = price("range", price_context)
				if _guest_purchase(guest, range_price, "range", "Driving range"):
					revenue += range_price
					_facility_revenue[kind] = float(_facility_revenue.get(kind, 0.0)) + range_price
				guest["skill"] = minf(1.0, float(guest.get("skill", 0.5)) + 0.025)
				guest["energy"] = maxf(0.0, float(guest.get("energy", 1.0)) - 0.04)
				_feedback(guest, "served_range", 0.03, "That was a useful stop.")
		"restroom":
			guest["restroom"] = 0.0
			_feedback(guest, "served_restroom", 0.03, "That was a useful stop.")
		"pro_shop":
			var retail_base: float = price("retail", {"minute": _day_seconds, "day": day})
			var retail_low: float = retail_base * 0.43
			var retail_high: float = retail_base * 1.43
			var retail_price: float = _rng.randf_range(retail_low, retail_high)
			if _guest_purchase(guest, retail_price, "retail", "Pro shop purchase"):
				revenue += retail_price
				_facility_revenue[kind] = float(_facility_revenue.get(kind, 0.0)) + retail_price
				guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.04)
				guest["thought"] = "Picked up something nice in the shop."
			else:
				guest["thought"] = "Browsed the pro shop."
		"restaurant":
			var meal_price: float = price("meal", {"minute": _day_seconds, "day": day})
			if _guest_purchase(guest, meal_price, "meals", "Restaurant meal"):
				revenue += meal_price
				_facility_revenue["meals"] = float(_facility_revenue.get("meals", 0.0)) + meal_price
				guest["hunger"] = maxf(0.0, float(guest.get("hunger", 0.0)) - 0.75)
				guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.10)
				_feedback(guest, "served_snack", 0.08, "A proper meal after the round.")
			else:
				guest["thought"] = "The menu looked a bit rich today."
		"bar_terrace":
			var drink_price: float = price("meal", {"minute": _day_seconds, "day": day}) * 0.55
			if _guest_purchase(guest, drink_price, "meals", "Terrace drink"):
				revenue += drink_price
				_facility_revenue["bar_terrace"] = float(_facility_revenue.get("bar_terrace", 0.0)) + drink_price
			guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.06)
			guest["thought"] = "A relaxing drink on the terrace."
		"spa":
			var spa_price: float = 45.0
			if _guest_purchase(guest, spa_price, "spa", "Spa treatment"):
				revenue += spa_price
				_facility_revenue[kind] = float(_facility_revenue.get(kind, 0.0)) + spa_price
			guest["energy"] = 1.0
			guest["mood"] = minf(1.0, float(guest.get("mood", 0.5)) + 0.12)
			guest["thought"] = "Feeling refreshed after the spa."
		"caddie_house":
			guest["skill"] = minf(1.0, float(guest.get("skill", 0.5)) + 0.04)
			guest["thought"] = "Great service from the caddie team."
		_:
			guest["thought"] = "That was a useful stop."
	return revenue


func _send_to_next_hole(group: Dictionary) -> void:
	var completed_ids = group.get("completed_hole_ids",[])
	var next_index = -1
	for index in range(_course_holes.size()):
		if not completed_ids.has(_course_holes[index].id):
			next_index=index
			break
	if next_index < 0:
		if bool(group.get("round_complete", false)):
			_begin_departure_or_lodge(group)
		else:
			_begin_post_round(group)
		return
	group["hole_index"] = next_index
	var hole: Dictionary = _course_holes[next_index]
	group["state"] = "to_tee"
	group["current_hole_id"] = int(hole.get("id", -1))
	_set_group_destination(group, hole.get("tee", _entrance()), bool(group.get("cart", false)))
	for guest in _group_guests(group):
		guest["hole_index"] = int(group["hole_index"])
		guest["activity"] = "walking_to_cart" if bool(group.get("cart", false)) else "walking"
		guest["thought"] = "On the way to hole %d." % (int(group["hole_index"]) + 1)


func _enqueue_hole(group: Dictionary) -> void:
	var hole_id: int = int(group.get("current_hole_id", -1))
	var queue: Array = _hole_queues.get(hole_id, [])
	if not queue.has(int(group["id"])):
		queue.append(int(group["id"]))
	if _group_has_priority_member(group) and queue.size() > 1:
		var last_index: int = queue.size() - 1
		var previous: Variant = queue[last_index - 1]
		queue[last_index - 1] = queue[last_index]
		queue[last_index] = previous
	_hole_queues[hole_id] = queue
	group["state"] = "tee_queue"
	group["wait_seconds"] = 0.0
	group["_wait_noted"] = false
	for guest in _group_guests(group):
		guest["activity"] = "waiting_at_tee"
		guest["thought"] = "Waiting for the fairway to clear."


func _tick_tee_queue(group: Dictionary, dt: float) -> void:
	var hole_id: int = int(group.get("current_hole_id", -1))
	var queue: Array = _hole_queues.get(hole_id, [])
	if queue.is_empty() or int(queue[0]) != int(group["id"]) or int(_hole_occupancy.get(hole_id, -1)) >= 0:
		group["wait_seconds"] = float(group.get("wait_seconds", 0.0)) + dt
		_apply_wait_mood(group, dt, _tee_queue_grace_seconds(hole_id))
		return
	queue.pop_front()
	_hole_queues[hole_id] = queue
	_hole_occupancy[hole_id] = int(group["id"])
	group["state"] = "playing"
	group["hole_start_minute"] = _actor_elapsed_seconds / 60.0
	group["cart_parked"] = true
	group["player_turn"] = 0
	group["play_phase"] = "ready"
	group["turn_pause"] = 2.4 * _play_pace_multiplier(group, hole_id)
	var hole: Dictionary = _hole_by_id(hole_id)
	for guest in _group_guests(group):
		var tee: Vector3 = start_position(hole, float(guest.get("skill", 0.5)))
		guest["ball_pos"] = tee
		guest["hole_strokes"] = 0
		guest["hole_done"] = false
		guest["activity"] = "watching"
	var beauty: float = 50.0
	var tee_sample: Vector3 = start_position(hole, 0.5)
	if terrain != null and terrain.has_method("beauty_at"):
		beauty = float(terrain.beauty_at(tee_sample))
	for guest in _group_guests(group):
		if beauty < 15.0:
			_feedback(guest, "bland_scenery", -0.015, "The scenery here feels a bit plain.")
		elif beauty > 60.0:
			_feedback(guest, "lovely_scenery", 0.02, "What a beautiful setting for golf.")


func _tick_play(group: Dictionary, dt: float) -> void:
	var hole: Dictionary = _hole_by_id(int(group.get("current_hole_id", -1)))
	if hole.is_empty() or not bool(hole.get("open", true)):
		_safe_refund_and_depart(group, "Course work interrupted the round.", 0.5, "refund_construction")
		return
	_tick_guest_needs(group)
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
		var use_cart: bool = bool(group.get("cart", false))
		if _move_guest(golfer, dt, use_cart):
			if use_cart:
				group["cart_pos"] = golfer["pos"]
			golfer["activity"] = "watching"
			var last_shot: Dictionary = golfer.get("last_shot", {})
			golfer["ball_pos"] = last_shot.get("end", golfer.get("pos", _entrance()))
			if bool(last_shot.get("holed", false)) or int(golfer.get("hole_strokes", 0)) >= MAX_STROKES:
				_finish_player_hole(group, golfer, hole)
			else:
				group["play_phase"] = "ready"
				group["turn_pause"] = 1.6
				golfer["shot_elapsed"] = 0.0
				_next_player_turn(group,players)


func _begin_shot(group: Dictionary, golfer: Dictionary, hole: Dictionary) -> void:
	var start: Vector3 = golfer.get("ball_pos", hole.get("tee", _entrance()))
	var shot: Dictionary
	if _shot_script != null and _shot_script.has_method("shot"):
		shot = _shot_script.shot(terrain, start, hole, float(golfer.get("skill", 0.5)), _rng)
	else:
		shot = _fallback_shot(start, hole, float(golfer.get("skill", 0.5)))
	# The persistent serial/last_shot pair lets the view animate independently
	# even when a 60-second root tick advances past this physical flight.
	shot["physics_duration"] = maxf(0.4,float(shot.get("duration", 1.0))) * SHOT_PACE
	shot["duration"] = shot["physics_duration"]
	golfer["shot"] = shot
	golfer["last_shot"] = shot.duplicate(true)
	golfer["shot_serial"] = int(golfer.get("shot_serial", 0)) + 1
	golfer["shot_elapsed"] = 0.0
	golfer["activity"] = "swinging"
	var thought: String = _shot_thought(shot)
	if bool(shot.get("hazard", false)):
		_feedback(golfer, "hazard", -0.02, thought)
	elif bool(shot.get("holed", false)):
		var strokes_after: int = int(golfer.get("hole_strokes", 0)) + 1 + int(shot.get("penalty", 0))
		if strokes_after < int(hole.get("par", 4)):
			_feedback(golfer, "great_hole", 0.04, thought)
		else:
			golfer["thought"] = thought
	else:
		golfer["thought"] = thought
	if String(shot.get("club", "")) == "putter" and terrain != null and terrain.has_method("condition_at"):
		if int(terrain.surface_at(start)) == 2 and float(terrain.condition_at(start)) < 0.4:
			var flagged: Array = golfer.get("_poor_greens", [])
			var hole_id: int = int(hole.get("id", -1))
			if not flagged.has(hole_id):
				flagged.append(hole_id)
				golfer["_poor_greens"] = flagged
				_feedback(golfer, "poor_greens", -0.03, "These greens are in rough shape.")
	group["play_phase"] = "shot"


func _finish_shot(group: Dictionary, golfer: Dictionary, hole: Dictionary) -> void:
	var shot: Dictionary = golfer.get("shot", {})
	var added: int = 1 + int(shot.get("penalty", 0))
	golfer["hole_strokes"] = int(golfer.get("hole_strokes", 0)) + added
	golfer["strokes"] = int(golfer.get("strokes", 0)) + added
	if bool(shot.get("hazard", false)):
		group["hole_hazards"] = int(group.get("hole_hazards", 0)) + 1
	var landing: Vector3 = shot.get("end", golfer.get("pos", _entrance()))
	var landing_sample: Vector3 = shot.get("landing", landing)
	analytics.add("landings", landing_sample, 1.0)
	if bool(shot.get("hazard", false)):
		analytics.add("hazard_landings", landing_sample, 1.0)
	if terrain != null and terrain.has_method("apply_wear_at"):
		var landing_surface: int = int(terrain.surface_at(landing_sample))
		if landing_surface == 4:
			terrain.apply_wear_at(landing_sample, 0.006)
		elif landing_surface == 2:
			terrain.apply_wear_at(landing_sample, 0.0015)
		elif landing_surface in [1, 3]:
			terrain.apply_wear_at(landing_sample, 0.0025)
	golfer["destination"] = landing
	# Golfers ride their group's cart to the ball when one is available.
	var use_cart: bool = bool(group.get("cart", false))
	golfer["route"] = _route(golfer.get("pos", start_position(hole)), landing, use_cart)
	golfer["route_index"] = 1 if (golfer["route"] as PackedVector3Array).size() > 1 else 0
	golfer["activity"] = "riding" if use_cart else "walking_to_ball"
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
	group["turn_pause"] = 1.4


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
	_record_hole_stats(group, hole)
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
	# Mid-round stop at the halfway house after the midpoint hole.
	var mid_index: int = int(floor(float(_course_holes.size()) / 2.0))
	if int(group["hole_index"]) == mid_index and int(group["hole_index"]) < _course_holes.size():
		if not group["facilities_visited"].has("halfway_house") and _has_facility("halfway_house"):
			if _group_average(group, "hunger") > 0.35 or _group_average(group, "energy") < 0.5:
				_send_to_facility(group, "halfway_house")
				return
	if int(group["hole_index"]) >= _course_holes.size():
		_begin_post_round(group)
		return
	_send_to_next_hole(group)


func _finish_departure(group: Dictionary) -> void:
	_has_departed=true
	group["state"] = "departed"
	group["departed_day"] = day
	group["departed_minute"] = minute
	var completed: bool = bool(group.get("round_complete", false))
	if not completed and not _course_holes.is_empty():
		completed = true
		for hole in _course_holes:
			if not group.get("completed_hole_ids", []).has(hole.id):
				completed = false
				break
	for guest in _group_guests(group):
		guest["activity"] = "departed"
		guest["pos"] = _entrance()
		guest["destination"] = _entrance()
		guest["route"] = PackedVector3Array()
		_today_spend_total += float(guest.get("spent", 0.0))
		_today_spend_guests += 1
		_today_mood_sum += float(guest.get("mood", 0.5))
		_today_mood_count += 1
		var refunded: bool = bool(guest.get("_patron_refund", false))
		_update_patron_after_visit(guest, float(guest.get("mood", 0.5)), float(guest.get("spent", 0.0)), completed, refunded)
		guest.erase("_patron_refund")
		if completed:
			completed_visits += 1
			_feedback(guest, "completed_round", 0.06, "A complete round—I’ll remember this place.")
		else:
			guest["thought"] = "Time to head home."
		_record_guest_review(guest, completed, int(group.get("hole_index", 0)))
		_add_rating_sample(_departure_star_rating(guest))
		satisfaction = lerpf(satisfaction, _group_average(group, "mood"), 0.018 * float(group.get("size", 1)))
	if completed:
		_today_completed_rounds += 1
		_track_course_record(group)
	if completed and bool(group.get("event", false)):
		var event: Dictionary = _event_by_id(int(group.get("event_id", -1)))
		if not event.is_empty():
			event["rounds_completed"] = int(event.get("rounds_completed", 0)) + int(group.get("size", 1))


func _safe_refund_and_depart(group: Dictionary, thought: String, fraction: float, tag: String = "refund_closure") -> void:
	_release_group_resources(group)
	var refund: float = 0.0
	for guest in _group_guests(group):
		var amount: float = float(guest.get("paid_green_fee", 0.0)) * clampf(fraction, 0.0, 1.0)
		refund += amount
		guest["budget"] = float(guest.get("budget", 0.0)) + amount
		guest["paid_green_fee"] = maxf(0,float(guest.get("paid_green_fee",0))-amount)
		guest["spent"] = maxf(0,float(guest.get("spent",0))-amount)
		if int(guest.get("patron_id", -1)) >= 0:
			guest["_patron_refund"] = true
		if tag.is_empty():
			guest["thought"] = thought
		else:
			_feedback(guest, tag, -0.04, thought)
		guest["shot"] = {}
		guest["shot_elapsed"] = 0.0
	if refund > 0.0:
		_force_expense(refund, "refund", "Guest recovery refund")
		post("warning", "guest", "Guest refunded", _group_leader_position(group))
	group["state"] = "departing"
	_set_group_destination(group, _entrance(), bool(group.get("cart", false)))


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
	if terrain != null and terrain.has_method("refresh_hole_condition_cache"):
		terrain.refresh_hole_condition_cache(minute)
	var cart_barn_exists: bool = not _facility_by_kind("cart_barn").is_empty()
	var minute_dt: float = dt / 60.0
	for worker in staff:
		_tick_worker_vitals(worker, dt, minute_dt)
		if not _worker_on_shift(worker):
			worker["activity"] = "off_shift"
			continue
		if _training_active(worker):
			worker["activity"] = "training"
			continue
		var role: String = str(worker.get("role", ""))
		if role == "groundskeeper":
			_tick_groundskeeper(worker, dt, cart_barn_exists)
			continue
		if role == "marshal":
			_tick_marshal(worker, dt)
			continue
		if role == "golf_pro":
			_tick_golf_pro(worker, dt)
			continue
		if role == "head_greenkeeper":
			_tick_head_greenkeeper(worker, dt, cart_barn_exists)
			continue
		if role == "shop_clerk":
			_tick_shop_clerk(worker, dt)
			continue
		var target: Dictionary = _staff_target(worker)
		if target.is_empty():
			worker["activity"] = "available"
			continue
		var target_pos: Vector3 = target.get("pos", _entrance())
		if worker.get("destination", _entrance()) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
			worker["destination"] = target_pos
			worker["route"] = _route(worker.get("pos", _entrance()), target_pos, false)
			worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
		if not _move_person(worker, dt, WALK_SPEED):
			worker["activity"] = "walking"
			worker["minutes_walking_today"] = float(worker.get("minutes_walking_today", 0.0)) + minute_dt
			continue
		var worker_skill: float = _effective_skill(worker)
		if role == "cleaner":
			worker["activity"] = "cleaning"
			worker["minutes_working_today"] = float(worker.get("minutes_working_today", 0.0)) + minute_dt
			var object_id: int = int(target.get("id", -1))
			var state: Dictionary = _facility_state.get(object_id, {})
			if not state.is_empty():
				state["cleanliness"] = minf(1.0, float(state.get("cleanliness", 1.0)) + dt * 0.0005 * worker_skill)
		else:
			worker["activity"] = "serving"
			worker["minutes_working_today"] = float(worker.get("minutes_working_today", 0.0)) + minute_dt


func _tick_groundskeeper(worker: Dictionary, dt: float, use_cart_travel: bool) -> void:
	var worker_skill: float = _effective_skill(worker) * _groundskeeper_supervision_multiplier(worker)
	var minute_dt: float = dt / 60.0
	var target_pos: Vector3 = Vector3(worker.get("maint_target", Vector3.INF))
	if not target_pos.is_finite():
		target_pos = _groundskeeper_target_pos(worker)
		worker["maint_target"] = target_pos
	var facility: Dictionary = _facility_near(target_pos, 10.0)
	if not facility.is_empty() and _staff_assignment(worker).get("kind", "") != "hole":
		worker["destination"] = facility.get("pos", target_pos)
		if worker.get("destination", _entrance()) != worker["destination"] or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
			worker["route"] = _route(worker.get("pos", _entrance()), worker["destination"], use_cart_travel)
			worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
		if not _move_person(worker, dt, CART_SPEED if use_cart_travel else WALK_SPEED):
			worker["activity"] = "walking"
			worker["minutes_walking_today"] = float(worker.get("minutes_walking_today", 0.0)) + minute_dt
			return
		worker["activity"] = "maintaining"
		worker["minutes_working_today"] = float(worker.get("minutes_working_today", 0.0)) + minute_dt
		var facility_id: int = int(facility.get("id", -1))
		var state: Dictionary = _facility_state.get(facility_id, {})
		if not state.is_empty():
			state["condition"] = minf(1.0, float(state.get("condition", 1.0)) + dt * 0.00022 * worker_skill * _maintenance_output_multiplier())
		return
	worker["destination"] = target_pos
	if worker.get("destination", _entrance()) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
		worker["route"] = _route(worker.get("pos", _entrance()), target_pos, use_cart_travel)
		worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
	if not _move_person(worker, dt, CART_SPEED if use_cart_travel else WALK_SPEED):
		worker["activity"] = "walking"
		worker["minutes_walking_today"] = float(worker.get("minutes_walking_today", 0.0)) + minute_dt
		return
	worker["activity"] = "maintaining"
	worker["minutes_working_today"] = float(worker.get("minutes_working_today", 0.0)) + minute_dt
	var restore_rate: float = dt * 0.0035 * worker_skill
	var hole: Dictionary = _hole_for_position(target_pos)
	if not hole.is_empty() and not bool(hole.get("open", true)):
		restore_rate *= 4.0
	if _maintenance_shed_near_hole(hole):
		restore_rate *= 1.5
	if terrain != null and terrain.has_method("restore_condition_at"):
		terrain.restore_condition_at(target_pos, restore_rate, 1)
		if terrain.has_method("condition_at") and float(terrain.condition_at(target_pos)) >= 0.995:
			worker["maint_target"] = _groundskeeper_next_cell(worker, target_pos)


func _staff_target(worker: Dictionary) -> Dictionary:
	var assignment: Dictionary = _staff_assignment(worker)
	if assignment.get("kind", "") == "object":
		return _facility_state.get(int(assignment.get("id", -1)), {})
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


func _staff_assignment(worker: Dictionary) -> Dictionary:
	var assignment: Variant = worker.get("assignment", -1)
	if assignment is Dictionary:
		return assignment as Dictionary
	if assignment is int and int(assignment) >= 0:
		return {"kind": "object", "id": int(assignment)}
	return {}


func _groundskeeper_target_pos(worker: Dictionary) -> Vector3:
	var assignment: Dictionary = _staff_assignment(worker)
	if assignment.get("kind", "") == "object":
		var facility: Dictionary = _facility_state.get(int(assignment.get("id", -1)), {})
		return facility.get("pos", _entrance())
	if assignment.get("kind", "") == "hole":
		var hole: Dictionary = _hole_by_id(int(assignment.get("id", -1)))
		if not hole.is_empty() and terrain != null and terrain.has_method("worst_cell_for_hole"):
			return terrain.worst_cell_for_hole(hole)
	var hole: Dictionary = _worst_condition_hole()
	if not hole.is_empty() and terrain != null and terrain.has_method("worst_cell_for_hole"):
		return terrain.worst_cell_for_hole(hole)
	return _lowest_condition_facility().get("pos", _entrance())


func _groundskeeper_next_cell(worker: Dictionary, current: Vector3) -> Vector3:
	if terrain == null or not terrain.has_method("worst_cell_near"):
		return _groundskeeper_target_pos(worker)
	var next: Vector3 = terrain.worst_cell_near(current, 30.0)
	if next.distance_to(current) < 0.5:
		return _groundskeeper_target_pos(worker)
	return next


func _worst_condition_hole() -> Dictionary:
	var best: Dictionary = {}
	var lowest: float = INF
	if terrain == null or not ("holes" in terrain) or not terrain.has_method("hole_condition"):
		return {}
	for hole_value in terrain.holes:
		var hole: Dictionary = hole_value
		var stats: Dictionary = terrain.hole_condition(hole)
		var score: float = float(stats.get("green", 1.0)) * 2.0
		if score < lowest:
			lowest = score
			best = hole
	return best


func _lowest_condition_facility() -> Dictionary:
	var best: Dictionary = {}
	var lowest: float = 2.0
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		var value: float = float(state.get("condition", 1.0))
		if value < lowest:
			lowest = value
			best = state
	return best


func _hole_for_position(pos: Vector3) -> Dictionary:
	if terrain == null or not ("holes" in terrain):
		return {}
	var best: Dictionary = {}
	var best_distance: float = INF
	for hole_value in terrain.holes:
		var hole: Dictionary = hole_value
		var cup: Vector3 = Vector3(hole.get("cup", Vector3.ZERO))
		var tee: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
		var distance: float = minf(pos.distance_to(cup), pos.distance_to(tee))
		if distance < best_distance:
			best_distance = distance
			best = hole
	return best


func _maintenance_shed_near_hole(hole: Dictionary) -> bool:
	if hole.is_empty() or terrain == null or not ("objects" in terrain):
		return false
	var center: Vector3 = Vector3(hole.get("cup", Vector3.ZERO)).lerp(Vector3(hole.get("tee", Vector3.ZERO)), 0.5)
	for object_value in terrain.objects:
		var object: Dictionary = object_value
		if str(object.get("kind", "")) != "maintenance_shed":
			continue
		if Vector3(object.get("pos", _entrance())).distance_to(center) <= 150.0:
			return true
	return false


func _facility_near(pos: Vector3, radius: float) -> Dictionary:
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		if Vector3(state.get("pos", _entrance())).distance_to(pos) <= radius:
			return state
	return {}


func _tick_facility_decay(dt: float) -> void:
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		if bool(state.get("closed", false)):
			continue
		var facility_id: int = int(state.get("id", -1))
		var use: float = float(_queue_for_facility(facility_id).size())
		var decay_mult: float = float(_facility_tier_stats(str(state.get("kind", "")), int(state.get("level", 1))).get("decay_mult", 1.0))
		state["cleanliness"] = maxf(0.0, float(state.get("cleanliness", 1.0)) - dt * (0.000002 + use * 0.000001) * decay_mult)
		state["condition"] = maxf(0.0, float(state.get("condition", 1.0)) - dt * 0.0000008)
		var condition: float = float(state.get("condition", 1.0))
		var cleanliness: float = float(state.get("cleanliness", 1.0))
		var warn_key: String = "%d:quality" % facility_id
		if condition < 0.3 or cleanliness < 0.3:
			if int(_facility_warn_day.get(warn_key, -1)) != day:
				_facility_warn_day[warn_key] = day
				var kind: String = str(state.get("kind", "facility"))
				post("warning", "facility", "%s needs maintenance (condition %.0f%%, cleanliness %.0f%%)" % [kind.replace("_", " "), condition * 100.0, cleanliness * 100.0], state.get("pos", _entrance()), {"kind": "object", "id": facility_id})
		if condition < 0.12:
			_facility_unusable_day = true
			var unusable_key: String = "%d:unusable" % facility_id
			if int(_facility_warn_day.get(unusable_key, -1)) != day:
				_facility_warn_day[unusable_key] = day
				post("critical", "facility", "%s is unusable" % str(state.get("kind", "facility")).replace("_", " "), state.get("pos", _entrance()), {"kind": "object", "id": facility_id})
		_sync_facility_object(state)


func _tick_watchdogs(dt: float) -> void:
	if not open:
		_cart_cap_since = -1.0
		_tee_queue_since.clear()
		return
	var barn: Dictionary = _facility_by_kind("cart_barn")
	if not barn.is_empty():
		var capacity: int = int(barn.get("capacity", 0))
		var carts_in_use: int = 0
		for group in groups:
			if bool(group.get("cart", false)) and str(group.get("state", "")) != "departed":
				carts_in_use += 1
		if capacity > 0 and carts_in_use >= capacity:
			if _cart_cap_since < 0.0:
				_cart_cap_since = 0.0
			_cart_cap_since += dt
			if _cart_cap_since >= 600.0 and int(_facility_warn_day.get("cart_barn:capacity", -1)) != day:
				_facility_warn_day["cart_barn:capacity"] = day
				var barn_id: int = int(barn.get("id", -1))
				post("info", "facility", "Cart barn at capacity", barn.get("pos", _entrance()), {"kind": "object", "id": barn_id})
		else:
			_cart_cap_since = -1.0
	for hole in _course_holes:
		var hole_id: int = int(hole.get("id", -1))
		var queue_size: int = _hole_queues.get(hole_id, []).size()
		if queue_size > 3:
			if not _tee_queue_since.has(hole_id):
				_tee_queue_since[hole_id] = 0.0
			_tee_queue_since[hole_id] = float(_tee_queue_since[hole_id]) + dt
			var queue_key: String = "hole:%d:queue" % hole_id
			if float(_tee_queue_since[hole_id]) >= 900.0 and int(_facility_warn_day.get(queue_key, -1)) != day:
				_facility_warn_day[queue_key] = day
				post("warning", "course", "Tee queue has %d groups waiting at hole %d" % [queue_size, _course_holes.find(hole) + 1], hole.get("tee", _entrance()), {"kind": "hole", "id": hole_id})
		elif _tee_queue_since.has(hole_id):
			_tee_queue_since.erase(hole_id)


func reopen() -> bool:
	if game_over:
		return false
	if cash < 0.0 and not sandbox:
		post("warning", "finance", "Positive cash is required to reopen", Vector3.INF, _tab_target("Money"))
		return false
	if _course_holes.is_empty():
		post("warning", "finance", "At least one playable hole is required to reopen", Vector3.INF, _tab_target("Money"))
		return false
	open = true
	_insolvent_days = 0
	_closed_reason = ""
	post("success", "finance", "Resort reopened", Vector3.INF, _tab_target("Money"))
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
			var kind: String = str(object.get("kind", ""))
			if bool(object.get("closed", false)):
				continue
			var definition: Dictionary = _catalog_find(kind)
			if definition.has("capacity"):
				var level: int = maxi(1, int(object.get("level", 1)))
				upkeep += float(_facility_tier_stats(kind, level).get("upkeep", definition.get("upkeep", 0.0)))
			else:
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
			post("warning", "finance", "%s missed a scheduled payment" % str(loan.get("name", "Loan")), Vector3.INF, _tab_target("Money"))


func _settle_events() -> void:
	for event in scheduled_events:
		var event_day: int = int(event.get("day", -1))
		if event_day < 0 or str(event.get("status", "")) != "active":
			continue
		var window_end: int = event_day + maxi(1, int(event.get("days", 1))) - 1
		if day < window_end:
			continue
		# Rounds now span many calendar days, so the result is judged once the
		# event field has finished playing, once attendance stalls for a
		# fortnight (saturated courses can hold part of the field waiting for
		# weeks), or a hard course-sized grace period ends.
		var still_playing: bool = false
		for group in groups:
			if int(group.get("event_id", -1)) == int(event.get("id", -1)) and str(group.get("state", "")) not in ["departed", "departing"]:
				still_playing = true
				break
		var last_attended: int = int(event.get("last_attended_day", window_end))
		var round_days: int = ceili(TARGET_ROUND_ACTOR_SECONDS * SIM_RATE / DAY_SIM_SECONDS)
		var field_waves: float = float(maxi(1, int(event.get("target", 1)))) / maxf(1.0, float(_course_holes.size()) * AVERAGE_GROUP_SIZE)
		var hard_grace: int = window_end + ceili(float(round_days) * (1.5 + field_waves))
		var stalled: bool = day > window_end and attendance_stalled(event, day, last_attended)
		if still_playing and day < hard_grace and not stalled:
			continue
		var attendance: int = int(event.get("attended", 0))
		var completed: int = int(event.get("rounds_completed", 0))
		var target: int = maxi(1, int(event.get("target", 1)))
		# Attendance is judged against the booking target; completion against
		# the guests who actually got onto the course, since a saturated
		# starter course can hold part of the field waiting for weeks.
		var completion_ratio: float = float(completed) / maxf(1.0, float(mini(attendance, target)))
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
			var awareness_gain: float = lerpf(4.0, 12.0, clampf(attendance_ratio, 0.0, 1.25))
			awareness = clampf(awareness + awareness_gain, 0.0, 100.0)
			buzz = clampf(buzz + 5.0, -20.0, 20.0)
			_add_press_headline("%s draws a strong crowd." % str(event.get("name", "Event")))
			satisfaction = minf(1.0, satisfaction + 0.025)
			post("success", "event", "%s succeeded · %d attended · %d completed rounds" % [str(event.get("name", "Event")), attendance, completed], Vector3.INF, _tab_target("Events"))
		else:
			buzz = clampf(buzz - 5.0, -20.0, 20.0)
			_add_press_headline("%s underwhelms local expectations." % str(event.get("name", "Event")))
			satisfaction = maxf(0.0, satisfaction - 0.018)
			post("warning", "event", "%s underperformed · %d attended · %d completed rounds" % [str(event.get("name", "Event")), attendance, completed], Vector3.INF, _tab_target("Events"))
		_update_derived_publicity()
		event_history.append(event.duplicate(true))
	_active_event_id = -1


func _reset_arrivals() -> void:
	_rotate_pins()
	press_headlines.clear()
	# Fractional demand carries across calendar days so small daily rates
	# still produce steady arrivals. Demand above what the course can absorb
	# simply queues guests longer and shows up as balks and poor reviews.
	_demand_carry += _demand_rate(day)
	var whole: int = int(_demand_carry)
	_demand_carry -= float(whole)
	_arrival_target = clampi(whole, 0, 60)
	_arrived_today = 0
	_next_arrival_in = _rng.randf_range(0.15, 0.5) * DAY_SIM_SECONDS / maxf(1.0, float(_arrival_target))
	var event_active: bool = false
	for event in scheduled_events:
		if int(event.get("id", -1)) == _active_event_id and str(event.get("status", "")) == "active":
			event_active = true
			break
	if not event_active:
		_active_event_id = -1
		for event in scheduled_events:
			if int(event.get("day", -1)) == day and str(event.get("status", "scheduled")) == "scheduled":
				event["status"] = "active"
				_active_event_id = int(event.get("id", -1))
				event_active = true
				post("info", "event", "%s is underway" % str(event.get("name", "Event")), Vector3.INF, _tab_target("Events"))
				break
	if event_active:
		var event: Dictionary = active_event()
		var spread: float = maxf(1.0, float(event.get("days", 1)))
		_arrival_target = clampi(_arrival_target + int(round(float(event.get("target", 0)) / spread)), 1, 60)
		var event_def: Dictionary = _event_definition(str(event.get("kind", "")))
		var entry_fee: float = price("event_entry", {"day": day})
		var attendance_ref: float = float(event_def.get("attendance_ref", 18.0))
		if entry_fee > attendance_ref:
			var penalty: float = clampf(1.0 - (entry_fee - attendance_ref) / maxf(1.0, attendance_ref * 2.0), 0.5, 1.0)
			_arrival_target = clampi(int(round(float(_arrival_target) * penalty)), 1, 60)
		_next_arrival_in = minf(_next_arrival_in, DAY_SIM_SECONDS / maxf(1.0, float(_arrival_target)))
	_refill_candidates()
	_schedule_member_arrivals()


func _add_event_hole(group: Dictionary) -> void:
	var event: Dictionary = _event_by_id(int(group.get("event_id", -1)))
	if event.is_empty():
		return
	if not bool(group.get("event_counted", false)):
		event["attended"] = int(event.get("attended", 0)) + int(group.get("size", 1))
		event["last_attended_day"] = day
		group["event_counted"] = true


func attendance_stalled(event: Dictionary, current_day: int, last_attended: int) -> bool:
	var round_days: int = ceili(TARGET_ROUND_ACTOR_SECONDS * SIM_RATE / DAY_SIM_SECONDS)
	return current_day - last_attended >= round_days and current_day >= int(event.get("day", 0)) + round_days


func _update_grade() -> void:
	while grade < 3:
		var target_grade: int = grade + 1
		var definition: Dictionary = _grade_definition(target_grade)
		var requirements: Dictionary = definition.get("requirements", {})
		var required_satisfaction: float = 0.60 if target_grade == 2 else 0.70
		var maximum_wear: float = 0.50 if target_grade == 2 else 0.35
		var quality_ok: bool = satisfaction >= required_satisfaction and _terrain_wear() <= maximum_wear
		var branch_ok: bool = _grade_branch_met(target_grade)
		if cash < float(requirements.get("cash", 0.0)) or _building_count() < int(requirements.get("buildings", 0)) or _course_holes.size() < int(requirements.get("holes", 0)) or publicity < float(requirements.get("publicity", 0.0)) or not _has_qualifying_event(target_grade):
			break
		if not sandbox and not _design_score_requirement_met(target_grade):
			break
		if not sandbox and not branch_ok:
			break
		if not quality_ok and not (sandbox and branch_ok):
			break
		grade = target_grade
		awareness = clampf(awareness + 10.0, 0.0, 100.0)
		_add_press_headline("Grade promotion puts Cedar House in the spotlight.")
		_update_derived_publicity()
		if unlocked.has("grade_club") == false and target_grade == 2:
			unlocked.append("grade_club")
		if unlocked.has("grade_resort") == false and target_grade == 3:
			unlocked.append("grade_resort")
		post("success", "event", "Resort upgraded to grade %d: %s" % [grade, str(definition.get("name", "new grade"))], Vector3.INF, _tab_target("Events"))


func _refresh_course() -> void:
	var previous_open: Dictionary = _hole_open_state.duplicate(true)
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
	if terrain != null and "holes" in terrain:
		for hole in terrain.holes:
			var hole_id: int = int(hole.get("id", -1))
			var was_open: bool = bool(previous_open.get(hole_id, hole.get("open", true)))
			var is_valid: bool = true
			if terrain.has_method("hole_valid"):
				is_valid = str(terrain.hole_valid(hole)).is_empty()
			var is_open: bool = bool(hole.get("open", true)) and is_valid
			_hole_open_state[hole_id] = is_open
			if was_open and not is_open:
				post("warning", "course", "%s is no longer playable" % str(hole.get("name", "Hole")), hole.get("tee", _entrance()), {"kind": "hole", "id": hole_id})
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
			var level: int = maxi(1, int(object.get("level", 1)))
			var tier_stats: Dictionary = _facility_tier_stats(kind, level)
			var state: Dictionary = _facility_state.get(object_id, {})
			if state.is_empty():
				state = {"id": object_id, "kind": kind}
			state["pos"] = object.get("pos", _entrance())
			state["level"] = level
			state["capacity"] = int(tier_stats.get("capacity", definition.get("capacity", 4)))
			state["upkeep"] = float(tier_stats.get("upkeep", definition.get("upkeep", 0.0)))
			state["closed"] = bool(object.get("closed", state.get("closed", false)))
			state["condition"] = float(object.get("condition", 1.0)) if reset_values else float(state.get("condition", object.get("condition", 1.0)))
			state["cleanliness"] = float(object.get("cleanliness", 1.0)) if reset_values else float(state.get("cleanliness", object.get("cleanliness", 1.0)))
			if not state.has("revenue_today"):
				state["revenue_today"] = 0.0
			if not state.has("visits_today"):
				state["visits_today"] = 0
			_facility_state[object_id] = state
			object["level"] = level
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
		var cart_start: Vector3 = group.get("cart_pos", leader.get("pos", _entrance()))
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
				guest["route"] = _route(guest.get("pos", _entrance()), cart_start, false)
				guest["route_index"] = 1 if (guest["route"] as PackedVector3Array).size() > 1 else 0
				guest["activity"] = "walking_to_cart"
				guest["cart_pos"] = group["cart_pos"]
			return
		group["cart"] = false
		group["cart_parked"] = true
		for guest in members:
			guest["cart"] = false
	var path: PackedVector3Array = _route(leader.get("pos", _entrance()), destination, false)
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
			_set_group_destination(group,group.get("final_destination",_entrance()),false)
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
		group["cart_pos"] = members[0].get("pos", group.get("cart_pos", _entrance()))
		analytics.add("cart_traffic", group["cart_pos"], dt)
		if terrain != null and terrain.has_method("apply_wear_at") and int(terrain.surface_at(group["cart_pos"])) == 1:
			terrain.apply_wear_at(group["cart_pos"], 0.0001 * dt)
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
		var cart_pos: Vector3 = group.get("cart_pos", _entrance())
		for guest in _group_guests(group):
			guest["cart_pos"] = cart_pos


func _move_guest(guest: Dictionary, dt: float, use_cart: bool) -> bool:
	return _move_person(guest, dt, CART_SPEED if use_cart else WALK_SPEED)


func _move_person(person: Dictionary, dt: float, speed: float) -> bool:
	var destination: Vector3 = person.get("destination", person.get("pos", _entrance()))
	var pos: Vector3 = person.get("pos", _entrance())
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
	var distance_left: float = speed * dt * BASE_PACE
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
	if person.has("group_id"):
		analytics.add("traffic", pos, dt)
	elif terrain != null and terrain.has_method("apply_wear_at"):
		var foot_surface: int = int(terrain.surface_at(pos))
		if foot_surface in [1, 2, 3]:
			terrain.apply_wear_at(pos, 0.00004 * dt)
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
			var start: Vector3 = guest.get("pos", _entrance())
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
		return guest.get("pos", _entrance()).distance_to(guest.get("destination", _entrance())) > 0.15
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
	return _entrance()


func _group_leader_position(group: Dictionary) -> Vector3:
	var members: Array[Dictionary] = _group_guests(group)
	return members[0].get("pos", _entrance()) if not members.is_empty() else _entrance()


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
	var reason: String = str(shot.get("reason", ""))
	if reason == "carry_hazard":
		return "Going for it."
	if reason == "safe_side":
		return "Aiming away from trouble."
	if reason == "lag_putt":
		return "Lagging this one close."
	if reason.contains("layup"):
		return "Laying up to set up the next shot."
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
	if terrain != null and "holes" in terrain:
		for hole_value in terrain.holes:
			var hole: Dictionary = hole_value
			if int(hole.get("id", -1)) == id:
				return hole
	for hole in _course_holes:
		if int(hole.get("id", -1)) == id:
			return hole
	return {}


func start_position(hole: Dictionary, skill: float = 0.5) -> Vector3:
	var tees_value: Variant = hole.get("tees", [])
	if tees_value is Array and (tees_value as Array).size() > 0 and _has_grant("tool:multi_tee"):
		var tees: Array = tees_value
		var forward: Vector3 = Vector3(hole.get("tee", _entrance()))
		var middle: Vector3 = forward
		var back: Vector3 = forward
		for tee_entry_value in tees:
			var tee_entry: Dictionary = tee_entry_value
			var name: String = str(tee_entry.get("name", "middle"))
			var pos: Vector3 = Vector3(tee_entry.get("pos", forward))
			if name == "forward":
				forward = pos
			elif name == "back":
				back = pos
			else:
				middle = pos
		if skill < 0.38:
			return forward
		if skill >= 0.72:
			return back
		return middle
	return Vector3(hole.get("tee", _entrance()))


func _rotate_pins() -> void:
	if terrain == null or not ("holes" in terrain):
		return
	for hole_value in terrain.holes:
		var hole: Dictionary = hole_value
		var pins_value: Variant = hole.get("pins", [])
		if pins_value is Array and (pins_value as Array).size() > 1:
			hole["pin_index"] = (int(hole.get("pin_index", 0)) + 1) % (pins_value as Array).size()


static func effective_cup(hole: Dictionary) -> Vector3:
	var pins_value: Variant = hole.get("pins", [])
	if pins_value is Array and (pins_value as Array).size() > 0:
		var index: int = clampi(int(hole.get("pin_index", 0)), 0, (pins_value as Array).size() - 1)
		return Vector3((pins_value as Array)[index])
	return Vector3(hole.get("cup", Vector3.ZERO))


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
		if str(state.get("kind", "")) != kind or bool(state.get("closed", false)):
			continue
		var score: float = float(state.get("condition", 0.0)) + float(state.get("cleanliness", 0.0)) - float(_queue_for_facility(int(state.get("id", -1))).size()) * 0.1
		if score > best_score:
			best_score = score
			best = state
	return best


func _has_facility(kind: String) -> bool:
	return _facility_is_open(_facility_by_kind(kind))


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
		if _assigned_to_object(worker, facility_id) or worker.get("pos", _entrance()).distance_to(_facility_state.get(facility_id, {}).get("pos", _entrance())) < 12.0:
			count += 1
	return count


func _service_workers_at(facility_id: int) -> int:
	var count: int = 0
	var target_pos: Vector3 = _facility_state.get(facility_id, {}).get("pos", _entrance())
	for worker in staff:
		if str(worker.get("role", "")) != "service_attendant":
			continue
		if _assigned_to_object(worker, facility_id) or (_staff_assignment(worker).is_empty() and worker.get("pos", _entrance()).distance_to(target_pos) < 12.0):
			count += 1
	return count


func _assigned_to_object(worker: Dictionary, object_id: int) -> bool:
	var assignment: Dictionary = _staff_assignment(worker)
	return assignment.get("kind", "") == "object" and int(assignment.get("id", -1)) == object_id


func _facility_duration(kind: String) -> float:
	match kind:
		"driving_range": return 150.0
		"snack_kiosk", "halfway_house": return 55.0
		"putting_green": return 70.0
		"restroom": return 38.0
		"pro_shop": return 80.0
		"restaurant": return 120.0
		"bar_terrace": return 75.0
		"spa": return 140.0
		"caddie_house": return 50.0
		_: return 60.0


func _group_average(group: Dictionary, field: String) -> float:
	var members: Array[Dictionary] = _group_guests(group)
	if members.is_empty():
		return 0.0
	var total: float = 0.0
	for guest in members:
		total += float(guest.get(field, 0.0))
	return total / float(members.size())


func _feedback(guest: Dictionary, tag: String, delta: float, text: String) -> void:
	guest["thought"] = text
	var feedback: Array = guest.get("feedback", [])
	feedback.append({"tag": tag, "delta": delta, "minute": minute})
	while feedback.size() > FEEDBACK_CAP:
		feedback.pop_front()
	guest["feedback"] = feedback
	guest["mood"] = clampf(float(guest.get("mood", 0.5)) + delta, 0.0, 1.0)


func _wait_feedback_tag(state: String) -> String:
	match state:
		"tee_queue":
			return "wait_tee"
		"checkin_queue":
			return "wait_checkin"
		"facility_queue":
			return "wait_facility"
	return ""


func _tick_guest_needs(group: Dictionary) -> void:
	for guest in _group_guests(group):
		if float(guest.get("hunger", 0.0)) > 0.8 and not _has_facility("snack_kiosk") and not bool(guest.get("_unmet_hunger", false)):
			guest["_unmet_hunger"] = true
			_feedback(guest, "unmet_hunger", -0.04, "I couldn't find anywhere to eat.")
		if float(guest.get("restroom", 0.0)) > 0.8 and not _has_facility("restroom") and not bool(guest.get("_unmet_restroom", false)):
			guest["_unmet_restroom"] = true
			_feedback(guest, "unmet_restroom", -0.04, "I really needed a restroom.")


func _skill_band(skill: float) -> String:
	if skill < 0.4:
		return "beginner"
	if skill < 0.72:
		return "intermediate"
	return "expert"


func _feedback_tag_counts(guest: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for entry in guest.get("feedback", []):
		var tag: String = str(entry.get("tag", ""))
		if tag.is_empty():
			continue
		counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


func _dominant_tag(counts: Dictionary, tags: Array[String]) -> String:
	var best_tag: String = ""
	var best_count: int = 0
	for tag in tags:
		var count: int = int(counts.get(tag, 0))
		if count > best_count:
			best_count = count
			best_tag = tag
	return best_tag


func _review_headline(tag_counts: Dictionary, mood: float) -> String:
	if mood < 0.45:
		var complaint: String = _dominant_tag(tag_counts, FEEDBACK_NEGATIVE_TAGS)
		if not complaint.is_empty():
			return str(FEEDBACK_TEXT.get(complaint, complaint))
	if mood > 0.7:
		var praise: String = _dominant_tag(tag_counts, FEEDBACK_POSITIVE_TAGS)
		if not praise.is_empty():
			return str(FEEDBACK_TEXT.get(praise, praise))
	return "A steady day on the course"


func _record_guest_review(guest: Dictionary, completed: bool, holes_played: int) -> void:
	var tag_counts: Dictionary = _feedback_tag_counts(guest)
	var mood: float = float(guest.get("mood", 0.5))
	var review: Dictionary = {
		"day": day,
		"guest_name": str(guest.get("name", "")),
		"guest_id": int(guest.get("id", -1)),
		"skill": _skill_band(float(guest.get("skill", 0.5))),
		"mood": mood,
		"spent": float(guest.get("spent", 0.0)),
		"strokes_total": int(guest.get("strokes", 0)),
		"holes_played": holes_played,
		"tags": tag_counts,
		"headline": _review_headline(tag_counts, mood),
	}
	reviews.append(review)
	while reviews.size() > REVIEWS_CAP:
		reviews.pop_front()
	if not daily_feedback.has(day):
		daily_feedback[day] = {}
	var day_counts: Dictionary = daily_feedback[day]
	for tag in tag_counts.keys():
		day_counts[tag] = int(day_counts.get(tag, 0)) + int(tag_counts[tag])
	daily_feedback[day] = day_counts


func feedback_summary(days: int = 1, end_day: int = -1) -> Dictionary:
	if days < 1:
		days = 1
	if end_day < 0:
		end_day = day
	var start_day: int = maxi(1, end_day - days + 1)
	var tag_totals: Dictionary = {}
	var mood_sum: float = 0.0
	var mood_count: int = 0
	var spend_sum: float = 0.0
	var spend_count: int = 0
	var refund_reviews: int = 0
	var completed_reviews: int = 0
	var review_count: int = 0
	var skill_mood: Dictionary = {"beginner": {"sum": 0.0, "count": 0}, "intermediate": {"sum": 0.0, "count": 0}, "expert": {"sum": 0.0, "count": 0}}
	for day_value in range(start_day, end_day + 1):
		var day_counts: Dictionary = daily_feedback.get(day_value, {})
		for tag in day_counts.keys():
			tag_totals[tag] = int(tag_totals.get(tag, 0)) + int(day_counts[tag])
	for review in reviews:
		var review_day: int = int(review.get("day", -1))
		if review_day < start_day or review_day > end_day:
			continue
		review_count += 1
		mood_sum += float(review.get("mood", 0.5))
		mood_count += 1
		spend_sum += float(review.get("spent", 0.0))
		spend_count += 1
		var review_tags: Dictionary = review.get("tags", {})
		var refunded: bool = false
		for refund_tag in FEEDBACK_REFUND_TAGS:
			if int(review_tags.get(refund_tag, 0)) > 0:
				refunded = true
				break
		if refunded:
			refund_reviews += 1
		if int(review_tags.get("completed_round", 0)) > 0:
			completed_reviews += 1
		var band: String = str(review.get("skill", "intermediate"))
		if not skill_mood.has(band):
			skill_mood[band] = {"sum": 0.0, "count": 0}
		skill_mood[band]["sum"] = float(skill_mood[band]["sum"]) + float(review.get("mood", 0.5))
		skill_mood[band]["count"] = int(skill_mood[band]["count"]) + 1
	var total_tags: int = 0
	for count in tag_totals.values():
		total_tags += int(count)
	var top_complaints: Array[Dictionary] = []
	for tag in FEEDBACK_NEGATIVE_TAGS:
		var count: int = int(tag_totals.get(tag, 0))
		if count <= 0:
			continue
		top_complaints.append({
			"tag": tag,
			"count": count,
			"share": float(count) / maxf(1.0, float(total_tags)),
		})
	top_complaints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	var top_praise: Array[Dictionary] = []
	for tag in FEEDBACK_POSITIVE_TAGS:
		var count: int = int(tag_totals.get(tag, 0))
		if count <= 0:
			continue
		top_praise.append({
			"tag": tag,
			"count": count,
			"share": float(count) / maxf(1.0, float(total_tags)),
		})
	top_praise.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	var by_skill: Dictionary = {}
	for band in skill_mood.keys():
		var bucket: Dictionary = skill_mood[band]
		var bucket_count: int = int(bucket.get("count", 0))
		by_skill[band] = float(bucket.get("sum", 0.0)) / maxf(1.0, float(bucket_count))
	return {
		"top_complaints": top_complaints.slice(0, 3),
		"top_praise": top_praise.slice(0, 3),
		"average_mood": mood_sum / maxf(1.0, float(mood_count)),
		"refund_rate": float(refund_reviews) / maxf(1.0, float(review_count)),
		"completion_rate": float(completed_reviews) / maxf(1.0, float(review_count)),
		"average_spend": spend_sum / maxf(1.0, float(spend_count)),
		"by_skill": by_skill,
		"review_count": review_count,
		"tag_totals": tag_totals,
	}


func _apply_wait_mood(group: Dictionary, dt: float, grace_seconds: float) -> void:
	analytics.add("waiting", _group_leader_position(group), dt)
	if float(group.get("wait_seconds", 0.0)) <= grace_seconds:
		return
	var state: String = str(group.get("state", ""))
	match state:
		"tee_queue":
			_wait_tee_seconds += dt
		"checkin_queue":
			_wait_checkin_seconds += dt
	var tag: String = _wait_feedback_tag(state)
	if tag.is_empty():
		return
	var mood_delta: float = -dt * 0.00008 * _marshal_wait_multiplier(group)
	var thought: String = "This queue is taking too long."
	if not bool(group.get("_wait_noted", false)):
		group["_wait_noted"] = true
		for guest in _group_guests(group):
			_feedback(guest, tag, mood_delta, thought)
	else:
		for guest in _group_guests(group):
			guest["mood"] = maxf(0.0, float(guest.get("mood", 0.5)) + mood_delta)
			guest["thought"] = thought


func _guest_purchase(guest: Dictionary, amount: float, category: String, description: String) -> bool:
	if not _price_willing(guest, amount):
		_feedback(guest, "too_expensive", -0.03, "That price felt steep.")
		guest["thought"] = "That price felt steep."
		return false
	if float(guest.get("budget", 0.0)) + 0.001 < amount:
		guest["thought"] = "I’ll save my remaining cash."
		return false
	guest["budget"] = float(guest.get("budget", 0.0)) - amount
	guest["spent"] = float(guest.get("spent", 0.0)) + amount
	credit(amount, category, description)
	return true


func _checkin_capacity() -> int:
	var clubhouse: Dictionary = _facility_by_kind("clubhouse")
	if clubhouse.is_empty():
		return 1
	var quality: float = minf(float(clubhouse.get("condition", 1.0)), float(clubhouse.get("cleanliness", 1.0)))
	var base: int = maxi(1, int(round(float(int(clubhouse.get("capacity", 4)) / 4) * clampf(quality, 0.35, 1.0))))
	var bonus: int = int(_facility_tier_stats("clubhouse", int(clubhouse.get("level", 1))).get("checkin_bonus", 0))
	return base + _service_workers_at(int(clubhouse.get("id", -1))) + bonus


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


func _normalize_worker(worker: Dictionary) -> void:
	var assignment: Variant = worker.get("assignment", -1)
	if assignment is int and int(assignment) >= 0:
		worker["assignment"] = {"kind": "object", "id": int(assignment)}
	worker["experience"] = float(worker.get("experience", 0.0))
	worker["morale"] = float(worker.get("morale", 0.7))
	worker["fatigue"] = float(worker.get("fatigue", 0.0))
	worker["shift"] = str(worker.get("shift", "full"))
	if not worker.has("training") or not (worker.get("training") is Dictionary):
		worker["training"] = {}
	if not worker.has("traits"):
		worker["traits"] = []
	worker["hired_day"] = int(worker.get("hired_day", day))
	worker["raise_requested"] = bool(worker.get("raise_requested", false))
	worker["low_morale_days"] = int(worker.get("low_morale_days", 0))
	worker["raise_ignored_days"] = int(worker.get("raise_ignored_days", 0))
	worker["minutes_working_today"] = float(worker.get("minutes_working_today", 0.0))
	worker["minutes_walking_today"] = float(worker.get("minutes_walking_today", 0.0))
	worker["minutes_off_today"] = float(worker.get("minutes_off_today", 0.0))
	worker["worked_today"] = bool(worker.get("worked_today", false))


func _effective_skill(worker: Dictionary) -> float:
	var base: float = clampf(float(worker.get("skill", 0.7)), 0.25, 1.5)
	var experience: float = clampf(float(worker.get("experience", 0.0)), 0.0, 1.0)
	var morale: float = clampf(float(worker.get("morale", 0.7)), 0.0, 1.0)
	var fatigue: float = clampf(float(worker.get("fatigue", 0.0)), 0.0, 1.0)
	var value: float = base * (0.7 + 0.3 * experience) * (0.6 + 0.4 * morale) * (1.0 - 0.35 * fatigue)
	if morale > 0.8:
		value *= 1.1
	if fatigue > FATIGUE_WARN_THRESHOLD:
		value *= 0.5
	return clampf(value, 0.1, 2.0)


func _training_active(worker: Dictionary) -> bool:
	var training: Variant = worker.get("training", {})
	return training is Dictionary and int((training as Dictionary).get("days_left", 0)) > 0


func _worker_on_shift(worker: Dictionary) -> bool:
	# Staggered actor-time duty cycles: 15 minutes on, 5 minutes off.
	var shift: String = str(worker.get("shift", "full"))
	var offset: float = {"early": 0.0, "full": 300.0, "late": 600.0}.get(shift, 300.0)
	return fmod(_actor_elapsed_seconds + offset, 1200.0) < 900.0


func _tick_worker_vitals(worker: Dictionary, dt: float, minute_dt: float) -> void:
	if not _worker_on_shift(worker):
		worker["minutes_off_today"] = float(worker.get("minutes_off_today", 0.0)) + minute_dt
		worker["fatigue"] = maxf(0.0, float(worker.get("fatigue", 0.0)) - minute_dt * 0.0025)
		return
	if _training_active(worker):
		return
	var fatigue_rate: float = FATIGUE_RATE
	if (worker.get("traits", []) as Array).has("careful"):
		fatigue_rate *= 0.85
	var activity: String = str(worker.get("activity", ""))
	if activity in ["maintaining", "cleaning", "serving", "patrolling", "teaching", "supervising"]:
		worker["worked_today"] = true
		worker["fatigue"] = minf(1.0, float(worker.get("fatigue", 0.0)) + minute_dt * fatigue_rate)
		var experience_rate: float = 0.004 / 45.0
		if (worker.get("traits", []) as Array).has("quick_learner"):
			experience_rate *= 1.35
		if _mentor_near(worker):
			experience_rate *= 1.25
		worker["experience"] = minf(1.0, float(worker.get("experience", 0.0)) + minute_dt * experience_rate)
		if float(worker.get("fatigue", 0.0)) > FATIGUE_WARN_THRESHOLD and not bool(worker.get("_fatigue_warned", false)):
			worker["_fatigue_warned"] = true
			post("warning", "staff", "%s is exhausted" % str(worker.get("name", "Worker")), worker.get("pos", _entrance()), {"kind": "staff", "id": int(worker.get("id", -1))})
	var target_morale: float = _morale_target(worker)
	var morale: float = float(worker.get("morale", 0.7))
	worker["morale"] = clampf(lerpf(morale, target_morale, minute_dt * 0.02), 0.0, 1.0)


func _morale_target(worker: Dictionary) -> float:
	var definition: Dictionary = _role_definition(str(worker.get("role", "")))
	var base_wage: float = float(definition.get("wage", worker.get("wage", 150.0)))
	var experience: float = float(worker.get("experience", 0.0))
	var fair_wage: float = base_wage * (1.0 + experience)
	var wage_ratio: float = float(worker.get("wage", fair_wage)) / maxf(1.0, fair_wage)
	var wage_score: float = clampf((wage_ratio - 0.75) / 0.5, 0.0, 1.0)
	var work_minutes: float = float(worker.get("minutes_working_today", 0.0))
	var walk_minutes: float = float(worker.get("minutes_walking_today", 0.0))
	var workload: float = 0.65
	if work_minutes + walk_minutes > 0.01:
		workload = clampf(work_minutes / maxf(1.0, work_minutes + walk_minutes), 0.2, 1.0)
	var facility_score: float = 0.7
	var assignment: Dictionary = _staff_assignment(worker)
	if assignment.get("kind", "") == "object":
		var state: Dictionary = _facility_state.get(int(assignment.get("id", -1)), {})
		if not state.is_empty():
			facility_score = minf(float(state.get("condition", 1.0)), float(state.get("cleanliness", 1.0)))
	elif assignment.get("kind", "") == "hole":
		var hole: Dictionary = _hole_by_id(int(assignment.get("id", -1)))
		if not hole.is_empty() and terrain != null and terrain.has_method("hole_condition"):
			var stats: Dictionary = terrain.hole_condition(hole)
			facility_score = float(stats.get("green", 1.0))
	var target: float = wage_score * 0.45 + workload * 0.20 + facility_score * 0.20 + satisfaction * 0.15
	if (worker.get("traits", []) as Array).has("grumpy"):
		target -= 0.05
	return clampf(target, 0.05, 1.0)


func _end_staff_day() -> void:
	for index in range(staff.size() - 1, -1, -1):
		var worker: Dictionary = staff[index]
		var worker_id: int = int(worker.get("id", -1))
		if _training_active(worker):
			var training: Dictionary = worker.get("training", {})
			training["days_left"] = int(training.get("days_left", 0)) - 1
			if int(training.get("days_left", 0)) <= 0:
				var course: Dictionary = _training_definition(str(training.get("course", "")))
				if not course.is_empty():
					worker["skill"] = minf(1.5, float(worker.get("skill", 0.7)) + float(course.get("skill_bonus", 0.0)))
				worker["training"] = {}
				worker["activity"] = "available"
				post("success", "staff", "%s completed training" % str(worker.get("name", "Worker")), worker.get("pos", _entrance()), {"kind": "staff", "id": worker_id})
			continue
		# Fatigue follows actor time and recovers continuously while off shift;
		# calendar rollover only closes the accounting record.
		worker["minutes_working_today"] = 0.0
		worker["minutes_walking_today"] = 0.0
		worker["minutes_off_today"] = 0.0
		worker["worked_today"] = false
		worker.erase("_fatigue_warned")


func _review_staff_month() -> void:
	for index in range(staff.size() - 1, -1, -1):
		var worker: Dictionary = staff[index]
		var worker_id: int = int(worker.get("id", -1))
		var morale: float = float(worker.get("morale", 0.7))
		if morale < 0.3:
			worker["low_morale_days"] = int(worker.get("low_morale_days", 0)) + 1
			if int(worker.get("low_morale_days", 0)) >= 3 and not bool(worker.get("raise_requested", false)):
				worker["raise_requested"] = true
				post("warning", "staff", "%s requested a raise" % str(worker.get("name", "Worker")), worker.get("pos", _entrance()), {"kind": "staff", "id": worker_id})
		else:
			worker["low_morale_days"] = 0
			if not bool(worker.get("raise_requested", false)):
				worker["raise_ignored_days"] = 0
		if bool(worker.get("raise_requested", false)):
			worker["raise_ignored_days"] = int(worker.get("raise_ignored_days", 0)) + 1
			if int(worker.get("raise_ignored_days", 0)) >= 5:
				staff.remove_at(index)
				post("critical", "staff", "%s quit after an ignored raise request" % str(worker.get("name", "Worker")), worker.get("pos", _entrance()), {"kind": "staff", "id": worker_id})


func _refill_candidates() -> void:
	candidates.clear()
	if _catalog_script == null or not _catalog_script.has_method("staff_roles"):
		return
	for role_def_value in _catalog_script.staff_roles():
		var role_def: Dictionary = role_def_value
		var role_id: String = str(role_def.get("id", ""))
		if role_id.is_empty() or not _role_unlocked(role_def):
			continue
		if not _role_facility_ready(role_def):
			continue
		var applicant_count: int = _rng.randi_range(2, 4)
		for _index in range(applicant_count):
			candidates.append(_roll_candidate(role_def))


func _roll_candidate(role_def: Dictionary) -> Dictionary:
	var role_id: String = str(role_def.get("id", ""))
	var skill: float = _rng.randf_range(0.45, 0.95)
	var base_wage: float = float(role_def.get("wage", 150.0))
	var wage: float = round(base_wage * _rng.randf_range(0.92, 1.18))
	var traits: Array[String] = []
	if _rng.randf() < 0.55:
		traits.append(STAFF_TRAIT_IDS[_rng.randi_range(0, STAFF_TRAIT_IDS.size() - 1)])
	var candidate_id: int = _next_candidate_id
	_next_candidate_id += 1
	return {
		"id": candidate_id,
		"role": role_id,
		"name": "%s applicant %02d" % [str(role_def.get("name", role_id)), candidate_id],
		"skill": skill,
		"wage": wage,
		"traits": traits,
	}


func _role_unlocked(role_def: Dictionary) -> bool:
	if sandbox:
		return true
	return can_build(str(role_def.get("id", "")))


func _role_facility_ready(role_def: Dictionary) -> bool:
	var needs: String = str(role_def.get("needs", ""))
	if needs.is_empty():
		return true
	return _has_facility(needs)


func _candidate_by_id(candidate_id: int) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("id", -1)) == candidate_id:
			return candidate
	return {}


func _worker_by_id(worker_id: int) -> Dictionary:
	for worker in staff:
		if int(worker.get("id", -1)) == worker_id:
			return worker
	return {}


func _training_definition(course_id: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("training"):
		for value in _catalog_script.training():
			var item: Dictionary = value
			if str(item.get("id", "")) == course_id:
				return item
	return {}


func _mentor_near(worker: Dictionary) -> bool:
	var pos: Vector3 = worker.get("pos", _entrance())
	for other in staff:
		if int(other.get("id", -1)) == int(worker.get("id", -1)):
			continue
		if not (other.get("traits", []) as Array).has("mentor"):
			continue
		if pos.distance_to(other.get("pos", _entrance())) <= 25.0:
			return true
	return false


func _head_greenkeeper_near(pos: Vector3) -> bool:
	for worker in staff:
		if str(worker.get("role", "")) != "head_greenkeeper" or _training_active(worker):
			continue
		if pos.distance_to(worker.get("pos", _entrance())) <= 200.0:
			return true
	return false


func _groundskeeper_supervision_multiplier(worker: Dictionary) -> float:
	if str(worker.get("role", "")) != "groundskeeper":
		return 1.0
	return 1.2 if _head_greenkeeper_near(worker.get("pos", _entrance())) else 1.0


func _marshal_on_hole(hole_id: int) -> bool:
	for worker in staff:
		if str(worker.get("role", "")) != "marshal" or _training_active(worker):
			continue
		var assignment: Dictionary = _staff_assignment(worker)
		if assignment.get("kind", "") == "hole" and int(assignment.get("id", -1)) == hole_id:
			return worker.get("pos", _entrance()).distance_to(_hole_by_id(hole_id).get("tee", _entrance())) < 80.0 or worker.get("pos", _entrance()).distance_to(_hole_by_id(hole_id).get("cup", _entrance())) < 80.0
	return false


func _marshal_turn_multiplier(hole_id: int) -> float:
	return 0.88 if _marshal_on_hole(hole_id) else 1.0


func _marshal_wait_multiplier(group: Dictionary) -> float:
	if str(group.get("state", "")) != "tee_queue":
		return 1.0
	var hole_id: int = int(group.get("current_hole_id", -1))
	return 0.6 if _marshal_on_hole(hole_id) else 1.0


func _tick_marshal(worker: Dictionary, dt: float) -> void:
	var assignment: Dictionary = _staff_assignment(worker)
	var hole: Dictionary = {}
	if assignment.get("kind", "") == "hole":
		hole = _hole_by_id(int(assignment.get("id", -1)))
	if hole.is_empty():
		hole = _course_holes[0] if not _course_holes.is_empty() else {}
	if hole.is_empty():
		worker["activity"] = "available"
		return
	var target_pos: Vector3 = hole.get("tee", _entrance()) if int(worker.get("marshal_phase", 0)) == 0 else hole.get("cup", _entrance())
	worker["destination"] = target_pos
	if worker.get("destination", _entrance()) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
		worker["route"] = _route(worker.get("pos", _entrance()), target_pos, false)
		worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
	if not _move_person(worker, dt, WALK_SPEED):
		worker["activity"] = "walking"
		worker["minutes_walking_today"] = float(worker.get("minutes_walking_today", 0.0)) + dt / 60.0
		return
	worker["activity"] = "patrolling"
	worker["minutes_working_today"] = float(worker.get("minutes_working_today", 0.0)) + dt / 60.0
	if worker.get("pos", _entrance()).distance_to(target_pos) < 2.5:
		worker["marshal_phase"] = 1 - int(worker.get("marshal_phase", 0))


func _tick_golf_pro(worker: Dictionary, dt: float) -> void:
	var range_facility: Dictionary = _facility_by_kind("driving_range")
	if range_facility.is_empty():
		worker["activity"] = "available"
		return
	var target_pos: Vector3 = range_facility.get("pos", _entrance())
	worker["destination"] = target_pos
	if worker.get("destination", _entrance()) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
		worker["route"] = _route(worker.get("pos", _entrance()), target_pos, false)
		worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
	if not _move_person(worker, dt, WALK_SPEED):
		worker["activity"] = "walking"
		return
	worker["activity"] = "teaching" if bool(worker.get("lesson_busy", false)) else "available"


func _golf_pro_available() -> bool:
	for worker in staff:
		if str(worker.get("role", "")) != "golf_pro" or _training_active(worker):
			continue
		var range_facility: Dictionary = _facility_by_kind("driving_range")
		if range_facility.is_empty():
			return false
		if worker.get("pos", _entrance()).distance_to(range_facility.get("pos", _entrance())) <= 14.0:
			return true
	return false


func _tick_head_greenkeeper(worker: Dictionary, dt: float, use_cart_travel: bool) -> void:
	var shed: Dictionary = _facility_by_kind("maintenance_shed")
	var target_pos: Vector3 = shed.get("pos", _entrance()) if not shed.is_empty() else _entrance()
	worker["destination"] = target_pos
	if worker.get("destination", _entrance()) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
		worker["route"] = _route(worker.get("pos", _entrance()), target_pos, use_cart_travel)
		worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
	if not _move_person(worker, dt, CART_SPEED if use_cart_travel else WALK_SPEED):
		worker["activity"] = "walking"
		return
	worker["activity"] = "supervising"


func _tick_shop_clerk(worker: Dictionary, dt: float) -> void:
	var shop: Dictionary = _facility_by_kind("pro_shop")
	if shop.is_empty():
		worker["activity"] = "available"
		return
	var target_pos: Vector3 = shop.get("pos", _entrance())
	worker["destination"] = target_pos
	if worker.get("destination", _entrance()) != target_pos or (worker.get("route", PackedVector3Array()) as PackedVector3Array).is_empty():
		worker["route"] = _route(worker.get("pos", _entrance()), target_pos, false)
		worker["route_index"] = 1 if (worker["route"] as PackedVector3Array).size() > 1 else 0
	if not _move_person(worker, dt, WALK_SPEED):
		worker["activity"] = "walking"
		return
	worker["activity"] = "serving"


func _add_staff(role: String, stagger: bool) -> void:
	var definition: Dictionary = _role_definition(role)
	var id: int = _next_staff_id
	_next_staff_id += 1
	var worker: Dictionary = {
		"id": id, "name": "%s %02d" % [str(definition.get("name", role.capitalize())), id],
		"role": role, "pos": _entrance() + Vector3(float(id % 3) * 1.3, 0.0, float(id % 2) * 1.1),
		"destination": _entrance(), "activity": "starting" if stagger else "available", "assignment": -1,
		"wage": float(definition.get("wage", definition.get("daily_wage", 150.0))),
		"skill": float(definition.get("skill", 0.7)),
		"experience": 0.0 if stagger else 1.0,
		"morale": 0.7 if stagger else 1.0,
		"fatigue": 0.0,
		"shift": "full",
		"training": {},
		"traits": [],
		"hired_day": day,
		"raise_requested": false,
		"low_morale_days": 0,
		"raise_ignored_days": 0,
		"minutes_working_today": 0.0,
		"minutes_walking_today": 0.0,
		"minutes_off_today": 0.0,
		"worked_today": false,
		"route": PackedVector3Array(), "route_index": 0,
	}
	staff.append(worker)


func _add_staff_from_candidate(candidate: Dictionary) -> void:
	var role: String = str(candidate.get("role", ""))
	var definition: Dictionary = _role_definition(role)
	var id: int = _next_staff_id
	_next_staff_id += 1
	var traits: Array = candidate.get("traits", [])
	var worker: Dictionary = {
		"id": id, "name": str(candidate.get("name", "%s %02d" % [definition.get("name", role), id])),
		"role": role, "pos": _entrance() + Vector3(float(id % 3) * 1.3, 0.0, float(id % 2) * 1.1),
		"destination": _entrance(), "activity": "starting", "assignment": -1,
		"wage": float(candidate.get("wage", definition.get("wage", 150.0))),
		"skill": float(candidate.get("skill", definition.get("skill", 0.7))),
		"experience": 0.0,
		"morale": 0.7,
		"fatigue": 0.0,
		"shift": "late" if traits.has("night_owl") else "full",
		"training": {},
		"traits": traits.duplicate(),
		"hired_day": day,
		"raise_requested": false,
		"low_morale_days": 0,
		"raise_ignored_days": 0,
		"minutes_working_today": 0.0,
		"minutes_walking_today": 0.0,
		"minutes_off_today": 0.0,
		"worked_today": false,
		"route": PackedVector3Array(), "route_index": 0,
	}
	staff.append(worker)


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


func _facility_tier_stats(kind: String, level: int) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("facility_tier"):
		return _catalog_script.facility_tier(kind, level)
	var definition: Dictionary = _catalog_find(kind)
	return {
		"capacity": int(definition.get("capacity", 4)),
		"upkeep": float(definition.get("upkeep", 0.0)),
	}


func _facility_is_open(state: Dictionary) -> bool:
	return not state.is_empty() and not bool(state.get("closed", false))


func _facility_staffed(state: Dictionary) -> bool:
	var kind: String = str(state.get("kind", ""))
	if kind == "pro_shop":
		return _shop_clerk_present()
	return _workers_at(int(state.get("id", -1))) > 0


func _shop_clerk_present() -> bool:
	var shop: Dictionary = _facility_by_kind("pro_shop")
	if shop.is_empty() or bool(shop.get("closed", false)):
		return false
	for worker in staff:
		if str(worker.get("role", "")) != "shop_clerk":
			continue
		if worker.get("pos", _entrance()).distance_to(shop.get("pos", _entrance())) < 14.0:
			return true
	return false


func _lodge_occupied_rooms() -> int:
	var count: int = 0
	for group in groups:
		if str(group.get("state", "")) == "lodged":
			count += int(group.get("size", 1))
	return count


func _lodge_rooms_available() -> int:
	var lodge: Dictionary = _facility_by_kind("lodge")
	if not _facility_is_open(lodge):
		return 0
	return maxi(0, int(lodge.get("capacity", 0)) - _lodge_occupied_rooms())


func _choose_post_round_facilities(group: Dictionary) -> Array:
	var candidates: Array[Dictionary] = []
	if _has_facility("restaurant") and _group_average(group, "hunger") > 0.25:
		candidates.append({"kind": "restaurant", "score": _group_average(group, "hunger") + 0.2})
	if _has_facility("bar_terrace") and _group_average(group, "mood") < 0.72:
		candidates.append({"kind": "bar_terrace", "score": 0.72 - _group_average(group, "mood")})
	if _has_facility("spa") and _group_average(group, "energy") < 0.55:
		candidates.append({"kind": "spa", "score": 0.55 - _group_average(group, "energy")})
	if _has_facility("pro_shop"):
		candidates.append({"kind": "pro_shop", "score": 0.35})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var choices: Array = []
	for item in candidates:
		var kind: String = str(item.get("kind", ""))
		if choices.size() >= 2 or choices.has(kind):
			continue
		choices.append(kind)
	return choices


func _begin_post_round(group: Dictionary) -> void:
	if not bool(group.get("round_complete", false)):
		group["round_complete"] = true
		group["post_round_queue"] = _choose_post_round_facilities(group)
		group["post_round_index"] = 0
	var queue: Array = group.get("post_round_queue", [])
	if queue.is_empty():
		_begin_departure_or_lodge(group)
		return
	group["post_round"] = true
	_send_to_facility(group, str(queue[0]))


func _begin_departure_or_lodge(group: Dictionary) -> void:
	if bool(group.get("wants_lodging", false)) and int(group.get("lodge_nights", 0)) > 0 and _lodge_rooms_available() >= int(group.get("size", 1)):
		_charge_lodge_booking(group)
	_release_group_resources(group)
	group["state"] = "departing"
	_set_group_destination(group, _entrance(), bool(group.get("cart", false)))
	for guest in _group_guests(group):
		guest["activity"] = "departing"
		guest["thought"] = "Heading home after the round."


func _charge_lodge_booking(group: Dictionary) -> void:
	var nights: int = maxi(1, int(group.get("lodge_nights", 1)))
	var room_rate: float = price("room", {"day": day})
	for guest in _group_guests(group):
		for _night in range(nights):
			_guest_purchase(guest, room_rate, "lodging", "Lodge booking")
	group["lodge_nights"] = 0
	group["wants_lodging"] = false


func _send_to_lodge(group: Dictionary) -> void:
	var lodge: Dictionary = _facility_by_kind("lodge")
	if lodge.is_empty():
		_release_group_resources(group)
		group["state"] = "departing"
		_set_group_destination(group, _entrance(), bool(group.get("cart", false)))
		return
	_release_group_resources(group)
	group["state"] = "lodged"
	group["post_round"] = false
	_set_group_destination(group, lodge.get("pos", _entrance()), false)
	for guest in _group_guests(group):
		guest["activity"] = "lodged"
		guest["thought"] = "Checking in for the night."
	post("info", "facility", "Guests checked into the lodge", lodge.get("pos", _entrance()), {"kind": "object", "id": int(lodge.get("id", -1))})


func _process_lodge_night() -> void:
	var lodge: Dictionary = _facility_by_kind("lodge")
	var room_rate: float = price("room", {"day": day})
	for group in groups:
		if str(group.get("state", "")) != "lodged":
			continue
		var room_revenue: float = 0.0
		for guest in _group_guests(group):
			if _guest_purchase(guest, room_rate, "lodging", "Lodge room"):
				room_revenue += room_rate
			guest["hunger"] = maxf(0.0, float(guest.get("hunger", 0.0)) - 0.35)
			guest["energy"] = minf(1.0, float(guest.get("energy", 0.0)) + 0.45)
			guest["restroom"] = 0.0
			guest["thought"] = "A comfortable night at the lodge."
		if room_revenue > 0.0:
			_facility_revenue["lodge"] = float(_facility_revenue.get("lodge", 0.0)) + room_revenue
			if not lodge.is_empty():
				lodge["revenue_today"] = float(lodge.get("revenue_today", 0.0)) + room_revenue
		group["lodge_nights"] = maxi(0, int(group.get("lodge_nights", 0)) - 1)
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		if str(state.get("kind", "")) == "bar_terrace" and int(state.get("visits_today", 0)) >= 3:
			awareness = clampf(awareness + 0.6, 0.0, 100.0)
			_update_derived_publicity()


func _release_lodge_guests_to_tee() -> void:
	for group in groups:
		if str(group.get("state", "")) != "lodged":
			continue
		if int(group.get("lodge_nights", 0)) <= 0:
			group["wants_lodging"] = false
			_release_group_resources(group)
			group["state"] = "departing"
			_set_group_destination(group, _entrance(), bool(group.get("cart", false)))
			continue
		group["paid"] = false
		group["hole_index"] = 0
		group["completed_hole_ids"] = []
		group["facilities_visited"] = []
		group["round_complete"] = false
		group["post_round"] = false
		group["post_round_queue"] = []
		group["post_round_index"] = 0
		group["state"] = "to_tee"
		for guest in _group_guests(group):
			guest["hole_index"] = 0
			guest["strokes"] = 0
			guest["scorecard"] = []
			guest["thought"] = "Ready for another round."
		_send_to_next_hole(group)


func _play_pace_multiplier(group: Dictionary, hole_id: int) -> float:
	var multiplier: float = _marshal_turn_multiplier(hole_id)
	if bool(group.get("caddie", false)):
		multiplier *= 0.9
	return multiplier


func _maintenance_output_multiplier() -> float:
	var shed: Dictionary = _facility_by_kind("maintenance_shed")
	if shed.is_empty():
		return 1.0
	return float(_facility_tier_stats("maintenance_shed", int(shed.get("level", 1))).get("maint_bonus", 1.0))


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
	if terrain != null and terrain.has_method("course_wear"):
		return clampf(float(terrain.course_wear()), 0.0, 1.0)
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


func _bootstrap_unlocks(starter: bool) -> void:
	if not starter:
		return
	var starter_nodes: Array[String] = [
		"cart_fleet", "greenkeeping", "local_press", "garden_accents",
		"snack_bar", "bunker_craft", "irrigation",
	]
	for node_id in starter_nodes:
		if not unlocked.has(node_id):
			unlocked.append(node_id)


func _migrate_unlocks_from_grade(saved_grade: int) -> void:
	unlocked.clear()
	projects.clear()
	if _catalog_script == null or not _catalog_script.has_method("unlocks"):
		return
	for node in _catalog_script.unlocks():
		if str(node.get("kind", "")) == "grade":
			continue
		if node.has("milestone"):
			continue
		if int(node.get("grade", 1)) <= saved_grade:
			unlocked.append(str(node.get("id", "")))
	if saved_grade >= 2 and not unlocked.has("grade_club"):
		unlocked.append("grade_club")
	if saved_grade >= 3 and not unlocked.has("grade_resort"):
		unlocked.append("grade_resort")


func _unlock_node(node_id: String) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("unlock_node"):
		return _catalog_script.unlock_node(node_id)
	return {}


func _grade_unlock_node(target_grade: int) -> Dictionary:
	if _catalog_script != null and _catalog_script.has_method("grade_unlock_node"):
		return _catalog_script.grade_unlock_node(target_grade)
	return {}


func _grade_branch_met(target_grade: int) -> bool:
	var grade_node: Dictionary = _grade_unlock_node(target_grade)
	if grade_node.is_empty():
		return true
	for node_id in grade_node.get("nodes", []):
		if not unlocked.has(str(node_id)):
			return false
	return true


func _has_grant(kind: String) -> bool:
	if _catalog_script == null or not _catalog_script.has_method("grant_keys_for_kind"):
		return false
	for grant_key in _catalog_script.grant_keys_for_kind(kind):
		if _grant_from_completed(str(grant_key)):
			return true
	return false


func _grant_from_completed(grant_key: String) -> bool:
	if _catalog_script == null or not _catalog_script.has_method("unlocks"):
		return false
	for node_id in unlocked:
		var node: Dictionary = _unlock_node(node_id)
		for grant in node.get("grants", []):
			if str(grant) == grant_key:
				return true
	return false


func _project_for(node_id: String) -> Dictionary:
	for project in projects:
		if str(project.get("id", "")) == node_id:
			return project
	return {}


func _tick_projects() -> void:
	var finished: Array[String] = []
	for project in projects:
		project["days_left"] = maxi(0, int(project.get("days_left", 0)) - 1)
		if int(project.get("days_left", 0)) <= 0:
			finished.append(str(project.get("id", "")))
	for node_id in finished:
		var project: Dictionary = _project_for(node_id)
		if project.is_empty():
			continue
		projects.erase(project)
		if not unlocked.has(node_id):
			unlocked.append(node_id)
		var node: Dictionary = _unlock_node(node_id)
		post("success", "construction", "Completed %s" % str(node.get("name", node_id)), Vector3.INF, _tab_target("Progress"))


func _money_text(value: float) -> String:
	return str(roundi(value))


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
	return _entrance()


func _sync_facility_object(state: Dictionary) -> void:
	if terrain == null or not ("objects" in terrain):
		return
	var state_id: int = int(state.get("id", -1))
	for object_value in terrain.objects:
		var object: Dictionary = object_value
		if int(object.get("id", -2)) == state_id:
			object["condition"] = float(state.get("condition", 1.0))
			object["cleanliness"] = float(state.get("cleanliness", 1.0))
			if state.has("closed"):
				object["closed"] = bool(state.get("closed", false))
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


func _reset_daily_accumulators() -> void:
	_today_by_category = {"revenue": {}, "expenses": {}}
	_today_groups = 0
	_today_completed_rounds = 0
	_today_refunds = 0.0
	_today_spend_total = 0.0
	_today_spend_guests = 0
	_today_mood_sum = 0.0
	_today_mood_count = 0
	_wait_tee_seconds = 0.0
	_wait_checkin_seconds = 0.0
	_max_tee_queue = 0
	for state_value in _facility_state.values():
		var state: Dictionary = state_value
		state["revenue_today"] = 0.0
		state["visits_today"] = 0
	_facility_visits.clear()
	_facility_revenue.clear()
	_hole_stats_today.clear()
	today_series.clear()
	_last_series_sample_minute = -TODAY_SERIES_INTERVAL
	_today_peak_guests = 0
	_today_peak_queue = 0
	_today_peak_queue_minute = 0.0
	_today_balked = 0


func _total_tee_queue() -> int:
	var total: int = 0
	for queue in _hole_queues.values():
		total += (queue as Array).size()
	return total


func _total_facility_queue() -> int:
	var total: int = 0
	for queue in _facility_queues.values():
		total += (queue as Array).size()
	return total


func _maybe_sample_today_series() -> void:
	var bucket: int = mini(int(minute / TODAY_SERIES_INTERVAL), TODAY_SERIES_MAX - 1)
	var last_bucket: int = int(_last_series_sample_minute / TODAY_SERIES_INTERVAL)
	while last_bucket < bucket and today_series.size() < TODAY_SERIES_MAX:
		last_bucket += 1
		var sample_minute: float = float(last_bucket) * TODAY_SERIES_INTERVAL
		var tee_queue: int = _total_tee_queue()
		var facility_queue: int = _total_facility_queue()
		var queue_total: int = tee_queue + facility_queue
		today_series.append({
			"minute": sample_minute,
			"guests_on_site": guests.size(),
			"cash": cash,
			"tee_queue_total": tee_queue,
			"facility_queue_total": facility_queue,
		})
		_today_peak_guests = maxi(_today_peak_guests, guests.size())
		if queue_total > _today_peak_queue:
			_today_peak_queue = queue_total
			_today_peak_queue_minute = sample_minute
	_last_series_sample_minute = float(bucket) * TODAY_SERIES_INTERVAL
	var current_tee_queue: int = _total_tee_queue()
	_max_tee_queue = maxi(_max_tee_queue, current_tee_queue)


func _record_hole_stats(group: Dictionary, hole: Dictionary) -> void:
	var hole_id: int = int(hole.get("id", -1))
	if hole_id < 0:
		return
	if not _hole_stats_today.has(hole_id):
		_hole_stats_today[hole_id] = {"strokes_sum": 0.0, "rounds": 0, "hazards": 0, "minutes_sum": 0.0}
	var stats: Dictionary = _hole_stats_today[hole_id]
	var stroke_total: float = 0.0
	for guest in _group_guests(group):
		stroke_total += float(int(guest.get("hole_strokes", 0)))
	stats["strokes_sum"] = float(stats.get("strokes_sum", 0.0)) + stroke_total / maxf(1.0, float(group.get("size", 1)))
	stats["rounds"] = int(stats.get("rounds", 0)) + 1
	stats["hazards"] = int(stats.get("hazards", 0)) + int(group.get("hole_hazards", 0))
	var hole_minutes: float = maxf(0.0, _actor_elapsed_seconds / 60.0 - float(group.get("hole_start_minute", _actor_elapsed_seconds / 60.0)))
	stats["minutes_sum"] = float(stats.get("minutes_sum", 0.0)) + hole_minutes
	group["hole_hazards"] = 0


func _track_course_record(group: Dictionary) -> void:
	var best_strokes: int = 999
	var best_guest: Dictionary = {}
	for guest in _group_guests(group):
		var total: int = int(guest.get("strokes", 0))
		if total < best_strokes:
			best_strokes = total
			best_guest = guest
	if best_guest.is_empty():
		return
	var current: Dictionary = records.get("course_record", {})
	if current.is_empty() or int(current.get("strokes", 999)) > best_strokes:
		records["course_record"] = {
			"name": str(best_guest.get("name", "Golfer")),
			"day": day,
			"strokes": best_strokes,
		}
		var par_total: int = _course_par_total()
		if par_total > 0 and best_strokes <= par_total - 6 and _course_record_press_day != day:
			_course_record_press_day = day
			buzz = clampf(buzz + 5.0, -20.0, 20.0)
			_add_press_headline("Course record! %s fires a %d at Cedar House." % [str(best_guest.get("name", "Golfer")), best_strokes])
			_update_derived_publicity()


func _append_monthly_history(net: float, settled_day: int) -> void:
	_maybe_sample_today_series()
	var revenue: Dictionary = (_today_by_category.get("revenue", {}) as Dictionary).duplicate(true)
	var expenses: Dictionary = (_today_by_category.get("expenses", {}) as Dictionary).duplicate(true)
	var hole_stats: Dictionary = {}
	for hole_id_value in _hole_stats_today.keys():
		var hole_id: int = int(hole_id_value)
		var raw: Dictionary = _hole_stats_today[hole_id]
		var rounds: int = int(raw.get("rounds", 0))
		hole_stats[hole_id] = {
			"rounds": rounds,
			"average_strokes": float(raw.get("strokes_sum", 0.0)) / maxf(1.0, float(rounds)),
			"hazards": int(raw.get("hazards", 0)),
			"average_minutes": float(raw.get("minutes_sum", 0.0)) / maxf(1.0, float(rounds)),
		}
	var event_record: Dictionary = {}
	for event in scheduled_events:
		if int(event.get("day", -1)) <= settled_day and str(event.get("status", "")) not in ["scheduled"]:
			event_record = {"id": int(event.get("id", -1)), "name": str(event.get("name", "")), "status": str(event.get("status", ""))}
			break
	for past in event_history:
		if int(past.get("day", -1)) <= settled_day and int(past.get("day", -1)) > settled_day - 40:
			event_record = {"id": int(past.get("id", -1)), "name": str(past.get("name", "")), "status": str(past.get("status", ""))}
			break
	var wages: float = 0.0
	for worker in staff:
		wages += float(worker.get("wage", 0.0))
	var arrivals: int = _period_arrivals
	var completion_rate: float = float(_today_completed_rounds) / maxf(1.0, float(maxi(1, _today_groups)))
	var average_spend: float = _today_spend_total / maxf(1.0, float(_today_spend_guests))
	var average_mood: float = _today_mood_sum / maxf(1.0, float(_today_mood_count))
	var average_wait_tee: float = _wait_tee_seconds / maxf(1.0, float(maxi(1, arrivals)))
	var average_wait_checkin: float = _wait_checkin_seconds / maxf(1.0, float(maxi(1, arrivals)))
	var record: Dictionary = {
		"day": settled_day,
		"date": date_string_for(settled_day),
		"season": season_name_for(settled_day),
		"weekday": (settled_day - 1) % 7,
		"cash_open": _today_cash_open,
		"cash_close": cash,
		"revenue": revenue,
		"expenses": expenses,
		"arrivals": arrivals,
		"groups": _today_groups,
		"completed_rounds": _today_completed_rounds,
		"completion_rate": clampf(completion_rate, 0.0, 1.0),
		"refunds": _today_refunds,
		"average_spend": average_spend,
		"satisfaction": satisfaction,
		"average_mood": average_mood,
		"rating": rating_or_satisfaction(),
		"publicity": publicity,
		"grade": grade,
		"wear": _terrain_wear(),
		"average_wait_tee": average_wait_tee,
		"max_tee_queue": _max_tee_queue,
		"average_wait_checkin": average_wait_checkin,
		"facility_visits": _facility_visits.duplicate(true),
		"facility_revenue": _facility_revenue.duplicate(true),
		"staff_count": staff.size(),
		"wages": wages,
		"holes_open": _course_holes.size(),
		"event": event_record,
		"hole_stats": hole_stats,
		"peak_guests": _today_peak_guests,
		"peak_queue_minute": _today_peak_queue_minute,
		"net": net,
	}
	history.append(record)
	while history.size() > HISTORY_CAP:
		history.pop_front()
	_update_records(record)


func _update_records(record: Dictionary) -> void:
	var day_revenue: float = 0.0
	for amount in (record.get("revenue", {}) as Dictionary).values():
		day_revenue += float(amount)
	var best_revenue: Dictionary = records.get("best_revenue_day", {})
	if best_revenue.is_empty() or day_revenue > float(best_revenue.get("amount", 0.0)):
		records["best_revenue_day"] = {"day": int(record.get("day", 1)), "amount": day_revenue}
	var rounds: int = int(record.get("completed_rounds", 0))
	var most_rounds: Dictionary = records.get("most_rounds_day", {})
	if most_rounds.is_empty() or rounds > int(most_rounds.get("rounds", 0)):
		records["most_rounds_day"] = {"day": int(record.get("day", 1)), "rounds": rounds}
	var net: float = float(record.get("net", 0.0))
	if net >= 0.0:
		_positive_streak += 1
	else:
		_positive_streak = 0
	records["positive_streak"] = _positive_streak
	records["longest_positive_streak"] = maxi(int(records.get("longest_positive_streak", 0)), _positive_streak)
	var refunds: float = float(record.get("refunds", 0.0))
	var largest_refund: Dictionary = records.get("largest_refund_day", {})
	if largest_refund.is_empty() or refunds > float(largest_refund.get("amount", 0.0)):
		records["largest_refund_day"] = {"day": int(record.get("day", 1)), "amount": refunds}


func _record(amount: float, category: String, description: String) -> void:
	ledger.append({"day": day, "minute": minute, "amount": amount, "category": category, "description": description, "balance": cash})
	if amount > 0.0:
		var revenue: Dictionary = _today_by_category.get("revenue", {})
		revenue[category] = float(revenue.get(category, 0.0)) + amount
		_today_by_category["revenue"] = revenue
	elif amount < 0.0:
		var expenses: Dictionary = _today_by_category.get("expenses", {})
		expenses[category] = float(expenses.get(category, 0.0)) + absf(amount)
		_today_by_category["expenses"] = expenses
		if category == "refund":
			_today_refunds += absf(amount)


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
