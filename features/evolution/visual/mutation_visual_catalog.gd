class_name MutationVisualCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/visual/mutation_visuals.json"
)


func load_default() -> Array[MutationVisualDefinition]:
	return load_from_path(DEFAULT_PATH)


func load_from_path(
	path: String
) -> Array[MutationVisualDefinition]:
	var result: Array[MutationVisualDefinition] = []

	if not FileAccess.file_exists(path):
		push_error(
			"MutationVisualCatalog: Không tìm thấy file: "
			+ path
		)
		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"MutationVisualCatalog: Không mở được file: "
			+ path
		)
		return result

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		push_error(
			"MutationVisualCatalog: Root JSON phải là Array."
		)
		return result

	var seen: Dictionary = {}

	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var definition := (
			MutationVisualDefinition.from_dict(
				value as Dictionary
			)
		)

		if definition == null:
			continue

		if seen.has(
			definition.mutation_id()
		):
			push_error(
				"MutationVisualCatalog: Trùng mutation_id: "
				+ String(
					definition.mutation_id()
				)
			)
			return []

		seen[definition.mutation_id()] = true
		result.append(definition)

	result.sort_custom(
		_sort_by_id
	)

	return result


func find_by_id(
	definitions: Array[MutationVisualDefinition],
	mutation_id: StringName
) -> MutationVisualDefinition:
	for definition in definitions:
		if (
			definition.mutation_id()
			== mutation_id
		):
			return definition

	return null


func _sort_by_id(
	a: MutationVisualDefinition,
	b: MutationVisualDefinition
) -> bool:
	return (
		String(a.mutation_id())
		< String(b.mutation_id())
	)
