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
