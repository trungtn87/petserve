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
		+ ". The AI has broad freedom to invent this individual pet. "
		+ "Do not reuse a fixed template, fixed face, fixed fur pattern or fixed silhouette from another pet."
	)

	spec.style_section = (
		style.base_style()
		+ " Use the element only as creative visual inspiration: "
		+ style.accent_for(
			identity.element()
		)
		+ ". Freely decide how those elemental cues appear on this individual."
	)

	spec.form_section = (
		"Stage 1 is a young "
		+ String(identity.species())
		+ ". Keep believable species anatomy, but otherwise let the AI freely invent the exact individual: "
		+ "fur pattern, fluff, small asymmetries, expression and a natural animal pose. "
		+ "Elemental details should feel organically part of the animal rather than pasted-on accessories."
		+ "\n\n[STAGE 1 ELEMENTAL IDENTITY CUES]\n"
		+ stage_one_face
		+ " These are lineage anchors for this element, not a fixed character template. "
		+ "Preserve room for individual variation inside these cues so different pets of the same element still look unique."
	)

	spec.scene_section = (
		"Create a natural environmental background that belongs to the same "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ " world. Use these scene descriptors only as loose inspiration, not as a rigid layout: "
		+ scene_profile.environment_theme
		+ "; "
		+ scene_profile.palette_description
		+ "; "
		+ scene_profile.lighting_theme
		+ ". The AI may freely invent the scenery, depth, plants, rocks, atmosphere and lighting as long as the element feels coherent."
	)

	spec.composition_section = (
		"Generate exactly one pet in one continuous natural environment. "
		+ "The pet and background must be one coherent scene, not separate assets, collage or character sheet."
	)

	spec.ui_safe_section = (
		"Render a full-bleed vertical 9:16 mobile PetHome scene that fills the screen edge to edge. "
		+ "Use a wide environmental composition rather than a close-up portrait. "
		+ "Keep the whole pet comfortably visible at about 35 percent of total image height, centered around the lower-middle of the frame. "
		+ "Keep the ground contact around 90 percent of image height so there is scenic space below the paws. "
		+ "Leave the upper 24 to 28 percent calm and low-detail for UI. "
		+ "The background should remain clearly visible around the pet with foreground, midground and background depth. "
		+ "Do not draw UI, text, labels, icons, frames or interface elements into the artwork."
	)

	spec.future_space_section = (
		"This is an early-life form. Keep it visually simple enough to evolve later, "
		+ "but do not force a predetermined face, silhouette, ornament placement or body design. "
		+ "Uniqueness between different pets is desirable."
	)

	spec.negative_prompt = (
		style.negative_prompt()
		+ ", fixed template character, repeated identical pet design, repeated identical face, repeated identical fur pattern"
		+ ", plain studio background, empty neutral backdrop, isolated character on blank background"
		+ ", split image, collage, character sheet, duplicated pet, multiple pets"
		+ ", close-up portrait, bust shot, giant pet filling the frame, cropped ears, cropped paws, cropped tail"
		+ ", humanoid pose, standing upright like a person, text, labels, UI, buttons, interface panels"
	)

	if not spec.is_valid():
		return null

	return spec
