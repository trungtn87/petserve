class_name IncubationRules
extends RefCounted


const TASK_PATH_TEMPLATE: String = (
	"res://data/tasks/egg_stage_%d.json"
)


var _cache: Dictionary = {}


func get_options(
	stage: int,
	egg_type: String = ""
) -> Array:
	var data: Variant = _load_stage_data(
		stage
	)

	if data == null:
		return []

	# Dạng:
	# [
	#   task,
	#   task
	# ]
	if typeof(data) == TYPE_ARRAY:
		return (
			data as Array
		).duplicate(true)

	# Dạng:
	# {
	#   "fire": [...],
	#   "water": [...]
	# }
	if typeof(data) == TYPE_DICTIONARY:
		var dictionary: Dictionary = (
			data as Dictionary
		)

		var value: Variant = dictionary.get(
			egg_type,
			dictionary.get(
				"all",
				[]
			)
		)

		if typeof(value) == TYPE_ARRAY:
			return (
				value as Array
			).duplicate(true)

	return []


func has_rules(
	stage: int,
	egg_type: String = ""
) -> bool:
	return not get_options(
		stage,
		egg_type
	).is_empty()


func clear_cache() -> void:
	_cache.clear()


func _load_stage_data(
	stage: int
) -> Variant:
	var key: String = str(stage)

	if _cache.has(key):
		return _cache[key]

	var path: String = (
		TASK_PATH_TEMPLATE
		% stage
	)

	if not FileAccess.file_exists(path):
		_cache[key] = null
		return null

	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"IncubationRules: Không mở được "
			+ path
		)

		_cache[key] = null
		return null

	var text: String = file.get_as_text()

	file.close()

	var parsed: Variant = JSON.parse_string(
		text
	)

	if parsed == null:
		push_error(
			"IncubationRules: JSON lỗi tại "
			+ path
		)

		_cache[key] = null
		return null

	_cache[key] = parsed

	return parsed
