class_name StageEvolutionPlanValidator
extends RefCounted


const PLAN_SCHEMA: int = 6
const FINAL_STAGE: int = 4


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

	if int(
		pending.get(
			"schema",
			0
		)
	) != PLAN_SCHEMA:
		return "Pending evolution cũ phải được rebuild theo Gene/Natural policy mới."

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
		return "Pending evolution thiếu Identity/Genome hợp lệ."

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
		from_stage < 1
		or from_stage >= FINAL_STAGE
		or current.stage() != from_stage
		or to_stage != from_stage + 1
		or next.stage() != to_stage
	):
		return "Pending evolution có stage transition không hợp lệ."

	var source_visual := PetVisualRecord.from_dict(
		pending.get(
			"source_visual",
			{}
		)
	)
	var scene_profile := PetSceneProfile.from_dict(
		data.get(
			"scene_profile",
			{}
		)
	)

	if (
		source_visual == null
		or source_visual.pet_id
			!= identity.pet_id()
	):
		return "Pending evolution có source visual sai identity."

	if (
		scene_profile == null
		or scene_profile.element
			!= identity.element()
	):
		return "Pending evolution có Scene Profile không hợp lệ."

	var request_value: Variant = pending.get(
		"render_request",
		{}
	)

	if typeof(request_value) != TYPE_DICTIONARY:
		return "Pending evolution thiếu serialized render request."

	var request := EvolutionEditCoordinator.new().request_from_dict(
		request_value as Dictionary
	)

	if request == null:
		return "Pending evolution có render request không hợp lệ."

	if (
		request.pet_id != identity.pet_id()
		or request.output_key
			!= (
				identity.pet_id()
				+ "_pethome_v7_stage_%d"
				% to_stage
			)
	):
		return "Pending evolution có render request không khớp identity/stage."

	if from_stage == 1:
		if (
			request.mode
				!= PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
			or not request.source_image_path.is_empty()
		):
			return "Stage 1 -> 2 phải dùng full-regenerate."
	else:
		if (
			request.mode
				!= PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
			or request.source_image_path
				!= source_visual.image_path
		):
			return "Stage 2+ phải dùng image-edit từ visual hiện tại."

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
		return "Pending evolution thiếu source phenotype."

	if target_phenotype.is_empty():
		return "Pending evolution thiếu target phenotype."

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
				identity,
				current,
				next,
				pending,
				request,
				source_visual,
				scene_profile,
				to_stage
			)

		StageEvolutionResolver.MODE_GENE:
			return _validate_gene(
				identity,
				current,
				next,
				pending,
				request,
				source_visual,
				scene_profile,
				to_stage
			)

		_:
			return "Pending evolution có resolution_mode không hợp lệ."


func _validate_natural(
	identity: PetIdentity,
	current: PetGenome,
	next: PetGenome,
	pending: Dictionary,
	request: PetRenderRequest,
	source_visual: PetVisualRecord,
	scene_profile: PetSceneProfile,
	to_stage: int
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

	var expected_plan := EvolutionEditCoordinator.new().build_natural_request(
		identity,
		current,
		source_visual,
		to_stage,
		scene_profile
	)
	var expected_request := expected_plan.get(
		"request"
	) as PetRenderRequest

	if (
		not bool(
			expected_plan.get(
				"ok",
				false
			)
		)
		or expected_request == null
		or expected_request.to_debug_dict()
			!= request.to_debug_dict()
	):
		return "Natural Growth render request đã drift khỏi canonical plan."

	return ""


func _validate_gene(
	identity: PetIdentity,
	current: PetGenome,
	next: PetGenome,
	pending: Dictionary,
	request: PetRenderRequest,
	source_visual: PetVisualRecord,
	scene_profile: PetSceneProfile,
	to_stage: int
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
	var step_index := int(
		delta.get(
			"step_index",
			0
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
		or step_index < 1
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
		return "Gene evolution phải thay đúng một visual locus."

	var current_mutations := current.mutation_ids()
	var next_mutations := next.mutation_ids()

	if next_mutations.size() != current_mutations.size() + 1:
		return "Gene mutation history phải tăng đúng một entry."

	for index in range(
		current_mutations.size()
	):
		if next_mutations[index] != current_mutations[index]:
			return "Gene evolution đã sửa mutation history cũ."

	if next_mutations.back() != mutation_id:
		return "Gene mutation history không khớp EvolutionDelta."

	var resolution_value: Variant = pending.get(
		"gene_resolution",
		{}
	)

	if typeof(resolution_value) != TYPE_DICTIONARY:
		return "Gene plan thiếu provenance."

	var resolution := resolution_value as Dictionary
	var selected_direction := StringName(
		resolution.get(
			"selected_direction",
			""
		)
	)
	var resolved_trait := StringName(
		resolution.get(
			"resolved_trait",
			""
		)
	)
	var reinforced := bool(
		resolution.get(
			"reinforced",
			false
		)
	)

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
		or String(selected_direction).is_empty()
		or resolved_trait != to_trait
	):
		return "Gene provenance không khớp EvolutionDelta."

	if (
		not reinforced
		and selected_direction != to_trait
	):
		return "Gene branch mới phải biểu hiện đúng selected direction."

	if request.target_region != target_trait:
		return "Gene render target region không khớp EvolutionDelta."

	var delta_object := EvolutionDelta.new(
		mutation_id,
		target_trait,
		from_trait,
		to_trait,
		step_index
	)

	if not delta_object.is_valid():
		return "Gene EvolutionDelta object không hợp lệ."

	var mutated := PetGenome.new(
		current.stage(),
		current.body_growth(),
		next.traits_snapshot(),
		next.mutation_ids()
	)

	if not mutated.is_valid():
		return "Không rebuild được mutated Genome để validate request."

	var expected_plan := EvolutionEditCoordinator.new().build_request(
		identity,
		current,
		mutated,
		delta_object,
		source_visual,
		to_stage,
		scene_profile
	)
	var expected_request := expected_plan.get(
		"request"
	) as PetRenderRequest

	if (
		not bool(
			expected_plan.get(
				"ok",
				false
			)
		)
		or expected_request == null
		or expected_request.to_debug_dict()
			!= request.to_debug_dict()
	):
		return "Gene render request đã drift khỏi canonical plan."

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

		var trait_id := String(
			source.get(
				key,
				""
			)
		).strip_edges().to_lower()

		if trait_id.is_empty():
			return {}

		result[key] = trait_id

	if result.size() != PetGenomeSchema.VISUAL_LOCI.size():
		return {}

	return result
