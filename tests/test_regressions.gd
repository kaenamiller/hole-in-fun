extends SceneTree
var failures=0

func approx_within(a: float, b: float, tolerance: float) -> bool:
	return absf(float(a) - float(b)) <= tolerance


func check(value: bool, message: String) -> void:
	if not value:
		failures+=1
		push_error(message)

func _init() -> void:
	var terrain=TerrainModel.new()
	terrain.starter_resort()
	var sim=ResortSimulation.new()
	sim.setup(terrain,false,true)
	var sim2=ResortSimulation.new()
	var copy=TerrainModel.new()
	copy.restore(terrain.snapshot())
	sim2.setup(copy,false,true)
	for i in range(100):sim.tick(0.1)
	sim2.tick(10)
	check(is_equal_approx(sim.minute,sim2.minute),"fixed ticks independent of caller partition")
	check(sim.snapshot().rng_state==sim2.snapshot().rng_state,"fixed ticks retain RNG stream")
	var empty=TerrainModel.new()
	var isolated=ResortSimulation.new()
	isolated.setup(empty,true,false)
	check(isolated.admit_group(1)<0,"blank land cannot admit golfers")
	check(isolated.borrow("course_expansion").contains("funded"),"sandbox bypasses loan grade")
	check(isolated.schedule_event("invitational").contains("18"),"events retain physical course requirements in sandbox")
	for z in range(256):
		for x in range(80,90):
			empty.surfaces[z*256+x]=5
			empty.water_levels[z*256+x]=0
	empty.touch()
	var a=Vector3(280,empty.height_at(Vector3(280,0,240)),240)
	var b=Vector3(400,empty.height_at(Vector3(400,0,240)),240)
	check(empty.route(a,b).is_empty(),"water stripe blocks pathfinding")
	check(isolated._route(a,b,false).is_empty(),"simulation never fabricates a route across water")
	var person={"pos":a,"destination":b,"route":PackedVector3Array(),"route_index":0}
	check(not isolated._move_person(person,100,1.8),"unreachable person remains blocked")
	check(person.pos==a,"unreachable person does not teleport")
	empty.add_object("bridge_cart",Vector3(304,0,240),0,Vector3(384,0,240))
	check(not empty.route(a,b).is_empty(),"bridge restores pedestrian connectivity")
	check(not empty.route(Vector3(304,0,240),Vector3(384,0,240),true).is_empty(),"bridge permits carts")
	SaveStore.directory="user://test_saves/regression_%d"%OS.get_process_id()
	SaveStore.save_game("Backup",terrain,sim)
	var first_cash=sim.cash
	sim.cash-=1000
	SaveStore.save_game("Backup",terrain,sim)
	var f=FileAccess.open(SaveStore.directory.path_join("Backup.hif"),FileAccess.WRITE)
	f.store_string("invalid save")
	f.close()
	var recovered=SaveStore.load_game("Backup")
	check(not recovered.is_empty() and recovered.simulation.cash==first_cash,"corrupted primary save recovers atomic backup")
	for file in ["Backup.hif","Backup.hif.bak"]:DirAccess.remove_absolute(SaveStore.directory.path_join(file))
	DirAccess.remove_absolute(SaveStore.directory)
	var event_terrain=TerrainModel.new()
	event_terrain.starter_resort()
	var events=ResortSimulation.new()
	events.setup(event_terrain,false,true)
	var opening=events.cash
	check(events.schedule_event("open_day",1).contains("scheduled"),"starter can host open day")
	events.tick(72000)
	check(events.event_history.size()==1,"calendar event resolves after two actual simulated days")
	if not events.event_history.is_empty():
		var result=events.event_history[0]
		print("REAL_EVENT ",result.result," publicity=",events.publicity)
		check(result.status=="success","starter open day qualifies through actual attendance and completed rounds")
	var net=0.0
	for entry in events.ledger:net+=entry.amount
	check(absf(events.cash-(opening+net))<0.01,"cash reconciles with the entire ledger after wages, upkeep, event revenue and refunds")
	var log_terrain=TerrainModel.new()
	log_terrain.starter_resort()
	var log_sim=ResortSimulation.new()
	log_sim.setup(log_terrain,false,true)
	log_sim.post("warning","finance","Regression notice test")
	var before=log_sim.snapshot()
	var restored=ResortSimulation.new()
	var restored_terrain=TerrainModel.new()
	restored_terrain.restore(log_terrain.snapshot())
	restored.setup(restored_terrain,false,true)
	restored.restore(before)
	check(restored.log.size()==before.log.size() and int(restored.log.back().get("id",-1))==int(before.log.back().get("id",-1)),"snapshot restore preserves event log")
	check(restored.notice==before.notice,"notice string survives snapshot restore")
	var history_terrain=TerrainModel.new()
	history_terrain.starter_resort()
	var history_sim=ResortSimulation.new()
	history_sim.setup(history_terrain,false,true)
	history_sim.tick(72000)
	var history_before=history_sim.snapshot()
	var history_restored=ResortSimulation.new()
	var history_restored_terrain=TerrainModel.new()
	history_restored_terrain.restore(history_terrain.snapshot())
	history_restored.setup(history_restored_terrain,false,true)
	history_restored.restore(history_before)
	check(history_restored.history.size()==history_before.history.size(),"snapshot restore preserves history")
	check(history_restored.records.size()==history_before.records.size(),"snapshot restore preserves records")
	if history_sim.history.size() >= 1:
		var record: Dictionary = history_sim.history[0]
		var ledger_income: float = 0.0
		var ledger_costs: float = 0.0
		for item in history_sim.ledger:
			if int(item.get("day", -1)) <= int(record.get("day", -1)) - 30 or int(item.get("day", -1)) > int(record.get("day", -1)):
				continue
			var amount: float = float(item.get("amount", 0.0))
			if str(item.get("category", "")) in ["capital", "loan", "loan_payment"]:
				continue
			elif amount > 0.0:
				ledger_income += amount
			else:
				ledger_costs -= amount
		var history_income: float = 0.0
		var history_costs: float = 0.0
		for amount in (record.get("revenue", {}) as Dictionary).values():
			history_income += float(amount)
		for amount in (record.get("expenses", {}) as Dictionary).values():
			history_costs += float(amount)
		check(absf(history_income - ledger_income) < 2.0 and absf(history_costs - ledger_costs) < 2.0, "daily history matches ledger-derived numbers within rounding")
	var feedback_terrain=TerrainModel.new()
	feedback_terrain.starter_resort()
	var feedback_sim=ResortSimulation.new()
	feedback_sim.setup(feedback_terrain,false,true)
	feedback_sim.admit_group(2)
	feedback_sim.tick(72000)
	var feedback_before=feedback_sim.snapshot()
	var feedback_restored=ResortSimulation.new()
	var feedback_restored_terrain=TerrainModel.new()
	feedback_restored_terrain.restore(feedback_terrain.snapshot())
	feedback_restored.setup(feedback_restored_terrain,false,true)
	feedback_restored.restore(feedback_before)
	check(feedback_restored.reviews.size()==feedback_before.reviews.size(),"snapshot restore preserves reviews")
	check(feedback_restored.daily_feedback.size()==feedback_before.daily_feedback.size(),"snapshot restore preserves daily_feedback")
	var summary_total=0
	for count in feedback_sim.feedback_summary(7).get("tag_totals", {}).values():
		summary_total+=int(count)
	var daily_total=0
	var start_day=maxi(1, feedback_sim.day-6)
	for day_value in feedback_sim.daily_feedback.keys():
		if int(day_value) < start_day or int(day_value) > feedback_sim.day:
			continue
		for count in feedback_sim.daily_feedback[day_value].values():
			daily_total+=int(count)
	check(summary_total==daily_total,"feedback_summary(7) sums match per-day dictionaries")
	var wear_terrain=TerrainModel.new()
	wear_terrain.starter_resort(false)
	var wear_sim=ResortSimulation.new()
	wear_sim.setup(wear_terrain,false,true)
	check(wear_sim._terrain_wear()>=0.0 and wear_sim._terrain_wear()<=1.0,"terrain wear stays within 0..1 for starter")
	check(wear_sim.grade==1,"starter grade remains gated by unchanged wear thresholds")
	var legacy_staff: Array = [{
		"id": 9, "name": "Legacy Cleaner", "role": "cleaner",
		"pos": ResortSimulation.ENTRANCE, "destination": ResortSimulation.ENTRANCE,
		"activity": "available", "assignment": 102, "wage": 105.0, "skill": 0.68,
		"route": PackedVector3Array(), "route_index": 0,
	}]
	var legacy_snapshot: Dictionary = wear_sim.snapshot()
	legacy_snapshot["staff"] = legacy_staff
	var legacy_sim = ResortSimulation.new()
	legacy_sim.setup(wear_terrain, false, false)
	legacy_sim.restore(legacy_snapshot)
	check(legacy_sim.staff.size() == 1, "legacy staff array restores one worker")
	var restored_worker: Dictionary = legacy_sim.staff[0]
	check(restored_worker.get("assignment") is Dictionary and str(restored_worker.get("assignment", {}).get("kind", "")) == "object", "integer assignment migrates to object kind")
	check(float(restored_worker.get("morale", -1.0)) >= 0.0 and float(restored_worker.get("morale", 2.0)) <= 1.0, "missing morale restores with defaults")
	var wage_net: float = 0.0
	for entry in legacy_sim.ledger:
		wage_net += float(entry.get("amount", 0.0))
	legacy_sim._settle_wages_and_upkeep()
	for entry in legacy_sim.ledger:
		if str(entry.get("category", "")) == "wages":
			wage_net += float(entry.get("amount", 0.0))
	check(legacy_sim.ledger.any(func(item: Dictionary) -> bool: return str(item.get("category", "")) == "wages"), "restored staff wages reconcile in ledger")

	var unlock_terrain = TerrainModel.new()
	unlock_terrain.starter_resort()
	var unlock_sim = ResortSimulation.new()
	unlock_sim.setup(unlock_terrain, false, true)
	var legacy_unlock_snapshot: Dictionary = unlock_sim.snapshot()
	legacy_unlock_snapshot.erase("unlocked")
	legacy_unlock_snapshot.erase("projects")
	legacy_unlock_snapshot["grade"] = 2
	var restored_unlock = ResortSimulation.new()
	var restored_unlock_terrain = TerrainModel.new()
	restored_unlock_terrain.restore(unlock_terrain.snapshot())
	restored_unlock.setup(restored_unlock_terrain, false, true)
	restored_unlock.restore(legacy_unlock_snapshot)
	var kinds_ok: bool = true
	for obj in restored_unlock_terrain.objects:
		var kind: String = str(obj.get("kind", ""))
		if Catalog.find(kind).is_empty():
			continue
		kinds_ok = kinds_ok and restored_unlock.can_build(kind)
	check(kinds_ok, "restoring an old grade-2 save keeps every placed catalog object buildable")
	var sandbox_sim = ResortSimulation.new()
	sandbox_sim.setup(TerrainModel.new(), true, false)
	check(sandbox_sim.can_build("cart_barn") and sandbox_sim.can_build("maintenance_shed"), "sandbox bypasses unlock locks")

	var legacy_object_terrain = TerrainModel.new()
	legacy_object_terrain.starter_resort()
	for object in legacy_object_terrain.objects:
		if str(object.get("kind", "")) == "clubhouse":
			object.erase("level")
	var legacy_object_sim = ResortSimulation.new()
	legacy_object_sim.setup(legacy_object_terrain, false, true)
	check(int(legacy_object_sim._facility_by_kind("clubhouse").get("level", 0)) == 1, "old objects without level default to 1")

	var lodge_stress_terrain = TerrainModel.new()
	lodge_stress_terrain.starter_resort()
	lodge_stress_terrain.objects.append({
		"id": 880, "kind": "lodge", "pos": Vector3(220.0, 0.0, 180.0),
		"rotation": 0.0, "condition": 1.0, "cleanliness": 1.0, "level": 1,
	})
	var lodge_stress_sim = ResortSimulation.new()
	lodge_stress_sim.setup(lodge_stress_terrain, false, true)
	lodge_stress_sim.unlocked.append("pro_shop")
	lodge_stress_sim.unlocked.append("restaurant")
	lodge_stress_sim.unlocked.append("lodge")
	lodge_stress_sim._arrival_target = 48
	for _index in range(12):
		lodge_stress_sim.admit_group(4)
	lodge_stress_sim._arrival_target = 0
	for _day_index in range(120):
		lodge_stress_sim._arrival_target = 0
		lodge_stress_sim.tick(800.0)
		var resolved: bool = true
		for group in lodge_stress_sim.groups:
			var state: String = str(group.get("state", ""))
			if state not in ["departed", "lodged"]:
				resolved = false
				break
		if resolved and lodge_stress_sim.completed_visits > 0:
			break
	var stranded: int = 0
	for group in lodge_stress_sim.groups:
		if str(group.get("state", "")) not in ["departed", "lodged", "playing", "departing"]:
			stranded += 1
	var blocked_guests: int = 0
	for guest in lodge_stress_sim.guests:
		if bool(guest.get("blocked", false)):
			blocked_guests += 1
	check(stranded == 0 and blocked_guests == 0, "100-guest stress with a lodge leaves nobody blocked or stranded")

	var ledger_sim = ResortSimulation.new()
	ledger_sim.setup(lodge_stress_terrain, false, true)
	ledger_sim.unlocked.append("pro_shop")
	ledger_sim.unlocked.append("restaurant")
	ledger_sim.unlocked.append("lodge")
	ledger_sim.prices = ledger_sim._migrate_prices({
		"retail": 42.0, "meal": 28.0, "room": 120.0, "event_entry": 18.0,
	})
	var ledger_opening: float = ledger_sim.cash
	ledger_sim.credit(240.0, "retail", "Pro shop test")
	ledger_sim.credit(84.0, "meals", "Restaurant test")
	ledger_sim.credit(240.0, "lodging", "Lodge rooms test")
	ledger_sim.credit(ledger_sim.price("event_entry", {}) * 2.0, "admissions", "Event entry fees")
	var ledger_net: float = 0.0
	for entry in ledger_sim.ledger:
		ledger_net += float(entry.get("amount", 0.0))
	check(absf(ledger_sim.cash - (ledger_opening + ledger_net)) < 0.01, "ledger reconciles with rooms, retail, and event entry")

	var publicity_terrain = TerrainModel.new()
	publicity_terrain.starter_resort()
	var publicity_sim = ResortSimulation.new()
	publicity_sim.setup(publicity_terrain, false, true)
	check(publicity_sim.publicity >= 18.0, "starter derived publicity still clears grade-two threshold")
	publicity_sim.schedule_event("open_day", 1)
	for _publicity_day in range(120):
		publicity_sim.tick(800.0)
		if not publicity_sim.event_history.is_empty():
			break
	check(not publicity_sim.event_history.is_empty() and str((publicity_sim.event_history[0] as Dictionary).get("status", "")) == "success" and publicity_sim.awareness >= 18.0, "event scenario keeps publicity grade requirements reachable")

	var campaign_terrain = TerrainModel.new()
	campaign_terrain.starter_resort()
	var campaign_sim = ResortSimulation.new()
	campaign_sim.setup(campaign_terrain, false, true)
	campaign_sim.cash = 200000.0
	campaign_sim.start_campaign("local_flyers")
	campaign_sim.start_campaign("radio_spot")
	campaign_sim._add_rating_sample(4.2)
	var campaign_before = campaign_sim.snapshot()
	var campaign_restored = ResortSimulation.new()
	var campaign_restored_terrain = TerrainModel.new()
	campaign_restored_terrain.restore(campaign_terrain.snapshot())
	campaign_restored.setup(campaign_restored_terrain, false, true)
	campaign_restored.restore(campaign_before)
	check(campaign_restored.campaigns.size() == 2, "snapshot restore preserves active campaigns")
	check(approx_within(campaign_restored._rating_sum, float(campaign_before.get("rating_sum", 0.0)), 0.01), "snapshot restore preserves rolling rating state")

	var campaign_ledger_sim = ResortSimulation.new()
	campaign_ledger_sim.setup(campaign_terrain, false, true)
	campaign_ledger_sim.cash = 200000.0
	var campaign_opening: float = campaign_ledger_sim.cash
	campaign_ledger_sim.start_campaign("local_flyers")
	campaign_ledger_sim._roll_day()
	var campaign_net: float = 0.0
	for entry in campaign_ledger_sim.ledger:
		campaign_net += float(entry.get("amount", 0.0))
	check(absf(campaign_ledger_sim.cash - (campaign_opening + campaign_net)) < 0.01, "ledger reconciles with campaign charges")

	var patron_terrain = TerrainModel.new()
	patron_terrain.starter_resort()
	var patron_sim = ResortSimulation.new()
	patron_sim.setup(patron_terrain, false, true)
	var patron_id: int = patron_sim._create_patron_from_guest({"name": "Snapshot Patron", "skill": 0.55, "budget": 160.0}, 0.8, 55.0)
	patron_sim.patrons[patron_id]["member"] = true
	patron_sim.patrons[patron_id]["tier"] = "social"
	patron_sim.patrons[patron_id]["joined_day"] = 12
	patron_sim.membership_dues["social"] = 195.0
	var patron_before = patron_sim.snapshot()
	var patron_restored = ResortSimulation.new()
	var patron_restored_terrain = TerrainModel.new()
	patron_restored_terrain.restore(patron_terrain.snapshot())
	patron_restored.setup(patron_restored_terrain, false, true)
	patron_restored.restore(patron_before)
	check(patron_restored.patrons.size() == patron_before.get("patrons", {}).size(), "snapshot restore preserves patrons")
	check(int(patron_restored.patrons[patron_id].get("joined_day", -1)) == 12, "snapshot restore preserves membership dues schedule")
	check(is_equal_approx(float(patron_restored.membership_dues.get("social", 0.0)), 195.0), "snapshot restore preserves editable dues")

	var legacy_patron_sim = ResortSimulation.new()
	legacy_patron_sim.setup(patron_terrain, false, true)
	legacy_patron_sim.restore({"guests": [], "staff": [], "groups": [], "ledger": []})
	check(legacy_patron_sim.patrons.is_empty(), "a save without patrons loads an empty dictionary")

	var dues_sim = ResortSimulation.new()
	dues_sim.setup(patron_terrain, false, true)
	var dues_opening: float = dues_sim.cash
	var dues_patron_id: int = dues_sim._create_patron_from_guest({"name": "Dues Patron", "skill": 0.5, "budget": 300.0}, 0.85, 80.0)
	dues_sim._join_membership(dues_sim.patrons[dues_patron_id], "social", {"patron_id": dues_patron_id, "name": "Dues Patron"})
	dues_sim.patrons[dues_patron_id]["joined_day"] = dues_sim.day
	dues_sim._settle_membership_dues()
	var dues_net: float = 0.0
	for entry in dues_sim.ledger:
		dues_net += float(entry.get("amount", 0.0))
	check(absf(dues_sim.cash - (dues_opening + dues_net)) < 0.01, "ledger reconciliation still balances with membership dues")

	print("test_regressions: ","passed" if failures==0 else "FAILED")
	quit(0 if failures==0 else 1)
