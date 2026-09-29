class_name StageEvolutionService
extends RefCounted


const FINAL_STAGE: int = 4
const STAGE_ONE: int = 1
const PENDING_SCHEMA: int = 4


var _save := EvolutionSaveService.new()


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

	if current_stage == STAGE_ONE:
		return _prepare_stage_one(
			data,
			state,
			identity,
			genome,
			source_visual,
			scene_profile
		)

	return _prepare_legacy_stage(
		data,
		identity,
		genome,
		source_visual,
		scene_profile
	)


func _prepare_stage_one(
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
					"Không resolve được tiến hóa Stage 1."
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
	var delta := resolution.get(
		"delta"
	) as EvolutionDelta
	var coordinator := EvolutionEditCoordinator.new()
	var plan: Dictionary = {}

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
				resolved_genome,
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
					"Không tạo được Stage 1 image-edit plan."
				)
			)
		)

	var request := plan.get(
		"request"
	) as PetRenderRequest

	if request == null:
		return _error(
			"Stage 1 render request bị rỗng."
		)

	var next := PetGenome.new(
		target_stage,
		0.0,
		resolved_genome.traits_snapshot(),
		resolved_genome.mutation_ids()
	)

	if not next.is_valid():
		return _error(
			"Không tạo được Genome Stage 2."
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
		"gene_resolution": (
			_serializable_gene_resolution(
				resolution
			)
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


func _prepare_legacy_stage(
	data: Dictionary,
	identity: PetIdentity,
	genome: PetGenome,
	source_visual: PetVisualRecord,
	scene_profile: PetSceneProfile
) -> Dictionary:
	var delta := (
		EvolutionRuleEngine.new()
		.choose_next(
			identity,
			genome,
			MutationCatalog.new()
			.load_default()
		)
	)

	if delta == null:
		return _error(
			"Chưa có mutation tiến hóa hợp lệ."
		)

	var changed := GenomeDeltaApplier.new().apply(
		genome,
		delta
	)

	if changed == null:
		return _error(
			"Không áp dụng được mutation tiến hóa."
		)

	var target_stage := genome.stage() + 1
	var coordinator := EvolutionEditCoordinator.new()
	var plan := coordinator.build_request(
		identity,
		genome,
		changed,
		delta,
		source_visual,
		target_stage,
		scene_profile
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
					"Không tạo được evolution image-edit plan."
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
		changed.traits_snapshot(),
		changed.mutation_ids()
	)

	data["pending_evolution"] = {
		"schema": 3,
		"from_stage": genome.stage(),
		"to_stage": target_stage,
		"resolution_mode": "legacy_mutation",
		"genome": next.to_dict(),
		"delta": delta.to_dict(),
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
		+ "_pethome_v5_stage_%d"
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
	visual.mutation_id = StringName(
		str(
			pending.get(
				"delta",
				{}
			).get(
				"mutation_id",
				""
			)
		)
	)
	visual.source_mode = (
		&"evolution_pethome_v5_image_edit"
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
