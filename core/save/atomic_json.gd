class_name AtomicJson
extends RefCounted

static var blocked := false

static func write(path: String, data: Dictionary) -> bool:
	if blocked:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	# Copy only a valid previous generation; never replace good fallback with damaged data.
	if FileAccess.file_exists(path) and _parse(FileAccess.get_file_as_string(path)) is Dictionary:
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak.tmp")) != OK:
			return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"), ProjectSettings.globalize_path(path + ".bak")) != OK:
			return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func read(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var parsed: Variant = _parse(FileAccess.get_file_as_string(candidate))
			if parsed is Dictionary:
				return parsed
	return {}

static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

static func erase(path: String) -> bool:
	if blocked:
		return false
	var ok := true
	for candidate in [path, path + ".bak", path + ".tmp", path + ".bak.tmp"]:
		if FileAccess.file_exists(candidate):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate)) == OK and ok
	return ok

static func _parse(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null
