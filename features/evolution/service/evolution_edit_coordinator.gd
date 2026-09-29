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
		+ "The code-selected mutation is the only new Gene change."
	) % target_stage

	var stage_detail := _element_stage_prompt(
		identity.element(),
		target_stage
	)

	if stage_detail.is_empty():
		return {
			"ok": false,
			"error": "Thiếu Element Stage profile cho %s Stage %d."
			% [
				String(identity.element()),
				target_stage,
			],
		}

	positive_prompt += (
		"\n\n[ELEMENTAL DETAIL PROGRESSION]\n"
		+ stage_detail
		+ " This is stage presentation detail, not a new Gene. It may refine "
		+ "existing fur edges, markings, material feel and restrained aura across "
		+ "the current silhouette, but must not create new limbs or replace the body plan."
	)

	positive_prompt += _local_edit_boundary(
		spec.target_region(),
		target_stage
	)
	positive_prompt += _anatomy_lock_section()

	positive_prompt += _pethome_scale_lock_section()

	positive_prompt += (
		"\n\n[PETHOME CONTINUITY]\n"
		+ _scene_continuity_prompt(
			scene_profile
		)
	)

	positive_prompt += (
		" Keep the same full-body environmental framing and low-detail UI-safe areas. "
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
		+ "_pethome_v8_stage_%d"
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
		return _build_later_natural_edit(
			identity,
			current_genome,
			source_visual,
			target_stage,
			scene_profile
		)

	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	var stage_two_morphology := _element_stage_prompt(
		identity.element(),
		2
	)

	if stage_two_morphology.is_empty():
		return {
			"ok": false,
			"error": "Thiếu Stage 2 morphology profile cho hệ %s."
			% String(identity.element()),
		}

	var phenotype := PhenotypePromptBuilder.new()
	var positive_prompt := (
		"[IDENTITY BLUEPRINT]\n"
		+ style.identity_lock()
		+ " Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
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
		+ "Create a completely new full portrait from scratch for this same canonical pet lineage. "
		+ "Do not copy infant body geometry. Stage 2 must be visibly older and more physically mature than Stage 1, "
		+ "with a mature juvenile body rather than a giant baby head, while keeping the locked on-screen PetHome scale. "
		+ "This is a whole-body age transition, so secondary morphology is intentionally allowed to change."
	)

	positive_prompt += (
		"\n\n[ELEMENT MORPHOLOGY STAGE 2]\n"
		+ stage_two_morphology
		+ " Let elemental lineage shape the silhouette and body language, not just the colors. "
		+ "The seven elements should remain distinguishable in grayscale."
	)

	positive_prompt += (
		"\n\n[PHENOTYPE GUIDANCE]\n"
		+ "Existing Gene values remain canonical constraints, but they are not a literal pixel-shape lock. "
		+ "Target phenotype: "
		+ phenotype.describe(
			current_genome
		)
		+ ". You may redesign secondary fur silhouette, ear styling, tail fur contour and body proportions "
		+ "according to the Stage 2 element morphology above, as long as these Gene values do not change. "
		+ "Do not invent an unrelated Gene, extra appendage or different species."
	)

	positive_prompt += (
		"\n\n[QUADRUPED BODY PLAN]\n"
		+ _stage_two_body_plan_prompt()
	)

	positive_prompt += (
		"\n\n[PETHOME SCALE LOCK]\n"
		+ _stage_two_composition_prompt()
	)

	positive_prompt += (
		"\n\n[PETHOME SCENE REBUILD]\n"
		+ _scene_rebuild_prompt(
			scene_profile
		)
		+ " Recreate the same world identity from these scene descriptors while generating "
		+ "a fresh image. Follow the PETHOME SCALE LOCK above exactly. Return one pet + background "
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
		+ "new horn, unrelated new marking, unrelated new aura, changed Gene tail type, changed Gene eye type, "
		+ "changed Gene ear type, changed Gene coat pattern, redesigned species, "
		+ _stage_two_negative_prompt()
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



func _build_later_natural_edit(
	identity: PetIdentity,
	current_genome: PetGenome,
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile
) -> Dictionary:
	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	var stage_detail := _element_stage_prompt(
		identity.element(),
		target_stage
	)

	if stage_detail.is_empty():
		return {
			"ok": false,
			"error": "Thiếu Element Stage profile cho %s Stage %d."
			% [
				String(identity.element()),
				target_stage,
			],
		}

	var phenotype := PhenotypePromptBuilder.new().describe(
		current_genome
	)
	var positive_prompt := (
		"[IDENTITY LOCK]\n"
		+ style.identity_lock()
		+ " Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ "."
	)

	positive_prompt += (
		"\n\n[NATURAL STAGE ADVANCE]\n"
		+ (
			"Advance this same individual naturally from Stage %d to Stage %d. "
			+ "No Gene Item was selected for this transition. Keep every existing Gene locus unchanged. "
			+ "Current and target phenotype are identical: %s. "
			+ "Only age, proportions, fur maturity and restrained elemental presentation may develop."
		) % [
			current_genome.stage(),
			target_stage,
			phenotype,
		]
	)

	positive_prompt += (
		"\n\n[ELEMENTAL DETAIL PROGRESSION]\n"
		+ stage_detail
		+ " This is natural stage presentation, not a new Gene. "
		+ "Do not create a new visual locus, appendage, marking or mutation."
	)

	positive_prompt += _anatomy_lock_section()
	positive_prompt += _pethome_scale_lock_section()
	positive_prompt += (
		"\n\n[PETHOME CONTINUITY]\n"
		+ _scene_continuity_prompt(
			scene_profile
		)
	)
	positive_prompt += (
		" Keep the same camera and full-body portrait composition. "
		+ "Return ONE complete pet + background portrait with no text or UI."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = _append_negative_guard(
		style.negative_prompt()
		+ ", new gene trait, random mutation, unrelated marking, "
		+ "extra appendage, redesigned species, changed existing gene locus"
	)
	request.source_image_path = source_visual.image_path
	request.target_region = NATURAL_TARGET_REGION
	request.edit_strength = NATURAL_EDIT_STRENGTH
	request.seed = _request_seed(
		identity,
		target_stage,
		StringName(
			"natural_stage_%d"
			% target_stage
		)
	)
	request.output_key = _stage_one_output_key(
		identity,
		target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Natural Stage image-edit request không hợp lệ.",
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

	match mode_value:
		int(
			PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
		):
			request.mode = (
				PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
			)

		int(
			PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		):
			request.mode = (
				PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
			)

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

	var stage_two_morphology := _element_stage_prompt(
		identity.element(),
		2
	)

	if stage_two_morphology.is_empty():
		return {
			"ok": false,
			"error": "Thiếu Stage 2 morphology profile cho hệ %s."
			% String(identity.element()),
		}

	var phenotype := PhenotypePromptBuilder.new()
	var positive_prompt := (
		"[IDENTITY BLUEPRINT]\n"
		+ style.identity_lock()
		+ " Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
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
		+ "Create a completely new full portrait from scratch for this same canonical pet lineage. "
		+ "Do not copy infant body geometry. Stage 2 must be visibly older and more physically mature than Stage 1, "
		+ "with a mature juvenile body while keeping the locked on-screen PetHome scale. Secondary morphology is intentionally allowed to change."
	)

	positive_prompt += (
		"\n\n[ELEMENT MORPHOLOGY STAGE 2]\n"
		+ stage_two_morphology
		+ " Let elemental lineage reshape the silhouette and body language, not just the colors. "
		+ "The seven elements should remain distinguishable in grayscale."
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
		"\n\n[QUADRUPED BODY PLAN]\n"
		+ _stage_two_body_plan_prompt()
	)

	positive_prompt += (
		"\n\n[PETHOME SCALE LOCK]\n"
		+ _stage_two_composition_prompt()
	)

	positive_prompt += (
		"\n\n[ANATOMY REQUIREMENT]\n"
		+ "Render one anatomically coherent pet with exactly one head, one torso and four natural legs. "
		+ "Keep one tail unless the selected Gene explicitly changes tail structure. "
		+ "No duplicated, floating or human-like limbs."
	)

	positive_prompt += (
		"\n\n[PETHOME SCENE REBUILD]\n"
		+ _scene_rebuild_prompt(
			scene_profile
		)
		+ " Recreate the same world identity from these scene descriptors while generating "
		+ "a fresh image. Follow the PETHOME SCALE LOCK above exactly. Return one pet + background "
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
		+ "unplanned horn, unrelated unplanned marking, redesigned species, "
		+ _stage_two_negative_prompt()
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
	target_region: StringName,
	target_stage: int
) -> String:
	if target_stage >= 3:
		return (
			"\n\n[EDIT BOUNDARY]\n"
			+ (
				"Apply the code-selected Gene change clearly in target region '%s'. "
				+ "Outside that region, preserve anatomy, limb count, pose, camera, face identity "
				+ "and the established Stage 2 body silhouette. The ELEMENTAL DETAIL PROGRESSION "
				+ "may add restrained surface-level fur contour, markings, material feel and aura "
				+ "across existing body surfaces, but it may not create new limbs, a humanoid pose "
				+ "or a different body plan."
			) % String(target_region)
		)

	return (
		"\n\n[LOCAL EDIT BOUNDARY]\n"
		+ (
			"Apply the selected evolution only inside or immediately around "
			+ "target region '%s'. Outside that region, keep anatomy topology, "
			+ "limb count, paw count, pose, face identity, markings, silhouette "
			+ "and scene composition unchanged."
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


func _element_stage_prompt(
	element: StringName,
	stage: int
) -> String:
	var catalog := ElementStageVisualCatalog.new()
	var profile := catalog.find_by_element(
		catalog.load_default(),
		element
	)

	return catalog.prompt_for_stage(
		profile,
		stage
	)


func _stage_two_body_plan_prompt() -> String:
	return (
		"Natural feline quadruped only. Keep the spine and torso horizontally organized like a cat, "
		+ "with two forelegs and two hind legs attached in anatomically correct positions. "
		+ "The pet must be supported naturally on four paws or in a clearly four-legged feline pose. "
		+ "Never stand upright on two legs, never use human shoulders or arms, never use a mascot pose, "
		+ "and never make the forelegs hang like human hands. The body may differ by element, "
		+ "but all seven elements remain coherent four-legged cats."
	)


func _stage_two_composition_prompt() -> String:
	return (
		"Use a vertical 9:16 environmental establishing shot, not a character portrait. "
		+ "Show the complete pet from the highest visible point of the ears or fur through all paws and the full tail. "
		+ "LOCKED SCALE FOR EVERY LIFE STAGE: the visible pet height must be about 35 percent of total image height, measured from the highest visible point of the pet to the lowest paw/ground contact point. "
		+ "Place the lowest paw/ground contact point at about 90 percent of total image height, leaving about 10 percent of image height from the pet's feet to the bottom edge. "
		+ "Keep the pet horizontally near center and in the lower-middle of the frame. Stage progression changes anatomy, proportions, fur maturity and elemental detail, not on-screen character size. "
		+ "Keep the environment dominant with clear foreground, midground and background depth. Leave the upper 24 to 28 percent calm and low-detail for UI. "
		+ "Do not zoom in, do not crop paws or tail, do not place the paws on the bottom edge, and do not replace the PetHome with a studio backdrop."
	)


func _pethome_scale_lock_section() -> String:
	return (
		"\n\n[PETHOME SCALE LOCK]\n"
		+ _stage_two_composition_prompt()
	)


func _stage_two_negative_prompt() -> String:
	return (
		"bipedal, two-legged stance, standing upright, humanoid pose, anthropomorphic body, "
		+ "human arms, mascot pose, front paws used as hands, vertical human torso, close-up portrait, "
		+ "medium portrait, bust shot, giant pet, oversized character, pet filling the frame, cropped paws, "
		+ "cropped tail, plain studio background, gray studio background, empty backdrop, missing environment, "
		+ "color-swap-only element design, identical silhouette across all elements"
	)


func _stage_one_output_key(
	identity: PetIdentity,
	target_stage: int
) -> String:
	return (
		identity.pet_id()
		+ "_pethome_v8_stage_%d"
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
