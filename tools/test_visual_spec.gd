extends SceneTree


const PetIdentityFactoryScript = preload(
	"res://features/evolution/domain/pet_identity_factory.gd"
)
const PetGenomeFactoryScript = preload(
	"res://features/evolution/domain/pet_genome_factory.gd"
)
const EvolutionDeltaScript = preload(
	"res://features/evolution/domain/evolution_delta.gd"
)
const MutationCatalogScript = preload(
	"res://features/evolution/rules/mutation_catalog.gd"
)
const GenomeDeltaApplierScript = preload(
	"res://features/evolution/rules/genome_delta_applier.gd"
)
const GalaxyStyleProfileScript = preload(
	"res://features/evolution/visual/galaxy_style_profile.gd"
)
const MutationVisualCatalogScript = preload(
	"res://features/evolution/visual/mutation_visual_catalog.gd"
)
const PetVisualSpecBuilderScript = preload(
	"res://features/evolution/visual/pet_visual_spec_builder.gd"
)
const PetPromptBuilderScript = preload(
	"res://features/evolution/visual/pet_prompt_builder.gd"
)


var _failures: int = 0


func _initialize() -> void:
	_test_style_profile()
	_test_visual_catalog_matches_mutation_catalog()
	_test_build_visual_spec()
	_test_prompt_contract()
	_test_rejects_unrelated_trait_change()

	if _failures == 0:
		print("M4 Visual Spec: PASS")
		quit(0)
		return

	push_error(
		"M4 Visual Spec: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_style_profile() -> void:
	var style = (
		GalaxyStyleProfileScript
		.load_default()
	)

	_expect(
		style != null and style.is_valid(),
		"galaxy style profile must load"
	)

	if style == null:
		return

	for element in [
		&"metal",
		&"wood",
		&"water",
		&"fire",
		&"earth",
		&"dark",
		&"light",
	]:
		_expect(
			not style.accent_for(
				element
			).is_empty(),
			"all seven elements need galaxy accent text"
		)


func _test_visual_catalog_matches_mutation_catalog() -> void:
	var mutations = (
		MutationCatalogScript.new()
		.load_default()
	)
	var visual_catalog = (
		MutationVisualCatalogScript.new()
	)
	var visuals = visual_catalog.load_default()

	_expect(
		visuals.size() == mutations.size(),
		"every M3 mutation needs one M4 visual definition"
	)

	for mutation in mutations:
		var visual = visual_catalog.find_by_id(
			visuals,
			mutation.id()
		)

		_expect(
			visual != null
			and visual.target_region()
				== mutation.target_trait(),
			"visual definition must match mutation target: %s"
			% String(mutation.id())
		)


func _test_build_visual_spec() -> void:
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

	var mutation_catalog = (
		MutationCatalogScript.new()
	)
	var mutations = mutation_catalog.load_default()
	var mutation = mutation_catalog.find_by_id(
		mutations,
		&"galaxy_eye_ring"
	)

	var delta = EvolutionDeltaScript.new(
		mutation.id(),
		mutation.target_trait(),
		mutation.required_trait(),
		mutation.result_trait(),
		1
	)

	var next_genome = (
		GenomeDeltaApplierScript.new()
		.apply(
			genome,
			delta
		)
	)

	var visual_catalog = (
		MutationVisualCatalogScript.new()
	)
	var visual = visual_catalog.find_by_id(
		visual_catalog.load_default(),
		delta.mutation_id()
	)

	var spec = (
		PetVisualSpecBuilderScript.new()
		.build(
			identity,
			genome,
			next_genome,
			delta,
			GalaxyStyleProfileScript.load_default(),
			visual
		)
	)

	_expect(
		spec != null and spec.is_valid(),
		"valid M3 delta must build valid visual spec"
	)

	if spec == null:
		return

	_expect(
		spec.pet_id() == identity.pet_id(),
		"visual spec must retain source pet_id"
	)

	_expect(
		spec.target_region() == &"eyes",
		"eye mutation must target only eyes"
	)

	_expect(
		spec.edit_strength() < 0.30,
		"single small mutation should use restrained edit strength"
	)


func _test_prompt_contract() -> void:
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
	var mutation_catalog = (
		MutationCatalogScript.new()
	)
	var mutation = mutation_catalog.find_by_id(
		mutation_catalog.load_default(),
		&"galaxy_eye_ring"
	)

	var delta = EvolutionDeltaScript.new(
		mutation.id(),
		mutation.target_trait(),
		mutation.required_trait(),
		mutation.result_trait(),
		1
	)

	var next_genome = (
		GenomeDeltaApplierScript.new()
		.apply(
			genome,
			delta
		)
	)

	var visual_catalog = (
		MutationVisualCatalogScript.new()
	)
	var visual = visual_catalog.find_by_id(
		visual_catalog.load_default(),
		delta.mutation_id()
	)

	var spec = (
		PetVisualSpecBuilderScript.new()
		.build(
			identity,
			genome,
			next_genome,
			delta,
			GalaxyStyleProfileScript.load_default(),
			visual
		)
	)

	var prompt_builder = (
		PetPromptBuilderScript.new()
	)
	var positive := (
		prompt_builder.build_positive(spec)
	)
	var negative := (
		prompt_builder.build_negative(spec)
	)

	_expect(
		positive.contains(
			"[IDENTITY LOCK]"
		)
		and positive.contains(
			"[GALAXY STYLE]"
		)
		and positive.contains(
			"[CHANGE ONLY]"
		)
		and positive.contains(
			"[PRESERVE]"
		),
		"positive prompt must preserve section contract"
	)

	_expect(
		positive.to_lower().contains(
			"same individual"
		),
		"prompt must explicitly lock same-individual identity"
	)

	_expect(
		positive.contains(
			"Galaxy Fantasy Chibi"
		),
		"prompt must lock Galaxy Fantasy Chibi style"
	)

	_expect(
		negative.to_lower().contains(
			"identity drift"
		),
		"negative prompt must reject identity drift"
	)


func _test_rejects_unrelated_trait_change() -> void:
	var identity = (
		PetIdentityFactoryScript.new()
		.create_initial(
			7281,
			&"dark"
		)
	)
	var factory = PetGenomeFactoryScript.new()
	var previous = factory.create_initial()

	var delta = EvolutionDeltaScript.new(
		&"galaxy_eye_ring",
		&"eyes",
		&"base",
		&"galaxy_ring",
		1
	)

	var bad_next = factory.create_snapshot(
		1,
		0.0,
		{
			"fur": "base",
			"eyes": "galaxy_ring",
			"ears": "base",
			"tail": "long_fluffy",
			"mark": "base",
		},
		[
			"galaxy_eye_ring",
		]
	)

	var visual_catalog = (
		MutationVisualCatalogScript.new()
	)
	var visual = visual_catalog.find_by_id(
		visual_catalog.load_default(),
		delta.mutation_id()
	)

	var spec = (
		PetVisualSpecBuilderScript.new()
		.build(
			identity,
			previous,
			bad_next,
			delta,
			GalaxyStyleProfileScript.load_default(),
			visual
		)
	)

	_expect(
		spec == null,
		"M4 must reject a render request that changes an unrelated trait"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
