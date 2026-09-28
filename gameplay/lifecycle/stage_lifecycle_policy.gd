class_name StageLifecyclePolicy
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/gameplay/lifecycle/stages.json"
)


var _stages: Dictionary = {}


func stage(
	stage_index: int
) -> Dictionary:
	var value: Variant = _stages.get(
		stage_index,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func can_grow(
	stage_index: int
) -> bool:
	return not stage(
		stage_index
	).is_empty()


func max_growth_stage() -> int:
	var maximum := 0

	for key_value in _stages.keys():
		maximum = maxi(
			maximum,
			int(key_value)
		)

	return maximum


static func load_default() -> StageLifecyclePolicy:
	return load_from_path(
		DEFAULT_PATH
	)


static func load_from_path(
	path: String
) -> StageLifecyclePolicy:
	if not FileAccess.file_exists(
		path
	):
		push_error(
			"StageLifecyclePolicy: không tìm thấy "
			+ path
		)
		return null

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return null

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		return null

	var policy := StageLifecyclePolicy.new()

	for raw_value in parsed as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return null

		var raw := raw_value as Dictionary
		var stage_index := int(
			raw.get(
				"stage",
				0
			)
		)
		var duration := int(
			raw.get(
				"duration_seconds",
				0
			)
		)
		var starting_food := int(
			raw.get(
				"starting_food_seconds",
				0
			)
		)
		var starved_multiplier := float(
			raw.get(
				"starved_growth_multiplier",
				0.0
			)
		)

		if (
			stage_index < 1
			or duration <= 0
			or starting_food < 0
			or starved_multiplier < 0.0
			or starved_multiplier > 1.0
			or policy._stages.has(
				stage_index
			)
		):
			return null

		policy._stages[stage_index] = {
			"stage": stage_index,
			"duration_seconds": duration,
			"starting_food_seconds": starting_food,
			"starved_growth_multiplier": starved_multiplier,
			"tutorial_protected": bool(
				raw.get(
					"tutorial_protected",
					true
				)
			),
		}

	if policy._stages.is_empty():
		return null

	return policy
