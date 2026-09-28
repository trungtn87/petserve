class_name MutationCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/mutations/base_mutations.json"
)


func load_default() -> Array[MutationDefinition]:
	return load_from_path(DEFAULT_PATH)


func load_from_path(
	path: String
) -> Array[MutationDefinition]:
	var result: Array[MutationDefinition] = []

	if not FileAccess.file_exists(path):
		push_error(
			"MutationCatalog: Không tìm thấy file: "
			+ path
		)
		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"MutationCatalog: Không mở được file: "
			+ path
		)
		return result

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(
		raw_text
	)

	if typeof(parsed) != TYPE_ARRAY:
		push_error(
			"MutationCatalog: Root JSON phải là Array."
		)
		return result

	var seen: Dictionary = {}

	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var definition := MutationDefinition.from_dict(
			value as Dictionary
		)

		if definition == null:
			continue

		if seen.has(definition.id()):
			push_error(
				"MutationCatalog: Trùng mutation id: "
				+ String(definition.id())
			)
			return []

		seen[definition.id()] = true
		result.append(definition)

	result.sort_custom(
		_sort_by_id
	)

	return result


func find_by_id(
	definitions: Array[MutationDefinition],
	mutation_id: StringName
) -> MutationDefinition:
	for definition in definitions:
		if definition.id() == mutation_id:
			return definition

	return null


func _sort_by_id(
	a: MutationDefinition,
	b: MutationDefinition
) -> bool:
	return String(a.id()) < String(b.id())
