class_name HatchSaveService
extends RefCounted


const SAVE_PATH: String = (
	"user://hatch_v11.json"
)


func save_data(
	data: Dictionary
) -> bool:
	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)


	if file == null:
		push_error(
			"HatchSaveService: Không mở được save."
		)

		return false


	file.store_string(
		JSON.stringify(
			data
		)
	)

	file.close()

	return true


func load_data() -> Dictionary:
	if not has_save():
		return {}


	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)


	if file == null:
		push_error(
			"HatchSaveService: Không đọc được save."
		)

		return {}


	var text: String = file.get_as_text()

	file.close()


	var parsed: Variant = JSON.parse_string(
		text
	)


	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(
			"HatchSaveService: Save không hợp lệ."
		)

		return {}


	return (
		parsed as Dictionary
	)


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
