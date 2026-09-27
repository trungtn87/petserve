extends Node


const SAVE_PATH := "user://save_v11.json"


func save_run(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Không thể mở file save để ghi.")
		return false

	file.store_string(JSON.stringify(data))
	file.close()

	return true


func load_run() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("Không thể mở file save để đọc.")
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if parsed == null:
		push_error("File save không hợp lệ.")
		return {}

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dữ liệu save không phải Dictionary.")
		return {}

	return parsed


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)
