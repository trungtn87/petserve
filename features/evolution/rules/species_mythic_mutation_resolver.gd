class_name SpeciesMythicMutationResolver
extends RefCounted


const MODE_NONE: StringName = &"none"
const MODE_AWAKEN: StringName = &"awaken"
const MODE_CONTINUE: StringName = &"continue"
const BASIS_POINTS: int = 10000
const SEED_MODULUS: int = 2147483647


var _factory: PetGenomeFactory = PetGenomeFactory.new()


func resolve(
	identity: PetIdentity,
	genome: PetGenome,
	gene_state: GeneDevelopmentState = null,
	target_stage: int = -1,
	definitions: Array = []
) -> Dictionary:
	if (
		identity == null
		or genome == null
		or not identity.is_valid()
		or not genome.is_valid()
	):
		return _error(
			"Identity/Genome không hợp lệ."
		)

	var next_stage := (
		genome.stage() + 1
		if target_stage < 0
		else target_stage
	)

	if (
		next_stage != genome.stage() + 1
		or next_stage
			> SpeciesMythicMutationDefinition.FINAL_STAGE
	):
		return _error(
			"Mythic Mutation chỉ resolve cho stage kế tiếp."
		)

	if (
		gene_state != null
		and (
			not gene_state.is_valid()
			or gene_state.stage_index()
				!= genome.stage()
		)
	):
		return _error(
			"GeneDevelopmentState không khớp stage hiện tại."
		)

	var catalog := SpeciesMythicMutationCatalog.new()
	var loaded: Array[SpeciesMythicMutationDefinition] = []

	if definitions.is_empty():
		loaded = catalog.load_default()
	else:
		for value in definitions:
			var definition := (
				value
				as SpeciesMythicMutationDefinition
			)

			if (
				definition == null
				or not definition.is_valid()
			):
				return _error(
					"Mythic Mutation definition test/runtime không hợp lệ."
				)

			loaded.append(
				definition
			)

	var species_definitions := catalog.for_species(
		loaded,
		identity.species()
	)

	if species_definitions.is_empty():
		return _none(
			genome,
			next_stage,
			false,
			[],
			0,
			-1
		)

	var existing := _existing_mythic_definitions(
		genome,
		loaded
	)

	if existing.size() > 1:
		return _error(
			"Một pet không được mang đồng thời nhiều Mythic Mutation branch."
		)

	if existing.size() == 1:
		var active := existing[0]

		if active.species() != identity.species():
			return _error(
				"Mythic Mutation hiện tại không thuộc species của pet."
			)

		if not active.supports_stage(
			next_stage
		):
			return _error(
				"Mythic Mutation hiện tại không hỗ trợ stage kế tiếp."
			)

		return {
			"ok": true,
			"mode": String(
				MODE_CONTINUE
			),
			"configured": true,
			"target_stage": next_stage,
			"mutation_id": String(
				active.id()
			),
			"display_name": (
				active.display_name()
			),
			"target_regions": (
				_string_regions(
					active.target_regions()
				)
			),
			"prompt": active.prompt_for_stage(
				next_stage
			),
			"preserve_hint": (
				active.preserve_hint()
			),
			"probability_basis_points": 0,
			"roll_basis_points": -1,
			"candidate_ids": [
				String(
					active.id()
				),
			],
			"genome": genome,
		}

	var tag_influences: Dictionary = {}

	if gene_state != null:
		tag_influences = (
			gene_state.tag_influences_snapshot()
		)

	var candidates: Array[Dictionary] = []
	var candidate_ids: Array[String] = []
	var total_weight := 0

	for definition in species_definitions:
		if (
			not definition.supports_stage(
				next_stage
			)
			or not definition.required_traits_match(
				genome
			)
		):
			continue

		var weight := (
			definition.effective_basis_points(
				tag_influences
			)
		)

		candidate_ids.append(
			String(
				definition.id()
			)
		)

		if weight <= 0:
			continue

		candidates.append({
			"definition": definition,
			"weight": weight,
		})
		total_weight += weight

	candidate_ids.sort()

	if candidates.is_empty():
		return _none(
			genome,
			next_stage,
			not candidate_ids.is_empty(),
			candidate_ids,
			0,
			-1
		)

	var activation_probability := mini(
		BASIS_POINTS,
		total_weight
	)
	var activation_roll := _roll_basis_points(
		identity,
		next_stage,
		"activation"
	)

	if activation_roll >= activation_probability:
		return _none(
			genome,
			next_stage,
			true,
			candidate_ids,
			activation_probability,
			activation_roll
		)

	var selection_roll := posmod(
		_stable_seed(
			identity,
			next_stage,
			"selection"
		),
		total_weight
	)
	var cursor := 0
	var selected: SpeciesMythicMutationDefinition = null

	for candidate in candidates:
		cursor += int(
			candidate.get(
				"weight",
				0
			)
		)

		if selection_roll < cursor:
			selected = candidate.get(
				"definition"
			) as SpeciesMythicMutationDefinition
			break

	if selected == null:
		selected = candidates.back().get(
			"definition"
		) as SpeciesMythicMutationDefinition

	if selected == null:
		return _error(
			"Không chọn được Mythic Mutation candidate."
		)

	var mutations: Array = []

	for mutation_id in genome.mutation_ids():
		mutations.append(
			mutation_id
		)

	mutations.append(
		selected.id()
	)

	var changed := _factory.create_snapshot(
		genome.stage(),
		genome.body_growth(),
		genome.traits_snapshot(),
		mutations
	)

	if changed == null:
		return _error(
			"Không tạo được Genome sau Mythic Mutation."
		)

	return {
		"ok": true,
		"mode": String(
			MODE_AWAKEN
		),
		"configured": true,
		"target_stage": next_stage,
		"mutation_id": String(
			selected.id()
		),
		"display_name": (
			selected.display_name()
		),
		"target_regions": (
			_string_regions(
				selected.target_regions()
			)
		),
		"prompt": selected.prompt_for_stage(
			next_stage
		),
		"preserve_hint": (
			selected.preserve_hint()
		),
		"probability_basis_points": (
			activation_probability
		),
		"roll_basis_points": (
			activation_roll
		),
		"candidate_ids": candidate_ids,
		"genome": changed,
	}


