extends SceneTree
const MapGeneratorClass = preload("res://scripts/map_generator.gd")
const TerrainModel = preload("res://scripts/terrain_model.gd")
func _init() -> void:
	var map_def: Dictionary = {}
	for m in preload("res://scripts/catalog.gd").maps():
		if str(m.get("id", "")) == "stonebrook_hills":
			map_def = m
	var terrain: TerrainModel = MapGeneratorClass.generate(map_def)
	print("crossings=%d reach=%.2f" % [MapGeneratorClass.river_crossing_count(terrain), MapGeneratorClass.reachability_ratio(terrain)])
	quit()
