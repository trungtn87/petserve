extends Node


const SAVE_PATH := "user://save_v11.json"
const META_PATH := "user://meta_v1.json"


func save_run(data: Dictionary) -> bool:
	return _write_dictionary(
		SAVE_PATH,
		data,
		"Không thể mở file save để ghi."
	)


func load_run() -> Dictionary:
	return _read_dictionary(
		SAVE_PATH,
		"File save không hợp lệ.",
		"Dữ liệu save không phải Dictionary."
	)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)


func save_meta(data: Dictionary) -> bool:
	return _write_dictionary(
		META_PATH,
		data,
		"Không thể mở file meta để ghi."
	)


func load_meta() -> Dictionary:
	return _read_dictionary(
		META_PATH,
		"File meta không hợp lệ.",
		"Dữ liệu meta không phải Dictionary."
	)


func has_meta_save() -> bool:
	return FileAccess.file_exists(META_PATH)


func delete_meta() -> void:
	# Archive device-wide Tetris records before removing per-life inventory.
	# If archival fails, keep the old metadata so the existing reset flow retries.
	var current := load_meta()
	if current.has("tetris_records"):
		if not AtomicJson.write(TetrisRecords.ARCHIVE_PATH, current["tetris_records"]):
			push_error("Không thể giữ bảng kỷ lục Tetris. Chưa xóa dữ liệu đời cũ.")
			return
	for key in ["tank_records_solo", "tank_records_duo"]:
		if current.has(key) and not AtomicJson.write("user://" + key + ".json", current[key]):
			push_error("Không thể giữ bảng kỷ lục Tank. Chưa xóa dữ liệu đời cũ.")
			return
	if FileAccess.file_exists(META_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(META_PATH)
		)


func _write_dictionary(
	path: String,
	data: Dictionary,
	error_message: String
) -> bool:
	return AtomicJson.write(path, data)


func _read_dictionary(
	path: String,
	parse_error: String,
	type_error: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Không thể mở file dữ liệu để đọc.")
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if parsed == null:
		push_error(parse_error)
		return {}

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(type_error)
		return {}

	return parsed
