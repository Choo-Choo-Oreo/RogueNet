class_name JsonOnloading

static func load_dict(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	push_error("JsonOnloading: couldn't load " + path)
	return {}

static func write_dict(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("JsonOnloading: couldn't open " + path + " for writing")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

## Finds every .json in `dir_path` and every folder under it, adding `id -> res:// path` to
## `into` (the id is the file name without ".json"). An id that already exists is kept and a
## warning names the duplicate. `kind` only words that warning. Non-json files are ignored.
static func find_by_id(dir_path: String, into: Dictionary, kind: String) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".json"):
			continue
		var id := file_name.get_basename()
		if into.has(id):
			push_warning("%s id '%s' exists twice (%s and %s), using the first" % [kind, id, into[id], dir_path + file_name])
			continue
		into[id] = dir_path + file_name
	for sub_dir in DirAccess.get_directories_at(dir_path):
		find_by_id(dir_path + sub_dir + "/", into, kind)
