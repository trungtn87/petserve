class_name ElementStageVisualCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/visual/element_stage_profiles.json"
)

const REQUIRED_FIELDS := [
	"stage_1_face",
	"stage_2_morphology",
	"stage_3_detail",
	"stage_4_final",
]


func load_default() -> Dictionary:
	return load_from_path(
		DEFAULT_PATH
	)


func load_from_path(
	path: String
) -> Dictionary:
	var result: Dictionary = {}

	if not FileAccess.file_exists(
		path
	):
		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return result

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		return result

	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var profile := value as Dictionary
		var element := String(
			profile.get(
				"element",
				""
			)
		).strip_edges().to_lower()

		if element.is_empty():
			continue

		var valid := true

		for field in REQUIRED_FIELDS:
			if String(
				profile.get(
					field,
					""
				)
			).strip_edges().is_empty():
				valid = false
				break

		if valid:
			result[element] = profile.duplicate(
				true
			)

	return result


func find_by_element(
	profiles: Dictionary,
	element: StringName
) -> Dictionary:
	var key := String(
		element
	).strip_edges().to_lower()

	if not profiles.has(
		key
	):
		return {}

	var value: Variant = profiles.get(
		key,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func prompt_for_stage(
	profile: Dictionary,
	stage: int
) -> String:
	var key := ""

	match stage:
		1:
			key = "stage_1_face"
		2:
			key = "stage_2_morphology"
		3:
			key = "stage_3_detail"
		4:
			key = "stage_4_final"
		_:
			return ""

	return String(
		profile.get(
			key,
			""
		)
	).strip_edges()
