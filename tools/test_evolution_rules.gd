extends SceneTree


const PetIdentityFactoryScript = preload(
	"res://features/evolution/domain/pet_identity_factory.gd"
)
const PetGenomeFactoryScript = preload(
	"res://features/evolution/domain/pet_genome_factory.gd"
)
const MutationCatalogScript = preload(
	"res://features/evolution/rules/mutation_catalog.gd"
)
const EvolutionRuleEngineScript = preload(
	"res://features/evolution/rules/evolution_rule_engine.gd"
)
const GenomeDeltaApplierScript = preload(
	"res://features/evolution/rules/genome_delta_applier.gd"
)


var _failures: int = 0


func _initialize() -> void:
	_test_catalog()
	_test_deterministic_choice()
	_test_apply_one_small_delta()
	_test_no_repeat_mutation()
	_test_stage_filter()
	_test_trait_chain()
	_test_old_genome_is_unchanged()

	if _failures == 0:
		print("M3 Evolution Rules: PASS")
		quit(0)
		return

	push_error(
		"M3 Evolution Rules: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_catalog() -> void:
	var definitions = (
		MutationCatalogScript.new()
		.load_default()
	)

	_expect(
		definitions.size() >= 8,
		"default mutation catalog must load"
	)

	var seen: Dictionary = {}

	for definition in definitions:
		_expect(
			definition != null
			and definition.is_valid(),
			"every mutation definition must be valid"
		)

		if definition == null:
			continue

		_expect(
			not seen.has(definition.id()),
			"mutation ids must be unique"
		)

		seen[definition.id()] = true


func _test_deterministic_choice() -> void:
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
	var definitions = (
		MutationCatalogScript.new()
		.load_default()
	)
	var engine = EvolutionRuleEngineScript.new()

	var a = engine.choose_next(
		identity,
		genome,
		definitions
	)
	var b = engine.choose_next(
		identity,
		genome,
		definitions
	)

	_expect(
		a != null
		and b != null
		and a.mutation_id() == b.mutation_id(),
		"same identity + genome must choose same mutation"
	)


func _test_apply_one_small_delta() -> void:
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
	var definitions = (
		MutationCatalogScript.new()
		.load_default()
	)

	var delta = (
		EvolutionRuleEngineScript.new()
		.choose_next(
			identity,
			genome,
			definitions
		)
	)

	var next_genome = (
		GenomeDeltaApplierScript.new()
		.apply(
			genome,
			delta
		)
	)

	_expect(
		next_genome != null,
		"valid delta must create next genome"
	)

	if next_genome == null:
		return

	_expect(
		next_genome.stage() == genome.stage(),
		"M3 mutation must not silently change stage"
	)

	_expect(
		is_equal_approx(
			next_genome.body_growth(),
			genome.body_growth()
		),
		"M3 mutation must not silently change body growth"
	)

	_expect(
		next_genome.get_trait(
			delta.target_trait()
		) == delta.to_trait(),
		"delta must change exactly its target trait"
	)

	_expect(
		next_genome.has_mutation(
			delta.mutation_id()
		),
		"delta mutation id must be recorded"
	)


func _test_no_repeat_mutation() -> void:
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
	var definitions = (
		MutationCatalogScript.new()
		.load_default()
	)
	var engine = EvolutionRuleEngineScript.new()
	var applier = GenomeDeltaApplierScript.new()

	var first = engine.choose_next(
		identity,
		genome,
		definitions
	)
	var next_genome = applier.apply(
		genome,
		first
	)
	var second = engine.choose_next(
		identity,
		next_genome,
		definitions
	)

	_expect(
		first != null
		and second != null
		and first.mutation_id()
			!= second.mutation_id(),
		"same mutation id must not repeat in one genome"
	)


func _test_stage_filter() -> void:
	var catalog = MutationCatalogScript.new()
	var definitions = catalog.load_default()

	var definition = catalog.find_by_id(
		definitions,
		&"astral_neck_fur"
	)

	var identity = (
		PetIdentityFactoryScript.new()
		.create_initial(
			7281,
			&"dark"
		)
	)
	var factory = PetGenomeFactoryScript.new()

	var stage_one = factory.create_initial()
	var stage_two = factory.create_snapshot(
		2,
		0.4,
		stage_one.traits_snapshot(),
		stage_one.mutation_ids()
	)

	_expect(
		definition != null
		and not definition.is_compatible(
			identity,
			stage_one
		)
		and definition.is_compatible(
			identity,
			stage_two
		),
		"min_stage must filter mutation eligibility"
	)


func _test_trait_chain() -> void:
	var catalog = MutationCatalogScript.new()
	var definitions = catalog.load_default()

	var twin_tip = catalog.find_by_id(
		definitions,
		&"tail_twin_tip"
	)

	var identity = (
		PetIdentityFactoryScript.new()
		.create_initial(
			7281,
			&"dark"
		)
	)
	var factory = PetGenomeFactoryScript.new()

	var stage_two_base = factory.create_snapshot(
		2,
		0.4,
		{
			"fur": "base",
			"eyes": "base",
			"ears": "base",
			"tail": "base",
			"mark": "base",
		},
		[]
	)

	var stage_two_long_tail = (
		factory.create_snapshot(
			2,
			0.4,
			{
				"fur": "base",
				"eyes": "base",
				"ears": "base",
				"tail": "long_fluffy",
				"mark": "base",
			},
			[
				"tail_long_fluffy",
			]
		)
	)

	_expect(
		twin_tip != null
		and not twin_tip.is_compatible(
			identity,
			stage_two_base
		)
		and twin_tip.is_compatible(
			identity,
			stage_two_long_tail
		),
		"mutation chain must require the previous trait"
	)


func _test_old_genome_is_unchanged() -> void:
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
	var definitions = (
		MutationCatalogScript.new()
		.load_default()
	)

	var delta = (
		EvolutionRuleEngineScript.new()
		.choose_next(
			identity,
			genome,
			definitions
		)
	)

	var old_traits := genome.traits_snapshot()
	var old_mutations := genome.mutation_ids()

	GenomeDeltaApplierScript.new().apply(
		genome,
		delta
	)

	_expect(
		genome.traits_snapshot() == old_traits
		and genome.mutation_ids() == old_mutations,
		"applying delta must not mutate old genome snapshot"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
