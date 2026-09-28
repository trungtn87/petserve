class_name StageEvolutionService
extends RefCounted


const FINAL_STAGE: int = 4


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
		return {
			"ok": false,
			"error": "Không đọc được dữ liệu pet.",
		}

	var current_stage := genome.stage()

	if current_stage >= FINAL_STAGE:
		return {
			"ok": false,
			"error": "Pet đã đạt hình thái cuối.",
		}

	if int(
		state.get(
			"stage_index",
			-1
		)
	) != current_stage:
		return {
			"ok": false,
			"error": "Lifecycle và Genome đang lệch giai đoạn.",
		}

	if not bool(
		state.get(
			"ready_to_evolve",
			false
		)
	):
		return {
			"ok": false,
			"error": "Pet chưa đủ điều kiện tiến hóa.",
		}

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
			return {
				"ok": false,
				"error": "Có pending evolution không khớp stage hiện tại.",
			}

		return {
			"ok": true,
			"data": data,
		}

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
		return {
			"ok": false,
			"error": "Chưa có mutation tiến hóa hợp lệ.",
		}

	var changed := (
		GenomeDeltaApplier.new()
		.apply(
			genome,
			delta
		)
	)

	if changed == null:
		return {
			"ok": false,
			"error": "Không áp dụng được mutation tiến hóa.",
		}

	var source_visual := (
		PetVisualRecord.from_dict(
			data.get(
				"current_visual",
				{}
			)
		)
	)

	if source_visual == null:
		return {
			"ok": false,
			"error": "Không đọc được ảnh PetHome hiện tại.",
		}

	var scene_profile := (
		PetSceneProfile.from_dict(
			data.get(
				"scene_profile",
				{}
			)
		)
	)

	if scene_profile == null:
		return {
			"ok": false,
			"error": "Không đọc được PetHome Scene Profile.",
		}

	var target_stage := current_stage + 1
	var coordinator := (
		EvolutionEditCoordinator.new()
	)
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
		return {
			"ok": false,
			"error": str(
				plan.get(
					"error",
					"Không tạo được evolution image-edit plan."
				)
			),
		}

	var request := (
		plan.get(
			"request"
		)
		as PetRenderRequest
	)

	if request == null:
		return {
			"ok": false,
			"error": "Evolution render request bị rỗng.",
		}

	var next := PetGenome.new(
		target_stage,
		0.0,
		changed.traits_snapshot(),
		changed.mutation_ids()
	)

	data["pending_evolution"] = {
		"schema": 3,
		"from_stage": current_stage,
		"to_stage": target_stage,
		"genome": next.to_dict(),
		"delta": delta.to_dict(),
		"source_visual": source_visual.to_dict(),
		"render_request": (
			coordinator.serialize_request(
				request
			)
		),
	}

	if not _save.save_data(
		data
	):
		return {
			"ok": false,
			"error": "Chưa lưu được evolution plan. Chưa gửi yêu cầu tạo ảnh.",
		}

	return {
		"ok": true,
		"data": data,
	}


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

	# Compatibility with pre-M7 pending Stage 1 plans.
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

	var previous_visual := (
		PetVisualRecord.from_dict(
			pending.get(
				"source_visual",
				{}
			)
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
