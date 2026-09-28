class_name InitialPetVisualSpecBuilder
extends RefCounted


func build(
	identity: PetIdentity,
	genome: PetGenome,
	style: MythicStyleProfile,
	species_profile: InitialSpeciesProfile
) -> InitialPetVisualSpec:
	if (
		identity == null
		or genome == null
		or style == null
		or species_profile == null
	):
		return null

	if (
		not identity.is_valid()
		or not genome.is_valid()
		or not style.is_valid()
		or not species_profile.is_valid()
	):
		return null

	if identity.species() != species_profile.species:
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
		+ ". This image establishes the permanent visual identity that all later evolution images must preserve."
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

	spec.composition_section = (
		species_profile.composition
		+ " Generate only one character."
	)

	spec.future_space_section = (
		"This is the clean infant base form before any mutation. "
		+ "The pet should already look polished, lovable and mythic, but remain visually simple enough for many later evolution steps. "
		+ "Element lineage cues are allowed only as stable base identity: palette, eye color, one small forehead sigil and one restrained tail-centered effect. "
		+ species_profile.forbidden_advanced_features
	)

	spec.negative_prompt = (
		style.negative_prompt()
		+ ", adult body, mature proportions, advanced evolution form, multiple mutation features, overly complex costume, excessive magical effects"
	)

	if not spec.is_valid():
		return null

	return spec
