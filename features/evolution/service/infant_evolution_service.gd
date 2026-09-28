class_name InfantEvolutionService
extends RefCounted

var _save := EvolutionSaveService.new()

func prepare(state: Dictionary) -> Dictionary:
	var data := _save.load_data()
	var identity := PetIdentity.from_dict(data.get("identity", {}))
	var genome := PetGenome.from_dict(data.get("genome", {}))
	if identity == null or genome == null:
		return {"ok": false, "error": "Không đọc được dữ liệu pet."}
	if genome.stage() != 1 or not bool(state.get("ready_to_evolve", false)):
		return {"ok": false, "error": "Pet chưa đủ điều kiện tiến hóa ấu thể."}
	if not data.get("pending_evolution", {}).is_empty():
		return {"ok": true, "data": data}
	var delta := EvolutionRuleEngine.new().choose_next(identity, genome, MutationCatalog.new().load_default())
	var changed := GenomeDeltaApplier.new().apply(genome, delta)
	if changed == null:
		return {"ok": false, "error": "Chưa có hình thái tiến hóa hợp lệ."}
	var catalog := MutationVisualCatalog.new()
	var visual := catalog.find_by_id(catalog.load_default(), delta.mutation_id())
	var spec := PetVisualSpecBuilder.new().build(identity, genome, changed, delta, MythicStyleProfile.load_default(), visual)
	if spec == null:
		return {"ok": false, "error": "Chưa tạo được mô tả hình thái mới."}
	var next := PetGenome.new(2, 0.0, changed.traits_snapshot(), changed.mutation_ids())
	data["pending_evolution"] = {
		"from_stage": 1, "to_stage": 2,
		"genome": next.to_dict(), "delta": delta.to_dict(),
		"source_visual": data.get("current_visual", {}).duplicate(true),
		"positive_prompt": PetPromptBuilder.new().build_positive(spec).replace("evolution stage 1", "evolution stage 2") + "\nAdvance this same pet to stage 2. Keep the same scene, lighting, full-body framing, small subject scale, and empty top/bottom UI areas. Return ONE complete pet + background portrait, without text.",
		"negative_prompt": PetPromptBuilder.new().build_negative(spec),
		"target_region": String(spec.target_region()),
		"edit_strength": spec.edit_strength(),
	}
	if not _save.save_data(data):
		return {"ok": false, "error": "Chưa lưu được tiến hóa. Chưa gửi yêu cầu tạo ảnh."}
	return {"ok": true, "data": data}

func build_request(data: Dictionary) -> PetRenderRequest:
	var pending: Dictionary = data.get("pending_evolution", {})
	var identity := PetIdentity.from_dict(data.get("identity", {}))
	if pending.is_empty() or identity == null:
		return null
	var request := PetRenderRequest.new()
	request.mode = PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	request.pet_id = identity.pet_id()
	request.positive_prompt = str(pending.get("positive_prompt", ""))
	request.negative_prompt = str(pending.get("negative_prompt", ""))
	request.source_image_path = str(pending.get("source_visual", {}).get("image_path", ""))
	request.target_region = StringName(str(pending.get("target_region", "")))
	request.edit_strength = float(pending.get("edit_strength", 0.0))
	request.output_key = identity.pet_id() + "_pethome_v5_stage_2"
	return request if request.is_valid() else null

func commit(result: PetRenderResult) -> bool:
	if result == null or not result.success or Image.load_from_file(result.image_path) == null:
		return false
	var data := _save.load_data()
	var pending: Dictionary = data.get("pending_evolution", {})
	if pending.is_empty():
		return false
	var identity := PetIdentity.from_dict(data.get("identity", {}))
	var next := PetGenome.from_dict(pending.get("genome", {}))
	if identity == null or next == null or next.stage() != 2:
		return false
	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.visual_index = 1
	visual.mutation_id = StringName(str(pending.get("delta", {}).get("mutation_id", "")))
	visual.source_mode = &"evolution_pethome_v5_image_edit"
	visual.image_path = result.image_path
	visual.renderer_id = result.renderer_id
	visual.model_id = result.model_id
	var history: Array = data.get("evolution_history", [])
	history.append(pending.duplicate(true))
	data["evolution_history"] = history
	data["genome"] = next.to_dict()
	data["current_visual"] = visual.to_dict()
	data.erase("pending_evolution")
	return _save.save_data(data)
