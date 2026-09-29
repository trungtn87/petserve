class_name InitialPetVisualSpecBuilder
extends RefCounted


const PetSceneProfileFactoryScript = preload(
	"res://features/evolution/domain/pet_scene_profile_factory.gd"
)


func build(
	identity: PetIdentity,
	genome: PetGenome,
	style: MythicStyleProfile,
	species_profile: InitialSpeciesProfile,
	scene_profile = null
) -> InitialPetVisualSpec:
	if (
		identity == null
		or genome == null
		or style == null
		or species_profile == null
	):
		return null

	if scene_profile == null:
		scene_profile = (
			PetSceneProfileFactoryScript.new()
			.create_initial(identity)
		)

	if (
		not identity.is_valid()
		or not genome.is_valid()
		or not style.is_valid()
		or not species_profile.is_valid()
		or scene_profile == null
		or not scene_profile.is_valid()
	):
		return null

	if identity.species() != species_profile.species:
		return null

	if identity.element() != scene_profile.element:
		return null

	if genome.stage() != 1:
		return null

	if not is_equal_approx(
		genome.body_growth(),
		0.0
	):
		return null

	if not genome.mutation_ids().is_empty():
		return null

	for key_value in genome.traits_snapshot().keys():
		var key := StringName(str(key_value))

		if genome.get_trait(key) != &"base":
			return null

	var stage_catalog := ElementStageVisualCatalog.new()
	var element_profile := stage_catalog.find_by_element(
		stage_catalog.load_default(),
		identity.element()
	)
	var stage_one_face := stage_catalog.prompt_for_stage(
		element_profile,
		1
	)

	if stage_one_face.is_empty():
		return null

	var spec := InitialPetVisualSpec.new()

	spec.pet_id = identity.pet_id()
	spec.style_id = style.style_id()

	spec.identity_section = (
		"Create the first visual form of one unique pet individual. "
		+ "Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ ". This Stage 1 image establishes the canonical face identity and elemental lineage "
		+ "that later stages inherit. The pet and PetHome environment must be rendered together "
		+ "as one coherent scene, not as separate assets."
	)

	spec.style_section = (
		style.base_style()
		+ " Element lineage appearance: "
		+ style.accent_for(
			identity.element()
		)
		+ "."
	)

	spec.form_section = (
		species_profile.infant_form
		+ " Stage 1 elemental face identity: "
		+ stage_one_face
		+ " Keep the body clearly infant and compact. Element differences at this stage should "
		+ "be strongest in face shape language, eye design, ear silhouette, cheek/forehead fur, "
		+ "lineage sigil and restrained tail cues. The seven elements must not look like simple "
		+ "recolors of one identical kitten; their faces should remain distinguishable in grayscale."
	)

	spec.scene_section = (
		"PetHome environment: "
		+ scene_profile.environment_theme
		+ ". Shared palette: "
		+ scene_profile.palette_description
		+ ". Lighting: "
		+ scene_profile.lighting_theme
		+ ". Repeating world motif: "
		+ scene_profile.motif_description
		+ ". Scene identity seed: "
		+ str(scene_profile.scene_seed)
		+ ". Keep the environment supportive and atmospheric, but the pet remains the clear focal point."
	)

	spec.composition_section = (
		species_profile.composition
		+ " Generate exactly one pet in exactly one continuous PetHome environment. "
		+ "Do not create a split image, collage, character sheet or separate background panel."
	)

	spec.ui_safe_section = (
		"Render a full-bleed vertical 9:16 mobile PetHome scene, designed to fill the entire game screen edge to edge. "
		+ "Use an environmental establishing shot, never a close-up portrait, medium shot or character showcase. Show the pet's complete body from the highest visible point of the ears or fur to every paw and the full tail. "
		+ "LOCKED COMPOSITION: the pet's visible full-body height must be about 35 percent of the total image height. Measure from the highest visible point of the pet to the lowest paw/ground contact point. "
		+ "Place the lowest paw/ground contact point at about 90 percent of the total image height, leaving about 10 percent of the image height from the pet's feet to the bottom edge. "
		+ "Keep the pet horizontally near the center and vertically in the lower-middle of the scene. Do not change on-screen pet scale by life stage; later stages show maturity through anatomy, proportions, fur and elemental detail, not by occupying more of the frame. "
		+ "Leave roughly the upper 24 to 28 percent of the image calm and low-detail for the compact PetHome status card. Keep the bottom 10 percent scenic and unobstructed. "
		+ "The environment must remain the dominant visual context with clear foreground, midground and background depth around the pet. "
		+ "Do not let the head, ears, paws or tail touch the image edges. "
		+ "Extend the environment naturally to every edge of the image with no border, frame, vignette panel or empty margin. "
		+ "Do not draw any UI, text, labels, icons, frames or interface elements into the artwork."
	)

	spec.future_space_section = (
		"This is the clean infant base form before any mutation. "
		+ "Stage 1 may already have a distinctive elemental face and small lineage-specific fur cues, "
		+ "but it must not use the mature Stage 2 body morphology or advanced Stage 3/4 detail language. "
		+ "Keep enough visual simplicity for later evolution while making the element recognizable without color alone. "
		+ "The PetHome world should remain recognizable in later stages so the same pet feels like it continues living in the same world. "
		+ species_profile.forbidden_advanced_features
	)

	spec.negative_prompt = (
		style.negative_prompt()
		+ ", adult body, mature proportions, Stage 2 body morphology, advanced evolution form, multiple mutation features, overly complex costume, excessive magical effects"
		+ ", generic identical face across all elements, color-swap-only element design, same silhouette for every element"
		+ ", plain studio background, neutral empty background, isolated character on blank background, scenery-free backdrop, split image, collage, character sheet, duplicated pet, multiple pets, text, labels, UI, buttons, interface panels"
		+ ", close-up portrait, medium close shot, bust shot, oversized pet, undersized pet, pet substantially larger or smaller than 35 percent of image height, giant head filling the frame, zoomed-in camera, cropped ears, cropped paws, cropped tail, pet touching the image edges, paws touching the bottom edge, excessive empty floor below the paws"
	)

	if not spec.is_valid():
		return null

	return spec
