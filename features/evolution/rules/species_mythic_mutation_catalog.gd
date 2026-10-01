class_name SpeciesMythicMutationCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/mutation/species_mythic_mutations.json"
)
const MAX_MUTATIONS_PER_SPECIES: int = 2


func load_default() -> Array[SpeciesMythicMutationDefinition]:
	return load_from_path(
		DEFAULT_PATH
	)


func load_from_path(
	path: String
) -> Array[SpeciesMythicMutationDefinition]:
	var result: Array[SpeciesMythicMutationDefinition] = []

	if not FileAccess.file_exists(
		path
	):
		push_error(
			"SpeciesMythicMutationCatalog: Không tìm thấy file: "
			+ path
		)
		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"SpeciesMythicMutationCatalog: Không mở được file: "
			+ path
		)
		return result

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		push_error(
			"SpeciesMythicMutationCatalog: Root JSON phải là Array."
		)
		return result

	var seen_ids: Dictionary = {}
	var species_counts: Dictionary = {}

	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var definition := (
			SpeciesMythicMutationDefinition.from_dict(
				value as Dictionary
			)
		)

		if definition == null:
			continue

		if seen_ids.has(
			definition.id()
		):
			push_error(
				"SpeciesMythicMutationCatalog: Trùng id: "
				+ String(
					definition.id()
				)
			)
			return []

		var species_key := String(
			definition.species()
		)
		var count := int(
			species_counts.get(
				species_key,
				0
			)
		) + 1

		if count > MAX_MUTATIONS_PER_SPECIES:
			push_error(
				"SpeciesMythicMutationCatalog: Species %s vượt giới hạn %d mutation."
				% [
					species_key,
					MAX_MUTATIONS_PER_SPECIES,
				]
			)
			return []

		seen_ids[
			definition.id()
		] = true
		species_counts[
			species_key
		] = count
		result.append(
			definition
		)

	result.sort_custom(
		_sort_definition
	)
	return result


func for_species(
	definitions: Array[SpeciesMythicMutationDefinition],
	species: StringName
) -> Array[SpeciesMythicMutationDefinition]:
	var normalized := StringName(
		String(species)
			.strip_edges()
			.to_lower()
			.replace(
				" ",
				"_"
			)
	)
	var result: Array[SpeciesMythicMutationDefinition] = []

	for definition in definitions:
		if (
			definition != null
			and definition.species()
				== normalized
		):
			result.append(
				definition
			)

	return result


func find_by_id(
	definitions: Array[SpeciesMythicMutationDefinition],
	mutation_id: StringName
) -> SpeciesMythicMutationDefinition:
	for definition in definitions:
		if (
			definition != null
			and definition.id()
				== mutation_id
		):
			return definition

	return null


func _sort_definition(
	a: SpeciesMythicMutationDefinition,
	b: SpeciesMythicMutationDefinition
) -> bool:
	var a_key := (
		String(
			a.species()
		)
		+ "|"
		+ String(
			a.id()
		)
	)
	var b_key := (
		String(
			b.species()
		)
		+ "|"
		+ String(
			b.id()
		)
	)

	return a_key < b_key
