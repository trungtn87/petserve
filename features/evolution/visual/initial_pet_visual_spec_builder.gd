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
		"IDENTITY LOCK: create exactly one young fantasy "
		+ String(identity.species())
		+ " pet. ELEMENT LOCK: "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ ". This is not an ordinary real-world "
		+ String(identity.species())
		+ "; the elemental identity must be visible directly on the creature."
	)

	spec.style_section = (
		"Premium polished stylized 3D fantasy game-pet art, collectible character quality, clean readable silhouette, soft cinematic rim light. "
		+ "ELEMENT BODY LOCK: the pet itself must communicate "
		+ PetElementCatalog.prompt_name(identity.element())
		+ " at first glance even if the entire background is removed. "
		+ "Use clear anatomy-safe color zones, markings, surface material cues, fur/plumage/scale flow and small body-integrated magical accents. "
		+ "Do not make a normal animal and place it in an elemental scene. "
		+ "ELEMENT TRAITS: "
		+ _simple_element_traits(
			identity.element()
		)
		+ ". FAILURE CONDITION: if the creature still looks like an ordinary realistic "
		+ String(identity.species())
		+ " with the element expressed mainly by the scenery, the render is wrong."
	)

	spec.form_section = (
		"Stage 1. Young juvenile fantasy "
		+ String(identity.species())
		+ ", at the youngest end of the juvenile-to-adolescent range. "
		+ "Keep the pet youthful with its individual inherited frame. "
		+ species_profile.infant_form
		+ " "
		+ species_profile.species_anatomy
		+ " Keep fantasy anatomy species-safe, but make the elemental identity clearly visible on the pet."
	)

	spec.form_section += preload("res://features/evolution/visual/lineage_morphology.gd").new().build(identity, 1)

	spec.scene_section = (
		"PETHOME HABITAT: a complete natural fantasy environment for the "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ " element. Scene: "
		+ scene_profile.environment_theme
		+ ". Palette: "
		+ scene_profile.palette_description
		+ ". Lighting: "
		+ scene_profile.lighting_theme
		+ ". Motif: "
		+ scene_profile.motif_description
		+ ". The canvas visibly contains foreground ground, midground habitat and distant background depth. "
		+ "The habitat supports the creature but remains visually secondary: the pet must be the first thing the eye notices. "
		+ "Do not rely on the scenery alone to communicate the element; the element must already be obvious on the pet itself. "
		+ "The pet is clearly standing or sitting inside this world."
	)

	spec.composition_section = (
		"Exactly one pet, complete full body from ears to feet and tail. "
		+ "The pet is the clear primary subject and visual focal point. "
		+ "All body parts fit comfortably inside the canvas. "
		+ "The pet touches a visible ground surface and casts a soft contact shadow. "
		+ species_profile.composition
		+ " "
		+ species_profile.freestyle_pose
	)

	spec.ui_safe_section = (
		"PRIMARY COMPOSITION: vertical 9:16 environmental PetHome shot. PET FIRST: the creature is the unmistakable main subject, with the habitat secondary. "
		+ "Show exactly one complete full-body pet at a medium-close environmental distance. "
		+ "Pet height is about 50 to 56 percent of the full canvas height, roughly 30 percent larger on screen than the old PetHome framing, centered in the lower-middle. "
		+ "Keep enough ground around the feet and enough space around ears, tail and authorized appendages so nothing is cropped. "
		+ "Keep the upper 24 to 28 percent calm and lower-detail for the game HUD, but do not shrink or push the pet far into the distance to create this space. "
		+ "The pet must visually dominate the scene while the environment still reads clearly as a complete habitat. "
		+ "One full-body pet plus environment, no text and no interface graphics."
	)

	spec.future_space_section = (
		"Keep the design simple enough for later evolution."
	)

	spec.negative_prompt = (
		species_profile.forbidden_advanced_features
		+ ", duplicate anatomy, duplicate tail, extra tail, split tail, extra limb, extra ear, multiple pets, "
		+ "close-up portrait, extreme close-up, bust shot, pet filling the entire frame, pet taller than 64 percent of image height, tiny distant pet, pet smaller than 45 percent of image height, humanoid pose, "
		+ "cropped ears, cropped feet, cropped body, cropped tail, floating pet, missing contact with ground, "
		+ "heavy accessories, fully adult animal, old animal, ordinary realistic "
		+ String(identity.species())
		+ ", plain natural "
		+ String(identity.species())
		+ ", generic real-world animal, documentary animal photo, farm-animal photo, plain natural coat with no elemental signature, element visible only in background, "
		+ "plain white background, white studio background, gray studio background, empty backdrop, transparent backdrop, product photo, missing environment, text, UI, logo, watermark"
	)

	if not spec.is_valid():
		return null

	return spec


