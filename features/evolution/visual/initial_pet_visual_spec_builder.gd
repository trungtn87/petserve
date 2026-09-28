class_name InitialPetVisualSpecBuilder
extends RefCounted


func build(
	identity: PetIdentity,
	genome: PetGenome,
	style: MythicStyleProfile,
	species_profile: InitialSpeciesProfile,
	scene_profile: PetSceneProfile = null
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
			PetSceneProfileFactory.new()
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

	var spec := InitialPetVisualSpec.new()

	spec.pet_id = identity.pet_id()
	spec.style_id = style.style_id()

	spec.identity_section = (
		"Create the first visual form of one unique pet individual. "
		+ "Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ String(identity.element())
		+ ". This image establishes the permanent visual identity that all later evolution images must preserve. "
		+ "The pet and its PetHome environment must be rendered together as one coherent scene, not as separate assets."
	)

	spec.style_section = (
		style.base_style()
		+ " Element lineage appearance: "
		+ style.accent_for(
			identity.element()
		)
		+ "."
	)

	spec.form_section = species_profile.infant_form

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
		"Design the composition for a portrait mobile PetHome screen. "
		+ "Keep the pet large and readable around the visual center to lower-middle area. "
		+ "Keep the upper area calm and low-detail for name, stage, growth and food UI. "
		+ "Keep the lower edge calm and low-detail for three menu buttons. "
		+ "Do not draw any UI, text, labels, icons, frames or interface elements into the artwork."
	)

	spec.future_space_section = (
		"This is the clean infant base form before any mutation. "
		+ "The pet should already look polished, lovable and mythic, but remain visually simple enough for many later evolution steps. "
		+ "Element lineage cues are allowed only as stable base identity: palette, eye color, one small forehead sigil and one restrained tail-centered effect. "
		+ "The PetHome world should also remain recognizable in later evolution images so the same pet feels like it continues living in the same world. "
		+ species_profile.forbidden_advanced_features
	)

	spec.negative_prompt = (
		style.negative_prompt()
		+ ", adult body, mature proportions, advanced evolution form, multiple mutation features, overly complex costume, excessive magical effects"
		+ ", plain studio background, neutral empty background, isolated character on blank background, no scenery, split image, collage, character sheet, duplicated pet, multiple pets, text, labels, UI, buttons, interface panels"
	)

	if not spec.is_valid():
		return null

	return spec
