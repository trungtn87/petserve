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

	var spec := InitialPetVisualSpec.new()

	spec.pet_id = identity.pet_id()
	spec.style_id = style.style_id()

	spec.identity_section = (
		"Create one young "
		+ String(identity.species())
		+ " pet. Element: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ "."
	)

	spec.style_section = (
		"Painterly fantasy game art, slight chibi, natural feline anatomy, soft fur and a simple readable design. "
		+ "Element traits: "
		+ _simple_element_traits(
			identity.element()
		)
	)

	spec.form_section = (
		"Stage 1. Normal feline anatomy: four legs total, two ears and exactly one tail total. "
		+ "Keep fantasy details subtle."
	)

	spec.scene_section = (
		"Simple natural fantasy background matching the same element. "
		+ "Keep it uncluttered and atmospheric."
	)

	spec.composition_section = (
		"Exactly one pet. Full body visible."
	)

	spec.ui_safe_section = (
		"Vertical 9:16 mobile scene. "
		+ "Pet about 25 to 30 percent of image height in the lower third. "
		+ "Background occupies most of the image. "
		+ "Keep the upper area calm for UI. No text or UI."
	)

	spec.future_space_section = (
		"Keep the design simple enough for later evolution."
	)

	spec.negative_prompt = (
		"extra tail, duplicate tail, split tail, extra limb, extra ear, multiple pets, "
		+ "close-up portrait, pet filling the frame, oversized pet, humanoid pose, "
		+ "heavy accessories, text, UI, logo, watermark"
	)

	if not spec.is_valid():
		return null

	return spec


func _simple_element_traits(
	element: StringName
) -> String:
	match element:
		&"metal":
			return "silver-gray fur with pale cyan crystal accents."
		&"wood":
			return "warm tan fur with soft green leaf accents."
		&"water":
			return "pearl-white and aqua fur with light water or mist accents."
		&"fire":
			return "warm cream fur with restrained orange-red flame accents."
		&"earth":
			return "sand-brown fur with subtle stone or mineral accents."
		&"dark":
			return "smoky blue-black and violet fur with soft shadow or mist accents."
		&"light":
			return "ivory-white fur with soft gold light accents."
		_:
			return "soft elemental accents."
