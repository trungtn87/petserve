class_name SpeciesNormalMutationResolver
extends RefCounted


const MODE_NONE: StringName = &"none"
const MODE_MUTATE: StringName = &"mutate"
const BASIS_POINTS: int = 10000
const SEED_MODULUS: int = 2147483647

const STAGE_CHANCE_BASIS_POINTS: Dictionary = {
	2: 3500,
	3: 4500,
	4: 5500,
	5: 4500,
}


var _applier := GenomeDeltaApplier.new()


func resolve(
	identity: PetIdentity,
	genome: PetGenome,
	target_stage: int = -1,
	definitions: Array = []
) -> Dictionary:
	if (
		identity == null
		or genome == null
		or not identity.is_valid()
		or not genome.is_valid()
	):
		return _error("Identity/Genome không hợp lệ.")

	var next_stage := (
		genome.stage() + 1
		if target_stage < 0
		else target_stage
	)

	if (
		next_stage != genome.stage() + 1
		or next_stage > 5
	):
		return _error("Normal Mutation chỉ resolve cho stage kế tiếp.")

	var loaded: Array[MutationDefinition] = []
	if definitions.is_empty():
		loaded = MutationCatalog.new().load_default()
	else:
		for value in definitions:
			var definition := value as MutationDefinition
			if definition == null or not definition.is_valid():
				return _error("Normal Mutation definition không hợp lệ.")
			loaded.append(definition)

	var stage_genome := PetGenome.new(
		next_stage,
		genome.body_growth(),
		genome.traits_snapshot(),
		genome.mutation_ids()
	)

	if not stage_genome.is_valid():
		return _error("Không tạo được stage compatibility Genome.")

	var candidates: Array[MutationDefinition] = []
	for definition in loaded:
		if definition.is_compatible(identity, stage_genome):
			candidates.append(definition)

	candidates.sort_custom(_sort_by_id)
	var candidate_ids := _ids(candidates)

	if candidates.is_empty():
		return _none(genome, next_stage, candidate_ids, 0, -1)

	var probability := int(
		STAGE_CHANCE_BASIS_POINTS.get(
			next_stage,
			0
		)
	)
	var activation_roll := _roll(
		identity,
		next_stage,
		"normal_activation"
	)

	if activation_roll >= probability:
		return _none(
			genome,
			next_stage,
			candidate_ids,
			probability,
			activation_roll
		)

	var total_weight := 0
	for candidate in candidates:
		total_weight += candidate.weight()

	if total_weight <= 0:
		return _none(
			genome,
			next_stage,
			candidate_ids,
			probability,
			activation_roll
		)

	var selection_roll := posmod(
		_stable_seed(
			identity,
			next_stage,
			"normal_selection"
		),
		total_weight
	)
	var cursor := 0
	var selected: MutationDefinition = null

	for candidate in candidates:
		cursor += candidate.weight()
		if selection_roll < cursor:
			selected = candidate
			break

	if selected == null:
		selected = candidates.back()

	var current_trait := genome.get_trait(
		selected.target_trait(),
		PetGenomeSchema.BASE_TRAIT
	)
	var delta := EvolutionDelta.new(
		selected.id(),
		selected.target_trait(),
		current_trait,
		selected.result_trait(),
		genome.mutation_ids().size() + 1
	)

	if not delta.is_valid():
		return _error("Không tạo được Normal Mutation delta.")

	var changed := _applier.apply(
		genome,
		delta
	)

	if changed == null:
		return _error("Không áp dụng được Normal Mutation delta.")

	return {
		"ok": true,
		"mode": String(MODE_MUTATE),
		"target_stage": next_stage,
		"mutation_id": String(selected.id()),
		"probability_basis_points": probability,
		"roll_basis_points": activation_roll,
		"candidate_ids": candidate_ids,
		"delta": delta,
		"genome": changed,
	}


func _none(
	genome: PetGenome,
	target_stage: int,
	candidate_ids: Array[String],
	probability: int,
	roll: int
) -> Dictionary:
	return {
		"ok": true,
		"mode": String(MODE_NONE),
		"target_stage": target_stage,
		"mutation_id": "",
		"probability_basis_points": probability,
		"roll_basis_points": roll,
		"candidate_ids": candidate_ids.duplicate(),
		"delta": null,
		"genome": genome,
	}


func _ids(
	definitions: Array[MutationDefinition]
) -> Array[String]:
	var result: Array[String] = []
	for definition in definitions:
		result.append(String(definition.id()))
	result.sort()
	return result


func _sort_by_id(
	a: MutationDefinition,
	b: MutationDefinition
) -> bool:
	return String(a.id()) < String(b.id())


func _roll(
	identity: PetIdentity,
	target_stage: int,
	channel: String
) -> int:
	return posmod(
		_stable_seed(
			identity,
			target_stage,
			channel
		),
		BASIS_POINTS
	)


func _stable_seed(
	identity: PetIdentity,
	target_stage: int,
	channel: String
) -> int:
	var value := posmod(
		identity.lineage_seed(),
		SEED_MODULUS
	)
	value = _mix(value, identity.generation() + 1)
	value = _mix(value, target_stage)
	value = _mix(value, _stable_string_hash(String(identity.species())))
	value = _mix(value, _stable_string_hash(channel))
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
	value: String
) -> int:
	var result: int = 7
	for index in range(value.length()):
		result = posmod(
			result * 31 + value.unicode_at(index),
			SEED_MODULUS
		)
	return result


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
