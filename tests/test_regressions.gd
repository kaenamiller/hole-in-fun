extends SceneTree
var failures=0

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
	print("test_regressions: ","passed" if failures==0 else "FAILED")
	quit(0 if failures==0 else 1)
