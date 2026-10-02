class_name EvolutionEditCoordinator
extends RefCounted


const InitialSpeciesCatalogScript = preload(
	"res://features/evolution/visual/initial_species_catalog.gd"
)


const PLAN_SCHEMA: int = 2
const NATURAL_TARGET_REGION: StringName = &"whole_pet_age"
const NATURAL_EDIT_STRENGTH: float = 0.18
const STAGE_TWO_EDIT_STRENGTH: float = 0.30
const COMPOSITE_GENE_TARGET_REGION: StringName = &"whole_pet_gene"
const COMPOSITE_MYTHIC_TARGET_REGION: StringName = &"whole_pet_mythic"
const MYTHIC_EDIT_STRENGTH: float = 0.24
const SEED_MODULUS: int = 2147483647
const ANATOMY_LOCK_PROMPT: String = (
	"Preserve the recognizable identity and overall species family of the reference pet. "
	+ "Gene traits selected by code may transform, extend or stylize body parts even when "
	+ "the result is unusual for the species. Keep every requested Gene trait on the same "
	+ "coherent creature with readable attachment and a believable fantasy silhouette."
)
const ANATOMY_NEGATIVE_PROMPT: String = (
	"second body, accidental duplicate body parts, malformed anatomy, deformed anatomy, "
	+ "impossible broken joint, detached body part"
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

	return build_stage_regenerate_request(
		identity,
		previous_genome,
		mutated_genome,
		[
			delta,
		],
		source_visual,
		target_stage,
		scene_profile,
		{}
	)

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
		return _build_stage_one_gene_edit(
			identity,
			previous_genome,
			mutated_genome,
			delta,
			visual,
			source_visual,
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
		+ "_pethome_v16_habitat_frame_stage_%d"
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

	return build_stage_regenerate_request(
		identity,
		current_genome,
		current_genome,
		[],
		source_visual,
		target_stage,
		scene_profile,
		{}
	)

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

	var positive_prompt := (
		_stage_two_base_prompt(
			identity
		)
		+ " No new Gene mutation."
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = _stage_two_simple_negative()
	request.source_image_path = source_visual.image_path
	request.target_region = NATURAL_TARGET_REGION
	request.edit_strength = STAGE_TWO_EDIT_STRENGTH
	request.seed = _request_seed(
		identity,
		target_stage,
		&"natural_stage_2"
	)
	request.output_key = _stage_one_output_key(
		identity,
		target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Stage 1 -> 2 Natural image-edit request không hợp lệ.",
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


func build_composite_request(
	identity: PetIdentity,
	previous_genome: PetGenome,
	target_genome: PetGenome,
	deltas: Array[EvolutionDelta],
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile = null,
	mythic_resolution: Dictionary = {}
) -> Dictionary:
	if (
		identity == null
		or previous_genome == null
		or target_genome == null
		or source_visual == null
		or not identity.is_valid()
		or not previous_genome.is_valid()
		or not target_genome.is_valid()
		or not source_visual.is_valid()
		or target_stage != previous_genome.stage() + 1
		or target_genome.stage() != previous_genome.stage()
		or source_visual.pet_id != identity.pet_id()
	):
		return {
			"ok": false,
			"error": "Dữ liệu composite evolution không hợp lệ.",
		}

	if (
		source_visual.image_path.is_empty()
		or not FileAccess.file_exists(
			source_visual.image_path
		)
	):
		return {
			"ok": false,
			"error": "Không tìm thấy ảnh PetHome nguồn cho composite evolution.",
		}

	if scene_profile != null:
		if (
			not scene_profile.is_valid()
			or scene_profile.element
				!= identity.element()
		):
			return {
				"ok": false,
				"error": "PetHome Scene Profile composite không hợp lệ.",
			}

	return build_stage_regenerate_request(
		identity,
		previous_genome,
		target_genome,
		deltas,
		source_visual,
		target_stage,
		scene_profile,
		mythic_resolution
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

	if (
		previous_genome.stage() == 1
		and target_stage == 2
	):
		if deltas.size() > 1:
			return {
				"ok": false,
				"error": "Stage 1 không được có nhiều hơn một Gene delta.",
			}

		var base_plan := (
			build_natural_request(
				identity,
				previous_genome,
				source_visual,
				target_stage,
				scene_profile
			)
			if deltas.is_empty()
			else build_request(
				identity,
				previous_genome,
				target_genome,
				deltas[0],
				source_visual,
				target_stage,
				scene_profile
			)
		)

		if (
			not bool(
				base_plan.get(
					"ok",
					false
				)
			)
			or not mythic_active
		):
			return base_plan

		var stage_two_request := base_plan.get(
			"request"
		) as PetRenderRequest

		if stage_two_request == null:
			return {
				"ok": false,
				"error": "Stage 2 composite request bị rỗng.",
			}

		_apply_mythic_prompt(
			stage_two_request,
			mythic_resolution
		)
		stage_two_request.target_region = COMPOSITE_MYTHIC_TARGET_REGION
		stage_two_request.edit_strength = maxf(
			stage_two_request.edit_strength,
			STAGE_TWO_EDIT_STRENGTH
		)
		stage_two_request.seed = _request_seed(
			identity,
			target_stage,
			_composite_seed_key(
				deltas,
				mythic_resolution
			)
		)

		return base_plan

	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile cho composite evolution.",
		}

	var stage_detail := _element_stage_prompt(
		identity.element(),
		target_stage
	)

	if stage_detail.is_empty():
		return {
			"ok": false,
			"error": "Thiếu Element Stage profile cho composite evolution.",
		}

	var phenotype := PhenotypePromptBuilder.new()
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
		"\n\n[SOURCE PHENOTYPE]\n"
		+ phenotype.describe(
			previous_genome
		)
		+ "\n\n[TARGET PHENOTYPE]\n"
		+ phenotype.describe(
			target_genome
		)
	)

	var visual_catalog := MutationVisualCatalog.new()
	var visuals := visual_catalog.load_default()
	var edit_strength := NATURAL_EDIT_STRENGTH

	if not deltas.is_empty():
		positive_prompt += (
			"\n\n[CODE-LOCKED GENE CHANGES]\n"
			+ "Apply every Gene change below in this same evolution. "
			+ "Do not drop one selected locus and do not invent a combined trait that is not listed."
		)

		for delta in deltas:
			if (
				delta == null
				or not delta.is_valid()
			):
				return {
					"ok": false,
					"error": "Composite evolution có Gene delta không hợp lệ.",
				}

			var visual := visual_catalog.find_by_id(
				visuals,
				delta.mutation_id()
			)

			if visual == null:
				return {
					"ok": false,
					"error": "Thiếu visual definition cho %s."
					% String(
						delta.mutation_id()
					),
				}

			edit_strength = maxf(
				edit_strength,
				visual.edit_strength()
			)
			positive_prompt += (
				"\n- %s: %s %s"
				% [
					String(
						delta.target_trait()
					),
					visual.instruction(),
					visual.preserve_hint(),
				]
			)

	positive_prompt += (
		"\n\n[ELEMENTAL DETAIL PROGRESSION]\n"
		+ stage_detail
		+ " This stage detail may refine existing surfaces but may not override the code-selected Gene or Mythic plan."
	)

	if mythic_active:
		edit_strength = maxf(
			edit_strength,
			MYTHIC_EDIT_STRENGTH
		)
		positive_prompt += (
			"\n\n[CODE-LOCKED MYTHIC DESTINY]\n"
			+ "Mythical beast: "
			+ String(
				mythic_resolution.get(
					"display_name",
					""
				)
			)
			+ ". "
			+ String(
				mythic_resolution.get(
					"prompt",
					""
				)
			)
			+ " "
			+ String(
				mythic_resolution.get(
					"preserve_hint",
					""
				)
			)
			+ " This Mythic branch was selected by code. Do not replace it with another mythical creature or mix branches."
		)

	positive_prompt += _anatomy_lock_section()
	positive_prompt += _pethome_scale_lock_section()
	positive_prompt += (
		"\n\n[PETHOME CONTINUITY]\n"
		+ _scene_continuity_prompt(
			scene_profile
		)
		+ " Keep this the same individual in the same world and framing. "
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
		+ ", unrelated gene trait, random mutation, wrong mythical creature, mixed mythical branches, "
		+ "redesigned species, different pet identity, changed PetHome world"
	)
	request.source_image_path = source_visual.image_path
	request.target_region = (
		COMPOSITE_MYTHIC_TARGET_REGION
		if mythic_active
		else COMPOSITE_GENE_TARGET_REGION
	)
	request.edit_strength = edit_strength
	request.seed = _request_seed(
		identity,
		target_stage,
		_composite_seed_key(
			deltas,
			mythic_resolution
		)
	)
	request.output_key = _stage_one_output_key(
		identity,
		target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Composite evolution render request không hợp lệ.",
		}

	return {
		"ok": true,
		"schema": PLAN_SCHEMA,
		"request": request,
	}


func _apply_mythic_prompt(
	request: PetRenderRequest,
	mythic_resolution: Dictionary
) -> void:
	var prompt := String(
		mythic_resolution.get(
			"prompt",
			""
		)
	).strip_edges()

	if prompt.is_empty():
		return

	request.positive_prompt += (
		" Fantasy mutation: "
		+ prompt
	)
	request.negative_prompt += (
		", unrelated fantasy mutation, mixed mutation branches"
	)


func _composite_seed_key(
	deltas: Array[EvolutionDelta],
	mythic_resolution: Dictionary
) -> StringName:
	var parts: Array[String] = [
		"composite",
	]

	for delta in deltas:
		if delta == null:
			continue
		parts.append(
			String(
				delta.mutation_id()
			)
		)

	var mythic_id := String(
		mythic_resolution.get(
			"mutation_id",
			""
		)
	)

	if not mythic_id.is_empty():
		parts.append(
			mythic_id
		)

	return StringName(
		"_".join(
			parts
		)
	)


func build_stage_regenerate_request(
	identity: PetIdentity,
	previous_genome: PetGenome,
	target_genome: PetGenome,
	deltas: Array[EvolutionDelta],
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile = null,
	mythic_resolution: Dictionary = {}
) -> Dictionary:
	if (
		identity == null
		or previous_genome == null
		or target_genome == null
		or source_visual == null
		or not identity.is_valid()
		or not previous_genome.is_valid()
		or not target_genome.is_valid()
		or not source_visual.is_valid()
		or source_visual.pet_id != identity.pet_id()
		or target_stage != previous_genome.stage() + 1
		or target_genome.stage() != previous_genome.stage()
	):
		return {
			"ok": false,
			"error": "Dữ liệu full-regenerate evolution không hợp lệ.",
		}

	if scene_profile != null:
		if (
			not scene_profile.is_valid()
			or scene_profile.element != identity.element()
		):
			return {
				"ok": false,
				"error": "PetHome Scene Profile full-regenerate không hợp lệ.",
			}

	if target_stage >= 3:
		return _build_reference_stage_request(
			identity,
			previous_genome,
			target_genome,
			deltas,
			source_visual,
			target_stage,
			scene_profile,
			mythic_resolution
		)

	var stage_one_detail := _element_stage_prompt(
		identity.element(),
		1
	)
	var target_stage_detail := _element_stage_prompt(
		identity.element(),
		target_stage
	)

	if (
		stage_one_detail.is_empty()
		or target_stage_detail.is_empty()
	):
		return {
			"ok": false,
			"error": "Thiếu Element Stage profile cho full-regenerate.",
		}

	var species_profile := _species_profile(
		identity.species()
	)

	if species_profile == null:
		return {
			"ok": false,
			"error": "Thiếu species profile cho full-regenerate.",
		}

	var phenotype := PhenotypePromptBuilder.new().describe(
		target_genome
	)
	var positive_prompt := ""

	if target_stage == 2:
		positive_prompt = (
			"Create one slightly older "
			+ String(identity.species())
			+ " pet. Element: "
			+ PetElementCatalog.prompt_name(
				identity.element()
			)
			+ ". "
			+ "Premium fantasy game character art, painterly fantasy game art, evolved chibi proportions, "
			+ "juvenile-to-adolescent fantasy character design language, slight chibi, species-appropriate anatomy, "
			+ "soft fur and a simple readable design. "
			+ "Element traits: "
			+ _simple_element_traits(
				identity.element()
			)
			+ " Stage 2. Juvenile-to-adolescent fantasy "
			+ String(identity.species())
			+ ". "
			+ "Make the pet clearly older and more developed than Stage 1 while keeping the same art direction: "
			+ "noticeably larger overall body, taller body, longer legs, a more developed chest and torso, "
			+ "fuller layered fur around the chest, cheeks and tail, and a face that is less baby-like while still cute and youthful. "
			+ "Use evolved chibi proportions: keep the head expressive, but reduce the tiny-kitten body proportions from Stage 1. "
			+ species_profile.species_anatomy
			+ " "
			+ "Prioritize distinct body proportions and readable selected Gene features before elemental glow. Use "
			+ "localized markings and separated elemental accents that do not obscure anatomy."
		)
	else:
		positive_prompt = (
			"Create a NEW image for evolution Stage %d. "
			+ "Do not copy, trace or image-edit the previous stage. "
			+ "This must visibly look older and more developed than Stage %d. "
			+ "Preserve the same pet lineage: species, elemental color family, face language, "
			+ "forehead lineage sigil, surface motif language and the code-authorized appendage layout. "
			+ "Use the same deterministic lineage seed so the new image still reads as the same individual design family. "
		) % [
			target_stage,
			previous_genome.stage(),
		]

		positive_prompt += (
			"Stage 1 ancestry cues: "
			+ stage_one_detail
			+ " Target stage morphology: "
			+ target_stage_detail
			+ " "
			+ species_profile.species_anatomy
			+ " "
			+ species_profile.freestyle_pose
		)

		positive_prompt += (
			" Target phenotype from game code: "
			+ phenotype
			+ "."
		)

	if not deltas.is_empty():
		positive_prompt += (
			" Apply only these Gene changes selected by code:"
		)

		for delta in deltas:
			if (
				delta == null
				or not delta.is_valid()
			):
				return {
					"ok": false,
					"error": "Full-regenerate có Gene delta không hợp lệ.",
				}

			positive_prompt += (
				" Locus %s changes from %s to %s."
				% [
					String(
						delta.target_trait()
					),
					String(
						delta.from_trait()
					),
					String(
						delta.to_trait()
					),
				]
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

	if mythic_active:
		positive_prompt += (
			" Special fantasy mutation is ACTIVE because game conditions were met: "
			+ String(
				mythic_resolution.get(
					"display_name",
					""
				)
			)
			+ ". "
			+ String(
				mythic_resolution.get(
					"prompt",
					""
				)
			)
			+ " "
			+ String(
				mythic_resolution.get(
					"preserve_hint",
					""
				)
			)
		)
	else:
		positive_prompt += (
			" No special fantasy mutation is active as a Mythic branch. "
			+ "Do not add anatomy that is absent from the species profile, target phenotype and code-selected normal mutations."
		)

	if target_stage == 2:
		positive_prompt += (
			" Rebuild a complete PetHome habitat matching the same element and canonical scene profile. "
			+ _scene_rebuild_prompt(scene_profile)
			+ " Exactly one pet. Full body visible from head to tail, including feet and all visible appendages. "
			+ _stage_two_composition_prompt()
			+ " Keep the pet physically grounded with a soft natural contact shadow. "
			+ "Keep the design simple enough for later evolution. No text or UI."
		)
	else:
		positive_prompt += (
			" Create a complete natural fantasy PetHome environment matching the "
			+ PetElementCatalog.prompt_name(
				identity.element()
			)
			+ " element. "
			+ _scene_rebuild_prompt(
				scene_profile
			)
			+ " Exactly one pet. Full body visible from head to tail. "
			+ _stage_two_composition_prompt()
			+ " Keep the pet physically grounded with a soft natural contact shadow. "
			+ "No text or UI."
		)

	var negative_prompt := (
		"extra tail, duplicate tail, split tail, extra limb, extra ear, multiple pets, "
		+ "close-up portrait, extreme close-up, bust shot, pet filling the entire frame, pet taller than 64 percent of image height, tiny distant pet, pet smaller than 45 percent of image height, humanoid pose, "
		+ "cropped ears, cropped feet, cropped body, cropped tail, floating pet, missing contact with ground, "
		+ "plain white background, white studio background, gray studio background, empty backdrop, transparent backdrop, product photo, missing environment, "
		+ "heavy accessories, text, UI, logo, watermark"
	)

	if target_stage == 2:
		negative_prompt += (
			", fully adult form, old animal, tiny infant proportions, baby body, "
			+ "drastic redesign, different species, different element"
		)
	else:
		negative_prompt += (
			", same-age copy of previous stage, unchanged kitten proportions, image-edit look"
		)

	if not mythic_active:
		negative_prompt += (
			", accidental duplicate body parts unrelated to requested Gene"
		)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = negative_prompt
	request.seed = max(
		1,
		posmod(
			identity.lineage_seed(),
			SEED_MODULUS
		)
	)
	request.output_key = (
		identity.pet_id()
		+ "_pethome_v15_stage_%d"
		% target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Evolution full-regenerate request không hợp lệ.",
		}

	return {
		"ok": true,
		"schema": PLAN_SCHEMA,
		"request": request,
	}


func _build_reference_stage_request(
	identity: PetIdentity,
	previous_genome: PetGenome,
	target_genome: PetGenome,
	deltas: Array[EvolutionDelta],
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile,
	mythic_resolution: Dictionary
) -> Dictionary:
	if (
		source_visual.image_path.is_empty()
		or not FileAccess.file_exists(
			source_visual.image_path
		)
	):
		return {
			"ok": false,
			"error": "Không tìm thấy ảnh Stage trước để làm reference.",
		}

	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile cho reference evolution.",
		}

	var phenotype := PhenotypePromptBuilder.new().describe(
		target_genome
	)
	var positive_prompt := (
		"[REFERENCE EVOLUTION RULE]\n"
		+ "Use the supplied previous-stage image as the canonical reference for this exact pet. "
		+ "Evolve the same individual into the next life stage. Preserve recognizable face, species, elemental palette and authorized appendage count. Rebuild proportions and contour according to the target morphology and accumulated Genes. "
		+ "Stage progression authorizes natural maturation and a new readable pose, but not unearned mythical anatomy."
	)

	positive_prompt += (
		"\n\n[GENE-ONLY PET CHANGE]\n"
		+ "Natural maturation develops the inherited frame; scored Genes direct its individual form. "
		+ "The structural Gene deltas below plus the [ACCUMULATED GENE SCORE PHENOTYPE] section appended to this request are the complete Gene authority. "
		+ "Use the reference for identity, not as a pose or proportion stencil. Unlisted traits mature naturally without adding new Gene directions. Structure Genes coordinate body proportions, stance and fur contours. "
		+ "For listed loci, total Gene score controls expression strength: preserve existing expression, strengthen it when the score tier requires it, and blend secondary scored directions without inventing a direction that is absent. "
		+ "Target phenotype bookkeeping: "
		+ phenotype
		+ "."
	)

	var visual_catalog := MutationVisualCatalog.new()
	var visuals := visual_catalog.load_default()
	var edit_strength := NATURAL_EDIT_STRENGTH

	if deltas.is_empty():
		positive_prompt += (
			"\nNo new structural Gene delta is selected for this transition. "
			+ "Develop the inherited frame to the target age and mature accumulated Gene features; do not invent new Gene directions."
		)
	else:
		positive_prompt += "\nCurrent transition Gene deltas:"

		for delta in deltas:
			if delta == null or not delta.is_valid():
				return {
					"ok": false,
					"error": "Reference evolution có Gene delta không hợp lệ.",
				}

			var visual := visual_catalog.find_by_id(
				visuals,
				delta.mutation_id()
			)

			if visual == null:
				return {
					"ok": false,
					"error": "Thiếu visual definition cho %s."
					% String(delta.mutation_id()),
				}

			edit_strength = maxf(
				edit_strength,
				visual.edit_strength()
			)
			positive_prompt += (
				"\n- Locus %s: %s %s"
				% [
					String(delta.target_trait()),
					visual.instruction(),
					visual.preserve_hint(),
				]
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

	if mythic_active:
		edit_strength = maxf(
			edit_strength,
			MYTHIC_EDIT_STRENGTH
		)
		positive_prompt += (
			"\n\n[CODE-LOCKED MYTHIC RESULT]\n"
			+ "This Mythic result is allowed only because game code resolved it from the pet's Gene history: "
			+ String(mythic_resolution.get("display_name", ""))
			+ ". "
			+ String(mythic_resolution.get("prompt", ""))
			+ " "
			+ String(mythic_resolution.get("preserve_hint", ""))
			+ " Do not substitute another Mythic branch or add unrelated mutation anatomy."
		)
	else:
		positive_prompt += (
			"\n\n[NO MYTHIC OVERRIDE]\n"
			+ "No Mythic anatomy is authorized. Do not invent horns, wings, extra tails or other special mutation anatomy."
		)

	positive_prompt += (
		"\n\n[PETHOME ENVIRONMENT LOCK]\n"
		+ "Element family: "
		+ PetElementCatalog.prompt_name(identity.element())
		+ ". "
		+ _scene_continuity_prompt(scene_profile)
		+ " The environment is NOT part of the evolution. Preserve the same habitat identity, ground plane, lighting direction, camera family and overall environmental composition from the reference image. "
		+ "Do not alter pet anatomy merely to express the element."
	)

	positive_prompt += _pethome_scale_lock_section()

	positive_prompt += (
		" Keep the pet physically grounded with a soft natural contact shadow. "
		+ "Return ONE complete pet + habitat portrait with no text, UI, logo or watermark."
	)

	var negative_prompt := _append_negative_guard(
		style.negative_prompt()
		+ ", different pet identity, unrelated gene trait, random mutation, unauthorized body redesign, "
		+ "wrong mythical creature, mixed mythical branches, extra pet, text, UI, logo, watermark"
	)

	if not mythic_active:
		negative_prompt += ", accidental duplicate body parts unrelated to requested Gene"

	var request := PetRenderRequest.new()
	request.mode = PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = negative_prompt
	request.source_image_path = source_visual.image_path
	request.target_region = (
		COMPOSITE_MYTHIC_TARGET_REGION
		if mythic_active
		else COMPOSITE_GENE_TARGET_REGION
	)
	request.edit_strength = edit_strength
	request.seed = _request_seed(
		identity,
		target_stage,
		_composite_seed_key(
			deltas,
			mythic_resolution
		)
	)
	request.output_key = _stage_one_output_key(
		identity,
		target_stage
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Reference evolution image-edit request không hợp lệ.",
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
		and mode_value
			!= int(
				PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
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

		int(
			PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
		):
			request.mode = (
				PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
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


func _build_stage_one_gene_edit(
	identity: PetIdentity,
	previous_genome: PetGenome,
	mutated_genome: PetGenome,
	delta: EvolutionDelta,
	visual: MutationVisualDefinition,
	source_visual: PetVisualRecord,
	target_stage: int,
	scene_profile: PetSceneProfile
) -> Dictionary:
	var positive_prompt := (
		_stage_two_base_prompt(
			identity
		)
		+ " Selected Gene change: "
		+ visual.instruction()
	)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = _stage_two_simple_negative()
	request.source_image_path = source_visual.image_path
	request.target_region = COMPOSITE_GENE_TARGET_REGION
	request.edit_strength = maxf(
		STAGE_TWO_EDIT_STRENGTH,
		visual.edit_strength()
	)
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
			"error": "Stage 1 -> 2 Gene image-edit request không hợp lệ.",
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


func _stage_one_to_two_lineage_prompt(
	identity: PetIdentity
) -> String:
	var stage_one := _element_stage_prompt(
		identity.element(),
		1
	)
	var stage_two := _element_stage_prompt(
		identity.element(),
		2
	)

	if (
		stage_one.is_empty()
		or stage_two.is_empty()
	):
		return ""

	return (
		"[LINEAGE CONTINUITY]\n"
		+ "The Stage 1 source image is the canonical individual identity. Preserve its unique face, fur pattern, markings and recognizable details. "
		+ "Its element-family identity was established with these Stage 1 cues: "
		+ stage_one
		+ " Do not reset these cues or replace them with a new random face."
		+ "\n\n[STAGE 2 MORPHOLOGY]\n"
		+ stage_two
		+ " Apply this as maturation of the same individual. It may change age-appropriate proportions and elemental shape language, "
		+ "but it must preserve the source pet's personal identity and previously established details unless a code-selected Gene explicitly changes them."
	)


func _stage_two_base_prompt(
	identity: PetIdentity
) -> String:
	return (
		"Evolve the exact same cat from Stage 1 to Stage 2 using the reference image. "
		+ "Keep the same individual face, fur pattern, element colors and exactly one tail. "
		+ "Make it slightly older and more developed. "
		+ "Painterly fantasy game art, slight chibi, natural feline anatomy. "
		+ "Element: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ ". "
		+ _simple_element_traits(
			identity.element()
		)
		+ " Preserve the element-themed PetHome habitat from the reference image. Full body visible. "
		+ "Keep the complete pet in the lower-middle area at about 50 to 56 percent of image height. "
		+ "Leave generous environment visible above and around the pet and keep the upper 30 percent calm for UI. "
		+ "Keep the pet grounded with a soft contact shadow. No text or UI."
	)


func _stage_two_simple_negative() -> String:
	return (
		"different individual, identity drift, extra tail, duplicate tail, split tail, "
		+ "extra leg, extra ear, multiple pets, close-up portrait, pet filling the frame, "
		+ "oversized pet, humanoid pose, heavy accessories, text, UI, logo, watermark"
	)


func _simple_element_traits(
	element: StringName
) -> String:
	match element:
		&"wood":
			return (
				"soft cream and warm light-brown fur with fresh green accents, "
				+ "small living sprouts growing naturally from the head and ear fur, "
				+ "leaf-like fur tufts, layered leafy chest fluff, "
				+ "subtle vine-like markings blended into the coat, "
				+ "and a soft bud-shaped leafy tail tip. "
				+ "Plant features should look naturally grown as part of the pet, "
				+ "not like loose leaves stuck onto the fur"
			)

		&"earth":
			return (
				"warm cream, beige and earthy brown fur with subtle mineral tones, "
				+ "small smooth pebbles and polished natural crystals emerging gently from the fur, "
				+ "especially around the forehead, chest and back, "
				+ "soft stone-like markings blended into the coat and a grounded fluffy silhouette. "
				+ "Mineral details should feel organically embedded in the body design, "
				+ "not like rocks randomly thrown onto the pet"
			)

		&"fire":
			return (
				"soft cream, peach and warm orange fur with glowing ember accents, "
				+ "small controlled flames naturally forming at the ear tips and tail tip, "
				+ "subtle glowing flame-shaped markings on the forehead and cheeks, "
				+ "and delicate warm ember lines flowing through the fur. "
				+ "Fire should feel like magical living fur energy, "
				+ "not like the pet is burning uncontrollably"
			)

		&"light":
			return (
				"soft ivory and warm pearl-white fur with pale golden accents, "
				+ "a small luminous star-shaped forehead mark, "
				+ "soft golden light woven naturally through the ear fur and tail, "
				+ "a restrained elegant halo-like glow around the silhouette, "
				+ "and tiny gentle light particles. "
				+ "The light should feel soft, pure and magical, not overly bright or angelic"
			)

		&"metal":
			return (
				"silver-white and very pale cool-gray fur with clean icy-blue accents, "
				+ "small polished metallic crystal facets growing naturally from the forehead and fur, "
				+ "subtle silver leaf-like plates blended into the chest and leg fur, "
				+ "fine metallic strands around the tail and a refined cool reflective sheen. "
				+ "Metal details should feel elegant and organically integrated, "
				+ "not like armor or mechanical equipment"
			)

		&"water":
			return (
				"pearl-white and soft aqua fur with clear turquoise accents, "
				+ "small translucent water-drop crystals naturally forming on the forehead and fur, "
				+ "soft wave-like fur tufts, flowing aqua gradients along the cheeks and tail, "
				+ "and a few delicate suspended bubbles and droplets. "
				+ "Water should feel naturally infused into the fur and body, "
				+ "not like the pet is simply wet"
			)

		&"dark":
			return (
				"smoky blue-black, charcoal-indigo and muted violet fur with restrained cyan-violet highlights, "
				+ "a subtle crescent or astral forehead mark, "
				+ "soft shadow-like fur gradients, faint luminous eye accents, "
				+ "restrained mist woven around the tail and silhouette, "
				+ "and a few elegant dark magical markings blended into the coat. "
				+ "Dark energy should feel mysterious and integrated into the pet, "
				+ "not like galaxy texture or random purple effects covering the body"
			)

		_:
			return "Soft elemental accents."


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
		"Use a vertical 9:16 medium-wide environmental character shot with the camera pulled back, never a close-up, product portrait or character showcase shot. "
		+ "The pet is the main composition and clear focal subject; the habitat remains complete but visually secondary around it. "
		+ "Keep the complete pet comfortably inside the frame from head to tail, including feet and all visible appendages. "
		+ "LOCKED PETHOME SCALE: the visible pet height should occupy about 50 to 56 percent of total image height. "
		+ "Place the pet in the lower-middle area, centered slightly below the vertical midpoint. "
		+ "Place the lowest visible pet point around 88 to 92 percent of total image height and the highest visible pet point around 34 to 42 percent. "
		+ "Do not enlarge the pet because it is older; Stage progression changes anatomy, proportions, fur maturity and elemental detail, not on-screen character size. "
		+ "Keep about 40 to 48 percent of the image reading clearly as environment, with foreground, midground and background depth. "
		+ "Leave generous environmental space around the silhouette and keep the upper 30 percent calm and low-detail for UI, especially the upper-left status area. "
		+ "Keep the pet physically grounded on a readable surface with a soft natural contact shadow. "
		+ "Do not zoom in, do not crop ears, feet, body or tail, do not place the paws on the bottom edge, and do not replace the PetHome with a studio backdrop."
	)


func _pethome_scale_lock_section() -> String:
	return (
		"\n\n[PETHOME SCALE LOCK]\n"
		+ _stage_two_composition_prompt()
	)


func _stage_two_negative_prompt() -> String:
	return (
		"close-up portrait, extreme close-up, bust shot, character showcase, character poster, giant pet, oversized character, "
		+ "pet filling the entire frame, pet taller than 64 percent of image height, tiny distant pet, pet smaller than 45 percent of image height, "
		+ "cropped ears, cropped feet, cropped body, cropped tail, floating pet, missing contact with ground, "
		+ "plain white background, white studio background, gray studio background, transparent backdrop, empty backdrop, product photo, missing environment, "
		+ "color-swap-only element design, upright bipedal cat, cat standing on two hind legs, anthropomorphic cat pose, humanoid torso, mascot pose, arms, hands, "
		+ "identical silhouette across all elements, duplicated appendage, duplicated body part, "
		+ "malformed species anatomy, impossible joint, detached appendage"
	)


func _stage_one_output_key(
	identity: PetIdentity,
	target_stage: int
) -> String:
	return (
		identity.pet_id()
		+ "_pethome_v15_stage_%d"
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