func _existing_mythic_definitions(
	genome: PetGenome,
	definitions: Array[SpeciesMythicMutationDefinition]
) -> Array[SpeciesMythicMutationDefinition]:
	var result: Array[SpeciesMythicMutationDefinition] = []
	var catalog := SpeciesMythicMutationCatalog.new()

	for mutation_id in genome.mutation_ids():
		var definition := catalog.find_by_id(
			definitions,
			mutation_id
		)

		if (
			definition != null
			and not result.has(
				definition
			)
		):
			result.append(
				definition
			)

	return result


func _none(
	genome: PetGenome,
	target_stage: int,
	configured: bool,
	candidate_ids: Array[String],
	probability_basis_points: int,
	roll_basis_points: int
) -> Dictionary:
	return {
		"ok": true,
		"mode": String(
			MODE_NONE
		),
		"configured": configured,
		"target_stage": target_stage,
		"mutation_id": "",
		"display_name": "",
		"target_regions": [],
		"prompt": "",
		"preserve_hint": "",
		"probability_basis_points": (
			probability_basis_points
		),
		"roll_basis_points": (
			roll_basis_points
		),
		"candidate_ids": (
			candidate_ids.duplicate()
		),
		"genome": genome,
	}


func _roll_basis_points(
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

	value = _mix(
		value,
		identity.generation() + 1
	)
	value = _mix(
		value,
		target_stage
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


func _string_regions(
	regions: Array[StringName]
) -> Array[String]:
	var result: Array[String] = []

	for region in regions:
		result.append(
			String(region)
		)

	return result


func _error(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
