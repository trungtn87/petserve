class_name StageEvolutionResolver
extends RefCounted


const MODE_NATURAL: StringName = &"natural"
const MODE_GENE: StringName = &"gene"
const FINAL_STAGE: int = 4
const SEED_MODULUS: int = 2147483647


var _factory: PetGenomeFactory = PetGenomeFactory.new()
var _applier: GenomeDeltaApplier = GenomeDeltaApplier.new()


func resolve(
	identity: PetIdentity,
	genome: PetGenome,
	gene_state: GeneDevelopmentState = null
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

	if genome.stage() >= FINAL_STAGE:
		return _error(
			"Final Form không còn Evolution Resolver."
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
			"GeneDevelopmentState không khớp Stage hiện tại."
		)

	if (
		gene_state == null
		or gene_state.is_empty()
	):
		return _natural_resolution(
			genome
		)

	var policy := StageGenePolicy.load_default()

	if (
		policy == null
		or not gene_state.is_valid(
			policy
		)
	):
		return _error(
			"GeneDevelopmentState không hợp lệ theo StageGenePolicy."
		)

	if genome.stage() != 1:
		return {
			"ok": false,
			"mode": String(
				MODE_GENE
			),
			"error": (
				"Gene Expression policy của Stage này chưa được khóa."
			),
			"requires_stage_expression_policy": true,
		}

	var candidates := _valid_candidates(
		gene_state
	)

	if candidates.is_empty():
		return _error(
			"Không có Gene Expression candidate hợp lệ."
		)

	var selected := _weighted_pick(
		identity,
		genome,
		candidates
	)

	if selected.is_empty():
		return _error(
			"Không chọn được Gene Expression."
		)

	var locus := _normalize_token(
		StringName(
			selected.get(
				"locus",
				""
			)
		)
	)
	var direction := _normalize_token(
		StringName(
			selected.get(
				"direction",
				""
			)
		)
	)
	var gene_id := _normalize_token(
		StringName(
			selected.get(
				"gene_id",
				""
			)
		)
	)
	var current_trait := genome.get_trait(
		locus,
		PetGenomeSchema.BASE_TRAIT
	)

	if current_trait == direction:
		return {
			"ok": false,
			"mode": String(
				MODE_GENE
			),
			"error": (
				"Gene direction đã biểu hiện. "
				+ "Cần expression chain của Stage sau trước khi reinforce."
			),
			"requires_expression_chain": true,
			"selected_gene_id": String(
				gene_id
			),
			"selected_locus": String(
				locus
			),
			"selected_direction": String(
				direction
			),
		}

	var delta_id := StringName(
		"gene_expr_%s_s%d"
		% [
			String(gene_id),
			genome.stage(),
		]
	)

	var delta := EvolutionDelta.new(
		delta_id,
		locus,
		current_trait,
		direction,
		genome.mutation_ids().size()
			+ 1
	)

	if not delta.is_valid():
		return _error(
			"Không tạo được Gene EvolutionDelta."
		)

	var changed := _applier.apply(
		genome,
		delta
	)

	if changed == null:
		return _error(
			"Không áp dụng được Gene EvolutionDelta."
		)

	return {
		"ok": true,
		"mode": String(
			MODE_GENE
		),
		"from_stage": genome.stage(),
		"to_stage": genome.stage() + 1,
		"selected_gene_id": String(
			gene_id
		),
		"selected_locus": String(
			locus
		),
		"selected_direction": String(
			direction
		),
		"selected_item_uid": String(
			selected.get(
				"item_uid",
				""
			)
		),
		"primary_influence": float(
			selected.get(
				"influence",
				0.0
			)
		),
		"gene_influences": (
			gene_state.influences_snapshot()
		),
		"tag_influences": (
			gene_state.tag_influences_snapshot()
		),
		"delta": delta,
		"genome": changed,
	}


func _natural_resolution(
	genome: PetGenome
) -> Dictionary:
	var unchanged := _factory.create_snapshot(
		genome.stage(),
		genome.body_growth(),
		genome.traits_snapshot(),
		genome.mutation_ids()
	)

	if unchanged == null:
		return _error(
			"Không tạo được Natural Growth snapshot."
		)

	return {
		"ok": true,
		"mode": String(
			MODE_NATURAL
		),
		"from_stage": genome.stage(),
		"to_stage": genome.stage() + 1,
		"selected_gene_id": "",
		"selected_locus": "",
		"selected_direction": "",
		"selected_item_uid": "",
		"primary_influence": 0.0,
		"gene_influences": {},
		"tag_influences": {},
		"delta": null,
		"genome": unchanged,
	}


func _valid_candidates(
	gene_state: GeneDevelopmentState
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for raw in gene_state.gene_items_snapshot():
		var gene_id := _normalize_token(
			StringName(
				raw.get(
					"gene_id",
					""
				)
			)
		)
		var locus := _normalize_token(
			StringName(
				raw.get(
					"locus",
					""
				)
			)
		)
		var direction := _normalize_token(
			StringName(
				raw.get(
					"direction",
					""
				)
			)
		)
		var influence := float(
			raw.get(
				"influence",
				0.0
			)
		)

		if (
			String(gene_id).is_empty()
			or not PetGenomeSchema.is_visual_locus(
				locus
			)
			or String(direction).is_empty()
			or direction
				== PetGenomeSchema.BASE_TRAIT
			or influence <= 0.0
		):
			continue

		var candidate := raw.duplicate(
			true
		)
		candidate["gene_id"] = String(
			gene_id
		)
		candidate["locus"] = String(
			locus
		)
		candidate["direction"] = String(
			direction
		)
		candidate["influence"] = influence
		result.append(
			candidate
		)

	result.sort_custom(
		_sort_candidate
	)
	return result


func _weighted_pick(
	identity: PetIdentity,
	genome: PetGenome,
	candidates: Array[Dictionary]
) -> Dictionary:
	var total := 0.0

	for candidate in candidates:
		total += float(
			candidate.get(
				"influence",
				0.0
			)
		)

	if total <= 0.0:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = _selection_seed(
		identity,
		genome,
		candidates
	)

	var roll := rng.randf_range(
		0.0,
		total
	)
	var cursor := 0.0

	for candidate in candidates:
		cursor += float(
			candidate.get(
				"influence",
				0.0
			)
		)

		if roll <= cursor:
			return candidate.duplicate(
				true
			)

	return candidates.back().duplicate(
		true
	)


func _selection_seed(
	identity: PetIdentity,
	genome: PetGenome,
	candidates: Array[Dictionary]
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

	for candidate in candidates:
		value = _mix(
			value,
			_stable_string_hash(
				(
					String(
						candidate.get(
							"gene_id",
							""
						)
					)
					+ "|"
					+ String(
						candidate.get(
							"locus",
							""
						)
					)
					+ "|"
					+ String(
						candidate.get(
							"direction",
							""
						)
					)
					+ "|"
					+ String(
						candidate.get(
							"item_uid",
							""
						)
					)
				)
			)
		)
		value = _mix(
			value,
			int(
				round(
					float(
						candidate.get(
							"influence",
							0.0
						)
					) * 100.0
				)
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


func _sort_candidate(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_key := (
		String(
			a.get(
				"gene_id",
				""
			)
		)
		+ "|"
		+ String(
			a.get(
				"item_uid",
				""
			)
		)
	)
	var b_key := (
		String(
			b.get(
				"gene_id",
				""
			)
		)
		+ "|"
		+ String(
			b.get(
				"item_uid",
				""
			)
		)
	)

	return a_key < b_key


func _normalize_token(
	value: StringName
) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(
				" ",
				"_"
			)
	)


func _error(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
