class_name EvolutionEditCoordinator
extends RefCounted


const PLAN_SCHEMA: int = 1
const NATURAL_TARGET_REGION: StringName = &"whole_pet_age"
const NATURAL_EDIT_STRENGTH: float = 0.18
const SEED_MODULUS: int = 2147483647
const ANATOMY_LOCK_PROMPT: String = (
	"Preserve the reference pet's anatomy exactly: same number of legs, paws, "
	+ "ears, tails and all other body parts. Do not add, duplicate, remove or "
	+ "invent limbs or appendages. Preserve limb attachment points, joint layout, "
	+ "stance, body orientation and pose. A body part hidden by perspective must "
	+ "remain hidden naturally instead of being duplicated or moved into view."
)
const ANATOMY_NEGATIVE_PROMPT: String = (
	"extra leg, extra legs, extra limb, extra limbs, extra paw, extra paws, "
	+ "duplicate leg, duplicated limb, duplicate paw, duplicated paw, "
	+ "extra tail, duplicate tail, extra ear, duplicate ear, second body, "
	+ "duplicated body parts, malformed anatomy, deformed legs, changed limb count, "
	+ "changed paw count"
)


func build_request(
	identity: PetIdentity,
	previous_genome: PetGenome,
	mutated_genome: PetGenome,
	delta: EvolutionDelta,
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile = null
) -> Dictionary:
	var error := _validate(
		identity,
		previous_genome,
		mutated_genome,
		delta,
		source_visual,
		target_stage,
		scene_profile
	)

	if not error.is_empty():
		return {
			"ok": false,
			"error": error,
		}

	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	var catalog := MutationVisualCatalog.new()
	var visual := catalog.find_by_id(
		catalog.load_default(),
		delta.mutation_id()
	)

	if visual == null:
		return {
			"ok": false,
			"error": "Không có visual definition cho mutation %s."
			% String(delta.mutation_id()),
		}

	if (
		previous_genome.stage() == 1
		and target_stage == 2
	):
		return _build_stage_one_gene_regenerate(
			identity,
			previous_genome,
			mutated_genome,
			delta,
			visual,
			target_stage,
			scene_profile
		)

	var spec := PetVisualSpecBuilder.new().build(
		identity,
		previous_genome,
		mutated_genome,
		delta,
		style,
		visual,
		target_stage
	)

	if spec == null:
		return {
			"ok": false,
			"error": "Không tạo được Evolution PetVisualSpec.",
		}

	var prompt_builder := PetPromptBuilder.new()
	var positive_prompt := prompt_builder.build_positive(
		spec
	)

	positive_prompt += (
		"\n\n[STAGE ADVANCE]\n"
		+ "Advance this same individual to evolution stage %d. "
		+ "The mutation above is the only newly introduced biological feature."
	) % target_stage

	positive_prompt += _local_edit_boundary(
		spec.target_region()
	)
	positive_prompt += _anatomy_lock_section()

	positive_prompt += (
		"\n\n[PETHOME CONTINUITY]\n"
		+ _scene_continuity_prompt(
			scene_profile
		)
	)

	positive_prompt += (
		" Keep the same full-body portrait framing, small subject scale, "
		+ "and low-detail UI-safe areas near the top and bottom. "
		+ "Return ONE complete pet + background portrait with no text or UI."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = _append_negative_guard(
		prompt_builder.build_negative(
			spec
		)
	)
	request.source_image_path = (
		source_visual.image_path
	)
	request.target_region = (
		spec.target_region()
	)
	request.edit_strength = (
		spec.edit_strength()
	)
	request.seed = _request_seed(
		identity,
		target_stage,
		delta.mutation_id()
	)
	request.output_key = (
		identity.pet_id()
		+ "_pethome_v5_stage_%d"
		% target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Evolution image-edit request không hợp lệ.",
		}

	return {
		"ok": true,
		"schema": PLAN_SCHEMA,
		"spec": spec,
		"request": request,
	}


func build_natural_request(
	identity: PetIdentity,
	current_genome: PetGenome,
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile = null
) -> Dictionary:
	var error := _validate_natural(
		identity,
		current_genome,
		source_visual,
		target_stage,
		scene_profile
	)

	if not error.is_empty():
		return {
			"ok": false,
			"error": error,
		}

	if (
		current_genome.stage() != 1
		or target_stage != 2
	):
		return {
			"ok": false,
			"error": "Natural Growth full-regenerate chỉ áp dụng cho Stage 1 -> 2.",
		}

	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	var phenotype := PhenotypePromptBuilder.new()
	var positive_prompt := (
		"[IDENTITY BLUEPRINT]\n"
		+ style.identity_lock()
		+ " Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ String(identity.element())
		+ "."
	)

	positive_prompt += (
		"\n\n[MYTHIC ELEMENTAL STYLE]\n"
		+ style.base_style()
		+ " Element lineage appearance: "
		+ style.accent_for(
			identity.element()
		)
		+ "."
	)

	positive_prompt += (
		"\n\n[STAGE 2 FULL REGENERATE]\n"
		+ "Create a completely new full portrait from scratch for this same canonical pet. "
		+ "Do not use infant body geometry as a template. The pet must read immediately "
		+ "as a visibly older and larger Stage 2 form: a larger torso, longer correctly "
		+ "attached legs, more developed shoulders and chest, a clearly lower head-to-body "
		+ "ratio than the infant form, and a stable natural four-legged stance. "
		+ "Keep the youthful species identity, but remove tiny-baby proportions. "
		+ "This is a whole-body age transition, not a local image edit."
	)

	positive_prompt += (
		"\n\n[PHENOTYPE LOCK]\n"
		+ "Preserve every established Gene/visual locus semantically. Target phenotype: "
		+ phenotype.describe(
			current_genome
		)
		+ ". Do not introduce any new Gene, mutation, marking, horn, aura, tail type, "
		+ "eye type, ear type, coat pattern or other special phenotype."
	)

	positive_prompt += (
		"\n\n[ANATOMY REQUIREMENT]\n"
		+ "Render one anatomically coherent pet with exactly one head, one torso, "
		+ "four naturally attached legs/paws and one tail unless the phenotype explicitly "
		+ "states otherwise. No duplicated or floating limbs."
	)

	positive_prompt += (
		"\n\n[PETHOME SCENE REBUILD]\n"
		+ _scene_rebuild_prompt(
			scene_profile
		)
		+ " Recreate the same world identity from these scene descriptors while generating "
		+ "a fresh image. Keep a full-body portrait, comfortable small subject scale, and "
		+ "low-detail UI-safe areas near the top and bottom. Return one pet + background "
		+ "portrait with no text or UI."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = _append_negative_guard(
		style.negative_prompt()
		+ ", infant proportions, tiny baby body, oversized baby head, "
		+ "unchanged infant body, extra tail, new gene trait, random mutation, "
		+ "new horn, new marking, new aura, changed tail type, changed eye type, "
		+ "changed ear type, changed coat pattern, redesigned species"
	)
	request.target_region = NATURAL_TARGET_REGION
	request.edit_strength = 0.0
	request.seed = _request_seed(
		identity,
		target_stage,
		&"stage2_full_regenerate_natural"
	)
	request.output_key = _stage_one_output_key(
		identity,
		target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Stage 1 Natural full-regenerate request không hợp lệ.",
		}

	return {
		"ok": true,
		"schema": PLAN_SCHEMA,
		"request": request,
	}


func serialize_request(
	request: PetRenderRequest
) -> Dictionary:
	if (
		request == null
		or not request.is_valid()
	):
		return {}

	return {
		"schema": PLAN_SCHEMA,
		"mode": int(request.mode),
		"pet_id": request.pet_id,
		"positive_prompt": request.positive_prompt,
		"negative_prompt": request.negative_prompt,
		"source_image_path": request.source_image_path,
		"target_region": String(
			request.target_region
		),
		"edit_strength": request.edit_strength,
		"seed": request.seed,
		"output_key": request.output_key,
	}


func request_from_dict(
	data: Dictionary
) -> PetRenderRequest:
	if (
		data.is_empty()
		or int(data.get("schema", 0))
			!= PLAN_SCHEMA
	):
		return null

	var mode_value := int(
		data.get(
			"mode",
			-1
		)
	)

	if (
		mode_value
			!= int(
				PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
			)
		and mode_value
			!= int(
				PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
			)
	):
		return null

	var request := PetRenderRequest.new()
	request.mode = mode_value as PetRenderRequest.RenderMode
	request.pet_id = str(
		data.get("pet_id", "")
	)
	request.positive_prompt = str(
		data.get("positive_prompt", "")
	)
	request.negative_prompt = str(
		data.get("negative_prompt", "")
	)
	request.source_image_path = str(
		data.get("source_image_path", "")
	)
	request.target_region = StringName(
		str(data.get("target_region", ""))
	)
	request.edit_strength = float(
		data.get("edit_strength", 0.0)
	)
	request.seed = int(
		data.get(
			"seed",
			0
		)
	)
	request.output_key = str(
		data.get("output_key", "")
	)

	if not request.is_valid():
		return null

	return request


func _build_stage_one_gene_regenerate(
	identity: PetIdentity,
	previous_genome: PetGenome,
	mutated_genome: PetGenome,
	delta: EvolutionDelta,
	visual: MutationVisualDefinition,
	target_stage: int,
	scene_profile: PetSceneProfile
) -> Dictionary:
	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	var phenotype := PhenotypePromptBuilder.new()
	var positive_prompt := (
		"[IDENTITY BLUEPRINT]\n"
		+ style.identity_lock()
		+ " Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ String(identity.element())
		+ "."
	)

	positive_prompt += (
		"\n\n[MYTHIC ELEMENTAL STYLE]\n"
		+ style.base_style()
		+ " Element lineage appearance: "
		+ style.accent_for(
			identity.element()
		)
		+ "."
	)

	positive_prompt += (
		"\n\n[STAGE 2 FULL REGENERATE]\n"
		+ "Create a completely new full portrait from scratch for this same canonical pet. "
		+ "Do not use infant body geometry as a template. The Stage 2 pet must be visibly "
		+ "older and larger: larger torso, longer correctly attached legs, more developed "
		+ "shoulders and chest, a clearly lower head-to-body ratio than the infant form, "
		+ "and a stable natural four-legged stance. Keep the species recognizable and "
		+ "youthful, but remove tiny-baby proportions. This is a whole-body age transition."
	)

	positive_prompt += (
		"\n\n[SOURCE PHENOTYPE BLUEPRINT]\n"
		+ phenotype.describe(
			previous_genome
		)
	)

	positive_prompt += (
		"\n\n[TARGET PHENOTYPE]\n"
		+ phenotype.describe(
			mutated_genome
		)
	)

	positive_prompt += (
		"\n\n[ONE GENE EXPRESSION]\n"
		+ (
			"The only newly introduced biological feature is in '%s': %s "
			+ "Do not invent any other gene trait. %s"
		) % [
			String(visual.target_region()),
			visual.instruction(),
			visual.preserve_hint(),
		]
	)

	positive_prompt += (
		"\n\n[ANATOMY REQUIREMENT]\n"
		+ "Render one anatomically coherent pet with exactly one head, one torso, "
		+ "four naturally attached legs/paws and one tail unless the selected Gene "
		+ "explicitly changes tail structure. No duplicated or floating limbs."
	)

	positive_prompt += (
		"\n\n[PETHOME SCENE REBUILD]\n"
		+ _scene_rebuild_prompt(
			scene_profile
		)
		+ " Recreate the same world identity from these scene descriptors while generating "
		+ "a fresh image. Keep a full-body portrait, comfortable small subject scale, and "
		+ "low-detail UI-safe areas near the top and bottom. Return one pet + background "
		+ "portrait with no text or UI."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = _append_negative_guard(
		style.negative_prompt()
		+ ", infant proportions, tiny baby body, oversized baby head, "
		+ "unchanged infant body, unrelated gene trait, random mutation, "
		+ "unplanned horn, unplanned marking, redesigned species"
	)
	request.target_region = visual.target_region()
	request.edit_strength = 0.0
	request.seed = _request_seed(
		identity,
		target_stage,
		delta.mutation_id()
	)
	request.output_key = _stage_one_output_key(
		identity,
		target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Stage 1 Gene full-regenerate request không hợp lệ.",
		}

	return {
		"ok": true,
		"schema": PLAN_SCHEMA,
		"request": request,
	}


func _validate_natural(
	identity: PetIdentity,
	current_genome: PetGenome,
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile
) -> String:
	if (
		identity == null
		or current_genome == null
		or source_visual == null
	):
		return "Thiếu dữ liệu Natural Growth image-edit."

	if (
		not identity.is_valid()
		or not current_genome.is_valid()
		or not source_visual.is_valid()
	):
		return "Dữ liệu Natural Growth image-edit không hợp lệ."

	if source_visual.pet_id != identity.pet_id():
		return "Ảnh nguồn không thuộc đúng pet."

	if (
		source_visual.image_path.is_empty()
		or not FileAccess.file_exists(
			source_visual.image_path
		)
	):
		return "Không tìm thấy ảnh PetHome nguồn."

	if target_stage != current_genome.stage() + 1:
		return "Natural Growth phải tiến đúng một life stage."

	if scene_profile != null:
		if (
			not scene_profile.is_valid()
			or scene_profile.element
				!= identity.element()
		):
			return "PetHome Scene Profile không hợp lệ."

	return ""


func _validate(
	identity: PetIdentity,
	previous_genome: PetGenome,
	mutated_genome: PetGenome,
	delta: EvolutionDelta,
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile
) -> String:
	if (
		identity == null
		or previous_genome == null
		or mutated_genome == null
		or delta == null
		or source_visual == null
	):
		return "Thiếu dữ liệu evolution image-edit."

	if (
		not identity.is_valid()
		or not previous_genome.is_valid()
		or not mutated_genome.is_valid()
		or not delta.is_valid()
		or not source_visual.is_valid()
	):
		return "Dữ liệu evolution image-edit không hợp lệ."

	if source_visual.pet_id != identity.pet_id():
		return "Ảnh nguồn không thuộc đúng pet."

	if (
		source_visual.image_path.is_empty()
		or not FileAccess.file_exists(
			source_visual.image_path
		)
	):
		return "Không tìm thấy ảnh PetHome nguồn."

	if target_stage != previous_genome.stage() + 1:
		return "Target stage phải tiến đúng một giai đoạn."

	if mutated_genome.stage() != previous_genome.stage():
		return "Mutation snapshot không được tự thay đổi stage."

	if scene_profile != null:
		if (
			not scene_profile.is_valid()
			or scene_profile.element
				!= identity.element()
		):
			return "PetHome Scene Profile không hợp lệ."

	return ""


func _local_edit_boundary(
	target_region: StringName
) -> String:
	return (
		"\n\n[LOCAL EDIT BOUNDARY]\n"
		+ (
			"Apply the selected evolution only inside or immediately around "
			+ "target region '%s'. Outside that region, keep anatomy topology, "
			+ "limb count, paw count, pose, face identity, markings, silhouette "
			+ "and scene composition unchanged. Do not reinterpret the whole pet."
		) % String(target_region)
	)


func _anatomy_lock_section() -> String:
	return (
		"\n\n[ANATOMY LOCK]\n"
		+ ANATOMY_LOCK_PROMPT
	)


func _append_negative_guard(
	base: String
) -> String:
	var negative := base.strip_edges()

	if negative.is_empty():
		return ANATOMY_NEGATIVE_PROMPT

	return (
		negative
		+ ", "
		+ ANATOMY_NEGATIVE_PROMPT
	)


func _stage_one_output_key(
	identity: PetIdentity,
	target_stage: int
) -> String:
	return (
		identity.pet_id()
		+ "_pethome_v6_stage_%d"
		% target_stage
	)


func _scene_rebuild_prompt(
	scene_profile: PetSceneProfile
) -> String:
	if scene_profile == null:
		return (
			"Create a coherent PetHome environment matching the pet's elemental world, "
			+ "with soft cinematic lighting and the established vertical mobile composition."
		)

	return (
		"World identity: %s; palette: %s; lighting: %s; motif: %s. "
		+ "Use these as canonical scene descriptors rather than copying pixels from an old image."
	) % [
		scene_profile.environment_theme,
		scene_profile.palette_description,
		scene_profile.lighting_theme,
		scene_profile.motif_description,
	]


func _request_seed(
	identity: PetIdentity,
	target_stage: int,
	change_id: StringName
) -> int:
	var value := posmod(
		identity.lineage_seed(),
		SEED_MODULUS
	)

	value = _mix_seed(
		value,
		identity.generation() + 1
	)
	value = _mix_seed(
		value,
		target_stage
	)

	for index in range(
		String(change_id).length()
	):
		value = _mix_seed(
			value,
			String(change_id).unicode_at(
				index
			)
		)

	return max(
		1,
		value
	)


func _mix_seed(
	current: int,
	input_value: int
) -> int:
	return posmod(
		current * 1103515245
		+ input_value * 12345
		+ 1013904223,
		SEED_MODULUS
	)


func _scene_continuity_prompt(
	scene_profile: PetSceneProfile
) -> String:
	if scene_profile == null:
		return (
			"Preserve the exact same environment, palette, lighting, "
			+ "camera and world identity from the reference image. "
			+ "Do not redesign or replace the room."
		)

	return (
		"Preserve the exact same environment and camera from the reference image. "
		+ "World identity: %s; palette: %s; lighting: %s; motif: %s. "
		+ "Do not redesign or replace the room."
	) % [
		scene_profile.environment_theme,
		scene_profile.palette_description,
		scene_profile.lighting_theme,
		scene_profile.motif_description,
	]
