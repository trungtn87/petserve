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

	var candidates := _valid_candidates(
		genome,
		gene_state
	)

	if candidates.is_empty():
		return _error(
			"Không có Gene Expression candidate hợp lệ cho phenotype hiện tại."
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
	var resolved_trait := _normalize_token(
		StringName(
			selected.get(
				"resolved_trait",
				""
			)
		)
	)
	var current_trait := genome.get_trait(
		locus,
		PetGenomeSchema.BASE_TRAIT
	)

	if (
		String(resolved_trait).is_empty()
		or resolved_trait == current_trait
	):
		return _error(
			"Gene Expression không tạo được trait kế tiếp."
		)

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
		resolved_trait,
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
		"resolved_trait": String(
			resolved_trait
		),
		"reinforced": bool(
			selected.get(
				"reinforced",
				false
			)
		),
		"selected_item_uid": String(
			selected.get(
				"item_uid",
				""
			)
		),
		"selected_item_uids": (
			selected.get(
				"item_uids",
				[]
			) as Array
		).duplicate(true),
		"candidate_count": candidates.size(),
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
		"resolved_trait": "",
		"reinforced": false,
		"selected_item_uid": "",
		"selected_item_uids": [],
		"candidate_count": 0,
		"primary_influence": 0.0,
		"gene_influences": {},
		"tag_influences": {},
		"delta": null,
		"genome": unchanged,
	}


func _valid_candidates(
	genome: PetGenome,
	gene_state: GeneDevelopmentState
) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()

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
		var definition := catalog.find_by_id(
			definitions,
			gene_id
		)

		if (
			definition == null
			or definition.locus() != locus
			or definition.direction() != direction
			or influence <= 0.0
		):
			continue

		var current_trait := genome.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		)
		var resolved_trait := definition.next_expression(
			current_trait
		)

		if (
			String(resolved_trait).is_empty()
			or resolved_trait == current_trait
		):
			continue

		var key := (
			String(gene_id)
			+ "|"
			+ String(locus)
			+ "|"
			+ String(resolved_trait)
		)
		var candidate: Dictionary = grouped.get(
			key,
			{}
		)

		if candidate.is_empty():
			candidate = {
				"gene_id": String(gene_id),
				"locus": String(locus),
				"direction": String(direction),
				"resolved_trait": String(
					resolved_trait
				),
				"reinforced": definition.reinforces(
					current_trait
				),
				"influence": 0.0,
				"item_uid": "",
				"item_uids": [],
			}

		candidate["influence"] = float(
			candidate.get(
				"influence",
				0.0
			)
		) + influence

		var item_uid := String(
			raw.get(
				"item_uid",
				""
			)
		)
		var item_uids: Array = candidate.get(
			"item_uids",
			[]
		)

		if (
			not item_uid.is_empty()
			and not item_uids.has(
				item_uid
			)
		):
			item_uids.append(
				item_uid
			)

		item_uids.sort()
		candidate["item_uids"] = item_uids
		candidate["item_uid"] = (
			String(item_uids[0])
			if not item_uids.is_empty()
			else ""
		)
		grouped[key] = candidate

	var result: Array[Dictionary] = []

	for value in grouped.values():
		result.append(
			(value as Dictionary).duplicate(
				true
			)
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
		var item_uids: Array = candidate.get(
			"item_uids",
			[]
		)
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
							"resolved_trait",
							""
						)
					)
					+ "|"
					+ str(
						item_uids
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
				"locus",
				""
			)
		)
		+ "|"
		+ String(
			a.get(
				"gene_id",
				""
			)
		)
		+ "|"
		+ String(
			a.get(
				"resolved_trait",
				""
			)
		)
	)
	var b_key := (
		String(
			b.get(
				"locus",
				""
			)
		)
		+ "|"
		+ String(
			b.get(
				"gene_id",
				""
			)
		)
		+ "|"
		+ String(
			b.get(
				"resolved_trait",
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
