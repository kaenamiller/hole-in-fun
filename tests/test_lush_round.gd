extends SceneTree
func _init() -> void:
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var sim := ResortSimulation.new()
	sim.setup(terrain,false,true,Catalog.map("cedar_house"))
	var group_id: int = sim.admit_group(1)
	# Isolate one real round; closing admissions does not interrupt existing visits.
	sim.open=false
	for minute in range(120):
		sim.tick(60)
		if sim._today_completed_rounds>0: break
	print("test_lush_round: group=%d completed=%d refunds=%d" % [group_id,sim._today_completed_rounds,sim._today_refunds])
	quit(0 if group_id>0 and sim._today_completed_rounds>0 else 1)
