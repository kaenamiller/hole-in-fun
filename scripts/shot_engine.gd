class_name ShotEngine
extends RefCounted

## Deterministic, bounded golf shot planning shared by the live game and previews.
##
## The engine deliberately talks only to the terrain methods documented in
## docs/INTERFACES.md.  It contains no scene or node dependencies, so a shot
## can be planned from a headless simulation as well as from the 3D view.

const MAX_STROKES: int = 14
const MAX_WAYPOINTS_CHECKED: int = 6
const MAX_ANCHOR_CHECKS: int = 2
const MAX_PLAN_CANDIDATES: int = 10
const PLAN_TIE_STROKES: float = 0.12
const WALK_SPEED: float = 1.8
const FOURBALL_TURN_PAUSE: float = 36.0

const _CLUBS: Array = [
	{"name": "putter", "carry": 18.0, "arc": 0.35, "roll": 1.2},
	{"name": "chip", "carry": 35.0, "arc": 2.5, "roll": 3.0},
	{"name": "wedge", "carry": 95.0, "arc": 12.0, "roll": 2.0},
	{"name": "9-iron", "carry": 125.0, "arc": 18.0, "roll": 2.4},
	{"name": "7-iron", "carry": 150.0, "arc": 22.0, "roll": 2.8},
	{"name": "5-iron", "carry": 175.0, "arc": 26.0, "roll": 3.1},
	{"name": "3-wood", "carry": 205.0, "arc": 31.0, "roll": 4.8},
	{"name": "driver", "carry": 230.0, "arc": 36.0, "roll": 6.0}
]

static func effective_cup(hole: Dictionary) -> Vector3:
	var pins_value: Variant = hole.get("pins", [])
	if pins_value is Array and (pins_value as Array).size() > 0:
		var index: int = clampi(int(hole.get("pin_index", 0)), 0, (pins_value as Array).size() - 1)
		return Vector3((pins_value as Array)[index])
	return Vector3(hole.get("cup", Vector3.ZERO))

static func shot(terrain, start: Vector3, hole: Dictionary, skill: float, rng: RandomNumberGenerator) -> Dictionary:
	var safe_skill: float = clampf(skill, 0.0, 1.0)
	var source_rng: RandomNumberGenerator = rng
	if source_rng == null:
		source_rng = RandomNumberGenerator.new()
		source_rng.seed = 1

	var cup: Vector3 = effective_cup(hole)
	var tee: Vector3 = Vector3(hole.get("tee", start))
	var green_radius: float = maxf(3.0, float(hole.get("green_radius", 16.0)))
	var start_surface: int = int(terrain.surface_at(start))
	var start_on_green: bool = _on_green(terrain, start, hole)
	var start_ground: Vector3 = _ground_point(terrain, start)
	var plan: Dictionary = _choose_target(terrain, start_ground, cup, hole, safe_skill, start_surface, start_on_green)
	var target: Vector3 = Vector3(plan.get("target", cup))
	var target_reason: String = String(plan.get("reason", "approach"))
	var intended_plan: String = String(plan.get("plan", "neutral"))
	var contested: bool = bool(plan.get("contested", false))
	var layup_choice: bool = target_reason.contains("layup")
	var distance: float = _flat_distance(start_ground, target)
	var slope: Vector2 = _read_slope(terrain, start_ground)
	var elevation: float = float(terrain.height_at(target)) - float(terrain.height_at(start_ground))
	var club: Dictionary = _choose_club(distance, start_surface, safe_skill, slope, elevation, terrain, start_ground, start_on_green)
	var club_name: String = String(club.get("name", "wedge"))
	var carry: float = float(club.get("carry", 95.0)) * _skill_distance_factor(safe_skill)
	carry *= _surface_distance_factor(start_surface, terrain, start_ground)
	carry *= _slope_distance_factor(slope)
	if elevation > 0.0:
		carry *= clampf(1.0 - elevation / 180.0, 0.74, 1.0)
	var direction: Vector3 = _flat_direction(start_ground, target)
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var dispersion: float = 0.018 + (1.0 - safe_skill) * 0.105
	if start_surface == 0:
		dispersion += 0.018
	elif start_surface == 4:
		dispersion += 0.045
		var start_bunker: Dictionary = _bunker_at(terrain, start_ground)
		if not start_bunker.is_empty():
			var start_depth: float = float(start_bunker.get("depth", 0.0))
			dispersion += clampf(start_depth / 0.8, 0.0, 1.0) * 0.06
			carry *= 1.0 - clampf(start_depth / 0.8, 0.0, 1.0) * 0.35
	if start_on_green and terrain != null and terrain.has_method("condition_at"):
		var green_condition: float = float(terrain.condition_at(start_ground))
		if green_condition < 0.5:
			var poor: float = (0.5 - green_condition) / 0.5
			dispersion += dispersion * 0.4 * poor
	var dispersion_meters: float = maxf(1.5, distance * dispersion)
	if club_name == "putter" and start_on_green:
		var green_stats: Dictionary = _green_slope_stats(terrain, hole)
		dispersion_meters += float(green_stats.get("mean", 0.0)) * 6.0
	var along_error: float = _noise(source_rng) * dispersion_meters * 1.15
	var side_error: float = _noise(source_rng) * dispersion_meters
	if club_name == "putter" and start_on_green:
		var putt_slope: Vector2 = _read_slope(terrain, start_ground)
		var line_slope: float = absf(putt_slope.dot(Vector2(direction.x, direction.z)))
		if line_slope > 0.04 and source_rng.randf() < 0.12:
			along_error += dispersion_meters * (0.8 if source_rng.randf() > 0.5 else -0.8)
	# Uphill shots come up short and downhill shots tend to run through.
	along_error -= elevation * 0.26
	along_error -= maxf(0.0, distance - carry) * 0.3
	var landing: Vector3 = target + direction * along_error + side * side_error
	landing = _ground_point(terrain, landing)
	var landing_surface: int = int(terrain.surface_at(landing))
	var zone: String = _zone_at(terrain, landing, hole)
	var hazard: bool = landing_surface == 5 or not bool(terrain.playable(landing)) or zone in ["ob", "penalty"]
	var penalty: int = 0
	var end: Vector3 = landing
	var reason: String = target_reason
	var bounce: float = float(club.get("arc", 10.0))
	var roll: float = float(club.get("roll", 2.0))
	var holed: bool = false
	if hazard:
		penalty = 1
		if zone == "ob":
			end = _ground_point(terrain, start)
			reason = "ob_penalty"
		elif zone == "penalty" or landing_surface == 5:
			if terrain != null and terrain.has_method("penalty_drop"):
				end = _ground_point(terrain, Vector3(terrain.penalty_drop(start, landing)))
			else:
				end = _ground_point(terrain, Vector3(terrain.nearest_safe(landing)))
			reason = "penalty_drop" if zone == "penalty" else "water_recovery"
		else:
			var safe_landing: Vector3 = Vector3(terrain.nearest_safe(landing))
			end = _ground_point(terrain, safe_landing)
			reason = "out_of_bounds_recovery"
		bounce = 1.0
		roll = 0.0
	else:
		if landing_surface == 4:
			reason = "sand_lie" if reason == "approach" else reason + "_sand"
			roll *= 0.45
			var landing_bunker: Dictionary = _bunker_at(terrain, landing)
			if not landing_bunker.is_empty():
				var bunker_depth: float = float(landing_bunker.get("depth", 0.0))
				roll *= 1.0 - clampf(bunker_depth / 0.8, 0.0, 1.0) * 0.35
		elif landing_surface == 2 and _on_green(terrain, landing, hole):
			roll *= 0.35
		var roll_direction: Vector3 = _flat_direction(start_ground, landing)
		end = _ground_point(terrain, landing + roll_direction * roll)
		var end_distance: float = _flat_distance(end, cup)
		var end_surface: int = int(terrain.surface_at(end))
		var end_on_green: bool = _on_green(terrain, end, hole)
		if end_on_green and end_distance <= maxf(0.65, 0.55 + safe_skill * 0.95):
			holed = true
		elif club_name == "putter" and end_distance <= maxf(0.45, 0.6 + safe_skill * 0.9):
			holed = true
		elif end_on_green and end_distance <= 1.0 and source_rng.randf() < 0.54 + safe_skill * 0.36:
			holed = true
		if holed:
			end = _ground_point(terrain, cup)
			reason = "holed_" + club_name
		elif end_on_green and reason == "approach":
			reason = "green_hit"

	var duration: float = 0.45 + distance / (52.0 if club_name != "putter" else 17.0)
	if hazard:
		duration += 0.3
	var arc: float = clampf(bounce + absf(elevation) * 0.08 + distance * 0.025, 0.2, 48.0)
	return {
		"start": start,
		"landing": landing,
		"end": end,
		"target": target,
		"arc": arc,
		"duration": clampf(duration, 0.35, 7.0),
		"club": club_name,
		"penalty": penalty,
		"holed": holed,
		"hazard": hazard,
		"reason": reason,
		# These fields are useful to the overlay and cost nothing for callers
		# that only consume the required contract fields.
		"surface": landing_surface,
		"landing_surface": landing_surface,
		"intended_target_distance": distance,
		"layup": layup_choice,
		"plan": intended_plan,
		"contested": contested,
		"distance": distance,
		"skill": safe_skill,
		"green_radius": green_radius,
		"tee": tee
	}

