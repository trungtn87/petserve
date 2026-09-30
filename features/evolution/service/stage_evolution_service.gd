class_name StageEvolutionService
extends RefCounted


const FINAL_STAGE: int = 4
const PENDING_SCHEMA: int = 8


var _save := EvolutionSaveService.new()
var _plan_validator := StageEvolutionPlanValidator.new()


func prepare(
	state: Dictionary
) -> Dictionary:
	var data := _save.load_data()
	var identity := PetIdentity.from_dict(
		data.get(
			"identity",
			{}
		)
	)
	var genome := PetGenome.from_dict(
		data.get(
			"genome",
			{}
		)
	)

	if identity == null or genome == null:
		return _error(
			"Không đọc được dữ liệu pet."
		)

	var current_stage := genome.stage()

	if current_stage >= FINAL_STAGE:
		return _error(
			"Pet đã đạt hình thái cuối."
		)

	if int(
		state.get(
			"stage_index",
			current_stage
		)
	) != current_stage:
		return _error(
			"Lifecycle và Genome đang lệch giai đoạn."
		)

	var naturally_ready := bool(
		state.get(
			"ready_to_evolve",
			false
		)
	)
	var can_evolve := bool(
		state.get(
			"can_evolve",
			naturally_ready
		)
	)

	if not can_evolve:
		return _error(
			"Pet chưa đủ điều kiện tiến hóa."
		)

	var existing: Dictionary = data.get(
		"pending_evolution",
		{}
	)

	if not existing.is_empty():
		if int(
			existing.get(
				"from_stage",
				-1
			)
		) != current_stage:
			return _error(
				"Có pending evolution không khớp stage hiện tại."
			)

		if (
			int(
				existing.get(
					"schema",
					0
				)
			) != PENDING_SCHEMA
		):
			data.erase(
				"pending_evolution"
			)

			if not _save.save_data(
				data
			):
				return _error(
					"Không migrate được pending evolution cũ."
				)
		else:
			var pending_error := _plan_validator.validate(
				data
			)

			if not pending_error.is_empty():
				return _error(
					pending_error
				)

			return {
				"ok": true,
				"data": data,
			}

	var source_visual := PetVisualRecord.from_dict(
		data.get(
			"current_visual",
			{}
		)
	)

	if source_visual == null:
		return _error(
			"Không đọc được ảnh PetHome hiện tại."
		)

	var scene_profile := PetSceneProfile.from_dict(
		data.get(
			"scene_profile",
			{}
		)
	)

	if scene_profile == null:
		return _error(
			"Không đọc được PetHome Scene Profile."
		)

	return _prepare_resolved_stage(
		data,
		state,
		identity,
		genome,
		source_visual,
		scene_profile
	)


