class_name StageEvolutionPlanValidator
extends RefCounted


const PLAN_SCHEMA: int = 11
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

	if (
		pending.is_empty()
		or int(
			pending.get(
				"schema",
				0
			)
		) != PLAN_SCHEMA
	):
		return "Pending evolution cũ phải được rebuild theo composite Gene/Mythic policy."

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

	var coordinator := EvolutionEditCoordinator.new()
	var request := coordinator.request_from_dict(
		request_value as Dictionary
	)

	if request == null:
		return "Pending evolution có render request không hợp lệ."

	if (
		request.pet_id != identity.pet_id()
		or request.output_key
			!= (
				identity.pet_id()
				+ "_pethome_v12_stage_%d"
				% to_stage
			)
	):
		return "Pending evolution có render request không khớp identity/stage."

	if to_stage == 2:
		if (
			request.mode
				!= PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
			or not request.source_image_path.is_empty()
		):
			return "Stage 1 -> 2 phải dùng full-regenerate text-to-image."
	elif (
		request.mode
			!= PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		or request.source_image_path
			!= source_visual.image_path
	):
		return "Stage 3/4 phải dùng ảnh stage trước làm reference image-edit."

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

	if (
		source_phenotype.is_empty()
		or source_phenotype
			!= _genome_phenotype(
				current
			)
	):
		return "Source phenotype không khớp Genome hiện tại."

	if (
		target_phenotype.is_empty()
		or target_phenotype
			!= _genome_phenotype(
				next
			)
	):
		return "Target phenotype không khớp Genome kế tiếp."

	var deltas_result := _restore_deltas(
		pending.get(
			"deltas",
			[]
		)
	)

	if not bool(
		deltas_result.get(
			"ok",
			false
		)
	):
		return String(
			deltas_result.get(
				"error",
				"Gene delta list không hợp lệ."
			)
		)

	var deltas: Array[EvolutionDelta] = []
	var restored_deltas_value: Variant = deltas_result.get(
		"deltas",
		[]
	)

	if typeof(restored_deltas_value) == TYPE_ARRAY:
		for raw_delta in restored_deltas_value as Array:
			var restored_delta := raw_delta as EvolutionDelta

			if restored_delta != null:
				deltas.append(
					restored_delta
				)
	var mode := StringName(
		pending.get(
			"resolution_mode",
			""
		)
	)

	if (
		mode == StageEvolutionResolver.MODE_NATURAL
		and not deltas.is_empty()
	):
		return "Natural Growth không được có Gene delta."

	if (
		mode == StageEvolutionResolver.MODE_GENE
		and deltas.is_empty()
	):
		return "Gene evolution phải có ít nhất một Gene delta."

	if mode not in [
		StageEvolutionResolver.MODE_NATURAL,
		StageEvolutionResolver.MODE_GENE,
	]:
		return "Pending evolution có resolution_mode không hợp lệ."

	var intermediate := _apply_deltas(
		current,
		deltas
	)

	if intermediate == null:
		return "Không rebuild được Genome sau Gene delta."

	var changed_loci := _changed_loci(
		current,
		intermediate
	)

	if (
		mode == StageEvolutionResolver.MODE_NATURAL
		and not changed_loci.is_empty()
	):
		return "Natural Growth đã làm thay đổi Gene locus."

	if (
		mode == StageEvolutionResolver.MODE_GENE
		and changed_loci.size()
			!= deltas.size()
	):
		return "Gene evolution không thay đúng số locus đã resolve."

	var mythic_value: Variant = pending.get(
		"mythic_resolution",
		{}
	)

	if typeof(mythic_value) != TYPE_DICTIONARY:
		return "Pending evolution thiếu Mythic resolution."

	var mythic := mythic_value as Dictionary
	var mythic_mode := StringName(
		mythic.get(
			"mode",
			"none"
		)
	)
	var mythic_id := StringName(
		mythic.get(
			"mutation_id",
			""
		)
	)
	var expected_mutations := intermediate.mutation_ids()
	var mythic_active := mythic_mode in [
		SpeciesMythicMutationResolver.MODE_AWAKEN,
		SpeciesMythicMutationResolver.MODE_CONTINUE,
	]

	if mythic_mode == SpeciesMythicMutationResolver.MODE_AWAKEN:
		if String(mythic_id).is_empty():
			return "Mythic awaken thiếu mutation_id."

		if expected_mutations.has(
			mythic_id
		):
			return "Mythic awaken không được đánh thức branch đã tồn tại."

		expected_mutations.append(
			mythic_id
		)

	elif mythic_mode == SpeciesMythicMutationResolver.MODE_CONTINUE:
		if (
			String(mythic_id).is_empty()
			or not expected_mutations.has(
				mythic_id
			)
		):
			return "Mythic continue không khớp branch hiện tại."

	elif mythic_mode != SpeciesMythicMutationResolver.MODE_NONE:
		return "Mythic resolution mode không hợp lệ."

	if next.traits_snapshot() != intermediate.traits_snapshot():
		return "Target Genome drift khỏi Gene delta đã khóa."

	if next.mutation_ids() != expected_mutations:
		return "Target mutation history drift khỏi Gene/Mythic plan."

	var destiny_value: Variant = pending.get(
		"mythic_destiny",
		{}
	)

	if typeof(destiny_value) != TYPE_DICTIONARY:
		return "Pending Mythic Destiny không phải Dictionary."

	var destiny := destiny_value as Dictionary

	if (
		not destiny.is_empty()
		and not SpeciesMythicDestinyService.new()
			.validate_for_identity(
				destiny,
				identity
			)
	):
		return "Pending Mythic Destiny không hợp lệ."

	if mythic_active:
		var catalog := SpeciesMythicMutationCatalog.new()
		var definition := catalog.find_by_id(
			catalog.load_default(),
			mythic_id
		)

		if (
			definition == null
			or definition.species()
				!= identity.species()
			or String(
				mythic.get(
					"display_name",
					""
				)
			) != definition.display_name()
			or String(
				mythic.get(
					"prompt",
					""
				)
			) != definition.prompt_for_stage(
				to_stage
			)
		):
			return "Mythic resolution không khớp species definition."

	var gene_scores_value: Variant = pending.get(
		"gene_scores",
		{}
	)

	if typeof(gene_scores_value) != TYPE_DICTIONARY:
		return "Pending Gene scores không phải Dictionary."

	var gene_scores := (
		gene_scores_value as Dictionary
	).duplicate(true)
	var expected_gene_prompt := GenePromptResolver.new().build_from_scores(
		gene_scores,
		identity.element(),
		to_stage
	)
	var stored_gene_prompt := String(
		pending.get(
			"gene_expression_prompt",
			""
		)
	)

	if stored_gene_prompt != expected_gene_prompt:
		return "Pending Gene score prompt đã drift khỏi score ledger."

	var lifetime_tags_value: Variant = pending.get(
		"gene_lifetime_tag_influences",
		{}
	)

	if typeof(lifetime_tags_value) != TYPE_DICTIONARY:
		return "Pending lifetime Gene tag influence không phải Dictionary."

	var same_stage_target := PetGenome.new(
		current.stage(),
		current.body_growth(),
		next.traits_snapshot(),
		next.mutation_ids()
	)

	if not same_stage_target.is_valid():
		return "Không rebuild được target Genome để validate render plan."

	var expected_plan: Dictionary = coordinator.build_stage_regenerate_request(
		identity,
		current,
		same_stage_target,
		deltas,
		source_visual,
		to_stage,
		scene_profile,
		mythic
	)

	var expected_request := expected_plan.get(
		"request"
	) as PetRenderRequest

	if (
		expected_request != null
		and not expected_gene_prompt.is_empty()
	):
		var gene_scope_rule := ""

		if to_stage >= 3:
			gene_scope_rule = (
				"Use the reference image as the baseline. Only Gene loci listed below are authorized to differ from the source pet. "
				+ "Total lifetime score controls expression strength; the highest-scored direction is dominant and other scored directions may blend. "
				+ "Do not invent a new direction or redesign an unlisted locus.\n"
			)

		expected_request.positive_prompt += (
			"\n\n[ACCUMULATED GENE SCORE PHENOTYPE]\n"
			+ gene_scope_rule
			+ expected_gene_prompt
		)

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
		return "Evolution render request đã drift khỏi canonical composite plan."

	return ""