func _simple_element_traits(
	element: StringName
) -> String:
	match element:
		&"wood":
			return (
				"warm cream and light-brown body colors with clearly readable fresh-green zones, "
				+ "small but visible living sprouts integrated into existing head or ear covering, "
				+ "leaf-like surface tufts, layered leafy chest texture, "
				+ "clear vine or vein markings blended into the body surface, "
				+ "and a readable bud-shaped leafy tail-tip treatment where species anatomy allows. "
				+ "Plant features should look naturally grown as part of the pet, "
				+ "not like loose leaves stuck onto the fur"
			)

		&"earth":
			return (
				"warm cream, beige and earthy-brown body colors with clearly readable mineral tones, "
				+ "small smooth mineral or polished crystal accents integrated into existing body surfaces, "
				+ "especially around the forehead, chest and back, "
				+ "readable stone-grain markings and a grounded heavy surface rhythm. "
				+ "Mineral details should feel organically embedded in the body design, "
				+ "not like rocks randomly thrown onto the pet"
			)

		&"fire":
			return (
				"cream, peach and warm-orange body colors with clearly visible ember accents, "
				+ "small controlled living-flame highlights on existing tips or contours, "
				+ "readable glowing flame-shaped markings on the forehead and face, "
				+ "and warm ember lines flowing through the body surface. "
				+ "Fire should feel like magical living fur energy, "
				+ "not like the pet is burning uncontrollably"
			)

		&"light":
			return (
				"ivory and warm pearl-white body colors with clearly readable pale-gold zones, "
				+ "a visible luminous star or radiant-arc forehead mark, "
				+ "golden light woven naturally through existing surface flow and tail, "
				+ "an elegant controlled halo-like edge glow close to the silhouette, "
				+ "and a few gentle light particles. "
				+ "The light should feel soft, pure and magical, not overly bright or angelic"
			)

		&"metal":
			return (
				"silver-white and pale cool-gray body colors with clearly readable icy-blue accents, "
				+ "small polished metallic or crystal facets integrated into the forehead and body surface, "
				+ "clean geometric silver surface separations around chest and legs, "
				+ "fine metallic-looking strands around the tail and a refined reflective sheen. "
				+ "Metal details should feel elegant and organically integrated, "
				+ "not like armor or mechanical equipment"
			)

		&"water":
			return (
				"pearl-white and aqua body colors with strong readable turquoise zones, "
				+ "small translucent water-drop accents integrated into the forehead and body surface, "
				+ "wave-like surface flow, flowing aqua gradients along the face and tail, "
				+ "ripple-like markings, moist reflective highlights and a few close-body droplets. "
				+ "Water should feel naturally infused into the fur and body, "
				+ "not like the pet is simply wet"
			)

		&"dark":
			return (
				"smoky blue-black, charcoal-indigo and muted-violet body colors with clearly readable cyan-violet highlights, "
				+ "a visible crescent or astral forehead sigil, "
				+ "readable shadow-gradient surface markings and luminous eye accents, "
				+ "controlled dark mist woven close to the mane or ruff, tail and lower legs where anatomically appropriate, "
				+ "and elegant dark magical markings visibly integrated into the body surface. "
				+ "Dark energy should feel mysterious and integrated into the pet, "
				+ "not like galaxy texture or random purple effects covering the body"
			)
		_:
			return "soft elemental accents."
