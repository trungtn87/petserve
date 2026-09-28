class_name PetIdentityFactory
extends RefCounted


const DEFAULT_SPECIES: StringName = &"cat"


func create_initial(
	run_seed: int,
	element: StringName,
	species: StringName = DEFAULT_SPECIES
) -> PetIdentity:
	return create(
		run_seed,
		element,
		species,
		0
	)


func create(
	lineage_seed: int,
	element: StringName,
	species: StringName = DEFAULT_SPECIES,
	generation: int = 0
) -> PetIdentity:
	var normalized_species := _normalize_token(species)
	var normalized_element := _normalize_token(element)

	if (
		lineage_seed <= 0
		or generation < 0
		or normalized_species == &""
		or normalized_element == &""
	):
		return null

	var id := "%s_%s_%d_g%d" % [
		String(normalized_species),
		String(normalized_element),
		lineage_seed,
		generation,
	]

	return PetIdentity.new(
		id,
		normalized_species,
		normalized_element,
		lineage_seed,
		generation
	)


func _normalize_token(
	value: StringName
) -> StringName:
	var text := String(value).strip_edges().to_lower()

	if text.is_empty():
		return &""

	text = text.replace(" ", "_")

	return StringName(text)
