class_name GeneCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/gene/base_genes.json"
)


func load_default() -> Array[GeneDefinition]:
	return load_from_path(
		DEFAULT_PATH
	)


func load_from_path(
	path: String
) -> Array[GeneDefinition]:
	var result: Array[GeneDefinition] = []

	if not FileAccess.file_exists(
		path
	):
		push_error(
			"GeneCatalog: không tìm thấy "
			+ path
		)
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

	var seen: Dictionary = {}

	for raw_value in parsed as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue

		var definition := (
			GeneDefinition.from_dict(
				raw_value as Dictionary
			)
		)

		if definition == null:
			continue

		if seen.has(
			definition.id()
		):
			push_error(
				"GeneCatalog: trùng gene id "
				+ String(
					definition.id()
				)
			)
			return []

		seen[definition.id()] = true
		result.append(
			definition
		)

	result.sort_custom(
		_sort_by_id
	)

	return result


func find_by_id(
	definitions: Array[GeneDefinition],
	gene_id: StringName
) -> GeneDefinition:
	var normalized := StringName(
		String(gene_id)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)

	for definition in definitions:
		if (
			definition != null
			and definition.id()
				== normalized
		):
			return definition

	return null


func _sort_by_id(
	a: GeneDefinition,
	b: GeneDefinition
) -> bool:
	return String(a.id()) < String(b.id())
