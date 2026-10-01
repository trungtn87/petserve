class_name EvolutionRuleEngine
extends RefCounted


const SEED_MODULUS: int = 2147483647


func choose_next(
	identity: PetIdentity,
	genome: PetGenome,
	definitions: Array[MutationDefinition]
) -> EvolutionDelta:
	if (
		identity == null
		or genome == null
		or not identity.is_valid()
		or not genome.is_valid()
	):
		return null

	var candidates: Array[MutationDefinition] = []

	for definition in definitions:
		if (
			definition != null
			and definition.is_compatible(
				identity,
				genome
			)
		):
			candidates.append(definition)

	if candidates.is_empty():
		return null

	candidates.sort_custom(
		_sort_by_id
	)

	var selected := _weighted_pick(
		identity,
		genome,
		candidates
	)

	if selected == null:
		return null

	return EvolutionDelta.new(
		selected.id(),
		selected.target_trait(),
		selected.required_trait(),
		selected.result_trait(),
		genome.mutation_ids().size() + 1
	)


func _weighted_pick(
	identity: PetIdentity,
	genome: PetGenome,
	candidates: Array[MutationDefinition]
) -> MutationDefinition:
	var total_weight: int = 0

	for candidate in candidates:
		total_weight += candidate.weight()

	if total_weight <= 0:
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = _selection_seed(
		identity,
		genome
	)

	var roll := rng.randi_range(
		1,
		total_weight
	)

	var cursor: int = 0

	for candidate in candidates:
		cursor += candidate.weight()

		if roll <= cursor:
			return candidate

	return candidates.back()


func _selection_seed(
	identity: PetIdentity,
	genome: PetGenome
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
		genome.stage()
	)

	value = _mix(
		value,
		genome.mutation_ids().size() + 1
	)

	for mutation_id in genome.mutation_ids():
		value = _mix(
			value,
			_stable_string_hash(
				String(mutation_id)
			)
		)

	return max(1, value)


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
	text: String
) -> int:
	var value: int = 7

	for index in range(text.length()):
		value = posmod(
			value * 31
			+ text.unicode_at(index),
			SEED_MODULUS
		)

	return value


func _sort_by_id(
	a: MutationDefinition,
	b: MutationDefinition
) -> bool:
	return String(a.id()) < String(b.id())
