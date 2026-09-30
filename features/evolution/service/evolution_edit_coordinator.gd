class_name EvolutionEditCoordinator
extends RefCounted


const InitialSpeciesCatalogScript = preload(
	"res://features/evolution/visual/initial_species_catalog.gd"
)


const PLAN_SCHEMA: int = 1
const NATURAL_TARGET_REGION: StringName = &"whole_pet_age"
const NATURAL_EDIT_STRENGTH: float = 0.18
const SEED_MODULUS: int = 2147483647
const ANATOMY_LOCK_PROMPT: String = (
	"Preserve the reference pet's species body plan and existing anatomy exactly. "
	+ "Keep every existing limb, wing, foot or paw, ear, tail, horn and other appendage "
	+ "consistent with the reference. Do not add, duplicate, remove or invent appendages. "
	+ "Preserve attachment points, joint layout, stance, body orientation and pose. "
	+ "A body part hidden by perspective must remain naturally hidden rather than being "
	+ "duplicated or moved into view."
)
const ANATOMY_NEGATIVE_PROMPT: String = (
	"extra limb, duplicate limb, duplicated appendage, extra appendage, second body, "
	+ "duplicated body parts, malformed anatomy, deformed anatomy, impossible joint, "
	+ "detached appendage, anatomy inconsistent with the species"
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
		+ " This is stage presentation guidance, not a new Gene. For Stage 3/4, "
		+ "use this progression only to style the selected target region and its immediate visual transition. "
		+ "It does not authorize redesigning unrelated body parts, markings, anatomy or silhouette."
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
		+ "_pethome_v11_stage_%d"
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

	var species_profile := _species_profile(
		identity.species()
	)

	if species_profile == null:
		return {
			"ok": false,
			"error": "Thiếu species profile cho %s."
			% String(identity.species()),
		}

	var positive_prompt := (
		"[STAGE 2 FREESTYLE]\n"
		+ "Create one unique Stage 2 "
		+ String(identity.species())
		+ " in premium Mythic Elemental Chibi game art. "
		+ "Element family: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ ". "
		+ style.base_style()
		+ " Use these elemental cues only as creative inspiration: "
		+ style.accent_for(
			identity.element()
		)
		+ ". The AI should freely invent the individual pet: face, fur pattern, fluff, ear details, tail shape, expression, elemental markings and natural animal pose. "
		+ "Do not copy a fixed template or reproduce the previous Stage 1 silhouette. Keep believable species anatomy and make the result feel naturally a little older than Stage 1 without forcing a specific body design."
	)

	positive_prompt += (
		"\n\n[ELEMENTAL NATURAL BACKGROUND]\n"
		+ _stage_two_environment_prompt(
			scene_profile,
			identity.element()
		)
	)

	positive_prompt += (
		"\n\n[PETHOME COMPOSITION]\n"
		+ _stage_two_composition_prompt()
		+ " Return one complete pet and one natural background scene with no text or UI."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = (
		style.negative_prompt()
		+ ", fixed template character, repeated identical pet design, repeated identical face, "
		+ "plain studio background, empty neutral backdrop, isolated character, multiple pets, "
		+ "close-up portrait, giant pet filling the frame, cropped pet, humanoid pose, standing upright like a person, text, UI"
	)
	request.target_region = NATURAL_TARGET_REGION
	request.edit_strength = 0.0
	request.seed = 0
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

	var species_profile := _species_profile(
		identity.species()
	)

	if species_profile == null:
		return {
			"ok": false,
			"error": "Thiếu species profile cho %s."
			% String(identity.species()),
		}

	var positive_prompt := (
		"[STAGE 2 FREESTYLE]\n"
		+ "Create one unique Stage 2 "
		+ String(identity.species())
		+ " in premium Mythic Elemental Chibi game art. "
		+ "Element family: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ ". "
		+ style.base_style()
		+ " Use these elemental cues only as creative inspiration: "
		+ style.accent_for(
			identity.element()
		)
		+ ". The AI should freely invent the individual pet instead of reproducing a fixed template or the previous Stage 1 silhouette. "
		+ "Keep believable species anatomy and a natural animal pose. "
		+ "There is one gameplay Gene expression to include naturally and without over-constraining the rest of the design: "
		+ visual.instruction()
	)

	positive_prompt += (
		"\n\n[ELEMENTAL NATURAL BACKGROUND]\n"
		+ _stage_two_environment_prompt(
			scene_profile,
			identity.element()
		)
	)

	positive_prompt += (
		"\n\n[PETHOME COMPOSITION]\n"
		+ _stage_two_composition_prompt()
		+ " Return one complete pet and one natural background scene with no text or UI."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = (
		style.negative_prompt()
		+ ", fixed template character, repeated identical pet design, repeated identical face, "
		+ "plain studio background, empty neutral backdrop, isolated character, multiple pets, "
		+ "close-up portrait, giant pet filling the frame, cropped pet, humanoid pose, standing upright like a person, text, UI"
	)
	request.target_region = visual.target_region()
	request.edit_strength = 0.0
	request.seed = 0
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
				"Apply the code-selected Gene change clearly and only in target region '%s'. "
				+ "Outside that region, preserve the reference pixels conceptually: species anatomy, "
				+ "appendage layout, pose, camera, face identity, existing markings, colors, silhouette "
				+ "and environment must remain unchanged. The ELEMENTAL DETAIL PROGRESSION only describes "
				+ "how the selected target region should evolve; it must not spill into unrelated regions."
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


func _species_profile(
	species: StringName
) -> InitialSpeciesProfile:
	var catalog := InitialSpeciesCatalogScript.new()

	return catalog.find_by_species(
		catalog.load_default(),
		species
	)


func _stage_two_environment_prompt(
	scene_profile: PetSceneProfile,
	element: StringName
) -> String:
	var text := (
		"Create a natural environmental background inspired by the "
		+ PetElementCatalog.prompt_name(element)
		+ " element. Let the AI freely invent the scenery, terrain, vegetation, atmosphere, weather and lighting so the world feels organically connected to the pet. "
	)

	if scene_profile != null:
		text += (
			"Use these existing descriptors only as loose inspiration, not as a continuity lock: "
			+ scene_profile.environment_theme
			+ "; "
			+ scene_profile.palette_description
			+ "; "
			+ scene_profile.lighting_theme
			+ ". "
		)

	text += (
		"Avoid a studio backdrop. The environment should feel alive, natural and spacious."
	)

	return text


func _stage_two_species_prompt(
	profile: InitialSpeciesProfile
) -> String:
	if profile == null:
		return ""

	return (
		profile.species_anatomy
		+ " "
		+ profile.freestyle_pose
		+ " Keep natural animal anatomy and pose; otherwise allow broad visual freedom."
	)


func _stage_two_composition_prompt() -> String:
	return (
		"Use a vertical 9:16 WIDE environmental establishing shot with the camera pulled back, never a character portrait or showcase shot. "
		+ "The environment is the main composition and the pet is a smaller focal subject living inside it. "
		+ "Keep the whole pet comfortably inside the frame and its overall species silhouette readable. "
		+ "Natural perspective and partial occlusion of limbs, tail or other appendages are allowed. "
		+ "LOCKED SCALE FOR STAGE 2: the visible pet height should occupy only about 28 to 32 percent of total image height. "
		+ "Visually, the pet should fit mostly inside the LOWER THIRD of the scene, with abundant environment visible above and around it. "
		+ "Place the lowest visible pet point around 88 to 90 percent of total image height and keep the highest visible pet point below roughly 55 to 60 percent of total image height. "
		+ "Do not enlarge the pet because it is older; Stage progression changes anatomy, proportions, fur maturity and elemental detail, not on-screen character size. "
		+ "Keep at least about 65 to 70 percent of the image reading as environment, with clear foreground, midground and background depth. "
		+ "Leave the upper 30 percent calm and low-detail for UI, especially the upper-left status area. "
		+ "Do not zoom in, do not crop the pet, do not let ears or head enter the top half of the frame, do not place the paws on the bottom edge, and do not replace the PetHome with a studio backdrop."
	)


func _pethome_scale_lock_section() -> String:
	return (
		"\n\n[PETHOME SCALE LOCK]\n"
		+ _stage_two_composition_prompt()
	)


func _stage_two_negative_prompt() -> String:
	return (
		"close-up portrait, medium portrait, bust shot, character showcase, character poster, giant pet, oversized character, "
		+ "pet filling the frame, pet occupying most of the image, pet taller than 35 percent of image height, zoomed-in camera, "
		+ "cropped pet, head in the upper half of the frame, plain studio background, gray studio background, "
		+ "empty backdrop, missing environment, color-swap-only element design, "
		+ "upright bipedal cat, cat standing on two hind legs, anthropomorphic cat pose, humanoid torso, mascot pose, arms, hands, "
		+ "identical silhouette across all elements, duplicated appendage, duplicated body part, "
		+ "malformed species anatomy, impossible joint, detached appendage"
	)


func _stage_one_output_key(
	identity: PetIdentity,
	target_stage: int
) -> String:
	return (
		identity.pet_id()
		+ "_pethome_v11_stage_%d"
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
