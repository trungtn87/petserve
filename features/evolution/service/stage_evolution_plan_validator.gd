class_name StageEvolutionPlanValidator
extends RefCounted


const STAGE_ONE_SCHEMA: int = 4


func validate(
	data: Dictionary
) -> String:
	var pending_value: Variant = data.get(
		"pending_evolution",
		{}
	)

	if typeof(pending_value) != TYPE_DICTIONARY:
		return "Pending evolution không phải Dictionary."

	var pending := pending_value as Dictionary

	if pending.is_empty():
		return "Không có pending evolution."

	var schema := int(
		pending.get(
			"schema",
			0
		)
	)

	# Legacy M7/M8 plans remain supported for Stage 2/3 until migrated.
	# Stage 1 legacy plans must be rebuilt by StageEvolutionService.
	if schema != STAGE_ONE_SCHEMA:
		if int(
			pending.get(
				"from_stage",
				-1
			)
		) == 1:
			return "Pending Stage 1 cũ phải được migrate sang schema M9.5."

		return ""

	var identity := PetIdentity.from_dict(
		data.get(
			"identity",
			{}
		)
	)
	var current := PetGenome.from_dict(
		data.get(
			"genome",
			{}
		)
	)
	var next := PetGenome.from_dict(
		pending.get(
			"genome",
			{}
		)
	)

	if (
		identity == null
		or current == null
		or next == null
	):
		return "Pending Stage 1 thiếu Identity/Genome hợp lệ."

	var from_stage := int(
		pending.get(
			"from_stage",
			-1
		)
	)
	var to_stage := int(
		pending.get(
			"to_stage",
			-1
		)
	)

	if (
		from_stage != 1
		or current.stage() != from_stage
		or to_stage != from_stage + 1
		or next.stage() != to_stage
	):
		return "Pending Stage 1 có stage transition không hợp lệ."

	var source_visual := PetVisualRecord.from_dict(
		pending.get(
			"source_visual",
			{}
		)
	)

	if (
		source_visual == null
		or source_visual.pet_id
			!= identity.pet_id()
	):
		return "Pending Stage 1 có source visual sai identity."

	var request_value: Variant = pending.get(
		"render_request",
		{}
	)

	if typeof(request_value) != TYPE_DICTIONARY:
		return "Pending Stage 1 thiếu serialized render request."

	var request := EvolutionEditCoordinator.new().request_from_dict(
		request_value as Dictionary
	)

	if (
		request == null
		or request.pet_id != identity.pet_id()
		or request.source_image_path
			!= source_visual.image_path
		or not request.output_key.ends_with(
			"_pethome_v5_stage_%d"
			% to_stage
		)
	):
		return "Pending Stage 1 có render request không khớp plan."

	var source_phenotype := _normalize_phenotype_dict(
		pending.get(
			"source_phenotype",
			{}
		)
	)
	var target_phenotype := _normalize_phenotype_dict(
		pending.get(
			"target_phenotype",
			{}
		)
	)

	if source_phenotype.is_empty():
		return "Pending Stage 1 thiếu source phenotype."

	if target_phenotype.is_empty():
		return "Pending Stage 1 thiếu target phenotype."

	if source_phenotype != _genome_phenotype(
		current
	):
		return "Source phenotype không khớp Genome hiện tại."

	if target_phenotype != _genome_phenotype(
		next
	):
		return "Target phenotype không khớp Genome kế tiếp."

	var mode := StringName(
		pending.get(
			"resolution_mode",
			""
		)
	)

	match mode:
		StageEvolutionResolver.MODE_NATURAL:
			return _validate_natural(
				current,
				next,
				pending,
				request
			)

		StageEvolutionResolver.MODE_GENE:
			return _validate_gene(
				current,
				next,
				pending,
				request
			)

		_:
			return "Pending Stage 1 có resolution_mode không hợp lệ."


func _validate_natural(
	current: PetGenome,
	next: PetGenome,
	pending: Dictionary,
	request: PetRenderRequest
) -> String:
	var delta_value: Variant = pending.get(
		"delta",
		{}
	)

	if (
		typeof(delta_value) != TYPE_DICTIONARY
		or not (
			delta_value as Dictionary
		).is_empty()
	):
		return "Natural Growth không được có EvolutionDelta."

	if _changed_loci(
		current,
		next
	).size() != 0:
		return "Natural Growth đã làm thay đổi visual Gene locus."

	if current.mutation_ids() != next.mutation_ids():
		return "Natural Growth không được tự thêm mutation history."

	if request.target_region != EvolutionEditCoordinator.NATURAL_TARGET_REGION:
		return "Natural Growth request có target region không hợp lệ."

	return ""