func _prepare_resolved_stage(
	data: Dictionary,
	state: Dictionary,
	identity: PetIdentity,
	genome: PetGenome,
	source_visual: PetVisualRecord,
	scene_profile: PetSceneProfile
) -> Dictionary:
	var gene_state_result := _gene_state_from_runtime(
		state,
		genome.stage()
	)

	if not bool(
		gene_state_result.get(
			"ok",
			false
		)
	):
		return _error(
			String(
				gene_state_result.get(
					"error",
					"Không đọc được GeneDevelopmentState."
				)
			)
		)

	var gene_state := gene_state_result.get(
		"gene_state"
	) as GeneDevelopmentState

	if gene_state == null:
		return _error(
			"GeneDevelopmentState bị rỗng."
		)

	var resolution := StageEvolutionResolver.new().resolve(
		identity,
		genome,
		gene_state
	)

	if not bool(
		resolution.get(
			"ok",
			false
		)
	):
		return _error(
			String(
				resolution.get(
					"error",
					"Không resolve được tiến hóa theo Gene/Natural policy."
				)
			)
		)

	var resolved_genome := resolution.get(
		"genome"
	) as PetGenome

	if resolved_genome == null:
		return _error(
			"Resolver không trả về PetGenome hợp lệ."
		)

	var target_stage := genome.stage() + 1
	var mode := StringName(
		resolution.get(
			"mode",
			""
		)
	)
	var deltas: Array[EvolutionDelta] = []
	var deltas_value: Variant = resolution.get(
		"deltas",
		[]
	)

	if typeof(deltas_value) == TYPE_ARRAY:
		for raw_delta in deltas_value as Array:
			var typed_delta := raw_delta as EvolutionDelta

			if typed_delta != null:
				deltas.append(
					typed_delta
				)

	var delta := (
		deltas[0]
		if not deltas.is_empty()
		else resolution.get(
			"delta"
		) as EvolutionDelta
	)

	if (
		mode == StageEvolutionResolver.MODE_GENE
		and deltas.is_empty()
		and delta != null
	):
		deltas.append(
			delta
		)

	var accumulated_gene_ids := _accumulated_gene_ids(
		data,
		gene_state
	)
	var destiny_value: Variant = data.get(
		"mythic_destiny",
		{}
	)
	var mythic_destiny: Dictionary = (
		(destiny_value as Dictionary).duplicate(
			true
		)
		if typeof(destiny_value) == TYPE_DICTIONARY
		else {}
	)
	var destiny_service := SpeciesMythicDestinyService.new()

	if (
		not mythic_destiny.is_empty()
		and not destiny_service.validate_for_identity(
			mythic_destiny,
			identity
		)
	):
		return _error(
			"Mythic Destiny đã lưu không hợp lệ với pet hiện tại."
		)

	if mythic_destiny.is_empty():
		mythic_destiny = destiny_service.from_gene_recipe(
			identity,
			accumulated_gene_ids
		)

	var mythic_resolution := SpeciesMythicMutationResolver.new().resolve(
		identity,
		resolved_genome,
		gene_state,
		target_stage,
		[],
		mythic_destiny,
		accumulated_gene_ids
	)

	if not bool(
		mythic_resolution.get(
			"ok",
			false
		)
	):
		return _error(
			String(
				mythic_resolution.get(
					"error",
					"Không resolve được Mythic Mutation."
				)
			)
		)

	var final_genome := mythic_resolution.get(
		"genome"
	) as PetGenome

	if final_genome == null:
		return _error(
			"Mythic resolver không trả về PetGenome hợp lệ."
		)

	var mythic_mode := StringName(
		mythic_resolution.get(
			"mode",
			"none"
		)
	)
	var mythic_active := mythic_mode in [
		SpeciesMythicMutationResolver.MODE_AWAKEN,
		SpeciesMythicMutationResolver.MODE_CONTINUE,
	]

	var coordinator := EvolutionEditCoordinator.new()
	var plan: Dictionary = {}

	if (
		mythic_active
		or deltas.size() > 1
	):
		plan = coordinator.build_composite_request(
			identity,
			genome,
			final_genome,
			deltas,
			source_visual,
			target_stage,
			scene_profile,
			mythic_resolution
		)
	else:
		match mode:
			StageEvolutionResolver.MODE_NATURAL:
				if delta != null:
					return _error(
						"Natural Growth không được có EvolutionDelta."
					)

				plan = coordinator.build_natural_request(
					identity,
					genome,
					source_visual,
					target_stage,
					scene_profile
				)

			StageEvolutionResolver.MODE_GENE:
				if delta == null:
					return _error(
						"Gene Expression thiếu EvolutionDelta."
					)

				plan = coordinator.build_request(
					identity,
					genome,
					final_genome,
					delta,
					source_visual,
					target_stage,
					scene_profile
				)

			_:
				return _error(
					"Evolution Resolver trả về mode không hợp lệ."
				)

	if not bool(
		plan.get(
			"ok",
			false
		)
	):
		return _error(
			str(
				plan.get(
					"error",
					"Không tạo được evolution render plan."
				)
			)
		)

	var request := plan.get(
		"request"
	) as PetRenderRequest

	if request == null:
		return _error(
			"Evolution render request bị rỗng."
		)

	var next := PetGenome.new(
		target_stage,
		0.0,
		final_genome.traits_snapshot(),
		final_genome.mutation_ids()
	)

	if not next.is_valid():
		return _error(
			"Không tạo được Genome cho stage kế tiếp."
		)

	data["pending_evolution"] = {
		"schema": PENDING_SCHEMA,
		"from_stage": genome.stage(),
		"to_stage": target_stage,
		"resolution_mode": String(
			mode
		),
		"genome": next.to_dict(),
		"delta": (
			delta.to_dict()
			if delta != null
			else {}
		),
		"deltas": _serialize_deltas(
			deltas
		),
		"gene_resolution": (
			_serializable_gene_resolution(
				resolution
			)
		),
		"mythic_resolution": (
			_serializable_mythic_resolution(
				mythic_resolution
			)
		),
		"mythic_destiny": (
			mythic_destiny.duplicate(
				true
			)
		),
		"accumulated_gene_ids": (
			accumulated_gene_ids.duplicate()
		),
		"source_phenotype": (
			_string_key_dict(
				genome.visual_traits_snapshot()
			)
		),
		"target_phenotype": (
			_string_key_dict(
				next.visual_traits_snapshot()
			)
		),
		"source_visual": source_visual.to_dict(),
		"render_request": (
			coordinator.serialize_request(
				request
			)
		),
	}

	return _persist_plan(
		data
	)


