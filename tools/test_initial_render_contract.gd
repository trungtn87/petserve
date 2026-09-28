extends SceneTree


const PetIdentityFactoryScript = preload(
	"res://features/evolution/domain/pet_identity_factory.gd"
)
const PetGenomeFactoryScript = preload(
	"res://features/evolution/domain/pet_genome_factory.gd"
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
		PetSceneProfileFactory.new()
		.create_initial(identity)
	)
	var style = (
		MythicStyleProfileScript.load_default()
	)
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
		request.is_valid(),
		"text-only initial request must be valid without source image"
	)

	_expect(
		request.source_image_path.is_empty(),
		"initial request must not require source image"
	)

	_expect(
		request.positive_prompt.contains(
			"first visual form"
		)
		and request.positive_prompt.contains(
			"Mythic Elemental Chibi"
		)
		and request.positive_prompt.contains(
			"single lineage sigil"
		)
		and request.positive_prompt.to_lower().contains(
			"dark"
		),
		"initial prompt must encode infant + mythic element identity"
	)

	_expect(
		request.positive_prompt.contains(
			"[PETHOME WORLD]"
		)
		and request.positive_prompt.contains(
			"[UI SAFE LAYOUT]"
		)
		and request.positive_prompt.to_lower().contains(
			"pethome environment"
		)
		and request.positive_prompt.to_lower().contains(
			"one coherent scene"
		),
		"initial prompt must render pet + PetHome background in one image"
	)

	_expect(
		request.negative_prompt.to_lower().contains(
			"neutral empty background"
		)
		and request.negative_prompt.to_lower().contains(
			"split image"
		),
		"initial negative prompt must reject pet-only and split outputs"
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