func _validate_gene(
	current: PetGenome,
	next: PetGenome,
	pending: Dictionary,
	request: PetRenderRequest
) -> String:
	var delta_value: Variant = pending.get(
		"delta",
		{}
	)

	if typeof(delta_value) != TYPE_DICTIONARY:
		return "Gene plan thiếu EvolutionDelta."

	var delta := delta_value as Dictionary
	var mutation_id := StringName(
		delta.get(
			"mutation_id",
			""
		)
	)
	var target_trait := StringName(
		delta.get(
			"target_trait",
			""
		)
	)
	var from_trait := StringName(
		delta.get(
			"from_trait",
			""
		)
	)
	var to_trait := StringName(
		delta.get(
			"to_trait",
			""
		)
	)

	if (
		String(mutation_id).is_empty()
		or not PetGenomeSchema.is_visual_locus(
			target_trait
		)
		or String(from_trait).is_empty()
		or String(to_trait).is_empty()
		or from_trait == to_trait
	):
		return "Gene EvolutionDelta không hợp lệ."

	if current.get_trait(
		target_trait,
		PetGenomeSchema.BASE_TRAIT
	) != from_trait:
		return "Gene EvolutionDelta from_trait không khớp source Genome."

	if next.get_trait(
		target_trait,
		PetGenomeSchema.BASE_TRAIT
	) != to_trait:
		return "Gene EvolutionDelta to_trait không khớp target Genome."

	var changed := _changed_loci(
		current,
		next
	)

	if (
		changed.size() != 1
		or changed[0] != target_trait
	):
		return "Gene Stage 1 phải thay đúng một visual locus."

	var current_mutations := current.mutation_ids()
	var next_mutations := next.mutation_ids()

	if next_mutations.size() != current_mutations.size() + 1:
		return "Gene Stage 1 mutation history phải tăng đúng một entry."

	for index in range(
		current_mutations.size()
	):
		if next_mutations[index] != current_mutations[index]:
			return "Gene Stage 1 đã sửa mutation history cũ."

	if next_mutations.back() != mutation_id:
		return "Gene Stage 1 mutation history không khớp EvolutionDelta."

	var resolution_value: Variant = pending.get(
		"gene_resolution",
		{}
	)

	if typeof(resolution_value) != TYPE_DICTIONARY:
		return "Gene Stage 1 thiếu provenance."

	var resolution := resolution_value as Dictionary

	if (
		String(
			resolution.get(
				"selected_gene_id",
				""
			)
		).is_empty()
		or StringName(
			resolution.get(
				"selected_locus",
				""
			)
		) != target_trait
		or StringName(
			resolution.get(
				"selected_direction",
				""
			)
		) != to_trait
	):
		return "Gene provenance không khớp EvolutionDelta."

	if request.target_region != target_trait:
		return "Gene render target region không khớp EvolutionDelta."

	return ""


func _changed_loci(
	before: PetGenome,
	after: PetGenome
) -> Array[StringName]:
	var result: Array[StringName] = []

	for locus in PetGenomeSchema.VISUAL_LOCI:
		if before.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		) != after.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		):
			result.append(
				locus
			)

	return result


func _genome_phenotype(
	genome: PetGenome
) -> Dictionary:
	var result: Dictionary = {}
	var traits := genome.visual_traits_snapshot()

	for locus in PetGenomeSchema.VISUAL_LOCI:
		result[String(
			locus
		)] = String(
			traits.get(
				locus,
				PetGenomeSchema.BASE_TRAIT
			)
		)

	return result


func _normalize_phenotype_dict(
	value: Variant
) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}

	var source := value as Dictionary
	var result: Dictionary = {}

	for locus in PetGenomeSchema.VISUAL_LOCI:
		var key := String(
			locus
		)

		if not source.has(
			key
		):
			return {}

		var trait := String(
			source.get(
				key,
				""
			)
		).strip_edges().to_lower()

		if trait.is_empty():
			return {}

		result[key] = trait

	if result.size() != PetGenomeSchema.VISUAL_LOCI.size():
		return {}

	return result