static func round_preview(terrain, hole: Dictionary, skill: float, seed_value: int) -> Dictionary:
	var safe_skill: float = clampf(skill, 0.0, 1.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var start: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
	var strokes: int = 0
	var hazards: int = 0
	var shots: Array = []
	while strokes < MAX_STROKES:
		var current: Dictionary = shot(terrain, start, hole, safe_skill, rng)
		shots.append(current)
		strokes += 1
		if bool(current.get("hazard", false)):
			hazards += 1
		if bool(current.get("holed", false)):
			break
		start = Vector3(current.get("end", start))
	return {"strokes": strokes, "hazards": hazards, "shots": shots}

static func analyze(terrain, hole: Dictionary, count: int = 30, seed_value: int = 42) -> Array:
	var rounds: int = clampi(count, 1, 120)
	var profiles: Array = [
		{"label": "beginner", "skill": 0.28},
		{"label": "intermediate", "skill": 0.58},
		{"label": "expert", "skill": 0.88}
	]
	var result: Array = []
	for profile_value in profiles:
		var profile: Dictionary = profile_value
		var total_strokes: int = 0
		var total_hazards: int = 0
		var sample_shots: Array = []
		for index in range(rounds):
			var preview: Dictionary = round_preview(terrain, hole, float(profile.get("skill", 0.5)), seed_value + index * 7919 + result.size() * 104729)
			total_strokes += int(preview.get("strokes", MAX_STROKES))
			total_hazards += int(preview.get("hazards", 0))
			var preview_shots: Array = preview.get("shots", [])
			for shot_value in preview_shots:
				sample_shots.append(shot_value)
		result.append({
			"label": String(profile.get("label", "player")),
			"skill": float(profile.get("skill", 0.5)),
			"average": float(total_strokes) / float(rounds),
			"hazard_rate": float(total_hazards) / float(rounds),
			"shots": sample_shots
		})
	return result

static func metrics(terrain, hole: Dictionary, count: int = 30, seed_value: int = 42) -> Dictionary:
	var rounds: int = clampi(count, 1, 120)
	var par: int = int(hole.get("par", 4))
	var analysis: Array = analyze(terrain, hole, rounds, seed_value)
	var beginner_avg: float = 0.0
	var intermediate_avg: float = 0.0
	var expert_avg: float = 0.0
	var intermediate_hazard_rate: float = 0.0
	var intermediate_shots: Array = []
	for profile_value in analysis:
		var profile: Dictionary = profile_value
		match String(profile.get("label", "")):
			"beginner":
				beginner_avg = float(profile.get("average", par))
			"intermediate":
				intermediate_avg = float(profile.get("average", par))
				intermediate_hazard_rate = float(profile.get("hazard_rate", 0.0))
				intermediate_shots = profile.get("shots", [])
			"expert":
				expert_avg = float(profile.get("average", par))

	var blowup_rounds: int = 0
	var decision_rounds: int = 0
	var decision_total: int = 0
	var penalty_total: int = 0
	var unlucky_penalties: int = 0
	var approach_total: int = 0
	var green_holds: int = 0
	var clubs_used: Dictionary = {}
	var round_strokes: int = 0
	var round_index: int = 0
	for shot_value in intermediate_shots:
		var current: Dictionary = shot_value
		round_strokes += 1
		var club_name: String = String(current.get("club", ""))
		if not club_name.is_empty():
			clubs_used[club_name] = true
		if int(current.get("penalty", 0)) > 0:
			penalty_total += 1
			if _flat_distance(Vector3(current.get("landing", Vector3.ZERO)), Vector3(current.get("target", Vector3.ZERO))) <= 10.0:
				unlucky_penalties += 1
		var reason: String = String(current.get("reason", ""))
		if reason == "approach" or reason.ends_with("_sand") or reason == "green_hit":
			approach_total += 1
			if reason == "green_hit" or (_on_green(terrain, Vector3(current.get("end", Vector3.ZERO)), hole) and not _on_green(terrain, Vector3(current.get("start", Vector3.ZERO)), hole)):
				green_holds += 1
		if round_strokes == 1 and par >= 4:
			if bool(current.get("contested", false)):
				decision_total += 1
				if String(current.get("plan", "aggressive")) != "aggressive":
					decision_rounds += 1
		if bool(current.get("holed", false)):
			if round_strokes >= par + 4:
				blowup_rounds += 1
			round_strokes = 0
			round_index += 1
	if round_strokes > 0 and round_strokes >= par + 4:
		blowup_rounds += 1

	var difficulty_value: float = intermediate_avg - float(par)
	var spread_value: float = expert_avg - beginner_avg
	var blowup_rate: float = float(blowup_rounds) / maxf(1.0, float(round_index if round_index > 0 else rounds))
	var fairness_value: float = 1.0 if penalty_total == 0 else 1.0 - float(unlucky_penalties) / float(penalty_total)
	var variety_value: float = float(clubs_used.size()) / 8.0
	var decision_value: float = float(decision_rounds) / maxf(1.0, float(decision_total))
	if par >= 4 and decision_value < 0.15:
		var tee_point: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
		var tee_surface: int = int(terrain.surface_at(tee_point))
		var low_plan: Dictionary = _choose_target(terrain, tee_point, effective_cup(hole), hole, 0.28, tee_surface, false)
		var high_plan: Dictionary = _choose_target(terrain, tee_point, effective_cup(hole), hole, 0.88, tee_surface, false)
		if bool(low_plan.get("contested", false)) and String(low_plan.get("plan", "")) != String(high_plan.get("plan", "")):
			decision_value = 0.45
	var pace_value: float = _fourball_pace_minutes(terrain, hole, 0.58, seed_value, rounds)
	var green_receptiveness_value: float = float(green_holds) / maxf(1.0, float(approach_total))
	var scenery_value: float = _hole_scenery(terrain, hole)

	var difficulty: Dictionary = _metric_band(
		difficulty_value, -0.3, 0.8,
		"Too easy for par %d — consider lowering par or tightening the landing area." % par,
		"Plays harder than par %d — add recovery room or soften hazards." % par,
		"Difficulty sits near par %d for mid-handicap players." % par
	)
	if difficulty_value < -0.5 and par >= 4:
		difficulty["note"] = "Very short for par %d — consider par 3." % par
		difficulty["band"] = "low"

	var spread: Dictionary = _metric_band(
		spread_value, 1.0, 2.2,
		"Experts and beginners score alike — add risk/reward or clearer lines.",
		"Gap is steep — widen fairways or add forward tees.",
		"Skill spread rewards better players without shutting out beginners."
	)
	var hazard_rate: Dictionary = _metric_band(
		intermediate_hazard_rate, 0.1, 0.6,
		"Hazards rarely bite — the hole may feel tame.",
		"Too many penalty shots — soften water, bunkers, or OB.",
		"Hazard rate gives meaningful tension without constant carnage."
	)
	var blowup: Dictionary = _metric_band(
		blowup_rate, 0.0, 0.12,
		"Blow-up holes are rare here.",
		"Beginners lose %.1f balls here on average. Widen the landing area or move trouble away." % (blowup_rate * float(rounds)),
		"Blow-up frequency stays manageable."
	)
	if blowup_rate >= 0.12:
		blowup["band"] = "high"
	var fairness: Dictionary = _metric_band(
		fairness_value, 0.75, 1.0,
		"Penalties often follow tight misses — shift hazards or widen targets.",
		"Penalties feel harsh even on good strikes.",
		"Penalties mostly punish real mistakes, not bad luck."
	)
	if fairness_value <= 0.75:
		fairness["band"] = "low"
	var variety: Dictionary = _metric_band(
		variety_value, 0.4, 1.0,
		"Few clubs required — add length tiers or doglegs.",
		"Every club in the bag — good variety.",
		"Players use a healthy mix of clubs."
	)
	if variety_value <= 0.4:
		variety["band"] = "low"
	var decision: Dictionary = _metric_band(
		decision_value, 0.2, 0.7,
		"One obvious line — add a layup or carry option.",
		"Too many competing lines — simplify the hero shot.",
		"Players weigh layup versus aggressive lines."
	)
	if par <= 3:
		decision = {"value": decision_value, "band": "ok", "note": "Par 3 — decision metric applies to par 4/5 holes."}
	var pace_limits: Dictionary = {3: 11.0, 4: 14.0, 5: 17.0}
	var pace_limit: float = float(pace_limits.get(par, 14.0))
	var pace: Dictionary = _metric_band(
		pace_value, 0.0, pace_limit,
		"Pace is brisk for par %d." % par,
		"Four-ball pace exceeds %d min — shorten walks or simplify greens." % int(pace_limit),
		"Expected four-ball pace fits par %d targets." % par
	)
	if pace_value > pace_limit:
		pace["band"] = "high"
	var green_receptiveness: Dictionary = _metric_band(
		green_receptiveness_value, 0.5, 1.0,
		"Approaches struggle to hold — soften slopes or enlarge the green.",
		"Approaches stick reliably.",
		"Greens accept well-struck approaches."
	)
	if green_receptiveness_value <= 0.5:
		green_receptiveness["band"] = "low"
	var scenery: Dictionary = {
		"value": scenery_value,
		"band": "ok",
		"note": "Scenery score from tee, landing zones, and green.",
	}
	var fun_value: float = _fun_score(variety_value, decision_value, fairness_value, spread_value, blowup_rate, par)
	var fun: Dictionary = _metric_band(
		fun_value, 0.6, 1.0,
		"Hole feels repetitive or punitive — tune variety, fairness, or blow-ups.",
		"Strong design mix — players should remember this hole.",
		"Balanced fun for a range of skills."
	)
	if fun_value < 0.6:
		fun["band"] = "low"

	return {
		"hole_id": int(hole.get("id", -1)),
		"par": par,
		"analysis": analysis,
		"beginner_avg": beginner_avg,
		"intermediate_avg": intermediate_avg,
		"expert_avg": expert_avg,
		"difficulty": difficulty,
		"spread": spread,
		"hazard_rate": hazard_rate,
		"blowup_rate": blowup,
		"fairness": fairness,
		"variety": variety,
		"decision": decision,
		"pace_minutes": pace,
		"green_receptiveness": green_receptiveness,
		"scenery": scenery,
		"fun": fun,
	}

static func course_metrics(terrain, holes: Array, count: int = 30, seed_value: int = 42, cached_metrics: Dictionary = {}) -> Dictionary:
	var open_holes: Array = []
	for hole_value in holes:
		var hole: Dictionary = hole_value
		if bool(hole.get("open", true)):
			open_holes.append(hole)
	if open_holes.is_empty():
		return {}

	var per_hole: Array = []
	var expert_total: float = 0.0
	var beginner_total: float = 0.0
	var par_total: int = 0
	var length_total: float = 0.0
	var par_mix: Dictionary = {"3": 0, "4": 0, "5": 0}
	var fun_values: Array = []
	var signature_candidate: Dictionary = {}
	var signature_fun: float = -1.0

	for hole in open_holes:
		var hole_id: int = int(hole.get("id", 0))
		var hole_metrics: Dictionary = cached_metrics.get(hole_id, {})
		if hole_metrics.is_empty():
			hole_metrics = metrics(terrain, hole, count, seed_value + hole_id * 9973)
		per_hole.append(hole_metrics)
		expert_total += float(hole_metrics.get("expert_avg", 0.0))
		beginner_total += float(hole_metrics.get("beginner_avg", 0.0))
		var par: int = int(hole.get("par", 4))
		par_total += par
		par_mix[str(par)] = int(par_mix.get(str(par), 0)) + 1
		length_total += _flat_distance(Vector3(hole.get("tee", Vector3.ZERO)), effective_cup(hole))
		var fun_metric: Dictionary = hole_metrics.get("fun", {})
		var fun_value: float = float(fun_metric.get("value", 0.0))
		fun_values.append(fun_value)
		var scenery_value: float = float(hole_metrics.get("scenery", {}).get("value", 0.0))
		if fun_value > 0.75 and scenery_value > 50.0 and fun_value > signature_fun:
			signature_fun = fun_value
			signature_candidate = {
				"id": int(hole.get("id", -1)),
				"name": str(hole.get("name", "Hole")),
				"fun": fun_value,
				"scenery": scenery_value,
			}

	var slope_raw: float = (beginner_total - expert_total) * 5.381 / 1.5
	var slope: float = clampf(slope_raw, 55.0, 155.0)
	var routing: Dictionary = _course_routing(terrain, open_holes)
	var rhythm: Dictionary = _course_rhythm(per_hole)
	var par_mix_note: String = ""
	var dominant: int = 0
	for key in par_mix.keys():
		dominant = maxi(dominant, int(par_mix.get(key, 0)))
	if open_holes.size() >= 6 and float(dominant) / float(open_holes.size()) >= 0.72:
		par_mix_note = "Par mix is monotonous — vary par 3/4/5 for better rhythm."
	var fun_mean: float = 0.0
	for value in fun_values:
		fun_mean += float(value)
	fun_mean /= maxf(1.0, float(fun_values.size()))
	var routing_score: float = clampf(1.0 - float(routing.get("long_transfers", 0)) / maxf(1.0, float(open_holes.size() - 1)), 0.0, 1.0)
	var rhythm_score: float = float(rhythm.get("score", 0.5))
	var par_mix_score: float = 1.0 if par_mix_note.is_empty() else clampf(1.0 - float(dominant) / float(open_holes.size()), 0.35, 1.0)
	var design_score: float = clampf(fun_mean * 40.0 + routing_score * 25.0 + rhythm_score * 20.0 + par_mix_score * 15.0, 0.0, 100.0)
	var grade_target: float = 45.0 if open_holes.size() < 9 else 65.0

	return {
		"course_rating": expert_total,
		"slope": slope,
		"par_total": par_total,
		"length_total": length_total,
		"par_mix": par_mix,
		"par_mix_note": par_mix_note,
		"routing": routing,
		"rhythm": rhythm,
		"signature_hole": signature_candidate,
		"design_score": design_score,
		"grade_target": grade_target,
		"holes": per_hole,
	}

static func filter_shots(metrics_data: Dictionary, filter_id: String) -> Array:
	var analysis: Array = metrics_data.get("analysis", [])
	var shots: Array = []
	for profile_value in analysis:
		var profile: Dictionary = profile_value
		if String(profile.get("label", "")) != "intermediate":
			continue
		shots = profile.get("shots", [])
		break
	if shots.is_empty():
		return []
	match filter_id:
		"hazard_rate", "hazards":
			return shots.filter(func(shot_value: Variant) -> bool: return bool((shot_value as Dictionary).get("hazard", false)))
		"blowup_rate", "blowups":
			return _blowup_shots(metrics_data, shots)
		"fairness":
			return shots.filter(func(shot_value: Variant) -> bool:
				var shot: Dictionary = shot_value
				return int(shot.get("penalty", 0)) > 0 and _flat_distance(Vector3(shot.get("landing", Vector3.ZERO)), Vector3(shot.get("target", Vector3.ZERO))) <= 10.0
			)
		"green_receptiveness":
			return shots.filter(func(shot_value: Variant) -> bool:
				var shot: Dictionary = shot_value
				var reason: String = String(shot.get("reason", ""))
				if reason != "approach" and not reason.ends_with("_sand"):
					return false
				return reason != "green_hit"
			)
		"decision":
			return shots.filter(func(shot_value: Variant) -> bool:
				var shot: Dictionary = shot_value
				return bool(shot.get("layup", false)) or String(shot.get("plan", "")) == "conservative" or String(shot.get("reason", "")) == "safe_side"
			)
		_:
			return shots

static func _blowup_shots(metrics_data: Dictionary, shots: Array) -> Array:
	var par: int = int(metrics_data.get("par", 4))
	var result: Array = []
	var round_shots: Array = []
	for shot_value in shots:
		var shot: Dictionary = shot_value
		round_shots.append(shot)
		if bool(shot.get("holed", false)):
			if round_shots.size() >= par + 4:
				result.append_array(round_shots)
			round_shots.clear()
	return result

static func _fourball_pace_minutes(terrain, hole: Dictionary, skill: float, seed_value: int, rounds: int) -> float:
	var total_minutes: float = 0.0
	for index in range(mini(rounds, 12)):
		var preview: Dictionary = round_preview(terrain, hole, skill, seed_value + index * 7919)
		var seconds: float = 0.0
		var previous: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
		for shot_value in preview.get("shots", []):
			var current: Dictionary = shot_value
			seconds += _flat_distance(previous, Vector3(current.get("start", previous))) / WALK_SPEED
			seconds += float(current.get("duration", 0.0))
			seconds += FOURBALL_TURN_PAUSE * 3.0
			previous = Vector3(current.get("end", previous))
		total_minutes += seconds / 60.0
	return total_minutes / maxf(1.0, float(mini(rounds, 12)))

static func _hole_scenery(terrain, hole: Dictionary) -> float:
	if terrain == null or not terrain.has_method("beauty_at"):
		return 0.0
	var tee: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
	var cup: Vector3 = effective_cup(hole)
	var samples: Array = [tee, cup, tee.lerp(cup, 0.35), tee.lerp(cup, 0.65)]
	var total: float = 0.0
	for point in samples:
		total += float(terrain.beauty_at(point))
	return total / float(samples.size())

static func _course_routing(terrain, holes: Array) -> Dictionary:
	var total_walk: float = 0.0
	var long_transfers: int = 0
	var warnings: Array = []
	for index in range(holes.size() - 1):
		var current: Dictionary = holes[index]
		var nxt: Dictionary = holes[index + 1]
		var start: Vector3 = effective_cup(current)
		var finish: Vector3 = Vector3(nxt.get("tee", Vector3.ZERO))
		var path: PackedVector3Array = PackedVector3Array([start, finish])
		if terrain != null and terrain.has_method("route"):
			path = terrain.route(start, finish, false)
		var distance: float = 0.0
		for step in range(path.size() - 1):
			distance += _flat_distance(path[step], path[step + 1])
		total_walk += distance
		if distance > 150.0:
			long_transfers += 1
			warnings.append({
				"from_hole": int(current.get("id", -1)),
				"to_hole": int(nxt.get("id", -1)),
				"distance": distance,
			})
	return {
		"total_walk": total_walk,
		"long_transfers": long_transfers,
		"warnings": warnings,
		"note": "Routing jump exceeds 150 m between holes %d and %d." % [int(warnings[0].from_hole), int(warnings[0].to_hole)] if not warnings.is_empty() else "Walk between greens and tees is compact.",
	}

static func _course_rhythm(per_hole: Array) -> Dictionary:
	if per_hole.size() < 3:
		return {"score": 0.55, "note": "Add more holes to judge course rhythm."}
	var diffs: Array = []
	for hole_metrics in per_hole:
		diffs.append(float(hole_metrics.get("difficulty", {}).get("value", 0.0)))
	var alternation: float = 0.0
	for index in range(1, diffs.size() - 1):
		var prev_easy: bool = float(diffs[index - 1]) < 0.0
		var current_hard: bool = float(diffs[index]) > 0.2
		var next_easy: bool = float(diffs[index + 1]) < 0.0
		if prev_easy and current_hard and next_easy:
			alternation += 1.0
		elif float(diffs[index]) * float(diffs[index - 1]) < 0.0:
			alternation += 0.5
	var score: float = clampf(0.35 + alternation / maxf(1.0, float(diffs.size() - 2)), 0.0, 1.0)
	return {
		"score": score,
		"note": "Difficulty alternates across the card." if score >= 0.55 else "Try an easy hole after two hard ones to improve rhythm.",
	}

static func _fun_score(variety_value: float, decision_value: float, fairness_value: float, spread_value: float, blowup_rate: float, par: int) -> float:
	var variety_score: float = clampf(variety_value / 0.4, 0.0, 1.0)
	var decision_score: float = clampf(decision_value / 0.7, 0.0, 1.0) if par >= 4 else 0.65
	var fairness_score: float = clampf(fairness_value / 0.75, 0.0, 1.0)
	var spread_score: float = 1.0 if spread_value >= 1.0 and spread_value <= 2.2 else clampf(1.0 - absf(spread_value - 1.6) / 1.6, 0.0, 1.0)
	var blowup_score: float = clampf(1.0 - blowup_rate / 0.12, 0.0, 1.0)
	return clampf(
		variety_score * 0.25 + decision_score * 0.25 + fairness_score * 0.2 + spread_score * 0.15 + blowup_score * 0.15,
		0.0, 1.0
	)

static func _metric_band(value: float, low: float, high: float, low_note: String, high_note: String, ok_note: String) -> Dictionary:
	var band: String = "ok"
	var note: String = ok_note
	if value < low:
		band = "low"
		note = low_note
	elif value > high:
		band = "high"
		note = high_note
	return {"value": value, "band": band, "note": note}

static func _choose_target(terrain, start: Vector3, cup: Vector3, hole: Dictionary, skill: float, start_surface: int, start_on_green: bool) -> Dictionary:
	return _plan_target(terrain, start, cup, hole, skill, start_surface, start_on_green)

static func _plan_target(terrain, start: Vector3, cup: Vector3, hole: Dictionary, skill: float, start_surface: int, start_on_green: bool) -> Dictionary:
	var slope: Vector2 = _read_slope(terrain, start)
	var max_reach: float = 230.0 * _skill_distance_factor(skill) * _surface_distance_factor(start_surface, terrain, start) * _slope_distance_factor(slope)
	var candidates: Array = _collect_candidates(terrain, start, cup, hole, max_reach, start_on_green, slope)
	if candidates.is_empty():
		return {"target": _ground_point(terrain, cup), "reason": "approach", "plan": "aggressive", "contested": false}
	var safer: int = 0
	var aggressive: int = 0
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		if String(candidate.get("plan", "")) == "aggressive":
			aggressive += 1
		else:
			safer += 1
	var contested: bool = aggressive > 0 and safer > 0
	if candidates.size() == 1:
		var single: Dictionary = (candidates[0] as Dictionary).duplicate()
		single["contested"] = false
		if not single.has("plan"):
			single["plan"] = "neutral"
		return single
	var chosen: Dictionary = _select_candidate(terrain, start, cup, hole, skill, start_surface, start_on_green, candidates)
	chosen["contested"] = contested
	if not chosen.has("plan"):
		chosen["plan"] = "neutral"
	return chosen

static func _collect_candidates(terrain, start: Vector3, cup: Vector3, hole: Dictionary, max_reach: float, start_on_green: bool, slope: Vector2) -> Array:
	var candidates: Array = []
	var seen: Dictionary = {}
	var direct_distance: float = _flat_distance(start, cup)
	var direction: Vector3 = _flat_direction(start, cup)
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var pin_blocked: bool = direct_distance > 1.0 and bool(terrain.segment_blocked(start, cup))
	if start_on_green:
		var putt_reason: String = "putt" if direct_distance <= 24.0 else "approach"
		_append_candidate(candidates, seen, terrain, start, cup, hole, putt_reason, "aggressive", max_reach, false)
		if direct_distance > 12.0 and slope.length() > 0.06:
			var lag_distance: float = clampf(direct_distance * 0.62, 4.0, direct_distance - 2.0)
			var lag_point: Vector3 = start + direction * lag_distance
			var side_slope: Vector3 = Vector3(-direction.z, 0.0, direction.x)
			var break_side: float = signf(slope.x * direction.x + slope.y * direction.z)
			if absf(break_side) < 0.001:
				break_side = 1.0
			lag_point += side_slope * break_side * minf(1.8, slope.length() * 6.0)
			_append_candidate(candidates, seen, terrain, start, lag_point, hole, "lag_putt", "conservative", max_reach, false)
		return candidates

	var cup_ground: Vector3 = _ground_point(terrain, cup)
	var pin_playable: bool = bool(terrain.playable(cup_ground)) or _on_green(terrain, cup_ground, hole)
	if pin_playable and not pin_blocked:
		_append_candidate(candidates, seen, terrain, start, cup_ground, hole, "approach", "aggressive", max_reach, true)

	var fat: Vector3 = _fat_of_green(terrain, cup_ground, hole)
	if _flat_distance(fat, cup_ground) >= 4.0:
		_append_candidate(candidates, seen, terrain, start, fat, hole, "safe_side", "conservative", max_reach, true)

	var hazard_span: Dictionary = _hazard_span_along(terrain, start, cup_ground, hole)
	if not hazard_span.is_empty():
		var short_of: Vector3 = Vector3(hazard_span.get("short_of", start))
		_append_candidate(candidates, seen, terrain, start, short_of, hole, "layup", "conservative", max_reach, true)
		var carry: Vector3 = Vector3(hazard_span.get("carry", Vector3.ZERO))
		if carry.length_squared() > 0.5:
			_append_candidate(candidates, seen, terrain, start, carry, hole, "carry_hazard", "aggressive", max_reach, true)

	var waypoints_value: Variant = hole.get("waypoints", [])
	var waypoints: Array = waypoints_value if waypoints_value is Array else []
	var checks: int = 0
	for waypoint_value in waypoints:
		if checks >= MAX_WAYPOINTS_CHECKED:
			break
		checks += 1
		var waypoint: Vector3 = Vector3(waypoint_value)
		var from_start: float = _flat_distance(start, waypoint)
		var remaining: float = _flat_distance(waypoint, cup)
		if from_start < 8.0 or remaining >= direct_distance - 2.0 or from_start > max_reach * 1.05:
			continue
		_append_candidate(candidates, seen, terrain, start, waypoint, hole, "waypoint_layup", "conservative", max_reach, true)

	var anchor_distance: float = minf(direct_distance * 0.62, max_reach * 0.82)
	var anchor: Vector3 = start + direction * maxf(8.0, anchor_distance)
	if pin_blocked:
		var anchors_used: int = 0
		for sign_value in [-1.0, 1.0]:
			if anchors_used >= MAX_ANCHOR_CHECKS:
				break
			var tree_point: Vector3 = _ground_point(terrain, anchor + side * 12.0 * sign_value)
			if bool(terrain.playable(tree_point)):
				_append_candidate(candidates, seen, terrain, start, tree_point, hole, "tree_layup", "conservative", max_reach, true)
				anchors_used += 1
	if direct_distance > max_reach * 0.96 or candidates.is_empty():
		_append_candidate(candidates, seen, terrain, start, anchor, hole, "layup", "conservative", max_reach, false)
	if candidates.is_empty():
		_append_candidate(candidates, seen, terrain, start, cup_ground, hole, "approach", "aggressive", max_reach, false)
	return candidates

static func _append_candidate(candidates: Array, seen: Dictionary, terrain, start: Vector3, point: Vector3, hole: Dictionary, reason: String, plan: String, max_reach: float, require_clear: bool) -> void:
	if candidates.size() >= MAX_PLAN_CANDIDATES:
		return
	var ground: Vector3 = _ground_point(terrain, point)
	var dist: float = _flat_distance(start, ground)
	if dist < 2.5 and reason != "putt" and reason != "lag_putt":
		return
	if dist > max_reach * 1.05 and reason != "putt" and reason != "lag_putt":
		return
	if require_clear and dist > 1.0 and bool(terrain.segment_blocked(start, ground)):
		return
	if reason != "approach" and reason != "putt" and reason != "carry_hazard" and not bool(terrain.playable(ground)) and not _on_green(terrain, ground, hole):
		return
	var key: Vector2i = Vector2i(int(round(ground.x / 4.0)), int(round(ground.z / 4.0)))
	if seen.has(key):
		return
	seen[key] = true
	candidates.append({"target": ground, "reason": reason, "plan": plan})

static func _fat_of_green(terrain, cup: Vector3, hole: Dictionary) -> Vector3:
	var green_radius: float = maxf(3.0, float(hole.get("green_radius", 16.0)))
	var danger: Vector3 = Vector3.ZERO
	var hits: int = 0
	for index in range(8):
		var angle: float = float(index) * TAU / 8.0
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var sample: Vector3 = _ground_point(terrain, cup + offset * green_radius * 0.9)
		if _probe_kind(terrain, sample, hole, cup) in ["water", "penalty", "ob"] or int(terrain.surface_at(sample)) == 4:
			danger += offset
			hits += 1
	if hits == 0 or danger.length_squared() < 0.01:
		return cup
	var away: Vector3 = -Vector3(danger.x, 0.0, danger.z).normalized()
	var fat: Vector3 = _ground_point(terrain, cup + away * green_radius * 0.45)
	if not bool(terrain.playable(fat)) and not _on_green(terrain, fat, hole):
		return cup
	return fat

static func _hazard_span_along(terrain, start: Vector3, end: Vector3, hole: Dictionary) -> Dictionary:
	var dist: float = _flat_distance(start, end)
	if dist < 12.0:
		return {}
	var steps: int = clampi(int(dist / 8.0), 2, 24)
	var direction: Vector3 = _flat_direction(start, end)
	var in_hazard: bool = false
	var last_safe: Vector3 = start
	var carry: Vector3 = Vector3.ZERO
	var found: bool = false
	for index in range(1, steps + 1):
		var sample: Vector3 = _ground_point(terrain, start + direction * dist * (float(index) / float(steps)))
		var kind: String = _probe_kind(terrain, sample, hole, start)
		var wet: bool = kind in ["water", "penalty", "ob"]
		if wet:
			found = true
			in_hazard = true
		else:
			if in_hazard:
				carry = sample
				in_hazard = false
			else:
				last_safe = sample
	if not found:
		return {}
	var short_of: Vector3 = last_safe - direction * 6.0
	if _flat_distance(start, short_of) < 8.0:
		short_of = last_safe
	var result: Dictionary = {"short_of": _ground_point(terrain, short_of)}
	if carry.length_squared() > 0.5:
		result["carry"] = _ground_point(terrain, carry + direction * 6.0)
	return result

static func _select_candidate(terrain, start: Vector3, cup: Vector3, hole: Dictionary, skill: float, start_surface: int, start_on_green: bool, candidates: Array) -> Dictionary:
	var scored: Array = []
	var best_score: float = INF
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		var evaluation: Dictionary = _evaluate_candidate(terrain, start, cup, hole, skill, start_surface, start_on_green, candidate)
		var row: Dictionary = candidate.duplicate()
		row.merge(evaluation)
		scored.append(row)
		best_score = minf(best_score, float(evaluation.get("score", 99.0)))
	var window: Array = []
	for row_value in scored:
		var row: Dictionary = row_value
		if float(row.get("score", 99.0)) <= best_score + PLAN_TIE_STROKES:
			window.append(row)
	if window.is_empty():
		return candidates[0]
	if start_on_green and skill < 0.35 and _read_slope(terrain, start).length() > 0.06:
		for row_value in scored:
			var conservative_row: Dictionary = row_value
			if String(conservative_row.get("reason", "")) == "lag_putt":
				return {
					"target": Vector3(conservative_row.get("target", cup)),
					"reason": "lag_putt",
					"plan": "conservative"
				}
	var prefer_aggressive: bool = skill >= 0.55
	var chosen: Dictionary = window[0]
	var chosen_rank: int = _aggression_rank(chosen)
	for row_value in window:
		var row: Dictionary = row_value
		var rank: int = _aggression_rank(row)
		if prefer_aggressive and rank > chosen_rank:
			chosen = row
			chosen_rank = rank
		elif not prefer_aggressive and rank < chosen_rank:
			chosen = row
			chosen_rank = rank
	return {"target": Vector3(chosen.get("target", cup)), "reason": String(chosen.get("reason", "approach")), "plan": String(chosen.get("plan", "neutral"))}

static func _aggression_rank(candidate: Dictionary) -> int:
	var reason: String = String(candidate.get("reason", ""))
	if reason == "carry_hazard" or reason == "approach" or reason == "putt":
		return 3
	if reason == "safe_side":
		return 1
	return 0

static func _evaluate_candidate(terrain, start: Vector3, cup: Vector3, hole: Dictionary, skill: float, start_surface: int, start_on_green: bool, candidate: Dictionary) -> Dictionary:
	var target: Vector3 = Vector3(candidate.get("target", cup))
	var distance: float = _flat_distance(start, target)
	var direction: Vector3 = _flat_direction(start, target)
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var sigma: float = _aim_dispersion_meters(terrain, start, hole, skill, start_surface, start_on_green, distance)
	var along_sigma: float = sigma * 1.15
	var probes: Array = [[0.0, 0.0, 0.36]]
	if distance >= 2.0:
		probes = [
			[0.0, 0.0, 0.36],
			[0.7, 0.0, 0.16],
			[-0.7, 0.0, 0.16],
			[0.0, 0.7, 0.14],
			[0.0, -0.7, 0.14],
			[1.1, 0.0, 0.02],
			[-1.1, 0.0, 0.02]
		]
	var ev: float = 0.0
	var center_remaining: float = 0.0
	var worst_remaining: float = 0.0
	var zone_cache: Dictionary = {}
	for probe_value in probes:
		var probe: Array = probe_value
		var landing: Vector3 = _ground_point(terrain, target + direction * (float(probe[0]) * along_sigma) + side * (float(probe[1]) * sigma))
		var remaining: float = _probe_remaining(terrain, start, cup, hole, skill, landing, zone_cache)
		var weight: float = float(probe[2])
		ev += remaining * weight
		if is_equal_approx(float(probe[0]), 0.0) and is_equal_approx(float(probe[1]), 0.0):
			center_remaining = remaining
		elif absf(float(probe[0])) <= 0.75 and absf(float(probe[1])) <= 0.75:
			worst_remaining = maxf(worst_remaining, remaining)
	var outcome_spread: float = maxf(0.0, worst_remaining - center_remaining)
	var risk_term: float = (1.15 - skill) * 0.35 * outcome_spread
	if start_on_green and String(candidate.get("reason", "")) == "putt" and _read_slope(terrain, start).length() > 0.06:
		risk_term += (1.15 - skill) * 0.22
	return {"ev": 1.0 + ev, "score": 1.0 + ev + risk_term, "spread": outcome_spread}

static func _aim_dispersion_meters(terrain, start: Vector3, hole: Dictionary, skill: float, start_surface: int, start_on_green: bool, distance: float) -> float:
	var dispersion: float = 0.018 + (1.0 - skill) * 0.105
	if start_surface == 0:
		dispersion += 0.018
	elif start_surface == 4:
		dispersion += 0.045
		var start_bunker: Dictionary = _bunker_at(terrain, start)
		if not start_bunker.is_empty():
			dispersion += clampf(float(start_bunker.get("depth", 0.0)) / 0.8, 0.0, 1.0) * 0.06
	if start_on_green and terrain != null and terrain.has_method("condition_at"):
		var green_condition: float = float(terrain.condition_at(start))
		if green_condition < 0.5:
			var poor: float = (0.5 - green_condition) / 0.5
			dispersion += dispersion * 0.4 * poor
	var meters: float = maxf(1.5, distance * dispersion)
	if start_on_green:
		var green_stats: Dictionary = _green_slope_stats(terrain, hole)
		meters += float(green_stats.get("mean", 0.0)) * 6.0
		meters += _read_slope(terrain, start).length() * 6.0
	return meters

static func _probe_remaining(terrain, start: Vector3, cup: Vector3, hole: Dictionary, skill: float, landing: Vector3, zone_cache: Dictionary) -> float:
	if _flat_distance(start, landing) > 1.0 and bool(terrain.segment_blocked(start, landing)):
		return 1.45 + _flat_distance(landing, cup) / 100.0
	var kind: String = _cached_probe_kind(terrain, landing, hole, start, zone_cache)
	if kind == "ob":
		return 1.0 + _remaining_from_lie(terrain, hole, cup, start, skill)
	if kind == "water" or kind == "penalty":
		var drop: Vector3 = landing
		if terrain != null and terrain.has_method("penalty_drop"):
			drop = _ground_point(terrain, Vector3(terrain.penalty_drop(start, landing)))
		elif terrain != null and terrain.has_method("nearest_safe"):
			drop = _ground_point(terrain, Vector3(terrain.nearest_safe(landing)))
		return 1.0 + _remaining_from_lie(terrain, hole, cup, drop, skill)
	if kind == "unplayable":
		var safe: Vector3 = landing
		if terrain != null and terrain.has_method("nearest_safe"):
			safe = _ground_point(terrain, Vector3(terrain.nearest_safe(landing)))
		return 1.0 + _remaining_from_lie(terrain, hole, cup, safe, skill)
	return _remaining_from_lie(terrain, hole, cup, landing, skill)

static func _remaining_from_lie(terrain, hole: Dictionary, cup: Vector3, point: Vector3, skill: float) -> float:
	var dist: float = _flat_distance(point, cup)
	if _on_green(terrain, point, hole):
		return _expected_putts(dist, _read_slope(terrain, point).length(), skill)
	var surface: int = int(terrain.surface_at(point))
	if surface == 2:
		return _expected_putts(dist, _read_slope(terrain, point).length(), skill)
	if surface == 5:
		return 2.2 + dist / 100.0
	if surface == 4:
		var depth: float = 0.0
		var bunker: Dictionary = _bunker_at(terrain, point)
		if not bunker.is_empty():
			depth = clampf(float(bunker.get("depth", 0.0)) / 0.8, 0.0, 1.0)
		return 1.7 + depth * 0.4 + dist / 110.0
	if surface == 0:
		return 1.35 + dist / 120.0
	return 1.15 + dist / 140.0

static func _expected_putts(distance: float, slope_length: float, skill: float) -> float:
	var base: float = 1.0 + clampf((distance - 0.8) / 14.0, 0.0, 1.4)
	base += slope_length * 2.0
	base += (1.0 - skill) * 0.15
	if distance <= 0.55 + skill * 0.95:
		base = minf(base, 1.05)
	return clampf(base, 1.0, 2.7)

static func _cached_probe_kind(terrain, point: Vector3, hole: Dictionary, start: Vector3, cache: Dictionary) -> String:
	var key: Vector2i = Vector2i(int(point.x / 4.0), int(point.z / 4.0))
	if cache.has(key):
		return String(cache[key])
	var kind: String = _probe_kind(terrain, point, hole, start)
	cache[key] = kind
	return kind

static func _probe_kind(terrain, point: Vector3, hole: Dictionary, _start: Vector3) -> String:
	var surface: int = int(terrain.surface_at(point))
	if surface == 5:
		return "water"
	var zone: String = _zone_at(terrain, point, hole)
	if zone == "ob":
		return "ob"
	if zone == "penalty":
		return "penalty"
	if not bool(terrain.playable(point)):
		return "unplayable"
	return ""

static func _choose_club(distance: float, surface: int, skill: float, slope: Vector2, elevation: float, terrain = null, start: Vector3 = Vector3.ZERO, on_green: bool = false) -> Dictionary:
	var terrain_factor: float = _surface_distance_factor(surface, terrain, start) * _slope_distance_factor(slope)
	if elevation > 0.0:
		terrain_factor *= clampf(1.0 - elevation / 180.0, 0.74, 1.0)
	for club_value in _CLUBS:
		var club: Dictionary = club_value
		var name: String = String(club.get("name", "wedge"))
		if name == "putter" and not on_green:
			continue
		var reachable: float = float(club.get("carry", 30.0)) * _skill_distance_factor(skill) * terrain_factor
		if reachable >= distance * 0.98:
			return club
	return _CLUBS[_CLUBS.size() - 1]

static func _on_green(terrain, point: Vector3, hole: Dictionary) -> bool:
	if terrain == null:
		return false
	# Registered holes decide by painted-cell ownership (shaped lobes count);
	# offline hole dictionaries fall back to the painted surface and radius.
	if terrain.has_method("on_green") and bool(terrain.on_green(point, hole)):
		return true
	if int(terrain.surface_at(point)) != 2:
		return false
	var cup: Vector3 = effective_cup(hole)
	return _flat_distance(point, cup) <= maxf(3.0, float(hole.get("green_radius", 16.0)))

static func _zone_at(terrain, point: Vector3, hole: Dictionary) -> String:
	if terrain != null and terrain.has_method("zone_at"):
		return String(terrain.zone_at(point, hole))
	return ""

static func _bunker_at(terrain, point: Vector3) -> Dictionary:
	if terrain != null and terrain.has_method("bunker_at"):
		return terrain.bunker_at(point)
	return {}

static func _green_slope_stats(terrain, hole: Dictionary) -> Dictionary:
	if terrain != null and terrain.has_method("green_slope_stats"):
		return terrain.green_slope_stats(hole)
	return {"mean": 0.0, "max": 0.0}

static func _ground_point(terrain, point: Vector3) -> Vector3:
	var ground_y: float = float(terrain.height_at(point))
	return Vector3(point.x, ground_y, point.z)

static func _read_slope(terrain, point: Vector3) -> Vector2:
	var value: Variant = terrain.slope_at(point)
	if value is Vector2:
		return value
	return Vector2.ZERO

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

static func _flat_direction(a: Vector3, b: Vector3) -> Vector3:
	var delta: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	if delta.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return delta.normalized()

static func _skill_distance_factor(skill: float) -> float:
	return 0.78 + skill * 0.30

static func _surface_distance_factor(surface: int, terrain = null, pos: Vector3 = Vector3.ZERO) -> float:
	var factor: float = 0.96
	if surface == 0:
		factor = 0.92
	elif surface == 4:
		factor = 0.67
	elif surface == 2:
		factor = 1.0
	if surface == 1 and terrain != null and terrain.has_method("condition_at"):
		var fairway_condition: float = float(terrain.condition_at(pos))
		if fairway_condition < 0.5:
			var poor: float = (0.5 - fairway_condition) / 0.5
			var halfway_rough: float = lerpf(0.96, 0.92, 0.5)
			factor = lerpf(0.96, halfway_rough, poor)
	return factor

static func _slope_distance_factor(slope: Vector2) -> float:
	return clampf(1.0 - slope.length() * 0.045, 0.78, 1.0)

static func _noise(rng: RandomNumberGenerator) -> float:
	return (rng.randf() + rng.randf() + rng.randf()) / 3.0 * 2.0 - 1.0
