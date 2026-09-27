class_name SaveService
extends RefCounted


const SAVE_PATH: String = (
	"user://save_v11.json"
)


func save_game(
	data: Dictionary
) -> bool:
	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"SaveService: Không thể mở file để ghi."
		)

		return false

	var json_text: String = JSON.stringify(
		data
	)

	file.store_string(
		json_text
	)

	file.close()

	return true


func load_game() -> Dictionary:
	if not has_save():
		return {}

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"SaveService: Không thể mở file để đọc."
		)

		return {}

	var text: String = file.get_as_text()

	file.close()

	var parsed: Variant = JSON.parse_string(
		text
	)

	if parsed == null:
		push_error(
			"SaveService: JSON save không hợp lệ."
		)

		return {}

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(
			"SaveService: Save root không phải Dictionary."
		)

		return {}

	return parsed as Dictionary


func has_save() -> bool:
	return FileAccess.file_exists(
		SAVE_PATH
	)


func delete_save() -> bool:
	if not has_save():
		return true

	var absolute_path: String = (
		ProjectSettings.globalize_path(
			SAVE_PATH
		)
	)

	var result: Error = (
		DirAccess.remove_absolute(
			absolute_path
		)
	)

	return result == OK
