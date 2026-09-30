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
		and request.positive_prompt.to_lower().contains(
			"dark"
		)
		and request.positive_prompt.contains(
			"AI has broad freedom to invent this individual pet"
		),
		"Stage 1 prompt must keep species/element style while leaving the individual design free"
	)

	_expect(
		request.positive_prompt.contains(
			"[PETHOME WORLD]"
		)
		and request.positive_prompt.contains(
			"[UI SAFE LAYOUT]"
		)
		and request.positive_prompt.contains(
			"natural environmental background"
		)
		and request.positive_prompt.contains(
			"loose inspiration"
		),
		"Stage 1 must generate a natural same-element environment without rigid scene continuity"
	)

	_expect(
		request.negative_prompt.to_lower().contains(
			"plain studio background"
		)
		and request.negative_prompt.to_lower().contains(
			"split image"
		)
		and request.negative_prompt.to_lower().contains(
			"fixed template character"
		),
		"Stage 1 negative prompt must reject studio/template outputs"
	)

	_expect(
		request.positive_prompt.to_lower().contains(
			"full-bleed vertical 9:16"
		)
		and request.positive_prompt.to_lower().contains(
			"35 percent"
		)
		and request.positive_prompt.to_lower().contains(
			"90 percent"
		)
		and request.positive_prompt.to_lower().contains(
			"upper 24 to 28 percent"
		),
		"Stage 1 must keep only the required PetHome mobile composition"
	)

	_expect(
		request.positive_prompt.contains(
			"natural animal pose"
		)
		and request.positive_prompt.contains(
			"[STAGE 1 ELEMENTAL IDENTITY CUES]"
		)
		and request.positive_prompt.contains(
			"narrow expressive feline face"
		)
		and request.positive_prompt.contains(
			"crescent forehead sigil"
		)
		and request.positive_prompt.contains(
			"different pets of the same element still look unique"
		)
		and not request.positive_prompt.contains(
			"front three-quarter view"
		),
		"Stage 1 must use element-specific lineage cues while keeping individual variation"
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
