extends SceneTree
const ShotEngineClass = preload("res://scripts/shot_engine.gd")
const TerrainModelClass = preload("res://scripts/terrain_model.gd")
func _init() -> void:
	# putts on worn greens
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 500.0)
	var cup: Vector3 = Vector3(360.0, 0.0, 500.0)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 12.0, 2)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 14.0, 1)
	var hole: Dictionary = terrain.add_hole(tee, cup, 3)
	var pristine: int = 0
	for seed_value in range(10):
		pristine += int(ShotEngineClass.round_preview(terrain, hole, 0.35, seed_value + 11).get("strokes", 0))
	print("A pristine_strokes=%d" % (pristine / 10))
	quit()