func _restore_deltas(
	value: Variant
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {
			"ok": false,
			"error": "Pending deltas không phải Array.",
		}

	var result: Array[EvolutionDelta] = []
	var seen_loci: Dictionary = {}

	for raw_value in value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"error": "Pending delta không phải Dictionary.",
			}

		var raw := raw_value as Dictionary
		var delta := EvolutionDelta.new(
			StringName(
				raw.get(
					"mutation_id",
					""
				)
			),
			StringName(
				raw.get(
					"target_trait",
					""
				)
			),
			StringName(
				raw.get(
					"from_trait",
					""
				)
			),
			StringName(
				raw.get(
					"to_trait",
					""
				)
			),
			int(
				raw.get(
					"step_index",
					0
				)
			)
		)

		if (
			not delta.is_valid()
			or seen_loci.has(
				delta.target_trait()
			)
		):
			return {
				"ok": false,
				"error": "Pending Gene delta trùng locus hoặc không hợp lệ.",
			}

		seen_loci[
			delta.target_trait()
		] = true
		result.append(
			delta
		)

	return {
		"ok": true,
		"deltas": result,
	}


func _apply_deltas(
	genome: PetGenome,
	deltas: Array[EvolutionDelta]
) -> PetGenome:
	var changed := PetGenome.new(
		genome.stage(),
		genome.body_growth(),
		genome.traits_snapshot(),
		genome.mutation_ids()
	)
	var applier := GenomeDeltaApplier.new()

	for delta in deltas:
		changed = applier.apply(
			changed,
			delta
		)

		if changed == null:
			return null

	return changed


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