func _persist_plan(
	data: Dictionary
) -> Dictionary:
	var pending_error := _plan_validator.validate(
		data
	)

	if not pending_error.is_empty():
		return _error(
			pending_error
		)

	if not _save.save_data(
		data
	):
		return _error(
			"Chưa lưu được evolution plan. Chưa gửi yêu cầu tạo ảnh."
		)

	return {
		"ok": true,
		"data": data,
	}


func _gene_state_from_runtime(
	state: Dictionary,
	stage_index: int
) -> Dictionary:
	var value: Variant = state.get(
		"gene_development",
		null
	)

	if typeof(value) == TYPE_DICTIONARY:
		var restored := GeneDevelopmentState.from_dict(
			value as Dictionary,
			StageGenePolicy.load_default()
		)

		if restored == null:
			return {
				"ok": false,
				"error": "GeneDevelopmentState runtime không hợp lệ.",
			}

		if restored.stage_index() != stage_index:
			return {
				"ok": false,
				"error": "GeneDevelopmentState runtime lệch Stage.",
			}

		return {
			"ok": true,
			"gene_state": restored,
		}

	if int(
		state.get(
			"gene_items_used",
			0
		)
	) > 0:
		return {
			"ok": false,
			"error": (
				"Có Gene Item đã dùng nhưng thiếu GeneDevelopmentState chi tiết. "
				+ "Từ chối Natural Growth để tránh làm mất hướng phát triển."
			),
		}

	return {
		"ok": true,
		"gene_state": GeneDevelopmentState.new(
			stage_index
		),
	}


func _accumulated_gene_ids(
	data: Dictionary,
	gene_state: GeneDevelopmentState
) -> Array[String]:
	var result: Array[String] = []
	var history_value: Variant = data.get(
		"evolution_history",
		[]
	)

	if typeof(history_value) == TYPE_ARRAY:
		for raw_plan in history_value as Array:
			if typeof(raw_plan) != TYPE_DICTIONARY:
				continue

			var gene_resolution_value: Variant = (
				(raw_plan as Dictionary).get(
					"gene_resolution",
					{}
				)
			)

			if typeof(gene_resolution_value) != TYPE_DICTIONARY:
				continue

			var gene_resolution := gene_resolution_value as Dictionary
			var changes_value: Variant = gene_resolution.get(
				"selected_changes",
				[]
			)
			var added_from_changes := false

			if typeof(changes_value) == TYPE_ARRAY:
				for raw_change in changes_value as Array:
					if typeof(raw_change) != TYPE_DICTIONARY:
						continue

					var history_gene_id := String(
						(raw_change as Dictionary).get(
							"gene_id",
							""
						)
					).strip_edges()

					if history_gene_id.is_empty():
						continue

					_append_unique_gene_id(
						result,
						history_gene_id
					)
					added_from_changes = true

			if not added_from_changes:
				_append_unique_gene_id(
					result,
					String(
						gene_resolution.get(
							"selected_gene_id",
							""
						)
					)
				)

	if gene_state != null:
		for item in gene_state.gene_items_snapshot():
			_append_unique_gene_id(
				result,
				String(
					item.get(
						"gene_id",
						""
					)
				)
			)

	result.sort()
	return result


