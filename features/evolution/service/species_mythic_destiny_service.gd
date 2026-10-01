class_name SpeciesMythicDestinyService
extends RefCounted


const SCHEMA_VERSION: int = 1
const SOURCE_EGG_STAGE4: StringName = &"egg_stage4"
const SOURCE_GENE_RECIPE: StringName = &"gene_recipe"
const SEED_MODULUS: int = 2147483647



func from_stage4_egg(
	identity: PetIdentity,
	egg_stage: int
) -> Dictionary:
	if (
		identity == null
		or not identity.is_valid()
		or egg_stage != 4
	):
		return {}

	var candidates: Array[SpeciesMythicMutationDefinition] = []

	for definition in _species_definitions(
		identity
	):
		if definition.egg_stage4_eligible():
			candidates.append(
				definition
			)

	if candidates.is_empty():
		return {}

	var selected := candidates[
		posmod(
			_stable_seed(
				identity,
				"egg_stage4"
			),
			candidates.size()
		)
	]

	return _build_destiny(
		identity,
		selected,
		SOURCE_EGG_STAGE4,
		[]
	)


func from_gene_recipe(
	identity: PetIdentity,
	accumulated_gene_ids: Array
) -> Dictionary:
	if (
		identity == null
		or not identity.is_valid()
	):
		return {}

	var matches: Array[SpeciesMythicMutationDefinition] = []
	var accumulated_loci := _gene_loci_from_ids(
		accumulated_gene_ids
	)

	for definition in _species_definitions(
		identity
	):
		if definition.recipe_matches(
			accumulated_loci
		):
			matches.append(
				definition
			)

	if matches.is_empty():
		return {}

	var selected := matches[
		posmod(
			_stable_seed(
				identity,
				"gene_recipe"
			),
			matches.size()
		)
	]

	var recipe_gene_ids := _matching_gene_ids_for_loci(
		accumulated_gene_ids,
		selected.required_loci()
	)

	return _build_destiny(
		identity,
		selected,
		SOURCE_GENE_RECIPE,
		recipe_gene_ids
	)


func validate_for_identity(
	destiny: Dictionary,
	identity: PetIdentity
) -> bool:
	if (
		destiny.is_empty()
		or identity == null
		or not identity.is_valid()
		or int(
			destiny.get(
				"schema",
				0
			)
		) != SCHEMA_VERSION
		or not bool(
			destiny.get(
				"locked",
				false
			)
		)
		or StringName(
			destiny.get(
				"species",
				""
			)
		) != identity.species()
	):
		return false

	var source := StringName(
		destiny.get(
			"source",
			""
		)
	)

	if source not in [
		SOURCE_EGG_STAGE4,
		SOURCE_GENE_RECIPE,
	]:
		return false

	var mutation_id := StringName(
		destiny.get(
			"mutation_id",
			""
		)
	)
	var definition := _definition_by_id(
		mutation_id
	)

	if (
		definition == null
		or definition.species()
			!= identity.species()
		or String(
			destiny.get(
				"display_name",
				""
			)
		) != definition.display_name()
	):
		return false

	if (
		source == SOURCE_EGG_STAGE4
		and not definition.egg_stage4_eligible()
	):
		return false

	if source == SOURCE_GENE_RECIPE:
		var recipe_value: Variant = destiny.get(
			"recipe_gene_ids",
			[]
		)

		if typeof(recipe_value) != TYPE_ARRAY:
			return false

		if not definition.recipe_matches(
			_gene_loci_from_ids(
				recipe_value as Array
			)
		):
			return false

	return true


func definition_for(
	destiny: Dictionary,
	identity: PetIdentity
) -> SpeciesMythicMutationDefinition:
	if not validate_for_identity(
		destiny,
		identity
	):
		return null

	return _definition_by_id(
		StringName(
			destiny.get(
				"mutation_id",
				""
			)
		)
	)


func display_name_for(
	destiny: Dictionary,
	identity: PetIdentity
) -> String:
	var definition := definition_for(
		destiny,
		identity
	)

	return (
		definition.display_name()
		if definition != null
		else ""
	)


func _build_destiny(
	identity: PetIdentity,
	definition: SpeciesMythicMutationDefinition,
	source: StringName,
	recipe_gene_ids: Array
) -> Dictionary:
	if (
		definition == null
		or definition.species()
			!= identity.species()
	):
		return {}

	# Keep persisted destiny JSON-native so the first in-memory plan and
	# the reloaded retry plan compare identically after AtomicJson round-trip.
	var serialized_recipe: Array = []

	for value in recipe_gene_ids:
		serialized_recipe.append(
			String(
				value
			)
		)

	return {
		"schema": SCHEMA_VERSION,
		"locked": true,
		"source": String(
			source
		),
		"species": String(
			identity.species()
		),
		"mutation_id": String(
			definition.id()
		),
		"display_name": (
			definition.display_name()
		),
		"recipe_gene_ids": (
			serialized_recipe
		),
		"recipe_loci": (
			_string_array(
				_gene_loci_from_ids(
					serialized_recipe
				)
			)
		),
	}



func _matching_gene_ids_for_loci(
	gene_ids: Array,
	required_loci: Array[StringName]
) -> Array[String]:
	var result: Array[String] = []
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()

	for value in gene_ids:
		var definition := catalog.find_by_id(
			definitions,
			StringName(
				str(value)
			)
		)

		if (
			definition == null
			or not required_loci.has(
				definition.locus()
			)
		):
			continue

		var gene_id := String(
			definition.id()
		)

		if not result.has(
			gene_id
		):
			result.append(
				gene_id
			)

	result.sort()
	return result


func _gene_loci_from_ids(
	gene_ids: Array
) -> Array[StringName]:
	var result: Array[StringName] = []
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()

	for value in gene_ids:
		var definition := catalog.find_by_id(
			definitions,
			StringName(
				str(value)
			)
		)

		if (
			definition == null
			or result.has(
				definition.locus()
			)
		):
			continue

		result.append(
			definition.locus()
		)

	result.sort()
	return result


func _string_array(
	values: Array
) -> Array[String]:
	var result: Array[String] = []

	for value in values:
		result.append(
			String(value)
		)

	result.sort()
	return result


func _species_definitions(
	identity: PetIdentity
) -> Array[SpeciesMythicMutationDefinition]:
	var catalog := SpeciesMythicMutationCatalog.new()

	return catalog.for_species(
		catalog.load_default(),
		identity.species()
	)


func _definition_by_id(
	mutation_id: StringName
) -> SpeciesMythicMutationDefinition:
	var catalog := SpeciesMythicMutationCatalog.new()

	return catalog.find_by_id(
		catalog.load_default(),
		mutation_id
	)


func _stable_seed(
	identity: PetIdentity,
	channel: String
) -> int:
	var value := posmod(
		identity.lineage_seed(),
		SEED_MODULUS
	)

	value = _mix(
		value,
		identity.generation() + 1
	)
	value = _mix(
		value,
		_stable_string_hash(
			String(
				identity.species()
			)
		)
	)
	value = _mix(
		value,
		_stable_string_hash(
			channel
		)
	)

	return max(
		1,
		value
	)


func _mix(
	current: int,
	input_value: int
) -> int:
	return posmod(
		current * 1103515245
		+ input_value * 12345
		+ 1013904223,
		SEED_MODULUS
	)


func _stable_string_hash(
	value: String
) -> int:
	var result: int = 7

	for index in range(
		value.length()
	):
		result = posmod(
			result * 31
			+ value.unicode_at(
				index
			),
			SEED_MODULUS
		)

	return result
