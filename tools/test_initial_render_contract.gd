extends SceneTree


const PetIdentityFactoryScript = preload(
	"res://features/evolution/domain/pet_identity_factory.gd"
)
const PetGenomeFactoryScript = preload(
	"res://features/evolution/domain/pet_genome_factory.gd"
)
const PetSceneProfileFactoryScript = preload(
	"res://features/evolution/domain/pet_scene_profile_factory.gd"
)
const MythicStyleProfileScript = preload(
	"res://features/evolution/visual/mythic_style_profile.gd"
)
const InitialSpeciesCatalogScript = preload(
	"res://features/evolution/visual/initial_species_catalog.gd"
)
const InitialPetVisualSpecBuilderScript = preload(
	"res://features/evolution/visual/initial_pet_visual_spec_builder.gd"
)
const InitialPetPromptBuilderScript = preload(
	"res://features/evolution/visual/initial_pet_prompt_builder.gd"
)
const PetRenderRequestScript = preload(
	"res://features/evolution/render/pet_render_request.gd"
)
const MockPetRendererScript = preload(
	"res://features/evolution/render/mock_pet_renderer.gd"
)


var _failures: int = 0


func _initialize() -> void:
	var identity = (
		PetIdentityFactoryScript.new()
		.create_initial(
			7281,
			&"dark"
		)
	)
	var genome = (
		PetGenomeFactoryScript.new()
		.create_initial()
	)
	var scene_profile = (
		PetSceneProfileFactoryScript.new()
		.create_initial(identity)
	)
	var style = MythicStyleProfileScript.load_default()
	var catalog = InitialSpeciesCatalogScript.new()
	var species = catalog.find_by_species(
		catalog.load_default(),
		&"cat"
	)

	var spec = (
		InitialPetVisualSpecBuilderScript.new()
		.build(
			identity,
			genome,
			style,
			species,
			scene_profile
		)
	)

	_expect(
		spec != null and spec.is_valid(),
		"initial visual spec must be valid"
	)

	if spec == null:
		_finish()
		return

	var prompts = InitialPetPromptBuilderScript.new()
	var request = PetRenderRequestScript.new()
	request.mode = (
		PetRenderRequestScript
		.RenderMode
		.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = prompts.build_positive(
		spec
	)
	request.negative_prompt = prompts.build_negative(
		spec
	)
	request.output_key = "test_initial"

	_expect(
		request.is_valid()
		and request.source_image_path.is_empty(),
		"Stage 1 must be a valid text-to-image request"
	)

	_expect(
		request.positive_prompt.contains(
			"Create one young cat pet"
		)
		and request.positive_prompt.contains(
			"premium fantasy game character art"
		)
		and request.positive_prompt.contains(
			"evolved chibi proportions"
		)
		and request.positive_prompt.contains(
			"juvenile-to-adolescent"
		)
		and request.positive_prompt.contains(
			"polished stylized 3D appearance"
		)
		and request.positive_prompt.contains(
			"organically grown from or naturally integrated"
		)
		and request.positive_prompt.contains(
			"smoky blue-black, charcoal-indigo and muted violet"
		),
		"Stage 1 must use the approved premium fantasy / evolved-chibi direction"
	)

	_expect(
		request.positive_prompt.contains(
			"exactly one tail total"
		)
		and request.negative_prompt.contains(
			"duplicate tail"
		)
		and request.negative_prompt.contains(
			"extra limb"
		),
		"Stage 1 must explicitly protect basic cat anatomy"
	)

	_expect(
		request.positive_prompt.contains(
			"38 to 44 percent"
		)
		and request.positive_prompt.contains(
			"lower-middle"
		)
		and request.positive_prompt.contains(
			"56 to 62 percent"
		)
		and request.positive_prompt.contains(
			"Camera is pulled back"
		)
		and request.negative_prompt.contains(
			"pet taller than 48 percent"
		),
		"Stage 1 must keep the pet medium-small inside PetHome with stable UI-safe framing"
	)

	_expect(
		request.positive_prompt.contains(
			"PETHOME HABITAT"
		)
		and request.positive_prompt.contains(
			scene_profile.environment_theme
		)
		and request.positive_prompt.contains(
			scene_profile.palette_description
		)
		and request.positive_prompt.contains(
			scene_profile.lighting_theme
		)
		and request.positive_prompt.contains(
			scene_profile.motif_description
		)
		and request.negative_prompt.contains(
			"plain white background"
		)
		and request.positive_prompt.contains(
			"no text and no interface graphics"
		),
		"Stage 1 must render the actual element PetHome scene and reject blank/studio backgrounds"
	)

	_expect(
		request.positive_prompt.length() < 5600,
		"Stage 1 prompt must stay bounded even with element-specific integrated traits"
	)

	var renderer = MockPetRendererScript.new()
	var result = await renderer.render(request)

	_expect(
		result.success,
		"mock M5 renderer must accept valid initial request"
	)

	renderer.queue_free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("M5/M6 Initial Render Contract: PASS")
		quit(0)
		return

	push_error(
		"M5/M6 Initial Render Contract: FAIL (%d)"
		% _failures
	)
	quit(1)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
