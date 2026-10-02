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
	"Premium fantasy pet illustration, premium fantasy game character art, "
	+ "polished stylized 3D appearance, evolved chibi proportions, "
	+ "cute youthful species-appropriate proportions, large expressive eyes where anatomically suitable, soft premium surface detail, "
	+ "smooth clean shading, delicate soft rim lighting, clean readable silhouette, "
	+ "harmonious collectible game-pet design. "
	+ "Elemental features must feel organically grown from or naturally integrated into the fur and body design, "
	+ "not like random objects, stickers or loose decorations placed on the pet. "
	+ "Keep the elemental palette rich but controlled. "
	+ "Element traits: "
	+ _simple_element_traits(
		identity.element()
	)
)

	spec.form_section = (
		"Stage 1. Young juvenile fantasy "
		+ String(identity.species())
		+ ", at the youngest end of the juvenile-to-adolescent range. "
		+ "Keep the pet youthful with its individual inherited frame. "
		+ species_profile.infant_form
		+ " "
		+ species_profile.species_anatomy
		+ " Keep fantasy details subtle."
	)

	spec.form_section += preload("res://features/evolution/visual/lineage_morphology.gd").new().build(identity, 1)

	spec.scene_section = (
		"MANDATORY PETHOME ENVIRONMENT. Render a complete natural fantasy habitat clearly belonging to the "
		+ PetElementCatalog.prompt_name(
			identity.element()
		)
		+ " element. Environment identity: "
		+ scene_profile.environment_theme
		+ ". Palette: "
		+ scene_profile.palette_description
		+ ". Lighting: "
		+ scene_profile.lighting_theme
		+ ". Element motif: "
		+ scene_profile.motif_description
		+ ". Show readable foreground, midground and background depth. "
		+ "The habitat must remain visible across the full canvas and must immediately communicate the element. "
		+ "Never use a white, empty, transparent, product-photo or studio backdrop."
	)

	spec.composition_section = (
		"Exactly one pet. Full body visible from head to tail, including feet and all visible appendages. "
		+ "The pet must be physically grounded in the habitat with a soft natural contact shadow beneath it. "
		+ species_profile.composition
		+ " "
		+ species_profile.freestyle_pose
	)

	spec.ui_safe_section = (
		"Vertical 9:16 mobile environmental establishing shot with the camera pulled back. "
		+ "The environment is the main composition and the pet is a smaller focal subject living inside it. "
		+ "Keep the complete pet in the lower-middle area, centered slightly below the vertical midpoint. "
		+ "LOCKED PETHOME SCALE: the visible pet height should occupy about 38 to 44 percent of total image height. "
		+ "Place the lowest visible pet point around 88 to 90 percent of image height and keep the highest visible pet point around 46 to 52 percent. "
		+ "At least about 55 to 60 percent of the image must clearly read as environment, with foreground, midground and background depth. "
		+ "Leave generous environmental space around the silhouette and keep the upper 30 percent calm and low-detail for UI, especially the upper-left status area. "
		+ "Use a medium-wide environmental character shot, never a close-up or product portrait. "
		+ "Do not zoom in, do not crop ears, feet, body or tail, and do not let the pet fill the frame. No text or UI."
	)

	spec.future_space_section = (
		"Keep the design simple enough for later evolution."
	)

	spec.negative_prompt = (
		species_profile.forbidden_advanced_features
		+ ", duplicate anatomy, duplicate tail, extra tail, split tail, extra limb, extra ear, multiple pets, "
		+ "close-up portrait, extreme close-up, bust shot, pet filling the frame, oversized pet, pet taller than 48 percent of image height, zoomed-in camera, humanoid pose, "
		+ "cropped ears, cropped feet, cropped body, cropped tail, floating pet, missing contact with ground, "
		+ "heavy accessories, fully adult animal, old animal, plain white background, white studio background, gray studio background, empty backdrop, transparent backdrop, product photo, missing environment, text, UI, logo, watermark"
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
			return "soft elemental accents."