func _append_unique_gene_id(
	result: Array[String],
	gene_id: String
) -> void:
	var normalized := gene_id.strip_edges().to_lower()

	if (
		normalized.is_empty()
		or result.has(
			normalized
		)
	):
		return

	result.append(
		normalized
	)


func _serialize_deltas(
	deltas: Array[EvolutionDelta]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for delta in deltas:
		if delta != null:
			result.append(
				delta.to_dict()
			)

	return result


func _serializable_mythic_resolution(
	resolution: Dictionary
) -> Dictionary:
	return {
		"mode": String(
			resolution.get(
				"mode",
				"none"
			)
		),
		"trigger_source": String(
			resolution.get(
				"trigger_source",
				""
			)
		),
		"mutation_id": String(
			resolution.get(
				"mutation_id",
				""
			)
		),
		"display_name": String(
			resolution.get(
				"display_name",
				""
			)
		),
		"target_regions": (
			resolution.get(
				"target_regions",
				[]
			) as Array
		).duplicate(
			true
		),
		"prompt": String(
			resolution.get(
				"prompt",
				""
			)
		),
		"preserve_hint": String(
			resolution.get(
				"preserve_hint",
				""
			)
		),
	}


func _serializable_gene_resolution(
	resolution: Dictionary
) -> Dictionary:
	return {
		"mode": String(
			resolution.get(
				"mode",
				""
			)
		),
		"selected_gene_id": String(
			resolution.get(
				"selected_gene_id",
				""
			)
		),
		"selected_locus": String(
			resolution.get(
				"selected_locus",
				""
			)
		),
		"selected_direction": String(
			resolution.get(
				"selected_direction",
				""
			)
		),
		"resolved_trait": String(
			resolution.get(
				"resolved_trait",
				""
			)
		),
		"reinforced": bool(
			resolution.get(
				"reinforced",
				false
			)
		),
		"candidate_count": int(
			resolution.get(
				"candidate_count",
				0
			)
		),
		"selected_item_uid": String(
			resolution.get(
				"selected_item_uid",
				""
			)
		),
		"primary_influence": float(
			resolution.get(
				"primary_influence",
				0.0
			)
		),
		"resolved_locus_count": int(
			resolution.get(
				"resolved_locus_count",
				0
			)
		),
		"selected_changes": (
			resolution.get(
				"selected_changes",
				[]
			) as Array
		).duplicate(
			true
		),
		"selected_item_uids": (
			resolution.get(
				"selected_item_uids",
				[]
			) as Array
		).duplicate(
			true
		),
		"gene_influences": (
			resolution.get(
				"gene_influences",
				{}
			) as Dictionary
		).duplicate(true),
		"tag_influences": (
			resolution.get(
				"tag_influences",
				{}
			) as Dictionary
		).duplicate(true),
	}


func _string_key_dict(
	source: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	for key_value in source.keys():
		result[String(
			key_value
		)] = String(
			source[key_value]
		)

	return result


func build_request(
	data: Dictionary
) -> PetRenderRequest:
	var pending: Dictionary = data.get(
		"pending_evolution",
		{}
	)

	if pending.is_empty():
		return null

	if not _plan_validator.validate(
		data
	).is_empty():
		return null

	var request_value: Variant = pending.get(
		"render_request",
		{}
	)

	if typeof(
		request_value
	) == TYPE_DICTIONARY:
		var restored := (
			EvolutionEditCoordinator.new()
			.request_from_dict(
				request_value as Dictionary
			)
		)

		if restored != null:
			return restored

	# Compatibility with pre-M7 pending plans.
	var identity := PetIdentity.from_dict(
		data.get(
			"identity",
			{}
		)
	)

	if identity == null:
		return null

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = str(
		pending.get(
			"positive_prompt",
			""
		)
	)
	request.negative_prompt = str(
		pending.get(
			"negative_prompt",
			""
		)
	)
	request.source_image_path = str(
		pending.get(
			"source_visual",
			{}
		).get(
			"image_path",
			""
		)
	)
	request.target_region = StringName(
		str(
			pending.get(
				"target_region",
				""
			)
		)
	)
	request.edit_strength = float(
		pending.get(
			"edit_strength",
			0.0
		)
	)
	request.output_key = (
		identity.pet_id()
		+ "_pethome_v8_stage_%d"
		% int(
			pending.get(
				"to_stage",
				2
			)
		)
	)

	return (
		request
		if request.is_valid()
		else null
	)


func commit(
	result: PetRenderResult
) -> bool:
	if (
		result == null
		or not result.success
		or Image.load_from_file(
			result.image_path
		) == null
	):
		return false

	var data := _save.load_data()
	var pending: Dictionary = data.get(
		"pending_evolution",
		{}
	)

	if pending.is_empty():
		return false

	if not _plan_validator.validate(
		data
	).is_empty():
		return false

	var expected_request := build_request(
		data
	)

	if expected_request == null:
		return false

	if (
		result.metadata.has(
			"seed"
		)
		and int(
			result.metadata.get(
				"seed",
				0
			)
		) != expected_request.seed
	):
		return false

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
		identity == null
		or current == null
		or next == null
		or from_stage < 1
		or to_stage != from_stage + 1
		or to_stage > FINAL_STAGE
		or current.stage() != from_stage
		or next.stage() != to_stage
	):
		return false

	var previous_visual := PetVisualRecord.from_dict(
		pending.get(
			"source_visual",
			{}
		)
	)

	if (
		previous_visual == null
		or previous_visual.pet_id
			!= identity.pet_id()
	):
		return false

	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.visual_index = (
		previous_visual.visual_index + 1
	)
	var mythic_resolution_value: Variant = pending.get(
		"mythic_resolution",
		{}
	)
	var visual_mutation_id := ""

	if typeof(mythic_resolution_value) == TYPE_DICTIONARY:
		visual_mutation_id = String(
			(mythic_resolution_value as Dictionary).get(
				"mutation_id",
				""
			)
		)

	if visual_mutation_id.is_empty():
		var deltas_value_commit: Variant = pending.get(
			"deltas",
			[]
		)

		if (
			typeof(deltas_value_commit) == TYPE_ARRAY
			and not (deltas_value_commit as Array).is_empty()
		):
			var last_delta_value: Variant = (
				(deltas_value_commit as Array).back()
			)

			if typeof(last_delta_value) == TYPE_DICTIONARY:
				visual_mutation_id = String(
					(last_delta_value as Dictionary).get(
						"mutation_id",
						""
					)
				)

	visual.mutation_id = StringName(
		visual_mutation_id
	)
	visual.source_mode = (
		&"evolution_pethome_v8_full_regenerate"
		if expected_request.mode
			== PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
		else &"evolution_pethome_v8_image_edit"
	)
	visual.image_path = result.image_path
	visual.renderer_id = result.renderer_id
	visual.model_id = result.model_id

	var history: Array = data.get(
		"evolution_history",
		[]
	)
	history.append(
		pending.duplicate(true)
	)

	data["evolution_history"] = history
	data["genome"] = next.to_dict()
	data["current_visual"] = visual.to_dict()

	var pending_destiny_value: Variant = pending.get(
		"mythic_destiny",
		{}
	)

	if typeof(pending_destiny_value) == TYPE_DICTIONARY:
		var pending_destiny := pending_destiny_value as Dictionary

		if (
			not pending_destiny.is_empty()
			and SpeciesMythicDestinyService.new()
				.validate_for_identity(
					pending_destiny,
					identity
				)
		):
			data["mythic_destiny"] = (
				pending_destiny.duplicate(
					true
				)
			)

	data.erase(
		"pending_evolution"
	)

	return _save.save_data(
		data
	)


func _error(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
