class_name SaveStore
extends RefCounted
const VERSION = 2
const DIRECTORY = "user://saves"
static var directory = DIRECTORY

static func clean_name(value: String) -> String:
	var result = ""
	for c in value.strip_edges():
		if c.is_valid_identifier() or c.is_valid_int() or c in [" ","-","_"]: result+=c
	return result.left(48) if not result.is_empty() else "My resort"

static func save_game(name_value: String, terrain: TerrainModel, sim: ResortSimulation, camera_data: Dictionary = {}) -> String:
	DirAccess.make_dir_recursive_absolute(directory)
	var path=directory.path_join(clean_name(name_value)+".hif")
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return "Could not write save: "+error_string(FileAccess.get_open_error())
	file.store_var({"version":VERSION,"saved_at":Time.get_datetime_string_from_system(),"terrain":terrain.snapshot(),"simulation":sim.snapshot(),"camera":camera_data},false)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(path+".bak")
		DirAccess.rename_absolute(path,path+".bak")
	var err=DirAccess.rename_absolute(path+".tmp",path)
	return "Saved “%s”" % clean_name(name_value) if err==OK else "Save failed: "+error_string(err)

static func load_game(name_value: String) -> Dictionary:
	var path=directory.path_join(clean_name(name_value)+".hif")
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var file=FileAccess.open(candidate,FileAccess.READ)
		if file==null:continue
		if file.get_length()<4:file.close();continue
		var encoded_length=file.get_32()
		if encoded_length>file.get_length()-4 or encoded_length<4:file.close();continue
		file.seek(0)
		var value=file.get_var(false)
		file.close()
		if not value is Dictionary:continue
		var save_version: int = int(value.get("version", -1))
		if save_version < 1 or save_version > VERSION:continue
		if not value.has("terrain") or not value.has("simulation"):continue
		var data=value.terrain
		if not data.get("heights",[]).size()==257*257 or not data.get("surfaces",[]).size()==256*256:continue
		return value
	return {}

static func list_saves() -> PackedStringArray:
	var result=PackedStringArray()
	var dir=DirAccess.open(directory)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".hif"):result.append(file.trim_suffix(".hif"))
	result.sort()
	return result
